[CCode(cheader_filename="wayland-server.h,wayland-server-protocol.h")]
namespace Wl {

[CCode(cname="wl_notify_func_t", has_target=false)]
public delegate void NotifyFunc(Listener? listener, void* data);

[CCode(cname="struct wl_display", free_function="wl_display_destroy")]
[Compact]
public class Display {
    [CCode(cname="wl_display_create")]
    public Display();
    public void add_destroy_listener(ref Listener listener);
    public int add_socket(string name);
    public void destroy_clients();
    public void flush_clients();
    public unowned EventLoop get_event_loop();
    public uint get_serial();
    public int init_shm();
    public uint next_serial();
    public void run();
}

[CCode(cname="struct wl_event_loop", free_function="wl_event_loop_destroy")]
[Compact]
public class EventLoop {
    [CCode(cname="wl_event_loop_create")]
    public EventLoop();
    public int dispatch(int timeout);
    public int get_fd();

}

[CCode (cname = "struct wl_listener", has_type_id = false, destroy_function="")]
public struct Listener {
    List link;
    NotifyFunc notify;
}

[CCode (cname = "struct wl_list", has_type_id = false, destroy_function="")]
public struct List {
    List? prev;
    List? next;

    [CCode (cname = "wl_list_init")]
    public List();
    public void remove();
}


} // namespace Wl
