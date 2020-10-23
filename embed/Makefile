VENVS := $(HOME)/.virtualenvs
VENV := $(VENVS)/wayland-demo
ARGS :=
NAME := embed.py
PROTOCOL_FILES := ../nuvola_embed/__init__.py nuvola_embed/nuv_embeder.py

info:
	cat Makefile

venv:
	mkdir -p $(VENVS)
	test -d $(VENV) || python3 -m venv $(VENV)
	$(VENV)/bin/python3 -m pip install -U pip wheel setuptools
	$(VENV)/bin/python3 -m pip install -U -r requirements.txt

$(PROTOCOL_FILES): ~/dev/repo/nuvola/nuvolaruntime/wayland/protocol/nuvola-embed.xml
	python3 -m pywayland.scanner -i $< -o ..

run-venv: $(PROTOCOL_FILES)
	PYTHONPATH=.. $(VENV)/bin/python3 $(NAME) $(ARGS)

run: $(PROTOCOL_FILES)
	PYTHONPATH=.. python3 $(NAME) $(ARGS)
