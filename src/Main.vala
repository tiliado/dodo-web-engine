namespace Wevf {

void main(string[] args) {
    Gtk.init(ref args);
    var wl_display = new Wl.Display();
    assert(wl_display != null);
    wl_display.init_shm();
    wl_display.add_socket("wevf-demo");

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

    var view = new View(display.embedder);
    view.show();
    window.add(view);

    Gtk.main();
}


} // namespace Wevf
