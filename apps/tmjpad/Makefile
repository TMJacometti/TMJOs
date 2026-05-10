.PHONY: run test install uninstall clean

run:
	python3 -m tmjpad

test:
	python3 -m pytest tests/ -v

install:
	pip install --user .
	install -Dm644 data/tmjpad.desktop ~/.local/share/applications/tmjpad.desktop
	@echo "TMJPad instalado. Abra pelo menu de apps ou rode: tmjpad"

uninstall:
	pip uninstall -y tmjpad
	rm -f ~/.local/share/applications/tmjpad.desktop

clean:
	rm -rf build/ dist/ *.egg-info __pycache__ tmjpad/__pycache__ tests/__pycache__ .pytest_cache
