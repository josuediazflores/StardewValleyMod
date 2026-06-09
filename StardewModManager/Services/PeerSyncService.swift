import Foundation
import MultipeerConnectivity
import Combine

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

    // File transfer state
    @Published var transferState: TransferState = .idle
    @Published var transferProgress: Double = 0
    private var progressObservation: AnyCancellable?
    var onModsReceived: ((URL) -> Void)?

    // Incoming connection consent
    struct PendingInvitation: Identifiable {
        let id = UUID()
        let peerName: String
        let respond: (Bool) -> Void
    }
    @Published var pendingInvitation: PendingInvitation?

    enum ConnectionState {
        case idle
        case searching
        case connected(String)
        case received
        case error(String)
    }

    enum TransferState: Equatable {
        case idle
        case zipping
        case sending
        case receiving
        case importing
        case complete(Int)
        case error(String)
    }

    override init() {
        myPeerID = MCPeerID(displayName: Host.current().localizedName ?? "Unknown Mac")
        super.init()
    }

    func startSearching() {
        let session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
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
        transferState = .idle
        transferProgress = 0
    }

    func stopSearching() {
        pendingInvitation?.respond(false)
        pendingInvitation = nil
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
        progressObservation = nil
    }

    func connectToPeer(_ peer: MCPeerID) {
        guard let session, let browser else { return }
        // Generous timeout: the other side has to approve the connection prompt
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }

    func sendModpack(_ modpack: ShareableModpack) {
        guard let session, !session.connectedPeers.isEmpty else {
            connectionState = .error("No connected peer")
            return
        }
        do {
            let data = try modpack.toJSON()
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            connectionState = .error("Send failed: \(error.localizedDescription)")
        }
    }

    // MARK: - File Transfer

    func sendMods(zipURL: URL) {
        guard let session, let peer = session.connectedPeers.first else {
            transferState = .error("No connected peer")
            return
        }

        transferState = .sending
        transferProgress = 0

        let progress = session.sendResource(at: zipURL, withName: "mods-transfer.zip", toPeer: peer) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.progressObservation = nil
                if let error {
                    self.transferState = .error("Send failed: \(error.localizedDescription)")
                } else {
                    self.transferProgress = 1.0
                    // Sender stays in .sending until they see completion
                    // The count is unknown on sender side, just show complete
                    self.transferState = .complete(0)
                }
            }
        }

        if let progress {
            progressObservation = progress.publisher(for: \.fractionCompleted)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] fraction in
                    self?.transferProgress = fraction
                }
        }
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
                    if case .received = connectionState {
                        // Keep received state — user is viewing results
                    } else if case .error = transferState {
                        // Keep error visible
                    } else if case .complete = transferState {
                        // Transfer finished — disconnect is expected
                    } else if transferState != .idle {
                        transferState = .error("Connection lost during transfer")
                    } else {
                        connectionState = .searching
                        // Restart discovery since we stopped it on connect
                        advertiser?.startAdvertisingPeer()
                        browser?.startBrowsingForPeers()
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
        Task { @MainActor in
            do {
                let modpack = try ShareableModpack.fromJSON(data)
                receivedModpack = modpack
                connectionState = .received
            } catch {
                connectionState = .error("Failed to read modpack data")
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        Task { @MainActor in
            transferState = .receiving
            transferProgress = 0
            progressObservation = progress.publisher(for: \.fractionCompleted)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] fraction in
                    self?.transferProgress = fraction
                }
        }
    }

    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        Task { @MainActor in
            progressObservation = nil
            if let error {
                transferState = .error("Receive failed: \(error.localizedDescription)")
                return
            }
            guard let localURL else {
                transferState = .error("No file received")
                return
            }

            // Move to a stable temp location (MC's localURL is ephemeral)
            let stableURL = FileManager.default.temporaryDirectory.appending(path: "received_mods_\(UUID().uuidString).zip")
            do {
                try FileManager.default.moveItem(at: localURL, to: stableURL)
                transferState = .importing
                onModsReceived?(stableURL)
            } catch {
                transferState = .error("Failed to save received file")
            }
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension PeerSyncService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Ask the user before joining a session; never auto-accept
        Task { @MainActor in
            guard pendingInvitation == nil else {
                invitationHandler(false, nil)
                return
            }
            pendingInvitation = PendingInvitation(peerName: peerID.displayName) { [weak self] accept in
                invitationHandler(accept, accept ? self?.session : nil)
                self?.pendingInvitation = nil
            }
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
