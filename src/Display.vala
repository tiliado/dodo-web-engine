namespace Embed {

public class Display: GLib.Object {
    public Wl.Display? wl_display;
    private unowned Wl.EventLoop loop;
    private unowned MainContext? context;
    private uint context_source_id;
    private Listener display_destroyed = new Listener();

    public Display(owned Wl.Display wl_display) {
        display_destroyed.connect(on_display_destroyed);
        wl_display.add_destroy_listener(ref display_destroyed.listener);
        this.loop = wl_display.get_event_loop();
        this.wl_display = (owned) wl_display;
    }

    ~Display() {
        quit();
    }

    public signal void destroyed();

    public bool dispatch() {
        if (wl_display == null) {
            return false;
        }

        loop.dispatch(0);
        wl_display.flush_clients();
        return true;
    }

    public void attach(MainContext context) {
        if (this.context != null) {
            this.context.find_source_by_id(context_source_id).destroy();
        }
        this.context = context;

        var source = new IOSource(
            new IOChannel.unix_new(loop.get_fd()),
            IOCondition.ERR|IOCondition.HUP|IOCondition.IN|IOCondition.NVAL|IOCondition.OUT|IOCondition.PRI
        );
        source.set_callback((source, condition) => {
            this.dispatch();
            return true;
        });
        context_source_id = source.attach(context);
    }

    public void quit() {
        if (context != null) {
            context.find_source_by_id(context_source_id).destroy();
            context = null;
        }

        if (wl_display != null) {
            loop.dispatch(0);
            wl_display.flush_clients();
            wl_display.destroy_clients();
            wl_display = null;
        }
    }

    private void on_display_destroyed(Listener listener, void* data) {
        debug("Display destroyed");
        destroyed();
        listener.disconnect();
    }
}

} // namespace Embed
