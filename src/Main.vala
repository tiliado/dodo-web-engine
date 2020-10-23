namespace Embed {

void main(string[] args) {
    Gtk.init(ref args);
    var wl_display = new Wl.Display();
    assert(wl_display != null);
    wl_display.init_shm();
    wl_display.add_socket("wayland-demo");

    var display = new Display((owned) wl_display);
    display.attach(MainContext.ref_thread_default());
    Gtk.main();
}


} // namespace Embed
