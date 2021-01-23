from __future__ import annotations
from typing import Optional, Tuple

from PySide2.QtCore import QSize, QTimer, QCoreApplication, Slot, QEvent, Signal, QObject
from PySide2.QtGui import QOpenGLFramebufferObject, QOpenGLContext, QOffscreenSurface, QCursor
from PySide2.QtQml import QQmlComponent
from PySide2.QtQuick import QQuickItem, QQuickRenderControl, QQuickWindow

from dodo.events import get_cursor_name
from dodo.framebuffers import FramebufferController, Framebuffer
from dodo.gl import RenderContext, get_default_format


class QmlOffscreenRenderer(QObject):
    """
    Offscreen rendering of a QML component.

    Args:
        rootItem: The root  item of a QML component to render.
        controller: The controller of a framebuffer life cycle.
    """

    cursor_changed = Signal((QCursor, str))

    size: QSize = QSize(0, 0)
    initialized: bool = False
    ctx: RenderContext = None

    _surface: QOffscreenSurface = None
    _control: QQuickRenderControl = None
    _window: QQuickWindow = None
    _renderTimer: QTimer = None
    _syncTimer: Optional[QTimer] = None
    _controller: FramebufferController
    _framebuffers: Optional[Tuple[Framebuffer, Framebuffer]] = None
    _component: QQmlComponent = None
    rootItem: QQuickItem = None
    _cursor: QCursor = None

    def __init__(self, rootItem: QQuickItem, controller: FramebufferController):
        super().__init__()
        self._controller = controller
        self.rootItem = rootItem

    def initialize(self, size: QSize, shareContext: QOpenGLContext) -> None:
        """
        Initialize offscreen renderer.

        Args:
            size: The size of the area available for rendering.
            shareContext: OpenGL context used as a share context.

        Raises:
            RuntimeError: If the renderer has already been initialized.
        """
        print(f'QmlOffscreenRenderer.initialize: {size}')
        if self.initialized:
            raise RuntimeError('Already initialized')

        context = QOpenGLContext()
        context.setShareContext(shareContext)
        context.setFormat(get_default_format(gles=False))
        context.create()
        assert not context.isOpenGLES(), "We need glGetTexImage from OpenGL"

        self.size = size

        # Create offscreen surface with initialized format
        surface = QOffscreenSurface()
        surface.setFormat(context.format())
        surface.create()
        self.ctx = RenderContext(context, surface)

        # Set up quick rendering
        self._control = control = QQuickRenderControl()
        self._window = window = QQuickWindow(control)
        self._cursor = self._window.cursor()

        # Don't polish/sync/render immediately for better performance, use a timer
        self._renderTimer = renderTimer = QTimer()
        renderTimer.setSingleShot(True)
        renderTimer.setInterval(5)
        renderTimer.timeout.connect(self._onRenderTimer)
        self._syncTimer = syncTimer = QTimer()
        syncTimer.setSingleShot(True)
        syncTimer.setInterval(5)
        syncTimer.timeout.connect(self._onSyncTimer)
        syncTimer.destroyed.connect(self._onSyncTimerDestroyed)

        # Request to create frame buffer
        window.sceneGraphInitialized.connect(self._onSceneGraphInitialized)
        # Request to release frame buffer
        window.sceneGraphInvalidated.connect(self._onSceneGraphInvalidated)
        # Only render is needed
        control.renderRequested.connect(self._onRenderRequested)
        # Polish, sync & render
        control.sceneChanged.connect(self._onSceneChanged)

        self.initialized = True

        # Attach root item
        self.rootItem.setParentItem(self._window.contentItem())
        self._window.contentItem().forceActiveFocus()
        self._updateSizes()
        self.ctx.makeCurrent()
        self._control.initialize(self.ctx.glContext)

    def resize(self, size: QSize) -> None:
        """
        Resize the area for rendering.

        Args:
             size: New size.
        """
        print(f'QmlOffscreenRenderer.resize: {self.size} → {size}, {self.initialized}')
        if not self.initialized or self.size == size:
            return

        self.size = size

        if self.rootItem and self.ctx.makeCurrent():
            self._destroyFrameBuffer()
            self._createFrameBuffer()
            self._updateSizes()

    def sendEvent(self, event: QEvent) -> None:
        """
        Send an event.

        Args:
            event: The event to send.
        """
        QCoreApplication.sendEvent(self._window, event)
        cursor = self._window.cursor()
        if cursor != self._cursor:
            self.cursor_changed.emit(cursor, get_cursor_name(cursor.shape()))
            self._cursor = cursor

    def _createFrameBuffer(self):
        """Create framebuffer for quick window."""
        print(f'QmlOffscreenRenderer._createFrameBufferObject: {self.size}')
        self.ctx.makeCurrent()
        self._framebuffers = (
            self._controller.create_framebuffer(self.ctx, self.size),
            self._controller.create_framebuffer(self.ctx, self.size),
        )
        fb = self._framebuffers[0]
        self._window.setRenderTarget(fb.id, fb.size)

    def _destroyFrameBuffer(self):
        """Release framebuffer."""
        self.ctx.makeCurrent()
        for fb in self._framebuffers:
            self._controller.release_framebuffer(fb)
        self._framebuffers = None

    def _updateSizes(self) -> None:
        """Update size of the quick window and QML root item."""
        print(f'QmlOffscreenRenderer._updateSizes: {self.size}')
        width, height = self.size.toTuple()
        self._window.setGeometry(0, 0, width, height)
        self.rootItem.setWidth(width)
        self.rootItem.setHeight(height)

    def _polishSyncRender(self):
        """Polish, sync & render."""
        if not self.initialized or not self.ctx.makeCurrent():
            return

        control = self._control
        control.polishItems()
        if control.sync():
            self._render()

    def _render(self):
        """Render QML component to a texture."""
        if not self.initialized or self._framebuffers is None or not self.ctx.makeCurrent():
            return

        self._control.render()
        self._window.resetOpenGLState()
        QOpenGLFramebufferObject.bindDefault()
        self.ctx.glContext.functions().glFlush()
        current_fb, next_fb = self._framebuffers
        self._controller.framebuffer_rendered(current_fb)
        self._framebuffers = next_fb, current_fb
        self._window.setRenderTarget(next_fb.id, next_fb.size)

    @Slot()
    def _onComponentStatusChanged(self):
        """QML component status has changed."""
        self._component.statusChanged.disconnect(self._onComponentStatusChanged)
        self._attachRootItem()

    @Slot()
    def _onRenderTimer(self):
        """Rendering scheduled."""
        self._render()

    @Slot()
    def _onSyncTimer(self):
        """Polish, sync & render scheduled."""
        self._polishSyncRender()

    @Slot()
    def _onSyncTimerDestroyed(self):
        """Sync timer was destroyed."""
        # Python wrapper is still alive though!
        self._syncTimer = None

    @Slot()
    def _onRenderRequested(self):
        """Schedule rendering."""
        if not self._renderTimer.isActive():
            self._renderTimer.start()

    @Slot()
    def _onSceneChanged(self):
        """Schedule polish, sync & render operations."""
        if self._syncTimer is not None and not self._syncTimer.isActive():
            self._syncTimer.start()

    @Slot()
    def _onSceneGraphInitialized(self):
        """Quick window's scene graph was initialized."""
        self._createFrameBuffer()

    @Slot()
    def _onSceneGraphInvalidated(self):
        """Quick window's scene graph was invalidated."""
        self._destroyFrameBuffer()
