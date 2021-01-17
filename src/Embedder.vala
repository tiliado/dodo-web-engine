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
    private HashTable<View, Adaptor> widgets;
    private unowned Wl.Client? client;
    private Compositor compositor;


    public Embedder(Display display, Compositor compositor) {
        this.display = display;
        this.compositor = compositor;
        bound = new HashTable<unowned Wl.Client, unowned Wevp.Embedder>(direct_hash, direct_equal);
        widgets = new HashTable<View, Adaptor>(direct_hash, direct_equal);
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

    public signal void orphaned_view(Adaptor adaptor);

    public Adaptor add_view(View widget) {
        var adaptor = new Adaptor(display, widget);
        widgets[widget] = adaptor;
        if (client != null) {
            request_view(adaptor);
        }
        return adaptor;
    }

    private void request_view(Adaptor adaptor) {
        debug("Request view %s.", Utils.client_info(client));
        unowned Gtk.Widget widget = adaptor.widget;
        uint width = (uint) widget.get_allocated_width();
        uint height = (uint) widget.get_allocated_height();
        uint scale = (uint) widget.scale_factor;
        debug("Window %u×%u factor %u.", width, height, scale);
        adaptor.serial = display.wl_display.next_serial();
        bound[client].send_view_requested(adaptor.serial, width, height, scale);
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
            List<unowned Adaptor> candidates =  self.widgets.get_values();
            foreach (unowned Adaptor adaptor in candidates) {
                if (adaptor.client == null) {
                    self.request_view(adaptor);
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
        Adaptor? adaptor = null;
        
        if (serial == 0) {
            var widget = new View();
            adaptor = new Adaptor(self.display, widget);
            self.widgets[widget] = adaptor;
            self.orphaned_view(adaptor);
        } else {
            List<unowned Adaptor> candidates =  self.widgets.get_values();
            foreach (unowned Adaptor candidate in candidates) {
                if (candidate.serial == serial) {
                    debug("Found serial %u", serial);
                    adaptor = candidate;
                    break;
                }
            }
        }

        if (adaptor == null) {
            warning("Serial not found: %u.", serial);
            client.post_implementation_error("Wrong view serial: %u.", serial);
        } else {
            unowned Wevp.View view = Wevp.View.create(client, ref Wevp.view_interface, VERSION, view_id);
            adaptor.attach_view(client, view, self.compositor.get_surface(surface.get_id()));
            adaptor.width = width;
            adaptor.height = height;
            adaptor.scale = scale;
            adaptor.check_state();
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

            List<unowned Adaptor> candidates =  this.widgets.get_values();
            foreach (unowned Adaptor adaptor in candidates) {
                if (adaptor.client == client) {
                    adaptor.serial = 0;
                    adaptor.client = null;
                    adaptor.view = null;
                    adaptor.surface = null;

                    if (this.client != null) {
                        request_view(adaptor);
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
