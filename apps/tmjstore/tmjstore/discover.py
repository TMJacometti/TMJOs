"""Descobre apps TMJOs via AppStream metadata + APT.

Estratégia:
1. Lista todos os pacotes do APT repo TMJOs (origin=tmjos)
2. Pra cada pacote, lê AppStream XML em /usr/share/metainfo/ (se
   instalado) OU consulta `apt show` pra metadata mínima
3. Returna lista de TMJApp com nome, descrição, ícone, install state

Pra v0.1 minimalista: usa apt-cache + /usr/share/metainfo XML files.
Quando madurar, migra pra libappstream-glib via PyGObject (parsing
metadata centralizado, suporte release history, screenshots, etc).
"""

from __future__ import annotations

import os
import re
import subprocess
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path


# Paths onde procurar AppStream metadata. Ordem importa — primeiro
# user-local (override possível), depois system. Os pacotes .deb
# instalam em /usr/share/metainfo/; dev mode via `make install` em
# ~/.local/share/metainfo/.
#
# Incluímos AMBOS XDG_DATA_HOME E o literal ~/.local/share porque
# alguns ambientes (VSCode snap-confined, Flatpak portals) setam
# XDG_DATA_HOME pra um path sandboxed que NÃO bate com o user real.
def _metainfo_dirs() -> list[Path]:
    paths: list[Path] = []
    xdg_home = os.environ.get("XDG_DATA_HOME")
    if xdg_home:
        paths.append(Path(xdg_home) / "metainfo")
    home_local = Path.home() / ".local/share/metainfo"
    if home_local not in paths:
        paths.append(home_local)
    paths.append(Path("/usr/share/metainfo"))
    return paths


METAINFO_DIRS = _metainfo_dirs()

# Cache local de AppStream metadata. Mantém appdata.xml dos apps
# vistos pelo TMJStore mesmo após uninstall — senão o user veria
# nome/icon/descrição fallback no card de um app que ele já conhece
# (caso típico: TMJPad instalado → metadados ricos; remove TMJPad →
# /usr/share/metainfo/ perde o XML → discover não acha → card pobre).
_CACHE_BASE = Path(
    os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))
) / "tmjstore"
_CACHE_DIR = _CACHE_BASE / "appdata"
ICON_CACHE_DIR = _CACHE_BASE / "icons"


def _cache_appdata(pkg: str, xml_path: Path) -> None:
    """Copia appdata.xml pro cache local (idempotente)."""
    try:
        _CACHE_DIR.mkdir(parents=True, exist_ok=True)
        dest = _CACHE_DIR / f"{pkg}.appdata.xml"
        # Skip se já cached com mesma mtime
        if dest.exists() and dest.stat().st_mtime >= xml_path.stat().st_mtime:
            return
        dest.write_bytes(xml_path.read_bytes())
    except OSError:
        pass


def _cached_appdata_path(pkg: str) -> Path | None:
    """Retorna path do appdata cacheado, ou None se não existe."""
    p = _CACHE_DIR / f"{pkg}.appdata.xml"
    return p if p.is_file() else None


def _cache_icon(pkg: str) -> None:
    """Cacheia o icon do pacote se encontrar em path conhecido.

    Procura em /usr/share/pixmaps/<pkg>.png ou
    /usr/share/icons/hicolor/512x512/apps/<pkg>.png. Copia pro
    cache pra sobreviver uninstall.
    """
    candidates = [
        Path(f"/usr/share/pixmaps/{pkg}.png"),
        Path(f"/usr/share/icons/hicolor/512x512/apps/{pkg}.png"),
        Path(f"/usr/share/icons/hicolor/256x256/apps/{pkg}.png"),
    ]
    for src in candidates:
        if src.is_file():
            try:
                ICON_CACHE_DIR.mkdir(parents=True, exist_ok=True)
                dest = ICON_CACHE_DIR / f"{pkg}.png"
                if (not dest.exists()
                        or dest.stat().st_mtime < src.stat().st_mtime):
                    dest.write_bytes(src.read_bytes())
            except OSError:
                pass
            return


