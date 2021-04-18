from __future__ import annotations

from typing import Union

from PySide2.QtCore import QUrl, Slot, QSocketNotifier, QObject, Signal
from PySide2.QtGui import QOpenGLContext, QOffscreenSurface
from pywayland.client import Display

from dodo.qml import Engine, Component
from dodo.view import View
from wl_protocols.wayland import WlShm, WlCompositor
from wl_protocols.dodo import DodoProtoEmbedder

SHM_FORMAT = {
    WlShm.format.argb8888.value: "ARGB8888",
    WlShm.format.xrgb8888.value: "XRGB8888",
    WlShm.format.rgb565.value: "RGB565",
}


class Client(QObject):
    disconnected = Signal()

    def __init__(self, display: Union[str, int], qml_view: QUrl, gl_context: QOpenGLContext):
        super().__init__()
        self.qml_view = qml_view
        self.display = display
        self.wl_display = Display(display)
        self.wl_compositor = None
        self.wl_shm = None
        self.wl_embedder = None
        self.views = {}
        self.fd_notifier = None
        self.engine = Engine()
        self.component = None
        self.qml_view = qml_view
        self.connected = False
        self.gl_context = gl_context

        assert gl_context.isOpenGLES()
        surface = QOffscreenSurface()
        surface.setFormat(gl_context.format())
        surface.create()
        gl_context.makeCurrent(surface)

    def __del__(self):
        print("Disconnecting from", self.display)
        if self.connected:
            self.stop()

    def start(self) -> None:
        assert not self.connected
        print("Connecting to", self.display)
        self.wl_display.connect()
        self.connected = True

        self.component = Component(self.engine, self.qml_view)
        self.component.load()
        self.component.relatedCreated.connect(self.on_related_created)

        registry = self.wl_display.get_registry()
        registry.dispatcher["global"] = self.on_global_object_added
        registry.dispatcher["global_remove"] = self.on_global_object_removed

        self.wl_display.dispatch(block=True)
        self.wl_display.roundtrip()

        self.fd_notifier = QSocketNotifier(self.wl_display.get_fd(), QSocketNotifier.Read)
        self.fd_notifier.activated.connect(self.on_can_read_wl_data)

        self.wl_display.dispatch()

    def stop(self) -> None:
        assert self.connected
        self.connected = False

        self.component.relatedCreated.disconnect(self.on_related_created)
        self.fd_notifier.activated.disconnect(self.on_can_read_wl_data)

        registry = self.wl_display.get_registry()
        registry.dispatcher["global"] = None
        registry.dispatcher["global_remove"] = None

        if self.wl_shm:
            self.wl_shm.dispatcher["format"] = None
        if self.wl_embedder:
            self.wl_embedder.dispatcher["ping"] = None
            self.wl_embedder.dispatcher["view_requested"] = None

        self.wl_compositor = None
        self.wl_shm = None
        self.wl_embedder = None

        self.wl_display.disconnect()
        self.disconnected.emit()

        # TODO: clear views

        self.fd_notifier = None
        self.component = None
        self.engine = None

    @Slot()
    def on_can_read_wl_data(self, *args):
        try:
            self.wl_display.read()
            self.wl_display.dispatch()
            self.wl_display.flush()
        except RuntimeError:
            self.stop()

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

    def on_view_requested(self, embedder, serial, width, height, scale, url):
        print("Request new view", serial, width, height, scale)
        item = self.component.create()
        if url:
            item.setProperty("url", url)
        self.create_view(serial, width, height, scale, item)

    @Slot()
    def on_related_created(self, view, item):
        self.create_view(0, view.width, view.height, view.scale, item)


