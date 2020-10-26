from __future__ import annotations
from typing import Optional, Tuple

from PySide2.QtCore import QSize, QUrl, QTimer, QCoreApplication, Slot, QEvent
from PySide2.QtGui import QOpenGLFramebufferObject, QOpenGLContext, QOffscreenSurface, QMouseEvent, \
    QWheelEvent, QSurfaceFormat
from PySide2.QtQml import QQmlComponent, QQmlEngine
from PySide2.QtQuick import QQuickItem, QQuickRenderControl, QQuickWindow


from wevf.framebuffers import FramebufferController, Framebuffer


class QmlOffscreenRenderer:
    """
    Offscreen rendering of a QML component.

    Args:
        qmlUrl: The URL of a QML component to render.
        controller: The controller of a framebuffer life cycle.
    """

    context: QOpenGLContext = None
    size: QSize = QSize(0, 0)
    initialized: bool = False

    _surface: QOffscreenSurface = None
    _control: QQuickRenderControl = None
    _window: QQuickWindow = None
    _engine: QQmlEngine = None
    _renderTimer: QTimer = None
    _syncTimer: Optional[QTimer] = None
    _controller: FramebufferController
    _framebuffers: Optional[Tuple[Framebuffer, Framebuffer]] = None
    _component: QQmlComponent = None
    _rootItem: QQuickItem = None

    def __init__(self, qmlUrl: QUrl, controller: FramebufferController):
        super().__init__()
        self.qmlUrl = qmlUrl
        self._controller = controller

    def makeCurrent(self) -> bool:
        return self.context.makeCurrent(self._surface)

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

        format = QSurfaceFormat()
        format.setDepthBufferSize(24)
        format.setStencilBufferSize(8)
        context = QOpenGLContext()
        context.setFormat(format)
        context.setShareContext(shareContext)
        context.create()

        self.size = size
        self.context = context

        # Create offscreen surface with initialized format
        self._surface = surface = QOffscreenSurface()
        surface.setFormat(context.format())
        surface.create()

        # Set up quick rendering
        self._control = control = QQuickRenderControl()
        self._window = window = QQuickWindow(control)
        self._engine = engine = QQmlEngine()
        if not engine.incubationController():
            engine.setIncubationController(window.incubationController())

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

        # Load QML component
        self._component = component = QQmlComponent(self._engine, self.qmlUrl)
        if component.isLoading():
            component.statusChanged.connect(self._onComponentStatusChanged)
        else:
            self._attachRootItem()

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

        if self._rootItem and self.makeCurrent():
            self._destroyFrameBuffer()
            self._createFrameBuffer()
            self.context.doneCurrent()
            self._updateSizes()

    def sendEvent(self, event: QEvent) -> None:
        """
        Send an event.

        Args:
            event: The event to send.
        """
        if event.type() == QEvent.Type.FocusOut:
            # Ignored - cannot get focus back reliably :-(
            return

        if isinstance(event, QMouseEvent):
            # `windowPos` is replaced with `localPos` as it has no meaning in offscreen rendering.
            event = QMouseEvent(event.type(), event.localPos(), event.screenPos(),
                                event.button(), event.buttons(), event.modifiers())

        elif isinstance(event, QWheelEvent):
            event = QWheelEvent(event.position(), event.position(), event.pixelDelta(),
                                event.angleDelta(), event.buttons(), event.modifiers(),
                                event.phase(), event.inverted(), event.source())

        self._window.contentItem().forceActiveFocus()
        QCoreApplication.sendEvent(self._window, event)

    def _attachRootItem(self):
        """Attach root QML item to Quick window."""
        component = self._component

        if component.isError():
            for err in component.errors():
                print("Error:", err.url(), err.line(), err)
            return

        rootObject = component.create()
        if component.isError():
            for err in component.errors():
                print("Error:", err.url(), err.line(), err)
            return

        if not isinstance(rootObject, QQuickItem):
            raise TypeError(f'Unexpected QML type {type(rootObject)}.')

        self._rootItem = rootObject
        rootObject.setParentItem(self._window.contentItem())
        self._window.contentItem().forceActiveFocus()
        self._updateSizes()
        self.makeCurrent()
        self._control.initialize(self.context)

    def _createFrameBuffer(self):
        """Create framebuffer for quick window."""
        print(f'QmlOffscreenRenderer._createFrameBufferObject: {self.size}')
        self.makeCurrent()
        self._framebuffers = (
            self._controller.create_framebuffer(self.size),
            self._controller.create_framebuffer(self.size),
        )
        fb = self._framebuffers[0]
        self._window.setRenderTarget(fb.id, fb.size)

    def _destroyFrameBuffer(self):
        """Release framebuffer."""
        self.makeCurrent()
        for fb in self._framebuffers:
            self._controller.release_framebuffer(fb)
        self._framebuffers = None

    def _updateSizes(self) -> None:
        """Update size of the quick window and QML root item."""
        print(f'QmlOffscreenRenderer._updateSizes: {self.size}')
        width, height = self.size.toTuple()
        self._window.setGeometry(0, 0, width, height)
        self._rootItem.setWidth(width)
        self._rootItem.setHeight(height)

    def _polishSyncRender(self):
        """Polish, sync & render."""
        if not self.initialized or not self.makeCurrent():
            return

        control = self._control
        control.polishItems()
        if control.sync():
            self._render()

    def _render(self):
        """Render QML component to a texture."""
        if not self.initialized or self._framebuffers is None or not self.makeCurrent():
            return

        self._control.render()
        self._window.resetOpenGLState()
        QOpenGLFramebufferObject.bindDefault()
        self.context.functions().glFlush()
        self.context.swapBuffers(self._surface)
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
