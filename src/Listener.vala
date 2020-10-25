namespace Wevf {

public delegate void ListenerHandler(Listener listener, void* data);


[Compact]
public class Listener {
    public Wl.Listener listener;  // Must be the first member.
    public ListenerHandler? handler;

    public Listener() {
        listener.notify = Listener.dispatch;
        listener.link = Wl.List();
    }

    private static void dispatch(Wl.Listener? listener, void* data) {
        unowned Listener? self = (Listener?) listener;
        if (self.handler != null) {
            self.handler(self, data);
        }
    }

    public void connect(owned ListenerHandler handler) {
        this.handler = (owned) handler;
    }

    public void disconnect() {
        assert(handler != null);
        handler = null;
        listener.link.remove();
    }
}

} // namespace Wevf
