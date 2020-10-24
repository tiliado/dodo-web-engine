namespace Embed {

public class Adaptor : GLib.Object {
    private unowned Display display;
    public View widget;
    public unowned Wl.Client? client;
    public unowned Nuv.View? view;
    public Surface? surface;
    public uint serial;
    public uint width;
    public uint height;
    public uint scale;
    private uint resize_timeout_id = 0;

    public Adaptor(Display display, View widget) {
        this.display = display;
        this.widget = widget;
        widget.size_allocate.connect_after(on_size_allocate);
        widget.notify["scale-factor"].connect_after(on_scale_factor_changed);
    }

    ~Adaptor() {
        widget.notify["scale-factor"].disconnect(on_scale_factor_changed);
        widget.size_allocate.disconnect(on_size_allocate);
    }

    public void check_state() {
        if (view == null) {
            return;
        }

        uint width = (uint) widget.get_allocated_width();
        uint height = (uint) widget.get_allocated_height();
        uint scale = (uint) widget.scale_factor;
        if (this.width != width || this.height != height) {
            this.width = width;
            this.height = height;
            view.send_resize(width, height);
        }
        if (this.scale != scale) {
            this.scale = scale;
            view.send_rescale(scale);
        }
        display.dispatch();
    }

    public void attach_view(Wl.Client? client, Nuv.View view, Surface surface) {
        this.serial = 0;
        this.client = client;
        this.view = view;
        this.surface = surface;
        widget.set_surface(surface);
    }

    private void on_size_allocate(Gtk.Allocation alloc) {
        if (resize_timeout_id != 0) {
            Source.remove(resize_timeout_id);
        }
        resize_timeout_id = Timeout.add(100, () => {
            resize_timeout_id = 0;
            check_state();
            return false;
        });
    }

    private void on_scale_factor_changed(GLib.Object o, ParamSpec p) {
        check_state();
    }
}

} // namespace Embed
