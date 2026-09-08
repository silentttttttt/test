import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Deliberately refuse to create a fake/unencrypted tunnel. A real implementation
        // must speak a defined protocol to a real relay/VPN server before routing packets.
        let error = NSError(domain: "WebBrowseVPN", code: 100, userInfo: [NSLocalizedDescriptionKey: "No relay/VPN server is configured. WebBrowse will not pretend that IP protection is active."])
        completionHandler(error)
    }
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) { completionHandler() }
}
