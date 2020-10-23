[CCode(cheader_filename="wayland-server.h,wayland-server-protocol.h")]
namespace Wl {

[CCode(cname="wl_global_bind_func_t", has_target=false)]
public delegate void GlobalBindFunc(Client client, void* data, uint version, uint id);

[CCode(cname="wl_notify_func_t", has_target=false)]
public delegate void NotifyFunc(Listener? listener, void* data);

[CCode(cname="wl_resource_destroy_func_t", has_target=false)]
public delegate void ResourceDestroyFunc(Resource? resource);

[CCode(cname="struct wl_client", free_function="wl_client_destroy")]
[Compact]
public class Client {
    public void add_destroy_listener(ref Wl.Listener listener);
    public void get_credentials(out uint pid, out uint uid, out uint gid);
    public void post_implementation_error(string fmt, ...);
    public void post_no_memory();
}

[CCode(cname="struct wl_display", free_function="wl_display_destroy")]
[Compact]
public class Display {
    [CCode(cname="wl_display_create")]
    public Display();
    public void add_client_created_listener(ref Wl.Listener listener);
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

[CCode(cname="struct wl_global", free_function="wl_global_destroy")]
[Compact]
public class Global {
    [CCode(cname="wl_global_create")]
    public Global(Display display, ref Interface ifce, int version, void* data, GlobalBindFunc bind);
}

[CCode(cname="struct wl_resource", free_function="wl_resource_destroy")]
[Compact]
public class Resource {
    [CCode(cname="wl_resource_create")]
    public Resource(Client client, ref Interface ifce, int version, uint id);
    [CCode(cname="wl_callback_send_done")]
    public void callback_done(uint data);
    public unowned Client? get_client();
    public void* get_user_data();
    public int get_version();
    public void post_error(uint code, string msg, ...);
    public void set_implementation(void* implementation, void *data, ResourceDestroyFunc? destroy);
    public void set_user_data(void* data);
}

[CCode (cname = "struct wl_interface", has_type_id = false)]
public struct Interface {
    public string? name;
    public int version;
    public int method_count;
    public Message? methods;
    public int event_count;
    public Message? events;
}

[CCode (cname = "struct wl_list", has_type_id = false, destroy_function="")]
public struct List {
    List? prev;
    List? next;

    [CCode (cname = "wl_list_init")]
    public List();
    public void remove();
}

[CCode (cname = "struct wl_listener", has_type_id = false, destroy_function="")]
public struct Listener {
    List link;
    NotifyFunc notify;
}

[CCode (cname = "struct wl_message", has_type_id = false)]
public struct Message {
    public string name;
    public string signature;
    public Interface** types;
}

} // namespace Wl
