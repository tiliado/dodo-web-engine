[CCode(cheader_filename="nuvola-embed-protocol.h")]
namespace Nuv {

[CCode(has_target=false)]
public delegate void PongFunc(Wl.Client client, Wl.Resource resource, uint serial);

[CCode (cname = "struct nuv_embeder_interface", has_type_id = false)]
public struct EmbederInterface {
    public PongFunc pong;
}

[CCode(cname="struct wl_resource", free_function="wl_resource_destroy")]
[Compact]
public class Embeder: Wl.Resource {
    [CCode(cname="wl_resource_create")]
    public Embeder(Wl.Client client, ref Wl.Interface ifce, int version, uint id);
    public void send_ping(uint serial);
}

public static Wl.Interface embeder_interface;

} // namespace Nuv
