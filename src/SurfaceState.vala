namespace Wevf {

public class SurfaceState {
    public Rect damage;
    public Update update;
    /** The x position of a buffer top left corner in surface coordinates relative to the current coordinates. */
    public int dx;
    /** The y position of a buffer top left corner in surface coordinates relative to the current coordinates. */
    public int dy;
    public int scale;
    public unowned Wl.Buffer? buffer;
    public SList<unowned Wl.Callback?> frames;
    private Listener buffer_destroyed_listener;

    public SurfaceState() {
        damage.reset();
        dx = dy = 0;
        buffer = null;
        scale = 1;
        buffer_destroyed_listener = new Listener();
    }

    ~SurfaceState() {
        reset_buffer();
        destroy_frame_callbacks();
    }

    public void set_buffer(Wl.Buffer? buffer) {
        reset_buffer();
        this.buffer = buffer;

        if (buffer != null) {
            buffer_destroyed_listener.connect(on_buffer_destroyed);
            buffer.add_destroy_listener(ref buffer_destroyed_listener.listener);
        }
    }

    public void reset_buffer() {
        if (buffer != null) {
            buffer_destroyed_listener.disconnect();
            buffer = null;
        }
    }

    public void commit(SurfaceState target) {
        if ((this.update & Update.BUFFER) != 0) {
            target.set_buffer(this.buffer);
            this.reset_buffer();
            target.dx = this.dx;
            target.dy = this.dy;
            this.dx = this.dy = 0;
        }

        if ((this.update & Update.DAMAGE) != 0) {
            target.damage = this.damage;
            this.damage.reset();
        }

        if ((this.update & Update.SCALE) != 0) {
            target.scale = scale;
        }

        if ((this.update & Update.FRAME) != 0) {
            target.destroy_frame_callbacks();
            target.frames = (owned) this.frames;
        }

        target.update = this.update;
        this.update = Update.NONE;
    }

    private void on_buffer_destroyed(Listener listener, void* data) {
        reset_buffer();
    }

    public void steal_frame_callback(Wl.Callback? node) {
        frames.remove(node);
    }

    public void destroy_frame_callbacks() {
        unowned SList<unowned Wl.Callback?>? node = frames;
        while (node != null) {
            node.data.destroy();
            node = node.next;
        }
        frames = null;
    }
}


public struct Rect {
    public int x;
    public int y;
    public int w;
    public int h;

    public Rect(int x, int y, int w, int h) {
        this.x = x;
        this.y = y;
        this.w = w;
        this.h = h;
    }

    public void reset() {
        x = y = w = h = -1;
    }

    public void expand(int x, int y, int w, int h) {
        if (this.x < 0) {
            this.x = x;
        } else {
            this.x = int.min(this.x, x);
        }
        if (this.y < 0) {
            this.y = y;
        } else {
            this.y = int.min(this.y, y);
        }
        if (this.w < 0) {
            this.w = w;
        } else {
            this.w = int.max(this.w, w);
        }
        if (this.h < 0) {
            this.h = h;
        } else {
            this.h = int.max(this.h, h);
        }
    }
}


[Flags]
public enum Update {
    NONE,
    DAMAGE,
    BUFFER,
    SCALE,
    FRAME;
}

} // namespace Wevf
