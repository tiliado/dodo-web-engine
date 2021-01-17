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
    private List<unowned Canvas> canvas_requests;
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
     * Emitted when an orphaned canvas is available.
     *
     * You must hold the reference to canvas it it will be destroyed.
     */
    public signal void unclaimed_canvas(Canvas canvas);

    /**
     * Add a new canvas for rendering.
     *
     * You must hold the reference to canvas it it will be destroyed.
     */
    public Canvas create_canvas() {
        var canvas = new Canvas(display);
        canvas.weak_ref(on_canvas_destroyed);
        canvas_requests.prepend(canvas);
        if (client != null) {
            request_canvas(canvas);
        }
        return canvas;
    }

    private void on_canvas_destroyed(GLib.Object object) {
        canvas_requests.remove((Canvas) object);
    }

    private void request_canvas(Canvas canvas) {
        debug("Request canvas %s.", Utils.client_info(client));
        uint width = (uint) canvas.get_allocated_width();
        uint height = (uint) canvas.get_allocated_height();
        uint scale = (uint) canvas.scale_factor;
        debug("Window %u×%u factor %u.", width, height, scale);
        canvas.serial = display.wl_display.next_serial();
        bound[client].send_view_requested(canvas.serial, width, height, scale);
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
            foreach (unowned Canvas canvas in self.canvas_requests) {
                if (canvas.client == null) {
                    self.request_canvas(canvas);
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
        debug("%s: New canvas serial=%u id=%u", Utils.client_info(client), serial, view_id);
        unowned Embedder self = (Embedder) wl_embedder.get_user_data();
        Canvas? canvas = null;
        
        if (serial == 0) {
            canvas = new Canvas(self.display);
        } else {
            foreach (unowned Canvas candidate in self.canvas_requests) {
                if (candidate.serial == serial) {
                    debug("Found serial %u", serial);
                    canvas = candidate;
                    self.canvas_requests.remove(candidate);
                    break;
                }
            }
            if (canvas == null) {
                warning("Serial not found: %u.", serial);
                client.post_implementation_error("Wrong canvas serial: %u.", serial);
                return;
            }
        }

         
        unowned Wevp.View wl_view = Wevp.View.create(client, ref Wevp.view_interface, VERSION, view_id);
        canvas.attach_view(client, wl_view, self.compositor.get_surface(surface.get_id()));
        canvas.width = width;
        canvas.height = height;
        canvas.scale = scale;
        canvas.update_state();

        if (serial == 0) {
            self.unclaimed_canvas(canvas);
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

            foreach (unowned Canvas canvas in canvas_requests) {
                if (canvas.client == client) {
                    canvas.serial = 0;
                    canvas.client = null;
                    canvas.surface = null;

                    if (this.client != null) {
                        request_canvas(canvas);
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