def cached_icon_path(pkg: str) -> Path | None:
    """Retorna path do icon cacheado, ou None."""
    p = ICON_CACHE_DIR / f"{pkg}.png"
    return p if p.is_file() else None


def _apt_cache_metadata(pkg: str) -> dict:
    """Tier 2 fallback: extrai metadata via `apt-cache show <pkg>`.

    Sempre funciona pra qualquer pacote no APT repo, mesmo nunca
    instalado. Não tem releases/screenshots, mas tem nome + Description
    (longa, do debian/control).

    Apt show output:
        Package: tmjpad
        Architecture: all
        Version: 0.1.2-1
        Description: TMJOs text editor with full session persistence
         TMJPad is the native TMJOs text editor...
         More multi-line description with leading space.
    """
    out: dict = {"display_name": "", "summary": "", "description": ""}
    try:
        result = subprocess.run(
            ["apt-cache", "show", pkg],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode != 0:
            return out

        lines = result.stdout.splitlines()
        in_desc = False
        desc_lines: list[str] = []
        for line in lines:
            if line.startswith("Description:") or line.startswith("Description-en:"):
                # primeira linha é o summary (single-line)
                _, _, summary = line.partition(":")
                out["summary"] = summary.strip()
                in_desc = True
                continue
            if in_desc:
                # Continuation lines começam com espaço (e ".\n" pra
                # paragraph break em debian-style)
                if line.startswith(" "):
                    stripped = line[1:]  # remove leading space
                    if stripped == ".":
                        desc_lines.append("")  # paragraph break
                    else:
                        desc_lines.append(stripped)
                else:
                    # Field novo — fim da Description
                    break

        if desc_lines:
            # Junta com newlines, depois colapsa runs de empty pra "\n\n"
            text = "\n".join(desc_lines)
            # Normaliza paragrafos (collapse runs de \n vazias)
            paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
            out["description"] = "\n\n".join(paragraphs)
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return out


# Origens válidas do APT repo TMJOs. Lista pra cobrir:
#   - packages.tmjos.com.br (custom domain atual)
#   - tmjacometti.github.io/TMJOs (URL legacy GH Pages, ainda válida)
#   - 192.168.* IPs (dev local serving via python -m http.server)
# A check é case-insensitive substring no output do apt-cache policy.
TMJ_REPO_ORIGINS = [
    "packages.tmjos.com.br",
    "tmjacometti.github.io/tmjos",
]
# Pacotes "core" da suite TMJOs — NÃO devem aparecer no TMJStore.
# TMJStore é pra apps USER-FACING (TMJPad, TMJCode, TMJNotes futuros,
# etc). O próprio TMJStore + TMJMenu/TMJDock são infraestrutura da
# suite — desinstalar via TMJStore quebraria a experiência. User que
# realmente quer remover usa `sudo apt remove tmjmenu` no terminal
# (força extra de "sei o que tô fazendo").
CORE_PACKAGES = frozenset({
    "tmjmenu",   # launcher + dock — infra da suite
    "tmjstore",  # o próprio software center
})


@dataclass
class TMJRelease:
    """Uma entrada de release history do AppStream XML."""
    version: str
    date: str         # "2026-05-10"
    description: str  # multi-line


@dataclass
class TMJApp:
    """Representa um app TMJOs no APT repo."""
    pkg_name: str            # ex: "tmjpad"
    display_name: str        # ex: "TMJPad"
    summary: str             # uma linha
    description: str         # multi-paragrafo
    icon_name: str           # nome no theme OU path absoluto
    installed: bool
    installed_version: str = ""
    candidate_version: str = ""
    homepage: str = ""
    bugtracker: str = ""
    vcs: str = ""
    developer: str = ""
    license: str = ""
    categories: list[str] = field(default_factory=list)
    keywords: list[str] = field(default_factory=list)
    releases: list[TMJRelease] = field(default_factory=list)
    has_update: bool = False


def _list_tmj_packages() -> list[str]:
    """Retorna nomes de pacotes do APT repo TMJOs.

    Usa `apt-cache madison` filtrando por origin. Mais robusto que
    grepar `apt list` porque parser estável.
    """
    pkg_names: set[str] = set()
    try:
        # apt-cache search '' lista tudo — vamos filtrar por policy
        result = subprocess.run(
            ["apt-cache", "search", "tmjos"],
            capture_output=True, text=True, timeout=10,
        )
        for line in result.stdout.splitlines():
            # "tmjpad - Editor de texto..."
            parts = line.split(" - ", 1)
            if parts:
                pkg_names.add(parts[0].strip())
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    # Filtra: do nosso repo + não-core (core fica invisível —
    # protegido contra acidente de uninstall).
    tmj_pkgs = []
    for name in pkg_names:
        if name in CORE_PACKAGES:
            continue
        if _is_from_tmj_repo(name):
            tmj_pkgs.append(name)
    return sorted(tmj_pkgs)


def _is_from_tmj_repo(pkg_name: str) -> bool:
    """Confirma que o pacote vem de algum APT repo TMJOs.

    Aceita múltiplas origens válidas (packages.tmjos.com.br atual,
    tmjacometti.github.io/tmjos legacy). Match case-insensitive
    pra robustez.
    """
    try:
        result = subprocess.run(
            ["apt-cache", "policy", pkg_name],
            capture_output=True, text=True, timeout=5,
        )
        output_lower = result.stdout.lower()
        return any(origin in output_lower for origin in TMJ_REPO_ORIGINS)
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def _parse_appdata_xml(path: Path) -> dict:
    """Parse completo do AppStream XML.

    Não usa libappstream-glib (dep extra) pra manter v0.1 simple.
    Pega: nome, summary, description (multi-paragraph + lists),
    categories, keywords, urls, developer, releases.
    """
    out: dict = {
        "display_name": "",
        "summary": "",
        "description": "",
        "categories": [],
        "keywords": [],
        "homepage": "",
        "bugtracker": "",
        "vcs": "",
        "developer": "",
        "license": "",
        "releases": [],
    }
    try:
        tree = ET.parse(path)
        root = tree.getroot()

        # Strip XML namespace se existir
        ns_pattern = re.compile(r'^\{.*\}')

        def tag(elem):
            return ns_pattern.sub('', elem.tag)

        def get_lang(elem):
            return elem.get("{http://www.w3.org/XML/1998/namespace}lang", "")

        def parse_description(elem) -> str:
            """Description pode ter <p>, <ul><li>, <ol><li>. Renderiza
            como texto plain com bullets pra UI."""
            parts = []
            for child in elem:
                t = tag(child)
                if t == "p" and child.text:
                    parts.append(child.text.strip())
                elif t in ("ul", "ol"):
                    bullets = []
                    for li in child:
                        if tag(li) == "li" and li.text:
                            bullets.append(f"  • {li.text.strip()}")
                    if bullets:
                        parts.append("\n".join(bullets))
            return "\n\n".join(parts)

        for child in root:
            t = tag(child)
            if t == "name" and child.text and not out["display_name"]:
                if not get_lang(child):
                    out["display_name"] = child.text.strip()
            elif t == "summary" and child.text and not out["summary"]:
                if not get_lang(child):
                    out["summary"] = child.text.strip()
            elif t == "description":
                out["description"] = parse_description(child)
            elif t == "categories":
                out["categories"] = [
                    c.text.strip() for c in child
                    if tag(c) == "category" and c.text
                ]
            elif t == "keywords":
                out["keywords"] = [
                    k.text.strip() for k in child
                    if tag(k) == "keyword" and k.text
                ]
            elif t == "url":
                kind = child.get("type", "")
                if child.text:
                    if kind == "homepage":
                        out["homepage"] = child.text.strip()
                    elif kind == "bugtracker":
                        out["bugtracker"] = child.text.strip()
                    elif kind == "vcs-browser":
                        out["vcs"] = child.text.strip()
            elif t == "developer":
                for c in child:
                    if tag(c) == "name" and c.text:
                        out["developer"] = c.text.strip()
                        break
            elif t == "project_license" and child.text:
                out["license"] = child.text.strip()
            elif t == "releases":
                releases = []
                for r in child:
                    if tag(r) == "release":
                        ver = r.get("version", "")
                        date = r.get("date", "")
                        desc = ""
                        for c in r:
                            if tag(c) == "description":
                                desc = parse_description(c)
                                break
                        if ver:
                            releases.append(TMJRelease(
                                version=ver, date=date, description=desc,
                            ))
                out["releases"] = releases
    except (ET.ParseError, OSError):
        pass
    return out


def _pkg_versions(pkg_name: str) -> tuple[bool, str, str]:
    """Retorna (installed, installed_version, candidate_version)."""
    installed = False
    inst_ver = ""
    cand_ver = ""
    try:
        result = subprocess.run(
            ["apt-cache", "policy", pkg_name],
            capture_output=True, text=True, timeout=5,
        )
        for line in result.stdout.splitlines():
            line = line.strip()
            if line.startswith("Installed:"):
                v = line.split(":", 1)[1].strip()
                if v != "(none)":
                    installed = True
                    inst_ver = v
            elif line.startswith("Candidate:"):
                cand_ver = line.split(":", 1)[1].strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return installed, inst_ver, cand_ver


def discover_tmj_apps() -> list[TMJApp]:
    """Função principal: retorna lista de TMJApps disponíveis no APT repo."""
    apps: list[TMJApp] = []

    for pkg in _list_tmj_packages():
        installed, inst_ver, cand_ver = _pkg_versions(pkg)
        has_update = installed and inst_ver != cand_ver and cand_ver != ""

        # Tenta achar appdata.xml em ordem:
        # 1. metainfo dirs (XDG user, system) — fonte autoritativa
        #    quando app está instalado.
        # 2. cache local (~/.cache/tmjstore/appdata/) — fallback pra
        #    apps já desinstalados (perdem /usr/share/metainfo/ entry
        #    mas o user já conhecia os metadados pelo install anterior).
        # Quando acha na fonte autoritativa, atualiza o cache.
        appdata: dict = {}
        found_xml: Path | None = None
        for metainfo_dir in METAINFO_DIRS:
            if not metainfo_dir.is_dir():
                continue
            for xml in metainfo_dir.glob(f"*{pkg}*.appdata.xml"):
                found_xml = xml
                break
            if found_xml is not None:
                break

        if found_xml is not None:
            appdata = _parse_appdata_xml(found_xml)
            _cache_appdata(pkg, found_xml)
            # Aproveita pra cachear o icon enquanto app tá instalado
            _cache_icon(pkg)
        else:
            # Tier 1: cache local
            cached = _cached_appdata_path(pkg)
            if cached is not None:
                appdata = _parse_appdata_xml(cached)
            else:
                # Tier 2: apt-cache show — funciona sempre pra apps
                # no APT repo, mesmo nunca instalados nem vistos antes.
                # Não tem releases/screenshots/categories, mas tem
                # name + description (do debian/control).
                appdata = _apt_cache_metadata(pkg)

        # Fallback: nome capitalizado se não tem appdata
        display_name = appdata.get("display_name") or pkg.title()
        summary = appdata.get("summary") or f"Pacote {pkg}"

        apps.append(TMJApp(
            pkg_name=pkg,
            display_name=str(display_name),
            summary=str(summary),
            description=str(appdata.get("description", "")),
            icon_name=pkg,
            installed=installed,
            installed_version=inst_ver,
            candidate_version=cand_ver,
            homepage=str(appdata.get("homepage", "")),
            bugtracker=str(appdata.get("bugtracker", "")),
            vcs=str(appdata.get("vcs", "")),
            developer=str(appdata.get("developer", "")),
            license=str(appdata.get("license", "")),
            categories=list(appdata.get("categories", []) or []),
            keywords=list(appdata.get("keywords", []) or []),
            releases=list(appdata.get("releases", []) or []),
            has_update=has_update,
        ))

    return apps
