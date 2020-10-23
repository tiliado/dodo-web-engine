namespace Embed {

void main(string[] args) {
    Gtk.init(ref args);
    var wl_display = new Wl.Display();
    assert(wl_display != null);
    wl_display.init_shm();
    wl_display.add_socket("wayland-demo");

    var display = new Display((owned) wl_display);
    display.attach(MainContext.ref_thread_default());

    var window = new Gtk.Window();
    window.set_default_size(400, 300);
    window.show_all();
    debug("Window %d×%d factor %d.", window.get_allocated_width(), window.get_allocated_height(), window.scale_factor);
    window.delete_event.connect(() => {
        display.quit();
        Gtk.main_quit();
        return false;
    });

    Gtk.main();
}


} // namespace Embed
