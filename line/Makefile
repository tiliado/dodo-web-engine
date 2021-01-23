VENVS := $(HOME)/.virtualenvs
VENV := $(VENVS)/wayland-demo
ARGS :=

info:
	cat Makefile

venv:
	mkdir -p $(VENVS)
	test -d $(VENV) || python3 -m venv $(VENV)
	$(VENV)/bin/python3 -m pip install -U pip wheel setuptools
	$(VENV)/bin/python3 -m pip install -U -r requirements.txt

run-venv:
	PYTHONPATH=.. $(VENV)/bin/python3 line.py $(ARGS)

run:
	PYTHONPATH=.. python3 line.py $(ARGS)
