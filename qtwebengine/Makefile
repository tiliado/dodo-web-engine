VENVS := $(HOME)/.virtualenvs
VENV := $(VENVS)/wayland-demo
ARGS :=
NAME := qtwebengine.py
PROTOCOL := ~/dev/repo/wayland-embedded-view-server/protocol/wevp-embed.xml
PROTOCOL_FILES := ../wl_protocols/wevp_embed/wevp_embedder.py ../wl_protocols/wevp_embed/wevp_view.py

info:
	cat Makefile

venv:
	mkdir -p $(VENVS)
	test -d $(VENV) || python3 -m venv $(VENV)
	$(VENV)/bin/python3 -m pip install -U pip wheel setuptools
	$(VENV)/bin/python3 -m pip install -U -r requirements.txt

$(PROTOCOL_FILES): $(PROTOCOL)
	python3 -m pywayland.scanner -o ../wl_protocols -i /usr/share/wayland/wayland.xml $<
	touch ../wl_protocols/__init__.py

run-venv: $(PROTOCOL_FILES)
	PYTHONPATH=.. $(VENV)/bin/python3 $(NAME) $(ARGS)

run: $(PROTOCOL_FILES)
	PYTHONPATH=.. python3 $(NAME) $(ARGS)

clean:
	rm -rf ../wl_protocols
