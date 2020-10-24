namespace Embed {

public class Compositor : GLib.Object{
    private const int COMPOSITOR_VERSION = 4;
    private static Wl.CompositorInterface impl = {
        Compositor.create_surface,
        Compositor.create_region
    };
    private HashTable<void*, Surface> surfaces;
    public Wl.Global glob;
    private unowned Display display;
    private HashTable<unowned Wl.Client, Wl.Resource> bound;

    public Compositor(Display display) {
        this.display = display;
        bound = new HashTable<unowned Wl.Client, Wl.Resource>(direct_hash, direct_equal);
        surfaces = new HashTable<void*, Surface>(direct_hash, direct_equal);
        glob = new Wl.Global(display.wl_display, ref Wl.compositor_interface, COMPOSITOR_VERSION, this, Compositor.bind);
        display.client_destroyed.connect(on_client_destroyed);

    }

    ~Compositor() {
        display.client_destroyed.disconnect(on_client_destroyed);
    }

    public signal void surface_created(Surface surface);
    public signal void surface_destroyed(Surface surface);

    public Surface? get_surface(uint id) {
        return surfaces[id.to_pointer()];
    }

    private static void bind(Wl.Client client, void *data, uint version, uint id) {
        debug("%s: Bind compositor version=%u, id=%u.", Utils.client_info(client), version, id);
        unowned Compositor self = (Compositor) data;
        if (client in self.bound) {
            client.post_implementation_error("Cannot bind compositor more than once.");
            return;
        }
        var resource = new Wl.Resource(client, ref Wl.compositor_interface, (int) version, id);
        resource.set_implementation(&Compositor.impl, self, null);
        self.bound[client] = (owned) resource;
    }

    private static void create_surface(Wl.Client client, Wl.Resource resource, uint id) {
        debug("%s: Create surface id=%u.", Utils.client_info(client), id);
        unowned Compositor self = (Compositor) resource.get_user_data();
        var surface = new Surface(self.display, client, resource.get_version(), id);
        self.surfaces[surface.id.to_pointer()] = surface;
        self.surface_created(surface);
        surface.destroyed.connect(self.on_surface_destroyed);
    }

    private static void create_region(Wl.Client client, Wl.Resource resource, uint id) {}

    private void on_client_destroyed(Wl.Client client) {
        if (client in bound) {
            bound.remove(client);
        }
    }

    private void on_surface_destroyed(Surface surface) {
        surface.destroyed.disconnect(on_surface_destroyed);
        surface_destroyed(surface);
        surfaces.remove(surface.id.to_pointer());
    }
}

} // namespace Embed
