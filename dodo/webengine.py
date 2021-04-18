# Copyright 2020-2021 Jiří Janoušek <janousek.jiri@gmail.com>
# Licensed under BSD-2-Clause license - see file LICENSE.
import os

from PySide2.QtCore import QUrl
from PySide2.QtGui import QGuiApplication
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
        client = Client(id, self.qml_view)
        client.connect()
        client.attach()
        client.wl_display.dispatch()


    @classmethod
    def initialize(cls):
        if not cls._initialized:
            # Must be done before QGuiApplication is created and before window’s QPlatformOpenGLContext is created.
            QtWebEngine.initialize()
            initialize_gl()
            cls._initialized = True

