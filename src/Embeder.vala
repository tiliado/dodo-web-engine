namespace Embed {

public class Embeder : GLib.Object {
    private const int VERSION = 1;
    private static Nuv.EmbederInterface impl = {
        Embeder.pong
    };
    public Wl.Global glob;
    private unowned Display display;
    private HashTable<unowned Wl.Client, Nuv.Embeder> bound;


    public Embeder(Display display) {
        this.display = display;
        bound = new HashTable<unowned Wl.Client, Nuv.Embeder>(direct_hash, direct_equal);
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
    }

    public static void pong(Wl.Client client, Wl.Resource resource, uint serial) {
        debug("%s: Pong serial=%u", Utils.client_info(client), serial);
    }

    private void on_client_destroyed(Wl.Client client) {
        if (client in bound) {
            bound.remove(client);
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
