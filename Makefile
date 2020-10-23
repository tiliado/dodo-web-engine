all:
	valac -v --save-temps -g -X -g -X '-DG_LOG_DOMAIN="Embed"' \
	  --vapidir=./vapi --pkg=wayland-server --pkg=gtk+-3.0 \
	  -d build -o wayland-embed src/*.vala

run: all
	G_MESSAGES_DEBUG=all build/wayland-embed

gdb: all
	G_MESSAGES_DEBUG=all gdb -ex run --args build/wayland-embed
