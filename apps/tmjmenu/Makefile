.PHONY: run test install uninstall clean

run:
	python3 -m tmjmenu.app

test:
	python3 -m pytest tests/ -v

install:
	pip install --user .
	install -Dm644 data/tmjmenu.desktop ~/.local/share/applications/tmjmenu.desktop
	@echo "TMJMenu instalado. Rode: tmjmenu"

uninstall:
	pip uninstall -y tmjmenu
	rm -f ~/.local/share/applications/tmjmenu.desktop

clean:
	rm -rf build/ dist/ *.egg-info __pycache__ tmjmenu/__pycache__ tests/__pycache__ .pytest_cache
