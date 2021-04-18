# Copyright 2020-2021 Jiří Janoušek <janousek.jiri@gmail.com>
# Licensed under BSD-2-Clause license - see file LICENSE.
import os

from PySide2.QtCore import QUrl, Slot
from PySide2.QtGui import QGuiApplication, QSurfaceFormat, QOpenGLContext
from PySide2.QtWebEngine import QtWebEngine

from dodo.client import Client
from dodo.gl import initialize_gl
from dodo.utils import get_data_path

WAYLAND_DISPLAY = os.environ.get("DODO_DISPLAY", "dodo/default")


class WebEngine:
    _initialized = False

    def __init__(self, id: str, app: QGuiApplication):
        assert self._initialized
        self.id = id
        self.app = app
        self.qml_view = QUrl(os.fspath(get_data_path("webview.qml")))

        gl_context = QOpenGLContext()
        gl_context.setFormat(QSurfaceFormat.defaultFormat())
        gl_context.create()

        self.client = Client(id, self.qml_view, gl_context)
        self.client.disconnected.connect(self.on_disconnected)
        self.client.start()

    @classmethod
    def initialize(cls):
        if not cls._initialized:
            # Must be done before QGuiApplication is created and before window’s QPlatformOpenGLContext is created.
            QtWebEngine.initialize()
            initialize_gl()
            cls._initialized = True

    @Slot()
    def on_disconnected(self):
        self.client.disconnected.disconnect(self.on_disconnected)
        print("quit")
        self.app.quit()
