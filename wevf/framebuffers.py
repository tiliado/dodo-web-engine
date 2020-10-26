from __future__ import annotations
from abc import ABC, abstractmethod

from PySide2.QtCore import QSize, QObject, Signal
from PySide2.QtGui import QOpenGLFramebufferObject


class FramebufferController:
    """Abstract framebuffer interface."""
    texture_rendered = Signal((int,))

    @abstractmethod
    def create_framebuffer(self, size: QSize) -> Framebuffer:
        raise NotImplementedError

    def release_framebuffer(self, framebuffer: Framebuffer) -> None:
        pass

    def framebuffer_rendered(self, framebuffer: Framebuffer) -> None:
        pass


class Framebuffer(ABC):
    """Abstract framebuffer interface."""

    @property
    @abstractmethod
    def id(self) -> int:
        """Return OpenGL id of the framebuffer."""

    @property
    @abstractmethod
    def size(self) -> QSize:
        """Return width and height of the framebuffer."""


class QtFramebufferController(QObject, FramebufferController):
    """
    Controller for QtFramebuffer.

    Signals:
        rendered(textureId: int): Emitted when the renderer rendered the content to an OpenGL texture.
    """

    def create_framebuffer(self, size: QSize) -> QtFramebuffer:
        print("create_framebuffer", size)
        return QtFramebuffer(QOpenGLFramebufferObject(size, QOpenGLFramebufferObject.CombinedDepthStencil))

    def framebuffer_rendered(self, framebuffer: QtFramebuffer) -> None:
        textureID = framebuffer.texture
        print("texture rendered", textureID)
        self.texture_rendered.emit(textureID)


class QtFramebuffer(Framebuffer):
    """
    Framebuffer backed by Qt's framebuffer object.

    Args:
        fbo: Qt's framebuffer object.
    """

    _fbo: QOpenGLFramebufferObject

    def __init__(self, fbo: QOpenGLFramebufferObject):
        self._fbo = fbo

    @property
    def id(self) -> int:
        return self._fbo.handle()

    @property
    def texture(self) -> int:
        return self._fbo.texture()

    @property
    def size(self) -> QSize:
        return self._fbo.size()
