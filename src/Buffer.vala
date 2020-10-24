using GL;

namespace Embed {

public class Buffer : GLib.Object {
    private unowned Wl.Buffer? wl_buffer;
    private bool wl_buffer_released;
    private unowned Gdk.GLContext gl_context;
    private GLuint texture;
    public int width;
    public int height;
    private Listener destroyed_listener = new Listener();
    private unowned Display display;

    public Buffer(Display display, Wl.Buffer wl_buffer, Gdk.GLContext gl_context, GLuint texture, bool released, int width, int height) {
        this.display = display;
        this.wl_buffer = wl_buffer;
        this.gl_context = gl_context;
        this.texture = texture;
        this.wl_buffer_released = released;
        this.width = width;
        this.height = height;
        destroyed_listener.connect(on_destroyed);
        wl_buffer.add_destroy_listener(ref destroyed_listener.listener);
    }

    ~Buffer() {
        debug("~Buffer");
        release();
        destroy_texture();
    }

    public signal void destroyed();

    public void release() {
        if (wl_buffer_released || wl_buffer == null) {
            return;
        }

        wl_buffer_released = true;
        wl_buffer.send_release();
        display.dispatch();
        wl_buffer = null;
    }

    /** Get texture without claiming the ownership. */
    public GLuint get_texture() {
        return texture;
    }

    /** Take texture claiming the ownership. */
    public GLuint take_texture() {
        GLuint taken_texture = this.texture;
        this.texture = 0;
        return taken_texture;
    }

    public void destroy_texture() {
        if (texture != 0) {
            gl_context.make_current();
            glDeleteTextures(1, {texture});
            texture = 0;
        }
    }

    public static Buffer? import(Display display, Wl.Buffer wl_buffer, Gdk.GLContext gl_context) {
        GLuint texture = 0;
        bool released = false;

        unowned Wl.ShmBuffer? shm_buffer = Wl.ShmBuffer.from_resource(wl_buffer);
        if (shm_buffer != null) {
            uint fmt = shm_buffer.get_format();
            int stride = shm_buffer.get_stride();
            int width = shm_buffer.get_width();
            int height = shm_buffer.get_height();

            gl_context.make_current();
            shm_buffer.begin_access();
            void *data = shm_buffer.get_data();
            texture = Textures.load_from_pixels(data, fmt, width, height, stride);
            shm_buffer.end_access();

            /* We copied all data so we don't need the wl_buffer anymore.
             * We would need hold the wl_buffer if we shared the backing
             * store without copying, e.g. using wl_drm.
             */
            wl_buffer.send_release();
            display.dispatch();
            released = true;
        } else {
            critical("Cannot upload texture: unknown buffer type");
            wl_buffer.post_error(0, "unknown buffer type"); // Disconnect the client with error.
            return null;
        }

        if (texture == 0) {
            // This is our failure, don't disconnect the client.
            critical("Failed to upload texture");
            wl_buffer.send_release();
            display.dispatch();
            return null;
        }

        int width, height;
        assert(Buffer.get_size(wl_buffer, out width, out height));
        debug("Texture imported %u %d×%d", (uint) texture, width, height);

        return new Buffer(display, wl_buffer, gl_context, texture, released, width, height);
    }

    public static bool get_size(Wl.Buffer wl_buffer, out int width, out int height) {
        unowned Wl.ShmBuffer? shm_buffer = Wl.ShmBuffer.from_resource(wl_buffer);
        if (shm_buffer != null) {
            width = shm_buffer.get_width();
            height = shm_buffer.get_height();
            return true;
        }

        width = height = 0;
        return false;
    }

    private void on_destroyed(Listener listener, void* data) {
        listener.disconnect();
        destroyed();
        wl_buffer = null;
    }
}


} // namespace Embed