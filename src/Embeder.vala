namespace Embed {

public class Embeder : GLib.Object {
    private const int VERSION = 1;
    private static Nuv.EmbederInterface impl = {
        Embeder.pong,
        Embeder.new_view
    };
    public Wl.Global glob;
    private unowned Display display;
    private HashTable<unowned Wl.Client, Nuv.Embeder> bound;
    private HashTable<Gtk.Widget, Adaptor> widgets;
    private unowned Wl.Client? client;
    private Compositor compositor;


    public Embeder(Display display, Compositor compositor) {
        this.display = display;
        this.compositor = compositor;
        bound = new HashTable<unowned Wl.Client, Nuv.Embeder>(direct_hash, direct_equal);
        widgets = new HashTable<Gtk.Widget, Adaptor>(direct_hash, direct_equal);
        glob = new Wl.Global(display.wl_display, ref Nuv.embeder_interface, VERSION, this, Embeder.bind);
        display.client_destroyed.connect(on_client_destroyed);
        Timeout.add_seconds(10, () => {send_ping(); return true;});
    }

    ~Embeder() {
        display.client_destroyed.disconnect(on_client_destroyed);
        stderr.printf("~Embed\n");
        destroyed();
    }

    public signal void destroyed();

    public void add_view(Gtk.Widget widget) {
        var adaptor = new Adaptor(display, widget);
        widgets[widget] = adaptor;
        if (client != null) {
            request_view(adaptor);
        }
    }

    private void request_view(Adaptor adaptor) {
        debug("Request view %s.", Utils.client_info(client));
        unowned Gtk.Widget widget = adaptor.widget;
        uint width = (uint) widget.get_allocated_width();
        uint height = (uint) widget.get_allocated_height();
        uint scale = (uint) widget.scale_factor;
        debug("Window %u×%u factor %u.", width, height, scale);
        adaptor.serial = display.wl_display.next_serial();
        bound[client].send_view_request(adaptor.serial, width, height, scale);
    }

    private static void bind(Wl.Client client, void *data, uint version, uint id) {
        debug("%s: Bind embeder version=%u id=%u", Utils.client_info(client), version, id);
        unowned Embeder self = (Embeder) data;
        if (client in self.bound) {
            client.post_implementation_error("Cannot bind embed more than once.");
            return;
        }

        var resource = new Nuv.Embeder(client, ref Nuv.embeder_interface, (int) version, id);
        resource.set_implementation(&Embeder.impl, self, null);
        self.bound[client] = (owned) resource;

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

    private static void pong(Wl.Client client, Wl.Resource resource, uint serial) {
        debug("%s: Pong serial=%u", Utils.client_info(client), serial);
    }

    private static void new_view(
        Wl.Client client, Wl.Resource resource, uint serial, uint view_id,
        Wl.Surface surface, uint width, uint height, uint scale
    ) {
        debug("%s: New view serial=%u id=%u", Utils.client_info(client), serial, view_id);
        unowned Embeder self = (Embeder) resource.get_user_data();
        List<unowned Adaptor> candidates =  self.widgets.get_values();
        foreach (unowned Adaptor adaptor in candidates) {
            if (adaptor.serial == serial) {
                var view = new Nuv.View(client, ref Nuv.view_interface, VERSION, view_id);
                adaptor.attach_view(client, (owned) view, self.compositor.get_surface(surface.get_id()));
                adaptor.width = width;
                adaptor.height = height;
                adaptor.scale = scale;
                adaptor.check_state();
                return;
            }
        }
        client.post_implementation_error("Wrong view serial: %u.", serial);
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
        var iter = HashTableIter<unowned Wl.Client, Nuv.Embeder>(bound);
        unowned Wl.Client client;
        unowned Nuv.Embeder embeder;
        while (iter.next (out client, out embeder)) {
            debug("Ping for %s: %u.", Utils.client_info(client), serial);
            embeder.send_ping(serial);
        }
        display.dispatch();
    }
}

} // namespace Embed
