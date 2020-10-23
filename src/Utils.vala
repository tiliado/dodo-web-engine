namespace Embed.Utils {

public string client_info(Wl.Client client) {
    uint pid;
    uint uid;
    uint gid;
    client.get_credentials(out pid, out uid, out gid);
    return "Client (pid=%u, uid=%u, gid=%u)".printf(pid, uid, gid);
}

} // namespace Embed.Utils
