using GL;

namespace Embed {

public class Surface : GLib.Object {
    private const int CALLBACK_VERSION = 1;
    private const int SURFACE_VERSION = 4;
    private static Wl.SurfaceInterface impl = {
        Surface.destroy,
        Surface.attach,
        Surface.damage,
        Surface.frame,
        Surface.set_opaque_region,
        Surface.set_input_region,
        Surface.commit,
        Surface.set_buffer_transform,
        Surface.set_buffer_scale,
        Surface.damage_buffer
    };
    public uint id;
    private unowned Wl.Surface? resource;
    private SurfaceState pending = new SurfaceState();
    private SurfaceState committed = new SurfaceState();
    /** The x position of a buffer top left corner in surface coordinates. */
    private int x;
    /** The y position of a buffer top left corner in surface coordinates. */
    private int y;
    public Buffer? buffer;
    private unowned Gdk.GLContext? gl_context = null;
    private unowned Wl.Client client;
    private unowned Display display;

    public Surface(Display display, Wl.Client client, int version, uint id) {
        this.id = id;
        this.display = display;
        this.client = client;
        debug("%s: New surface version=%d, id=%u.", Utils.client_info(client), version, id);
        assert(1 <= version <= SURFACE_VERSION);
        resource = Wl.Surface.borrow(client, ref Wl.surface_interface, version, id); // Owned by Wayland
        resource.set_implementation(&Surface.impl, this, Surface.resource_destroyed);
    }

    public signal void state_committed();
    public signal void destroyed();

    private static void resource_destroyed(Wl.Resource? resource) {
        unowned Surface self = (Surface) resource.get_user_data();
        self.pending.reset_buffer();
        self.committed.reset_buffer();
        self.buffer = null;
        self.destroyed();
    }

    private static void destroy(Wl.Client client, Wl.Resource resource) {
        resource.destroy();
    }

    private static void attach(Wl.Client client, Wl.Resource resource, Wl.Buffer buffer, int x, int y) {
        unowned Surface s = Surface.from_resource(resource);
        s.pending.update |= Update.BUFFER;
        s.pending.dx = x;
        s.pending.dy = y;
        s.pending.set_buffer(buffer);
    }

    private static void damage(Wl.Client client, Wl.Resource resource, int x, int y, int width, int height) {
        unowned Surface s = Surface.from_resource(resource);
        if (width < 0 || height < 0) {
            return;
        }

        // TODO: Proper manipulation with pixman
        Rect* damage = &s.pending.damage;
        damage.expand(x, y, width, height);
        s.pending.update |= Update.DAMAGE;
    }

    private static void frame(Wl.Client client, Wl.Resource resource, uint callback_id) {
        unowned Surface s = Surface.from_resource(resource);
        var callback_resource = new Wl.Callback(client, ref Wl.callback_interface, CALLBACK_VERSION, callback_id);
        callback_resource.set_implementation(null, null, null);
        // FIXME: callback_resource.set_implementation(null, null, callback_handle_resource_destroy);
        s.pending.frames.prepend((owned) callback_resource);
        s.pending.update |= Update.FRAME;
    }

    private static void set_opaque_region(Wl.Client client, Wl.Resource resource, Wl.Resource region){
    }

    private static void set_input_region(Wl.Client client, Wl.Resource resource, Wl.Resource region){
    }

    private static void commit(Wl.Client client, Wl.Resource resource) {
        unowned Surface s = Surface.from_resource(resource);
        s.pending.commit(s.committed);
        s.x += s.committed.dx;
        s.y += s.committed.dy;
        s.update_buffer();
        s.state_committed();
    }

    private static void set_buffer_transform(Wl.Client client, Wl.Resource resource, int transform) {

    }

    private static void set_buffer_scale(Wl.Client client, Wl.Resource resource, int scale) {
        if (scale <= 0) {
            resource.post_error(Wl.SurfaceError.INVALID_SCALE, "Specified scale value (%d) is not positive", scale);
            return;
        }
        unowned Surface s = Surface.from_resource(resource);
        s.pending.update |= Update.SCALE;
        s.pending.scale = scale;
    }

    private static void damage_buffer(Wl.Client client, Wl.Resource resource, int x, int y, int width, int height) {
        Surface.damage(client, resource, x, y, width, height);
    }

    private static unowned Surface from_resource(Wl.Resource resource) {
        return (Surface) resource.get_user_data();
    }

    private void update_buffer() {
        if ((committed.update & Update.BUFFER) == 0) {
            return;
        }

        this.buffer = null;
        unowned Wl.Buffer? resource = committed.buffer;
        if (resource == null) {
            return;
        }

        if (gl_context == null) {
            warning("No gl context");
            resource.send_release();
            return;
        }

        Buffer? buffer = Buffer.import(display, resource, gl_context);
        if (buffer == null) {
            critical("Failed to upload buffer");
            return;
        }

        this.buffer = buffer;
    }

    public void set_gl_context(Gdk.GLContext? gl_context) {
        if (this.gl_context != null && buffer != null) {
            buffer.destroy_texture();
        }
        this.gl_context = gl_context;
    }

    public void queue_render_frame() {
        uint time_msec = (uint) (GLib.get_monotonic_time() / 1000);
        SList<Wl.Callback?> callbacks = (owned) committed.frames;
        callbacks.reverse();
        foreach (unowned Wl.Callback? resource in callbacks) {
            resource.send_done(time_msec);
        }
        display.dispatch();
    }
}

} // namespace Embed
