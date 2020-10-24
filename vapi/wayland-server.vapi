[CCode(cheader_filename="wayland-server.h,wayland-server-protocol.h")]
namespace Wl {

[CCode(cname="wl_global_bind_func_t", has_target=false)]
public delegate void GlobalBindFunc(Client client, void* data, uint version, uint id);
[CCode(cname="wl_notify_func_t", has_target=false)]
public delegate void NotifyFunc(Listener? listener, void* data);
[CCode(cname="wl_resource_destroy_func_t", has_target=false)]
public delegate void ResourceDestroyFunc(Resource? resource);
[CCode(has_target=false)]
public delegate void AttachBufferFunc(Wl.Client client, Wl.Resource resource, Wl.Buffer buffer, int x, int y);
[CCode(has_target=false)]
public delegate void ClientResourceDestroyFunc(Wl.Client client, Wl.Resource resource);
[CCode(has_target=false)]
public delegate void CommitFunc(Wl.Client client, Wl.Resource resource);
[CCode(has_target=false)]
public delegate void CreateSurfaceFunc(Wl.Client client, Wl.Resource resource, uint id);
[CCode(has_target=false)]
public delegate void CreateRegionFunc(Wl.Client client, Wl.Resource resource, uint id);
[CCode(has_target=false)]
public delegate void DamageBufferFunc(Wl.Client client, Wl.Resource resource, int x, int y, int width, int height);
[CCode(has_target=false)]
public delegate void DamageSurfaceFunc(Wl.Client client, Wl.Resource resource, int x, int y, int width, int height);
[CCode(has_target=false)]
public delegate void RequestFrameFunc(Wl.Client client, Wl.Resource resource, uint callback_id);
[CCode(has_target=false)]
public delegate void SetBufferScaleFunc(Wl.Client client, Wl.Resource resource, int scale);
[CCode(has_target=false)]
public delegate void SetBufferTransformFunc(Wl.Client client, Wl.Resource resource, int transform);
[CCode(has_target=false)]
public delegate void SetInputRegionFunc(Wl.Client client, Wl.Resource resource, Wl.Resource region);
[CCode(has_target=false)]
public delegate void SetOpaqueRegionFunc(Wl.Client client, Wl.Resource resource, Wl.Resource region);

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
    [CCode(cname="wl_resource_create")]
    public static unowned Resource borrow(Client client, ref Interface ifce, int version, uint id);
    public void add_destroy_listener(ref Listener listener);
    public void destroy();
    public unowned Client? get_client();
    public uint get_id();
    public unowned List? get_link();
    public void* get_user_data();
    public int get_version();
    public void post_error(uint code, string msg, ...);
    public void set_implementation(void* implementation, void *data, ResourceDestroyFunc? destroy);
    public void set_user_data(void* data);
}

[CCode(cname="struct wl_resource", free_function="wl_resource_destroy")]
[Compact]
public class Buffer : Resource {
    [CCode(cname="wl_resource_create")]
    public Buffer(Client client, ref Interface ifce, int version, uint id);
    public void send_release();
}

[CCode(cname="struct wl_resource", free_function="wl_resource_destroy")]
[Compact]
public class Callback : Resource {
    [CCode(cname="wl_resource_create")]
    public Callback(Client client, ref Interface ifce, int version, uint id);
    public void send_done(uint data);
}

[CCode(cname="struct wl_shm_buffer", free_function="")]
[Compact]
public class ShmBuffer {
    [CCode(cname="wl_shm_buffer_get")]
    public static unowned ShmBuffer? from_resource(Wl.Resource resource);
    public void begin_access();
    public void end_access();
    public void* get_data();
    public int get_stride();
    public uint get_format();
    public int get_width();
    public int get_height();
}

[CCode(cname="struct wl_resource", free_function="wl_resource_destroy")]
[Compact]
public class Surface : Resource {
    [CCode(cname="wl_resource_create")]
    public Surface(Client client, ref Interface ifce, int version, uint id);
    [CCode(cname="wl_resource_create")]
    public static unowned Surface borrow(Client client, ref Interface ifce, int version, uint id);
}

[CCode (cname = "struct wl_compositor_interface", has_type_id = false)]
public struct CompositorInterface {
    public CreateSurfaceFunc create_surface;
    public CreateRegionFunc create_region;
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

[CCode (cname = "struct wl_surface_interface", has_type_id = false)]
public struct SurfaceInterface {
    public ClientResourceDestroyFunc destroy;
    public AttachBufferFunc attach;
    public DamageSurfaceFunc damage;
    public RequestFrameFunc frame;
    public SetOpaqueRegionFunc set_opaque_region;
    public SetInputRegionFunc set_input_region;
    public CommitFunc commit;
    public SetBufferTransformFunc set_buffer_transform;
    public SetBufferScaleFunc set_buffer_scale;
    public DamageBufferFunc damage_buffer;
}

[CCode (cname = "struct wl_list", has_type_id = false, destroy_function="")]
public struct List {
    List? prev;
    List? next;

    [CCode (cname = "wl_list_init")]
    public List();
    public void init();
    public void remove();

    public void destroy() {
        init();
        remove();
    }
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

public static Interface callback_interface;
public static Interface compositor_interface;
public static Interface surface_interface;

public enum SurfaceError {
    INVALID_SCALE = 0,
    INVALID_TRANSFORM = 1;
}

} // namespace Wl
