namespace Wevf {

public class View : Gtk.EventBox {
    public unowned Canvas canvas;
    private Gtk.IMContextSimple im_context;
    private string? im_string = null;

    public View(Canvas canvas) {
        this.canvas = canvas;
        this.im_context = new Gtk.IMContextSimple();
        canvas.show();
        add(canvas);
        above_child = true;
        visible_window = false;;
        can_focus = true;
        focus_on_click = true;
        add_events(
            Gdk.EventMask.BUTTON_RELEASE_MASK
            | Gdk.EventMask.BUTTON_PRESS_MASK
            | Gdk.EventMask.POINTER_MOTION_MASK
            | Gdk.EventMask.SCROLL_MASK     
            | Gdk.EventMask.KEY_PRESS_MASK 
            | Gdk.EventMask.KEY_RELEASE_MASK 
            | Gdk.EventMask.FOCUS_CHANGE_MASK
            | Gdk.EventMask.LEAVE_NOTIFY_MASK 
            | Gdk.EventMask.ENTER_NOTIFY_MASK 
            | Gdk.EventMask.VISIBILITY_NOTIFY_MASK
        );
        button_press_event.connect(on_button_event);
        button_release_event.connect(on_button_event);
        motion_notify_event.connect(on_motion_notify_event);
        key_press_event.connect(on_key_event);
        key_release_event.connect(on_key_event);
        focus_in_event.connect(on_focus_event);
        focus_out_event.connect(on_focus_event);
        scroll_event.connect(on_scroll_event);
        enter_notify_event.connect(on_crossing_event);
        leave_notify_event.connect(on_crossing_event);
        realize.connect_after(on_realize);
        canvas.cursor_changed.connect(on_cursor_changed);
        canvas.send_focus_event(has_focus);
    }

    ~View() {
        canvas.cursor_changed.disconnect(on_cursor_changed);
        realize.disconnect(on_realize);
        enter_notify_event.disconnect(on_crossing_event);
        leave_notify_event.disconnect(on_crossing_event);
        scroll_event.disconnect(on_scroll_event);
        focus_in_event.disconnect(on_focus_event);
        focus_out_event.disconnect(on_focus_event);
        key_press_event.disconnect(on_key_event);
        key_release_event.disconnect(on_key_event);
        motion_notify_event.disconnect(on_motion_notify_event);
        button_release_event.disconnect(on_button_event);
        button_press_event.disconnect(on_button_event);
        canvas.set_surface(null);
    }
    

    private bool on_key_event(Gdk.EventKey event) {
        string? str = ((unichar) Gdk.keyval_to_unicode(event.keyval)).to_string();
        
        if (im_context.filter_keypress(event)) {
            if (im_string != null) {
                str = (owned) im_string;
            } else {
                return true;
            }
        }
        
        Wevp.EventType type;
        switch (event.type) {
        case Gdk.EventType.KEY_PRESS:
            type = Wevp.EventType.KEY_PRESS;
            break;
        case Gdk.EventType.KEY_RELEASE:
            type = Wevp.EventType.KEY_RELEASE;
            break;
        default:
            return false;
        }
        
        canvas.send_key_event(type, Gdk.keyval_name(event.keyval), Keyboard.serialize_modifiers(event.state), event.keyval, event.hardware_keycode, (uint) event.state, str);
        return false;
    }

    private bool on_button_event(Gdk.EventButton event) {
        Wevp.EventType type;
        switch (event.type) {
        case Gdk.EventType.BUTTON_PRESS:
            type = Wevp.EventType.MOUSE_PRESS;
            break;
        case Gdk.EventType.BUTTON_RELEASE:
            type = Wevp.EventType.MOUSE_RELEASE;
            break;
        case Gdk.EventType.DOUBLE_BUTTON_PRESS:
            type = Wevp.EventType.MOUSE_DOUBLE_CLICK;
            break;
        default:
            return false;
        }
        grab_focus();
        canvas.send_mouse_event(type, (Wevp.MouseButton) event.button, Keyboard.serialize_modifiers(event.state), event.x, event.y, event.x, event.y, event.x_root, event.y_root);
        return false;
    }

    private bool on_focus_event(Gdk.EventFocus event) {
        bool has_focus = event.@in != 0;
        if (has_focus) {
            grab_focus();
            im_context.focus_in();
        } else {
            im_context.focus_out();
        }
        
        canvas.send_focus_event(has_focus);
        return false;
    }

    private bool on_motion_notify_event(Gdk.EventMotion event) {
        canvas.send_mouse_event(Wevp.EventType.MOUSE_MOVE, (Wevp.MouseButton) 0, Keyboard.serialize_modifiers(event.state), event.x, event.y, event.x, event.y, event.x_root, event.y_root);
        return false;
    }

    private bool on_scroll_event(Gdk.EventScroll event) {
        Wevp.EventType type;
        switch (event.direction) {
        case Gdk.ScrollDirection.UP:
            type = Wevp.EventType.SCROLL_UP;
            break;
        case Gdk.ScrollDirection.DOWN:
            type = Wevp.EventType.SCROLL_DOWN;
            break;
        case Gdk.ScrollDirection.LEFT:
            type = Wevp.EventType.SCROLL_LEFT;
            break;
        case Gdk.ScrollDirection.RIGHT:
            type = Wevp.EventType.SCROLL_RIGHT;
            break;
        default:
            return false;
        }

        return canvas.send_scroll_event(type, Keyboard.serialize_modifiers(event.state), event.delta_x, event.delta_y, event.x, event.y, event.x, event.y, event.x_root, event.y_root);
    }

    private bool on_crossing_event(Gdk.EventCrossing event) {
        Wevp.EventType type;
        switch (event.type) {
        case Gdk.EventType.ENTER_NOTIFY:
            type = Wevp.EventType.ENTER;
            break;
        case Gdk.EventType.LEAVE_NOTIFY:
            type = Wevp.EventType.LEAVE;
            break;
        default:
            return false;
        }
        
        canvas.send_crossing_event(type, event.x, event.y, event.x, event.y, event.x_root, event.y_root);
        return true;
    }

    public override bool focus(Gtk.DirectionType direction) {
        debug("Grab focus");
        grab_focus();
        return Gdk.EVENT_STOP;
    }

    private void on_cursor_changed(string? name) {
        var display = get_window().get_display();
        get_window().set_cursor(new Gdk.Cursor.from_name(display, name));
    }

    private void on_realize() {
        im_context.set_client_window(get_window());
        im_context.commit.connect(on_im_commited);
    }

    private void on_im_commited(string str) {
        this.im_string = str;
    }
}

} // namespace Wevf
