vala_src := $(wildcard src/*.vala)

all: build/wayland-embed

build:
	mkdir -p build

build/nuvola-embed-protocol.h: protocol/nuvola-embed.xml build
	wayland-scanner -s server-header $<  $@

build/nuvola-embed-protocol.c: protocol/nuvola-embed.xml build
	wayland-scanner -s private-code $< $@

build/wayland-embed: build/nuvola-embed-protocol.c build/nuvola-embed-protocol.h $(vala_src)
	valac -v --save-temps -X -g -X -Ibuild -X '-DG_LOG_DOMAIN="Embed"' \
	  --vapidir=./vapi --pkg=wayland-server --pkg=gtk+-3.0 --pkg=nuvola-embed-protocol \
	  -d build -o wayland-embed src/*.vala build/nuvola-embed-protocol.c

run: all
	G_MESSAGES_DEBUG=all build/wayland-embed

gdb: all
	G_MESSAGES_DEBUG=all gdb -ex run --args build/wayland-embed

clean:
	rm -rf build
