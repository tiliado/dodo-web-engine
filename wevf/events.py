from enum import IntFlag

from PySide2.QtCore import QEvent, Qt, QPoint

from wl_protocols.wevp_embed import WevpView

EventType = WevpView.event_type
MouseButton = WevpView.mouse_button

FOCUS_EVENTS = {
    EventType.focus_in: QEvent.FocusIn,
    EventType.focus_out: QEvent.FocusOut,
}

MOUSE_EVENTS = {
    EventType.mouse_double_click: QEvent.MouseButtonDblClick,
    EventType.mouse_move: QEvent.MouseMove,
    EventType.mouse_press: QEvent.MouseButtonPress,
    EventType.mouse_release: QEvent.MouseButtonRelease,
}

KEY_EVENTS = {
    EventType.key_press: QEvent.KeyPress,
    EventType.key_release: QEvent.KeyRelease,
}

MOUSE_BUTTONS = {
    MouseButton.left: Qt.LeftButton,
    MouseButton.right: Qt.RightButton,
    MouseButton.middle: Qt.MiddleButton,
    MouseButton.back: Qt.BackButton,
    MouseButton.forward: Qt.ForwardButton,
    MouseButton.none: Qt.NoButton,
}

WHEEL_ANGLES = {
    EventType.scroll_up: QPoint(0, 120),
    EventType.scroll_down: QPoint(0, -120),
    EventType.scroll_left: QPoint(120, 0),
    EventType.scroll_right: QPoint(-120, 0),
}

DEFAULT_CURSOR = "default"

CURSORS = {
    Qt.CursorShape.BlankCursor: "none",
    Qt.CursorShape.ArrowCursor: "default",
    Qt.CursorShape.WhatsThisCursor: "help",
    Qt.CursorShape.PointingHandCursor: "pointer",
    Qt.CursorShape.BusyCursor: "progress",
    Qt.CursorShape.WaitCursor: "wait",
    Qt.CursorShape.CrossCursor: "crosshair",
    Qt.CursorShape.IBeamCursor: "text",
    Qt.CursorShape.DragLinkCursor: "alias",
    Qt.CursorShape.DragCopyCursor: "copy",
    Qt.CursorShape.SizeAllCursor: "move",
    Qt.CursorShape.DragMoveCursor: "move",
    Qt.CursorShape.ForbiddenCursor: "not-allowed",
    Qt.CursorShape.OpenHandCursor: "grab",
    Qt.CursorShape.ClosedHandCursor: "grabbing",
    Qt.CursorShape.SizeHorCursor: "col-resize",
    Qt.CursorShape.SplitHCursor: "col-resize",
    Qt.CursorShape.SizeVerCursor: "row-resize",
    Qt.CursorShape.SplitVCursor: "row-resize",
    Qt.CursorShape.UpArrowCursor: "n-resize",
    Qt.CursorShape.SizeBDiagCursor: "nesw-resize",
    Qt.CursorShape.SizeFDiagCursor: "nwse-resize",
}


def get_cursor_name(cursor: Qt.CursorShape) -> str:
    return CURSORS.get(cursor, DEFAULT_CURSOR)


class Modifiers(IntFlag):
    NONE = 0
    SHIFT = 1 << 0
    CONTROL = 1 << 1
    ALT = 1 << 2
    META = 1 << 3


QT_MODIFIERS = {
    Modifiers.NONE: Qt.NoModifier,
    Modifiers.SHIFT: Qt.ShiftModifier,
    Modifiers.CONTROL: Qt.ControlModifier,
    Modifiers.ALT: Qt.AltModifier,
    Modifiers.META: Qt.MetaModifier,
}


def deserialize_modifiers(modifiers: int):
    result = Qt.NoModifier
    mods = Modifiers(modifiers)
    for mod in Modifiers:
        if mod & mods:
            result |= QT_MODIFIERS[mod]
    return result


QT_KEY_ALTERNATIVES = {
    "AudioLowerVolume": Qt.Key_VolumeDown,
    "AudioMute": Qt.Key_VolumeMute,
    "AudioRaiseVolume": Qt.Key_VolumeUp,
    "AudioPlay": Qt.Key_MediaPlay,
    "AudioStop": Qt.Key_MediaStop,
    "AudioPrev": Qt.Key_MediaPrevious,
    "AudioNext": Qt.Key_MediaNext,
    "AudioRecord": Qt.Key_MediaRecord,
    "AudioPause": Qt.Key_MediaPause,
    "AudioMedia": Qt.Key_LaunchMedia,
    "AudioMicMute": Qt.Key_MicMute,
    "KbdLightOnOff": Qt.Key_KeyboardLightOnOff,
    "KP_Enter": Qt.Key_Enter,
    "VoidSymbol": Qt.Key_unknown,
    "Alt_L": Qt.Key_Alt,
    "Alt_R": Qt.Key_AltGr,
    "parenleft": Qt.Key_ParenLeft,
    "parenright": Qt.Key_ParenRight,
    "bracketleft": Qt.Key_BracketLeft,
    "bracketright": Qt.Key_BracketRight,
    "braceleft": Qt.Key_BraceLeft,
    "braceright": Qt.Key_BraceRight,
    "asciitilde": Qt.Key_AsciiTilde,
    "asciicircum": Qt.Key_AsciiCircum,
    "Control_L": Qt.Key_Control,
    "Control_R": Qt.Key_Control,
    "Meta_L": Qt.Key_Meta,
    "Meta_R": Qt.Key_Meta,
    "Shift_L": Qt.Key_Shift,
    "Shift_R": Qt.Key_Shift,
    "Mail": Qt.Key_LaunchMail,
    "quotedbl": Qt.Key_QuoteDbl,
    "quoteleft ": Qt.Key_QuoteLeft,
    "OpenURL": Qt.Key_OpenUrl,
    "KbdBrightnessUp": Qt.Key_KeyboardBrightnessUp,
    "KbdBrightnessDown": Qt.Key_KeyboardBrightnessDown,
}


def get_qt_key(name: str) -> int:
    result = QT_KEY_ALTERNATIVES.get(name, 0)

    if not result:
        candidates = (
            name,
            name.replace("_", ""),
            name.title(),
            name.lower(),
            name.title().replace("_", ""),
            name.replace("_", "").title(),
        )
        for candidate in candidates:
            result = getattr(Qt, "Key_" + candidate, 0)
            if result:
                return result

    return result
