ARGS :=
PROTOCOL := protocol/dodo-proto.xml
PROTOCOL_PYTHON:= build/wl_protocols/dodo/dodo_proto_embedder.py build/wl_protocols/dodo/dodo_proto_view.py

vala_src := $(wildcard src/*.vala)

all: build/wayland-embed $(PROTOCOL_PYTHON)

build:
	mkdir -p build

build/dodo-proto.h: $(PROTOCOL) | build
	wayland-scanner -s server-header $<  $@

build/dodo-proto.c: $(PROTOCOL) | build
	wayland-scanner -s private-code $< $@

build/wayland-embed: build/dodo-proto.c build/dodo-proto.h $(vala_src)
	valac -v --save-temps -X -g -X -Ibuild -X '-DG_LOG_DOMAIN="Dodo"' -X -DGL_GLEXT_PROTOTYPES \
	  --vapidir=./vapi --pkg=wayland-server --pkg=gtk+-3.0 --pkg=dodo-proto --pkg=gl \
	  -d build -o wayland-embed src/*.vala build/dodo-proto.c

$(PROTOCOL_PYTHON): $(PROTOCOL)
	python3 -m pywayland.scanner -o build/wl_protocols -i /usr/share/wayland/wayland.xml $<
	touch build/wl_protocols/__init__.py

run-server: all
	G_MESSAGES_DEBUG=all build/wayland-embed

run-client: all
	PYTHONPATH=build:. python3 dodo/qtwebengine.py $(ARGS)

gdb-server: all
	G_MESSAGES_DEBUG=all gdb -ex run --args build/wayland-embed $(ARGS)

clean:
	rm -rf build
