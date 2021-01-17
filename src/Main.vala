namespace Wevf {

void main(string[] args) {
    Gtk.init(ref args);
    var wl_display = new Wl.Display();
    assert(wl_display != null);
    wl_display.init_shm();

    unowned string? wayland_socket = Environment.get_variable("DEMO_DISPLAY");
    if (wayland_socket == null) {
        wayland_socket = Environment.get_variable("WAYLAND_DISPLAY");
        if (wayland_socket == null) {
            wayland_socket = "wevf-demo";
        }
    }
    wl_display.add_socket(wayland_socket);

    var display = new Display((owned) wl_display);
    display.attach(MainContext.ref_thread_default());
    display.init_compositor();
    display.init_embedder();

    var window = new Gtk.Window();
    window.title = "Wayland Embedded View Framework";
    window.set_default_size(400, 300);
    window.show_all();

    window.delete_event.connect(() => {
        display.quit();
        Gtk.main_quit();
        return false;
    });

    display.embedder.unclaimed_canvas.connect((canvas) => {
        var w = new Gtk.Window();
        w.title = "Wayland Embedded View Framework";
        w.add(new View(canvas));
        w.show_all();
    });

    var canvas = display.embedder.create_canvas();
    var view = new View(canvas);
    view.show();
    window.add(view);

    Gtk.main();
}


} // namespace Wevf
