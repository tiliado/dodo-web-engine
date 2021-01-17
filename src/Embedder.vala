namespace Wevf {

public class Embedder : GLib.Object {
    private const int VERSION = 1;
    private static Wevp.EmbedderInterface impl = {
        Embedder.pong,
        Embedder.create_view
    };
    public Wl.Global glob;
    private unowned Display display;
    private HashTable<unowned Wl.Client, unowned Wevp.Embedder> bound;
    private List<unowned View> views;
    private unowned Wl.Client? client;
    private Compositor compositor;


    public Embedder(Display display, Compositor compositor) {
        this.display = display;
        this.compositor = compositor;
        bound = new HashTable<unowned Wl.Client, unowned Wevp.Embedder>(direct_hash, direct_equal);
        glob = new Wl.Global(display.wl_display, ref Wevp.embedder_interface, VERSION, this, Embedder.bind);
        display.client_destroyed.connect(on_client_destroyed);
        Timeout.add_seconds(10, () => {send_ping(); return true;});
    }

    ~Embedder() {
        display.client_destroyed.disconnect(on_client_destroyed);
        stderr.printf("~Embed\n");
        destroyed();
    }

    public signal void destroyed();

    /**
     * Emitted when an orphaned view is available.
     *
     * You must hold the reference to view it it will be destroyed.
     */
    public signal void orphaned_view(View view);

    /**
     * Add a new canvas for rendering.
     *
     * You must hold the reference to view it it will be destroyed.
     */
    public View add_canvas(Canvas canvas) {
        var view = new View(display, canvas);
        view.weak_ref(on_adaptor_destroyed);
        views.prepend(view);
        if (client != null) {
            request_view(view);
        }
        return view;
    }

    private void on_adaptor_destroyed(GLib.Object object) {
        views.remove((View) object);
    }

    private void request_view(View view) {
        debug("Request view %s.", Utils.client_info(client));
        unowned Canvas canvas = view.canvas;
        uint width = (uint) canvas.get_allocated_width();
        uint height = (uint) canvas.get_allocated_height();
        uint scale = (uint) canvas.scale_factor;
        debug("Window %u×%u factor %u.", width, height, scale);
        view.serial = display.wl_display.next_serial();
        bound[client].send_view_requested(view.serial, width, height, scale);
    }

    private static void bind(Wl.Client client, void *data, uint version, uint id) {
        debug("%s: Bind embedder version=%u id=%u", Utils.client_info(client), version, id);
        unowned Embedder self = (Embedder) data;
        if (client in self.bound) {
            client.post_implementation_error("Cannot bind embed more than once.");
            return;
        }

        unowned Wevp.Embedder wl_embedder = Wevp.Embedder.create(client, ref Wevp.embedder_interface, (int) version, id);
        wl_embedder.set_implementation(&Embedder.impl, self, null);
        self.bound[client] = wl_embedder;

        if (self.client == null) {
            self.client = client;
            foreach (unowned View view in self.views) {
                if (view.client == null) {
                    self.request_view(view);
                }
            }
        }
    }

    private static void pong(Wl.Client client, Wevp.Embedder wl_embedder, uint serial) {
        debug("%s: Pong serial=%u", Utils.client_info(client), serial);
    }

    private static void create_view(
        Wl.Client client, Wevp.Embedder wl_embedder, uint serial, uint view_id,
        Wl.Surface surface, uint width, uint height, uint scale
    ) {
        debug("%s: New view serial=%u id=%u", Utils.client_info(client), serial, view_id);
        unowned Embedder self = (Embedder) wl_embedder.get_user_data();
        View? view = null;
        
        if (serial == 0) {
            var canvas = new Canvas();
            view = new View(self.display, canvas);
            view.weak_ref(self.on_adaptor_destroyed);
            self.views.prepend(view);
            self.orphaned_view(view);
        } else {
            foreach (unowned View candidate in self.views) {
                if (candidate.serial == serial) {
                    debug("Found serial %u", serial);
                    view = candidate;
                    break;
                }
            }
        }

        if (view == null) {
            warning("Serial not found: %u.", serial);
            client.post_implementation_error("Wrong view serial: %u.", serial);
        } else {
            unowned Wevp.View wl_view = Wevp.View.create(client, ref Wevp.view_interface, VERSION, view_id);
            view.attach_view(client, wl_view, self.compositor.get_surface(surface.get_id()));
            view.width = width;
            view.height = height;
            view.scale = scale;
            view.check_state();
        }
    }

    private void on_client_destroyed(Wl.Client client) {
        if (client in bound) {
            bound.remove(client);
            if (this.client == client) {
                List<unowned Wl.Client>? candidates =  bound.get_keys();
                if (candidates == null) {
                    this.client = null;
                } else {
                    this.client = candidates.data;
                }
            }

            foreach (unowned View view in views) {
                if (view.client == client) {
                    view.serial = 0;
                    view.client = null;
                    view.view = null;
                    view.surface = null;

                    if (this.client != null) {
                        request_view(view);
                    }
                }
            }
        }
    }

    private void send_ping() {
        uint serial = display.wl_display.next_serial();
        var iter = HashTableIter<unowned Wl.Client, unowned Wevp.Embedder>(bound);
        unowned Wl.Client client;
        unowned Wevp.Embedder embedder;
        while (iter.next (out client, out embedder)) {
            debug("Ping for %s: %u.", Utils.client_info(client), serial);
            embedder.send_ping(serial);
        }
        display.dispatch();
    }
}

} // namespace Wevf
