import mmap

from OpenGL import GL
from PySide2.QtCore import QUrl, QSize, QPointF, QPoint, Slot, QEvent
from PySide2.QtGui import Qt, QMouseEvent, QKeyEvent, QWheelEvent, QCursor, QFocusEvent, QEnterEvent
from pywayland.utils import AnonymousFile

from wevf.events import MOUSE_BUTTONS, EventType, MOUSE_EVENTS, deserialize_modifiers, KEY_EVENTS, get_qt_key, \
    WHEEL_ANGLES, FOCUS_EVENTS
from wevf.framebuffers import TextureFramebufferController, Framebuffer
from wevf.renderers import QmlOffscreenRenderer
from wl_protocols.wayland import WlShm


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
        self.renderer.cursor_changed.connect(self.on_cursor_changed)
        self.controller.texture_rendered.connect(self.on_texture_rendered)
        self.mouse_buttons = set()

        view.dispatcher["resized"] = self.on_resized
        view.dispatcher["rescaled"] = self.on_rescaled
        view.dispatcher["mouse_event"] = self.on_mouse_event
        view.dispatcher["scroll_event"] = self.on_scroll_event
        view.dispatcher["key_event"] = self.on_key_event
        view.dispatcher["focus_event"] = self.on_focus_event

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
            self.buffer.dropped = True
            if self.buffer.released:
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
            buffer.dropped = False
            buffer.released = True
            buffer.dispatcher["release"] = self.on_buffer_released
            pool.destroy()
        self.buffer = buffer

    def commit(self):
        self.surface.damage(0, 0, self.scale * self.width, self.scale * self.height)
        self.surface.attach(self.buffer, 0, 0)
        self.surface.commit()
        if self.buffer is not None:
            self.buffer.released = False
            self.buffer.dropped = False
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

    def on_mouse_event(
        self, wl_view, type_, mouse, modifiers, local_x, local_y, window_x, window_y, screen_x, screen_y
    ):
        #print("mouse event", type_, mouse, modifiers, local_x, local_y, window_x, window_y, screen_x, screen_y)
        button = MOUSE_BUTTONS[mouse]
        if type_ == EventType.mouse_press:
            self.mouse_buttons.add(button)
        elif type_ == EventType.mouse_release:
            self.mouse_buttons.discard(button)

        buttons = Qt.NoButton
        for button in self.mouse_buttons:
            buttons |= button

        event = QMouseEvent(
            MOUSE_EVENTS[type_],
            QPointF(local_x, local_y),
            QPointF(window_x, window_y),
            QPointF(screen_x, screen_y),
            button,
            buttons,
            deserialize_modifiers(modifiers),
        )
        self.renderer.sendEvent(event)

    def on_key_event(
        self, wl_view, type_, name, modifiers, keyval, keycode, native_modifiers, text
    ):
        print(type_, name, modifiers, keyval, keycode, native_modifiers, text)
        print(KEY_EVENTS[type_], get_qt_key(name), deserialize_modifiers(modifiers), keycode, keyval, native_modifiers, text)
        event = QKeyEvent(
            KEY_EVENTS[type_],
            get_qt_key(name),
            deserialize_modifiers(modifiers),
            keycode,
            keyval,
            native_modifiers,
            text
        )
        self.renderer.sendEvent(event)

    def on_scroll_event(
            self, wl_view, type_, modifiers, delta_x, delta_y, local_x, local_y, window_x, window_y, screen_x, screen_y
    ):
        pixelDelta = QPoint(int(delta_x), int(delta_y)) if delta_x or delta_y else QPoint()
        buttons = Qt.NoButton
        for button in self.mouse_buttons:
            buttons |= button
        event = QWheelEvent(
            QPointF(local_x, local_y),
            QPointF(screen_x, screen_y),
            pixelDelta,
            WHEEL_ANGLES[type_],
            buttons,
            deserialize_modifiers(modifiers),
            Qt.NoScrollPhase,
            False
        )
        self.renderer.sendEvent(event)

    def on_crossing_event(self, wl_view, type_, local_x, local_y, window_x, window_y, screen_x, screen_y):
        if type_ == EventType.enter:
            event = QEnterEvent(QPointF(local_x, local_y), QPointF(window_x, window_y), QPointF(screen_x, screen_y))
        else:
            event = QEvent(QEvent.Leave)

        self.renderer.sendEvent(event)

    def on_focus_event(self, wl_view, type_):
        event = QFocusEvent(FOCUS_EVENTS[type_])
        self.renderer.sendEvent(event)

    def on_buffer_released(self, wl_buffer):
        wl_buffer.released = True
        if wl_buffer.dropped:
            wl_buffer.destroy()

    @Slot()
    def on_texture_rendered(self, framebuffer: Framebuffer):
        framebuffer.ctx.makeCurrent()
        GL.glBindTexture(GL.GL_TEXTURE_2D, framebuffer.texture)
        data = GL.glGetTexImage(GL.GL_TEXTURE_2D, 0, GL.GL_BGRA, GL.GL_UNSIGNED_BYTE)
        self.shm_data.seek(0)
        self.shm_data.write(data)
        self.commit()

    @Slot()
    def on_cursor_changed(self, cursor: QCursor, name: str):
        self.view.change_cursor(name)
