[CCode(cheader_filename="wevp-embed.h")]
namespace Wevp {

[CCode(has_target=false)]
public delegate void PongFunc(Wl.Client client, Embedder wl_embedder, uint serial);
[CCode(has_target=false)]
public delegate void ChangeCursorFunc(Wl.Client client, View wl_view, string? name);
[CCode(has_target=false)]
public delegate void CreateViewFunc(Wl.Client client, Embedder wl_embedder, uint serial, uint view_id, Wl.Surface surface, uint width, uint height, uint scale);

[CCode (cname = "struct wevp_embedder_interface", has_type_id = false)]
public struct EmbedderInterface {
    public PongFunc pong;
    public CreateViewFunc create_view;
}

[CCode (cname = "struct wevp_view_interface", has_type_id = false)]
public struct ViewInterface {
    ChangeCursorFunc change_cursor;
}

[CCode(cname="struct wl_resource", free_function="wl_resource_destroy")]
[Compact]
public class Embedder: Wl.Resource {
    [CCode(cname="wl_resource_create")]
    public static unowned Embedder create(Wl.Client client, ref Wl.Interface ifce, int version, uint id);
    public void send_ping(uint serial);
    public void send_view_requested(uint serial, uint width, uint height, uint scale);
}

[CCode(cname="struct wl_resource", free_function="wl_resource_destroy")]
[Compact]
public class View: Wl.Resource {
    [CCode(cname="wl_resource_create")]
    public static unowned View create(Wl.Client client, ref Wl.Interface ifce, int version, uint id);
    public void send_resized(uint width, uint height);
    public void send_rescaled(uint scale);
    [CCode(cname="vala_wevp_view_send_mouse_event")]
    public void send_mouse_event(EventType type, MouseButton mouse, uint modifiers, double local_x, double local_y, double window_x, double window_y, double screen_x, double screen_y) {
        _send_mouse_event((uint) type, (uint) mouse, modifiers, Wl.Fixed.from_double(local_x), Wl.Fixed.from_double(local_y), Wl.Fixed.from_double(window_x), Wl.Fixed.from_double(window_y), Wl.Fixed.from_double(screen_x), Wl.Fixed.from_double(screen_y));
    }
    [CCode(cname="wevp_view_send_mouse_event")]
    private void _send_mouse_event(uint type, uint mouse, uint modifiers, Wl.Fixed local_x, Wl.Fixed local_y, Wl.Fixed window_x, Wl.Fixed window_y, Wl.Fixed screen_x, Wl.Fixed screen_y);
    [CCode(cname="vala_wevp_view_send_key_event")]
    public void send_key_event(EventType type, string name, uint modifiers, uint keyval, uint keycode, uint native_modifiers, string? text) {
        _send_key_event((uint) type, name, modifiers, keyval, keycode, native_modifiers, text);
    }
    [CCode(cname="wevp_view_send_key_event")]
    private void _send_key_event(uint type, string name, uint modifiers, uint keyval, uint keycode, uint native_modifiers, string? text);
    [CCode(cname="vala_wevp_view_focus_event")]
    public void send_focus_event(EventType type) {
        _send_focus_event((uint) type);
    }
    [CCode(cname="wevp_view_send_focus_event")]
    private void _send_focus_event(uint type);
    [CCode(cname="vala_wevp_view_send_scroll_event")]
    public void send_scroll_event(EventType type, uint modifiers, double delta_x, double delta_y, double local_x, double local_y, double window_x, double window_y, double screen_x, double screen_y) {
        _send_scroll_event((uint) type, modifiers, Wl.Fixed.from_double(delta_x), Wl.Fixed.from_double(delta_y), Wl.Fixed.from_double(local_x), Wl.Fixed.from_double(local_y), Wl.Fixed.from_double(window_x), Wl.Fixed.from_double(window_y), Wl.Fixed.from_double(screen_x), Wl.Fixed.from_double(screen_y));
    }
    [CCode(cname="wevp_view_send_scroll_event")]
    private void _send_scroll_event(uint type, uint modifiers, Wl.Fixed delta_x, Wl.Fixed delta_y, Wl.Fixed local_x, Wl.Fixed local_y, Wl.Fixed window_x, Wl.Fixed window_y, Wl.Fixed screen_x, Wl.Fixed screen_y);
}

public static Wl.Interface embedder_interface;
public static Wl.Interface view_interface;

[CCode(cname="enum wevp_view_event_type", cprefix="WEVP_VIEW_EVENT_TYPE_", has_type_id=false)]
public enum EventType {
	MOUSE_PRESS,
	MOUSE_RELEASE,
	MOUSE_DOUBLE_CLICK,
	MOUSE_MOVE,
	KEY_PRESS,
	KEY_RELEASE,
	FOCUS_IN,
	FOCUS_OUT,
    SCROLL_UP,
    SCROLL_DOWN,
    SCROLL_LEFT,
    SCROLL_RIGHT,
}

[CCode(cname="enum wevp_view_mouse_button", cprefix="WEVP_VIEW_ MOUSE_BUTTON_", has_type_id=false)]
public enum MouseButton {
	NONE,
	LEFT,
	MIDDLE,
	RIGHT,
    SCROLL_UP,
    SCROLL_DOWN,
    SCROLL_LEFT,
    SCROLL_RIGHT,
	BACK,
	FORWARD;
}

} // namespace Nuv
