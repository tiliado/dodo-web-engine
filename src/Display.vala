namespace Embed {

public class Display: GLib.Object {
    public Wl.Display? wl_display;
    private unowned Wl.EventLoop loop;
    private unowned MainContext? context;
    private uint context_source_id;
    private Listener display_destroyed = new Listener();
    private Listener client_created_listenet = new Listener();
    private Embeder? embeder;
    private HashTable<unowned Wl.Client, Listener> clients;

    public Display(owned Wl.Display wl_display) {
        clients = new HashTable<unowned Wl.Client, Listener>(direct_hash, direct_equal);
        display_destroyed.connect(on_display_destroyed);
        wl_display.add_destroy_listener(ref display_destroyed.listener);
        client_created_listenet.connect(on_client_created);
        wl_display.add_client_created_listener(ref client_created_listenet.listener);
        this.loop = wl_display.get_event_loop();
        this.wl_display = (owned) wl_display;
    }

    ~Display() {
        quit();
    }

    public signal void destroyed();
    public signal void client_created(Wl.Client client);
    public signal void client_destroyed(Wl.Client client);

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

    public void init_embeder() {
        embeder = new Embeder(this);
    }

    private void on_display_destroyed(Listener listener, void* data) {
        debug("Display destroyed");
        destroyed();
        listener.disconnect();
    }

    private void on_client_created(Listener listener, void* data) {
        unowned Wl.Client client = (Wl.Client) data;
        debug("New %s.", Utils.client_info(client));
        var client_listener = new Listener();
        client_listener.connect(on_client_destroyed);
        client.add_destroy_listener(ref client_listener.listener);
        clients[client] = (owned) client_listener;
        client_created(client);
    }

    private void on_client_destroyed(Listener listener, void* data) {
        unowned Wl.Client client = (Wl.Client) data;
        debug("Destroyed %s.", Utils.client_info(client));
        client_destroyed(client);
        listener.disconnect();
        assert(client in clients);
        clients.remove(client);
    }
}

} // namespace Embed
