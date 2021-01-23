from PySide2.QtGui import QOpenGLContext, QSurface, QSurfaceFormat, QGuiApplication, Qt

from OpenGL import GL


def get_default_format(*, gles: bool):
    fmt = QSurfaceFormat()
    fmt.setVersion(2, 0)
    fmt.setProfile(QSurfaceFormat.CoreProfile)
    fmt.setRenderableType(QSurfaceFormat.OpenGLES if gles else QSurfaceFormat.OpenGL)
    fmt.setDepthBufferSize(24)
    fmt.setStencilBufferSize(8)
    fmt.setOption(QSurfaceFormat.DebugContext)
    return fmt


def initialize_gl():
    QSurfaceFormat.setDefaultFormat(get_default_format(gles=True))
    QGuiApplication.setAttribute(Qt.AA_UseOpenGLES, True)
    QGuiApplication.setAttribute(Qt.AA_ShareOpenGLContexts, True)


class RenderContext:
    def __init__(self, glContext: QOpenGLContext, surface: QSurface):
        self.glContext = glContext
        self.surface = surface

    def makeCurrent(self) -> bool:
        return self.glContext.makeCurrent(self.surface)


__all__ = ["GL", "get_default_format", "initialize_gl", "RenderContext"]
