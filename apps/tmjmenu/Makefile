.PHONY: run run-dock test install uninstall clean

run:
	python3 -m tmjmenu.app

run-dock:
	python3 -m tmjmenu.dock

test:
	python3 -m pytest tests/ -v

install:
	pip install --user .
	install -Dm644 data/tmjmenu.desktop ~/.local/share/applications/tmjmenu.desktop
	install -Dm644 data/tmjdock.desktop ~/.config/autostart/tmjdock.desktop
	install -Dm644 data/tmjmenu-first-run.desktop ~/.config/autostart/tmjmenu-first-run.desktop
	install -Dm755 data/tmjmenu-first-run ~/.local/bin/tmjmenu-first-run
	@echo "TMJMenu + TMJDock instalados. Roda: tmjmenu / tmjdock"

uninstall:
	pip uninstall -y tmjmenu
	rm -f ~/.local/share/applications/tmjmenu.desktop
	rm -f ~/.config/autostart/tmjdock.desktop
	rm -f ~/.config/autostart/tmjmenu-first-run.desktop
	rm -f ~/.local/bin/tmjmenu-first-run

clean:
	rm -rf build/ dist/ *.egg-info __pycache__ tmjmenu/__pycache__ tests/__pycache__ .pytest_cache
