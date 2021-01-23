#!/usr/bin/env python3
# Copyright 2020 Jiří Janoušek <janousek.jiri@gmail.com>
# Licensed under BSD-2-Clause license - see file LICENSE.
import os
import signal
import sys
from typing import List

from PySide2.QtCore import QUrl, Qt
from PySide2.QtGui import QGuiApplication
from PySide2.QtWebEngine import QtWebEngine
from PySide2.QtWidgets import QApplication

from wevf.client import Client
from wevf.gl import initialize_gl
from wevf.utils import get_data_path

WAYLAND_DISPLAY = os.environ.get("DEMO_DISPLAY", os.environ.get("WAYLAND_DISPLAY", "wevf-demo"))


def run(argv: List[str]):
    signal.signal(signal.SIGINT, signal.SIG_DFL)

    # Must be done before QGuiApplication is created and before window’s QPlatformOpenGLContext is created.
    QtWebEngine.initialize()
    initialize_gl()

    app = QGuiApplication(argv)

    qml_view = QUrl(os.fspath(get_data_path("webview.qml")))
    client = Client(WAYLAND_DISPLAY, qml_view)
    client.connect()
    client.attach()
    client.wl_display.dispatch()

    code = app.exec_()
    sys.exit(code)


run(sys.argv)
