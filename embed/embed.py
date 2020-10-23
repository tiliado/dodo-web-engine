#!/usr/bin/env python3
import os
import signal
from typing import Union

from pywayland.client import Display
from pywayland.protocol.wayland import WlCompositor, WlShm

from nuvola_embed import NuvEmbeder

# weston --debug -S wayland-weston
WAYLAND_DISPLAY = os.environ.get("DEMO_DISPLAY", os.environ.get("WAYLAND_DISPLAY", "wayland-weston"))

MARGIN = 10

SHM_FORMAT = {
    WlShm.format.argb8888.value: "ARGB8888",
    WlShm.format.xrgb8888.value: "XRGB8888",
    WlShm.format.rgb565.value: "RGB565",
}


class Context:
    def __init__(self, display: Union[str, int]):
        self.display = Display(display)
        self.compositor = None
        self.shm = None
        self.embeder = None
        self.views = []

    def __del__(self):
        print("Disconnecting from", WAYLAND_DISPLAY)
        self.display.disconnect()

    def connect(self):
        print("Connecting to", WAYLAND_DISPLAY)
        self.display.connect()

        registry = self.display.get_registry()
        registry.dispatcher["global"] = self.on_global_object_added
        registry.dispatcher["global_remove"] = self.on_global_object_removed

        self.display.dispatch(block=True)
        self.display.roundtrip()

    def run(self):
        while self.display.dispatch(block=True) != -1:
            pass

    def on_global_object_added(self, registry, object_id, interface, version):
        print("Global object added:", registry, object_id, interface, version)

        if interface == "wl_compositor":
            print("got compositor")
            self.compositor = registry.bind(object_id, WlCompositor, version)
        elif interface == "wl_shm":
            print("got shm")
            self.shm = registry.bind(object_id, WlShm, version)
            self.shm.dispatcher["format"] = self.on_shm_format
        elif interface == "nuv_embeder":
            print("got embeder")
            self.embeder = registry.bind(object_id, NuvEmbeder, version)
            self.embeder.dispatcher["ping"] = self.on_ping
            self.embeder.dispatcher["view_request"] = self.on_new_view

    def on_global_object_removed(self, registry, object_id):
        print("Global object removed:", registry, object_id)

    def on_shm_format(self, shm, shm_format):
        print("Possible shmem format: {}".format(SHM_FORMAT.get(shm_format, shm_format)))

    def on_ping(self, embeder, serial):
        embeder.pong(serial)

    def on_new_view(self, embeder, serial, width, height, scale):
        print("Request new view", serial, width, height, scale)
        view = embeder.new_view(serial, width, height, scale)
        view.dispatcher["resize"] = self.on_resize
        view.dispatcher["rescale"] = self.on_rescale
        self.views.append(view)

    def on_resize(self, view, width, height):
        print("resize", width, height)

    def on_rescale(self, view, scale):
        print("rescale", scale)


def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    ctx = Context(WAYLAND_DISPLAY)
    ctx.connect()
    ctx.run()


if __name__ == "__main__":
    main()
