from __future__ import annotations
from abc import ABC, abstractmethod

from PySide2.QtCore import QSize, QObject, Signal

from wevf.gl import RenderContext, GL


class Framebuffer(ABC):
    """Abstract framebuffer interface."""
    ctx: RenderContext = None

    @property
    @abstractmethod
    def id(self) -> int:
        """Return OpenGL id of the framebuffer."""

    @property
    @abstractmethod
    def size(self) -> QSize:
        """Return width and height of the framebuffer."""

    @property
    @abstractmethod
    def texture(self) -> int:
        """Return OpenGL texture od."""

    @abstractmethod
    def bind(self) -> None:
        """Return OpenGL texture od."""


class FramebufferController:
    """Abstract framebuffer interface."""
    texture_rendered = Signal((Framebuffer,))

    @abstractmethod
    def create_framebuffer(self, ctx: RenderContext, size: QSize) -> Framebuffer:
        raise NotImplementedError

    def release_framebuffer(self, framebuffer: Framebuffer) -> None:
        pass

    def framebuffer_rendered(self, framebuffer: Framebuffer) -> None:
        pass


class TextureFramebuffer(Framebuffer):
    def __init__(self, ctx: RenderContext, size: QSize):
        self.ctx = ctx
        self._size = size
        self._handle = self._texture = self._rbo = 0

        self.ctx.makeCurrent()
        self._handle = GL.glGenFramebuffers(1)
        GL.glBindFramebuffer(GL.GL_FRAMEBUFFER, self._handle)

        # Render to texture
        self._texture = GL.glGenTextures(1)
        GL.glBindTexture(GL.GL_TEXTURE_2D, self._texture)
        GL.glTexImage2D(
            GL.GL_TEXTURE_2D, 0, GL.GL_RGBA, size.width(), size.height(), 0, GL.GL_RGBA, GL.GL_UNSIGNED_BYTE, None
        )
        GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MIN_FILTER, GL.GL_LINEAR)
        GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAG_FILTER, GL.GL_LINEAR)
        GL.glFramebufferTexture2D(GL.GL_FRAMEBUFFER, GL.GL_COLOR_ATTACHMENT0, GL.GL_TEXTURE_2D, self._texture, 0)

        # But use render buffer for depth and stencil buffers
        self._rbo = GL.glGenRenderbuffers(1)
        GL.glBindRenderbuffer(GL.GL_RENDERBUFFER, self._rbo)
        GL.glRenderbufferStorage(GL.GL_RENDERBUFFER, GL.GL_DEPTH24_STENCIL8, size.width(), size.height())
        GL.glBindRenderbuffer(GL.GL_RENDERBUFFER, 0)
        GL.glFramebufferRenderbuffer(GL.GL_FRAMEBUFFER, GL.GL_DEPTH_STENCIL_ATTACHMENT, GL.GL_RENDERBUFFER, self._rbo)

        result = GL.glCheckFramebufferStatus(GL.GL_FRAMEBUFFER)
        if result != GL.GL_FRAMEBUFFER_COMPLETE:
            raise ValueError(result)

        GL.glBindFramebuffer(GL.GL_FRAMEBUFFER, 0)

    def bind(self) -> None:
        GL.glBindFramebuffer(GL.GL_FRAMEBUFFER, self._handle)

    def __del__(self):
        self.ctx.makeCurrent()

        if self._texture:
            GL.glDeleteTextures([self.texture])
        if self._rbo:
            GL.glDeleteRenderbuffers(1, [self._rbo])
        if self._handle:
            GL.glBindFramebuffer(GL.GL_FRAMEBUFFER, self._handle)
            GL.glDeleteFramebuffers(1, [self._handle])

    @property
    def id(self) -> int:
        return self._handle

    @property
    def size(self) -> QSize:
        return self._size

    @property
    def texture(self) -> int:
        return self._texture


class TextureFramebufferController(QObject, FramebufferController):
    """
    Controller for QtFramebuffer.

    Signals:
        rendered(textureId: int): Emitted when the renderer rendered the content to an OpenGL texture.
    """

    def create_framebuffer(self, ctx: RenderContext, size: QSize) -> TextureFramebuffer:
        print("create_framebuffer", size)
        return TextureFramebuffer(ctx, size)

    def framebuffer_rendered(self, framebuffer: TextureFramebuffer) -> None:
        self.texture_rendered.emit(framebuffer)
