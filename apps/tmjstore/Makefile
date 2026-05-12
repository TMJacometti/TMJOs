.PHONY: run test install uninstall clean

run:
	python3 -m tmjstore.app

test:
	python3 -m pytest tests/ -v

install:
	pip install --user .
	install -Dm644 data/tmjstore.desktop ~/.local/share/applications/tmjstore.desktop
	install -Dm644 data/br.com.tmjsistemas.tmjstore.appdata.xml \
		~/.local/share/metainfo/br.com.tmjsistemas.tmjstore.appdata.xml
	@echo "TMJStore instalado. Rode: tmjstore"

uninstall:
	pip uninstall -y tmjstore
	rm -f ~/.local/share/applications/tmjstore.desktop
	rm -f ~/.local/share/metainfo/br.com.tmjsistemas.tmjstore.appdata.xml

clean:
	rm -rf build/ dist/ *.egg-info __pycache__ tmjstore/__pycache__ tests/__pycache__ .pytest_cache
