vala_src := $(wildcard src/*.vala)

all: build/wayland-embed

build:
	mkdir -p build

build/wevp-embed.h: protocol/wevp-embed.xml | build
	wayland-scanner -s server-header $<  $@

build/wevp-embed.c: protocol/wevp-embed.xml | build
	wayland-scanner -s private-code $< $@

build/wayland-embed: build/wevp-embed.c build/wevp-embed.h $(vala_src)
	valac -v --save-temps -X -g -X -Ibuild -X '-DG_LOG_DOMAIN="WEVF"' -X -DGL_GLEXT_PROTOTYPES \
	  --vapidir=./vapi --pkg=wayland-server --pkg=gtk+-3.0 --pkg=wevp --pkg=gl \
	  -d build -o wayland-embed src/*.vala build/wevp-embed.c

run: all
	G_MESSAGES_DEBUG=all build/wayland-embed

gdb: all
	G_MESSAGES_DEBUG=all gdb -ex run --args build/wayland-embed

clean:
	rm -rf build
