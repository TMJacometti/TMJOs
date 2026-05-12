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


TMJ_REPO_ORIGIN = "packages.tmjos.com.br"
METAINFO_DIR = Path("/usr/share/metainfo")


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
    categories: list[str] = field(default_factory=list)
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

    # Filtra só pacotes com nossa origin
    tmj_pkgs = []
    for name in pkg_names:
        if _is_from_tmj_repo(name):
            tmj_pkgs.append(name)
    return sorted(tmj_pkgs)


def _is_from_tmj_repo(pkg_name: str) -> bool:
    """Confirma que o pacote vem do APT repo TMJOs (não outro)."""
    try:
        result = subprocess.run(
            ["apt-cache", "policy", pkg_name],
            capture_output=True, text=True, timeout=5,
        )
        return TMJ_REPO_ORIGIN in result.stdout
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def _parse_appdata_xml(path: Path) -> dict[str, str | list[str]]:
    """Parse simple do AppStream XML — nome, descrição, ícone, categorias.

    Não usa libappstream-glib (dep extra) pra manter v0.1 simple.
    Schema parsing manual de elementos chave.
    """
    out: dict[str, str | list[str]] = {
        "display_name": "",
        "summary": "",
        "description": "",
        "categories": [],
        "homepage": "",
        "icon": "",
    }
    try:
        tree = ET.parse(path)
        root = tree.getroot()

        # Strip XML namespace se existir
        ns_pattern = re.compile(r'^\{.*\}')

        def tag(elem):
            return ns_pattern.sub('', elem.tag)

        for child in root:
            t = tag(child)
            if t == "name" and child.text and not out["display_name"]:
                out["display_name"] = child.text.strip()
            elif t == "summary" and child.text and not out["summary"]:
                # primeiro sem xml:lang (locale default)
                if "lang" not in child.attrib:
                    out["summary"] = child.text.strip()
            elif t == "description":
                parts = []
                for p in child:
                    if tag(p) == "p" and p.text:
                        parts.append(p.text.strip())
                out["description"] = "\n\n".join(parts)
            elif t == "categories":
                out["categories"] = [
                    c.text.strip() for c in child
                    if tag(c) == "category" and c.text
                ]
            elif t == "url":
                if child.get("type") == "homepage" and child.text:
                    out["homepage"] = child.text.strip()
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

        # Tenta achar appdata.xml correspondente
        appdata: dict[str, str | list[str]] = {}
        if installed and METAINFO_DIR.is_dir():
            for xml in METAINFO_DIR.glob(f"*{pkg}*.appdata.xml"):
                appdata = _parse_appdata_xml(xml)
                break

        # Fallback: nome capitalizado se não tem appdata
        display_name = appdata.get("display_name") or pkg.title()
        summary = appdata.get("summary") or f"Pacote {pkg}"

        apps.append(TMJApp(
            pkg_name=pkg,
            display_name=str(display_name),
            summary=str(summary),
            description=str(appdata.get("description", "")),
            icon_name=pkg,  # ícone tem nome igual do pacote por convenção
            installed=installed,
            installed_version=inst_ver,
            candidate_version=cand_ver,
            homepage=str(appdata.get("homepage", "")),
            categories=list(appdata.get("categories", []) or []),
            has_update=has_update,
        ))

    return apps
