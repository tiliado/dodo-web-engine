from __future__ import annotations

import mmap
from typing import Union

from PySide2.QtCore import QUrl, QSize, Slot, QSocketNotifier
from PySide2.QtGui import QSurfaceFormat, QOpenGLContext, QOffscreenSurface
from pywayland.client import Display
from pywayland.utils import AnonymousFile

from wevf.framebuffers import Framebuffer, TextureFramebufferController
from wevf.renderers import QmlOffscreenRenderer
from wevf.gl import GL
from wl_protocols.wayland import WlShm, WlCompositor
from wl_protocols.wevp_embed import WevpEmbedder

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
        elif interface == "wevp_embedder":
            print("got embeder")
            self.wl_embedder = registry.bind(object_id, WevpEmbedder, version)
            self.wl_embedder.dispatcher["ping"] = self.on_ping
            self.wl_embedder.dispatcher["view_requested"] = self.on_view_requested

    def on_global_object_removed(self, registry, object_id):
        print("Global object removed:", registry, object_id)

    def on_shm_format(self, shm, shm_format):
        print("Possible shmem format: {}".format(SHM_FORMAT.get(shm_format, shm_format)))

    def on_ping(self, embeder, serial):
        embeder.pong(serial)
        self.wl_display.flush()

    def on_view_requested(self, embedder, serial, width, height, scale):
        print("Request new view", serial, width, height, scale)
        surface = self.wl_compositor.create_surface()
        view = embedder.create_view(serial, surface, width, height, scale)
        self.views[view] = View(
            self.wl_display, self.gl_context, self.wl_shm, self.qml_view, view, surface, width, height, scale
        )
        self.wl_display.flush()


class View:
    def __init__(self, wl_display, gl_context, shm, qml_view: QUrl, view, surface, width, height, scale):
        self.wl_display = wl_display
        self.gl_context = gl_context
        self.shm = shm
        self.view = view
        self.surface = surface
        self.width = width
        self.height = height
        self.scale = scale
        self.shm_data = None
        self.buffer = None
        self.last_time = 0

        self.controller = TextureFramebufferController()
        self.renderer = QmlOffscreenRenderer(qml_view, self.controller)
        self.renderer.initialize(QSize(width, height), self.gl_context)
        self.controller.texture_rendered.connect(self.on_texture_rendered)

        view.dispatcher["resized"] = self.on_resized
        view.dispatcher["rescaled"] = self.on_rescaled

        self.create_buffer()
        self.redraw()

    def redraw(self, time: int = None):
        if time is None:
            time = self.last_time
        else:
            self.last_time = time
        self.render(time)
        self.commit()

    def render(self, time):
        pass

    def create_buffer(self):
        if self.buffer is not None:
            self.buffer.destroy()
            self.buffer = None

        width = self.scale * self.width
        height = self.scale * self.height
        stride = width * 4
        size = stride * height

        with AnonymousFile(size) as fd:
            self.shm_data = mmap.mmap(
                fd, size, prot=mmap.PROT_READ | mmap.PROT_WRITE, flags=mmap.MAP_SHARED
            )
            pool = self.shm.create_pool(fd, size)
            buffer = pool.create_buffer(0, width, height, stride, WlShm.format.argb8888.value)
            pool.destroy()
        self.buffer = buffer

    def commit(self):
        self.surface.damage(0, 0, self.scale * self.width, self.scale * self.height)
        self.surface.attach(self.buffer, 0, 0)
        self.surface.commit()
        self.wl_display.flush()

    def on_resized(self, wl_view, width, height):
        print("resize", width, height)
        if self.width != width or self.height != height:
            self.width = width
            self.height = height
            self.renderer.resize(QSize(width, height))
            self.create_buffer()
            self.redraw()

    def on_rescaled(self, wl_view, scale):
        print("rescale", scale)
        if self.scale != scale:
            self.scale = scale
            self.create_buffer()
            self.redraw()

    @Slot()
    def on_texture_rendered(self, framebuffer: Framebuffer):
        framebuffer.ctx.makeCurrent()
        GL.glBindTexture(GL.GL_TEXTURE_2D, framebuffer.texture)
        data = GL.glGetTexImage(GL.GL_TEXTURE_2D, 0, GL.GL_BGRA, GL.GL_UNSIGNED_BYTE)
        self.shm_data.seek(0)
        self.shm_data.write(data)
        self.commit()
