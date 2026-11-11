import CryptoKit
import Foundation
import Network

/// Finds the other Mac over Bonjour (LAN or peer-to-peer Wi-Fi) and keeps one
/// TLS-PSK connection to it. A machine without the pairing key can't complete
/// the handshake, so it can neither see the headphones nor make a Mac drop them.
@MainActor
final class PeerMesh: PeerTransport {
  static let serviceType = "_othermac._tcp"

  var onMessage: ((String, HandoffMessage) -> Void)?
  var onPeers: (([String: String]) -> Void)?

  private let id: String
  private let name: String
  private var key: String
  private var listener: NWListener?
  private var browser: NWBrowser?
  private var all: [ObjectIdentifier: PeerLink] = [:]
  private var links: [String: PeerLink] = [:]
  private var names: [String: String] = [:]
  private var dialing: Set<String> = []

  init(id: String, name: String, key: String) {
    self.id = id
    self.name = name
    self.key = key
  }

  func start() {
    do {
      let listener = try NWListener(using: parameters())
      listener.service = NWListener.Service(name: id, type: Self.serviceType)
      listener.newConnectionHandler = { [weak self] connection in
        MainActor.assumeIsolated {
          self?.adopt(PeerLink(connection), dialed: nil)
        }
      }
      listener.start(queue: .main)
      self.listener = listener
    } catch {
      NSLog("Other Mac: couldn’t listen for the other Mac: \(error)")
    }

    let browseParameters = NWParameters()
    browseParameters.includePeerToPeer = true
    let browser = NWBrowser(
      for: .bonjour(type: Self.serviceType, domain: nil),
      using: browseParameters
    )
    browser.browseResultsChangedHandler = { [weak self] results, _ in
      let endpoints = results.map(\.endpoint)
      MainActor.assumeIsolated {
        self?.dial(endpoints)
      }
    }
    browser.start(queue: .main)
    self.browser = browser
  }

  func send(_ message: HandoffMessage, to peer: String?) {
    if let peer {
      links[peer]?.send(message)
    } else {
      links.values.forEach { $0.send(message) }
    }
  }

  func updateKey(_ key: String) {
    self.key = key
    listener?.cancel()
    browser?.cancel()
    all.values.forEach { $0.close() }
    start()
  }

  /// Both sides browse; only the lower id dials, so each pair gets one connection.
  private func dial(_ endpoints: [NWEndpoint]) {
    for endpoint in endpoints {
      guard
        case .service(name: let peer, type: _, domain: _, interface: _) = endpoint,
        id < peer,
        links[peer] == nil,
        !dialing.contains(peer)
      else {
        continue
      }
      dialing.insert(peer)
      adopt(PeerLink(NWConnection(to: endpoint, using: parameters())), dialed: peer)
    }
  }

  private func adopt(_ link: PeerLink, dialed: String?) {
    all[ObjectIdentifier(link)] = link

    link.onMessage = { [weak self, weak link] message in
      guard let self, let link else { return }
      if case .hello(let id, let name) = message {
        link.peerID = id
        let previous = self.links[id]
        self.links[id] = link
        self.names[id] = name
        previous?.close()
        self.publish()
      } else if let peerID = link.peerID {
        self.onMessage?(peerID, message)
      }
    }
    link.onClose = { [weak self, weak link] in
      guard let self else { return }
      if let dialed { self.dialing.remove(dialed) }
      if let link {
        self.all[ObjectIdentifier(link)] = nil
        if let peerID = link.peerID, self.links[peerID] === link {
          self.links[peerID] = nil
          self.publish()
        }
      }
      Task { [weak self] in
        try? await Task.sleep(for: .seconds(2))
        guard let self, let browser = self.browser else { return }
        self.dial(browser.browseResults.map(\.endpoint))
      }
    }
    link.start(hello: .hello(id: id, name: name))
  }

  private func publish() {
    onPeers?(names.filter { links[$0.key] != nil })
  }

  private func parameters() -> NWParameters {
    let tls = NWProtocolTLS.Options()
    let secret = HMAC<SHA256>.authenticationCode(
      for: Data("other-mac-v1".utf8),
      using: SymmetricKey(data: Data(key.utf8))
    )
    let psk = secret.withUnsafeBytes { DispatchData(bytes: $0) }
    let identity = Data("other-mac".utf8).withUnsafeBytes { DispatchData(bytes: $0) }
    sec_protocol_options_add_pre_shared_key(
      tls.securityProtocolOptions,
      psk as __DispatchData,
      identity as __DispatchData
    )
    sec_protocol_options_append_tls_ciphersuite(
      tls.securityProtocolOptions,
      tls_ciphersuite_t(rawValue: UInt16(TLS_PSK_WITH_AES_128_GCM_SHA256))!
    )

    let tcp = NWProtocolTCP.Options()
    tcp.enableKeepalive = true
    tcp.keepaliveIdle = 10

    let parameters = NWParameters(tls: tls, tcp: tcp)
    parameters.includePeerToPeer = true
    return parameters
  }
}

/// One connection, framed as a 4-byte big-endian length followed by JSON.
@MainActor
private final class PeerLink {
  var onMessage: ((HandoffMessage) -> Void)?
  var onClose: (() -> Void)?
  var peerID: String?

  private let connection: NWConnection
  private var closed = false

  init(_ connection: NWConnection) {
    self.connection = connection
  }

  func start(hello: HandoffMessage) {
    connection.stateUpdateHandler = { [weak self] state in
      MainActor.assumeIsolated {
        switch state {
        case .ready:
          self?.send(hello)
          self?.read()
        case .waiting:
          self?.close()  // unreachable or wrong key; the mesh redials
        case .failed, .cancelled:
          self?.finish()
        default:
          break
        }
      }
    }
    connection.start(queue: .main)
  }

  func send(_ message: HandoffMessage) {
    guard let body = try? JSONEncoder().encode(message) else { return }
    var frame = withUnsafeBytes(of: UInt32(body.count).bigEndian) { Data($0) }
    frame.append(body)
    connection.send(content: frame, completion: .contentProcessed { _ in })
  }

  func close() {
    connection.cancel()
  }

  private func finish() {
    guard !closed else { return }
    closed = true
    onClose?()
  }

  private func read() {
    connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] head, _, _, _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        guard let head, head.count == 4 else {
          self.close()
          return
        }
        let length = Int(head.reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
        guard length > 0, length <= 1 << 20 else {
          self.close()
          return
        }
        self.readBody(length)
      }
    }
  }

  private func readBody(_ length: Int) {
    connection.receive(minimumIncompleteLength: length, maximumLength: length) {
      [weak self] body, _, _, _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        guard let body, body.count == length else {
          self.close()
          return
        }
        // A message this version doesn't know is skipped, not fatal.
        if let message = try? JSONDecoder().decode(HandoffMessage.self, from: body) {
          self.onMessage?(message)
        }
        self.read()
      }
    }
  }
}
