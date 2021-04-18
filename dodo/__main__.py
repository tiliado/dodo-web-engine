# Copyright 2020-2021 Jiří Janoušek <janousek.jiri@gmail.com>
# Licensed under BSD-2-Clause license - see file LICENSE.
import signal
import sys
from typing import List

import gc
from PySide2.QtGui import QGuiApplication

from dodo.webengine import WebEngine


def run(argv: List[str]):
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    WebEngine.initialize()
    app = QGuiApplication(argv)
    webengine = WebEngine("dodo/" + argv[1], app)
    code = app.exec_()
    # Try to make QtWebEngine to shutdown properly without SIGSEGV
    del webengine
    gc.collect()
    del app
    gc.collect()
    return code


sys.exit(run(sys.argv))
