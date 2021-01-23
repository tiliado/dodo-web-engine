from __future__ import annotations

from typing import Union

from PySide2.QtCore import QUrl, Slot, QSocketNotifier
from PySide2.QtGui import QSurfaceFormat, QOpenGLContext, QOffscreenSurface
from pywayland.client import Display

from wevf.qml import Engine, Component
from wevf.view import View
from wl_protocols.wayland import WlShm, WlCompositor
from wl_protocols.dodo import DodoProtoEmbedder

SHM_FORMAT = {
    WlShm.format.argb8888.value: "ARGB8888",
    WlShm.format.xrgb8888.value: "XRGB8888",
    WlShm.format.rgb565.value: "RGB565",
}


class Client:
    def __init__(self, display: Union[str, int], qml_view: QUrl, gl_context: QOpenGLContext = None):
        self.qml_view = qml_view
        self.display = display
        self.wl_display = Display(display)
        self.wl_compositor = None
        self.wl_shm = None
        self.wl_embedder = None
        self.views = {}
        self.fd_notifier = None
        self.engine = Engine()
        self.component = Component(self.engine, qml_view)
        self.component.load()
        self.component.relatedCreated.connect(self.on_related_created)

        if gl_context is None:
            gl_context = QOpenGLContext()
            gl_context.setFormat(QSurfaceFormat.defaultFormat())
            gl_context.create()

        assert gl_context.isOpenGLES()
        self.gl_context = gl_context
        surface = QOffscreenSurface()
        surface.setFormat(gl_context.format())
        surface.create()
        gl_context.makeCurrent(surface)

    def __del__(self):
        print("Disconnecting from", self.display)
        self.wl_display.disconnect()

    def connect(self):
        print("Connecting to", self.display)
        self.wl_display.connect()

        registry = self.wl_display.get_registry()
        registry.dispatcher["global"] = self.on_global_object_added
        registry.dispatcher["global_remove"] = self.on_global_object_removed

        self.wl_display.dispatch(block=True)
        self.wl_display.roundtrip()

    def attach(self) -> bool:
        if self.fd_notifier:
            return False

        self.fd_notifier = QSocketNotifier(self.wl_display.get_fd(), QSocketNotifier.Read)
        self.fd_notifier.activated.connect(self.on_can_read_wl_data)
        return True

    @Slot()
    def on_can_read_wl_data(self, *args):
        self.wl_display.read()
        self.wl_display.dispatch()
        self.wl_display.flush()

    def run(self):
        while self.wl_display.dispatch(block=True) != -1:
            pass

    def on_global_object_added(self, registry, object_id, interface, version):
        print("Global object added:", registry, object_id, interface, version)

        if interface == "wl_compositor":
            print("got compositor")
            self.wl_compositor = registry.bind(object_id, WlCompositor, version)
        elif interface == "wl_shm":
            print("got shm")
            self.wl_shm = registry.bind(object_id, WlShm, version)
            self.wl_shm.dispatcher["format"] = self.on_shm_format
        elif interface == "dodo_proto_embedder":
            print("got embeder")
            self.wl_embedder = registry.bind(object_id, DodoProtoEmbedder, version)
            self.wl_embedder.dispatcher["ping"] = self.on_ping
            self.wl_embedder.dispatcher["view_requested"] = self.on_view_requested

    def on_global_object_removed(self, registry, object_id):
        print("Global object removed:", registry, object_id)

    def on_shm_format(self, shm, shm_format):
        print("Possible shmem format: {}".format(SHM_FORMAT.get(shm_format, shm_format)))

    def on_ping(self, embeder, serial):
        embeder.pong(serial)
        self.wl_display.flush()

    def create_view(self, serial: int, width: int, height: int, scale: int, rootItem):
        surface = self.wl_compositor.create_surface()
        wl_view = self.wl_embedder.create_view(serial, surface, width, height, scale)
        self.views[wl_view] = View(
            self.wl_display, self.gl_context, self.wl_shm, rootItem, wl_view, surface, width, height, scale
        )
        self.wl_display.flush()

    def on_view_requested(self, embedder, serial, width, height, scale):
        print("Request new view", serial, width, height, scale)
        item = self.component.create()
        item.setProperty("url", "https://bitmovin.com/demos/drm")
        self.create_view(serial, width, height, scale, item)

    @Slot()
    def on_related_created(self, view, item):
        self.create_view(0, view.width, view.height, view.scale, item)


