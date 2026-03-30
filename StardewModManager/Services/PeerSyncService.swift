import Foundation
import MultipeerConnectivity

@MainActor
class PeerSyncService: NSObject, ObservableObject {
    private let serviceType = "smm-sync"
    private let myPeerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    @Published var foundPeers: [MCPeerID] = []
    @Published var connectedPeer: MCPeerID?
    @Published var receivedModpack: ShareableModpack?
    @Published var isSearching = false
    @Published var connectionState: ConnectionState = .idle

    enum ConnectionState {
        case idle
        case searching
        case connected(String)
        case received
        case error(String)
    }

    override init() {
        myPeerID = MCPeerID(displayName: Host.current().localizedName ?? "Unknown Mac")
        super.init()
    }

    func startSearching() {
        let session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        self.session = session

        let advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser

        let browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser

        isSearching = true
        connectionState = .searching
        foundPeers = []
        connectedPeer = nil
        receivedModpack = nil
    }

    func stopSearching() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        isSearching = false
        connectionState = .idle
        foundPeers = []
        connectedPeer = nil
    }

    func connectToPeer(_ peer: MCPeerID) {
        guard let session, let browser else { return }
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 10)
    }

    func sendModpack(_ modpack: ShareableModpack) {
        guard let session, !session.connectedPeers.isEmpty else { return }
        guard let data = try? modpack.toJSON() else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }
}

// MARK: - MCSessionDelegate

extension PeerSyncService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                connectedPeer = peerID
                connectionState = .connected(peerID.displayName)
                // Stop browsing once connected
                advertiser?.stopAdvertisingPeer()
                browser?.stopBrowsingForPeers()
            case .notConnected:
                if connectedPeer == peerID {
                    connectedPeer = nil
                    if case .received = connectionState { } else {
                        connectionState = .searching
                    }
                }
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let modpack = try? ShareableModpack.fromJSON(data) else { return }
        Task { @MainActor in
            receivedModpack = modpack
            connectionState = .received
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension PeerSyncService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept invitations
        Task { @MainActor in
            invitationHandler(true, self.session)
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension PeerSyncService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            if !foundPeers.contains(peerID) {
                foundPeers.append(peerID)
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            foundPeers.removeAll { $0 == peerID }
        }
    }
}
