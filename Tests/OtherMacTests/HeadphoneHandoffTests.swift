import Foundation
import Testing

@testable import OtherMac

@MainActor
struct HeadphoneHandoffTests {
  @Test
  func sendingMovesTheHeadphonesToTheOtherMac() async throws {
    let desk = Desk(holder: "A")
    let a = desk.mac("A")
    let b = desk.mac("B")
    try await settle()

    #expect(a.send(desk.phone.address))
    try await settle()

    #expect(desk.phone.holder == "B")
    #expect(desk.routedAudio == ["B"])
    #expect(a.holder(of: desk.phone.address) == "Mac B")
    #expect(b.isConnected(desk.phone.address))
  }

  @Test
  func sendingKeepsTheHeadphonesWhenNoMacIsLinked() async throws {
    let desk = Desk(holder: "A")
    let a = desk.mac("A")
    try await settle()

    #expect(!a.send(desk.phone.address))
    #expect(desk.phone.holder == "A")
  }

  @Test
  func sendingIgnoresHeadphonesConnectedElsewhere() async throws {
    let desk = Desk(holder: "B")
    let a = desk.mac("A")
    _ = desk.mac("B")
    try await settle()

    #expect(!a.send(desk.phone.address))
    #expect(desk.phone.holder == "B")
  }

  @Test
  func bringingTakesTheHeadphonesFromTheOtherMac() async throws {
    let desk = Desk(holder: "A")
    _ = desk.mac("A")
    let b = desk.mac("B")
    try await settle()

    #expect(b.holder(of: desk.phone.address) == "Mac A")
    #expect(await b.bring(desk.phone.address))
    #expect(desk.phone.holder == "B")
  }

  @Test
  func bringingFailsWhenAnUnlinkedDeviceHoldsThem() async throws {
    let desk = Desk(holder: "a phone")
    let a = desk.mac("A")
    try await settle()

    #expect(await a.bring(desk.phone.address) == false)
    #expect(desk.phone.holder == "a phone")
  }

  @Test
  func swapSendsTheHeadphonesOnlyWhenTheToggleIsOn() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let desk = Desk(holder: "A")
    _ = desk.mac("B")
    let model = AppModel(
      backend: StubDisplayBackend(),
      store: SettingsStore(applicationSupportURL: root),
      makeHeadphoneHandoff: { _, _, _ in desk.mac("A", started: false) }
    )
    await model.refreshDisplays()
    model.startHeadphones()
    try await settle()
    model.setHeadphone(address: desk.phone.address)
    #expect(model.settings.headphoneName == "Fake XM6")
    #expect(model.isHeadphoneConnectedHere)
    #expect(model.linkedMacNames == ["Mac B"])

    model.setMoveHeadphones(false)
    await model.swap()
    try await settle()
    #expect(desk.phone.holder == "A")

    model.setMoveHeadphones(true)
    await model.swap()
    try await settle()
    #expect(desk.phone.holder == "B")
    #expect(model.headphoneHolder == "Mac B")

    try? FileManager.default.removeItem(at: root)
  }

  @Test
  func settingsWithoutHeadphoneFieldsDefaultToMoving() throws {
    let json = #"{"version": 4, "displayConfigs": {}}"#
    let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))

    #expect(settings.moveHeadphones)
    #expect(settings.headphoneAddress == nil)
  }

  @Test
  func pairingKeyIsCreatedOncePrivateAndReplaceable() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PairingKeyStore(applicationSupportURL: root)

    let key = store.load()
    #expect(PairingKeyStore.isValid(key))
    #expect(store.load() == key)
    let mode = try FileManager.default.attributesOfItem(atPath: store.url.path)[.posixPermissions]
    #expect(mode as? Int == 0o600)

    #expect(PairingKeyStore.normalize("  \(key.uppercased())\n") == key)
    #expect(PairingKeyStore.normalize("not a key") == nil)

    try FileManager.default.removeItem(at: root)
  }

  private func settle() async throws {
    try await Task.sleep(for: .milliseconds(150))
  }
}

/// Real Bonjour and TLS on this machine. Off by default: CI runners and
/// sandboxes often have no local network access.
@MainActor
@Suite(
  .serialized,
  .enabled(if: ProcessInfo.processInfo.environment["OTHER_MAC_NETWORK_TESTS"] == "1")
)
struct PeerMeshTests {
  @Test
  func macsWithTheSameKeyLinkAndTalk() async throws {
    let key = PairingKeyStore.generate()
    let a = PeerMesh(id: "test-a-\(UUID().uuidString)", name: "A", key: key)
    let b = PeerMesh(id: "test-b-\(UUID().uuidString)", name: "B", key: key)
    let inbox = Inbox()
    a.onPeers = { inbox.peers = $0 }
    b.onMessage = { _, message in inbox.messages.append(message) }
    a.start()
    b.start()

    try await wait { !inbox.peers.isEmpty }
    #expect(Array(inbox.peers.values) == ["B"])

    a.send(.take(address: "AA"), to: nil)
    try await wait { !inbox.messages.isEmpty }
    #expect(inbox.messages == [.take(address: "AA")])
  }

  @Test
  func aDifferentKeyNeverLinks() async throws {
    let a = PeerMesh(id: "test-c-\(UUID().uuidString)", name: "A", key: PairingKeyStore.generate())
    let b = PeerMesh(id: "test-d-\(UUID().uuidString)", name: "B", key: PairingKeyStore.generate())
    let inbox = Inbox()
    a.onPeers = { inbox.peers.merge($0) { $1 } }
    b.onPeers = { inbox.peers.merge($0) { $1 } }
    a.start()
    b.start()

    try await Task.sleep(for: .seconds(4))
    #expect(inbox.peers.isEmpty)
  }

  private func wait(_ condition: () -> Bool) async throws {
    for _ in 0..<80 where !condition() {
      try await Task.sleep(for: .milliseconds(100))
    }
    try #require(condition(), "timed out")
  }
}

@MainActor
private final class Inbox {
  var peers: [String: String] = [:]
  var messages: [HandoffMessage] = []
}

/// Two Macs and headphones without multipoint: one host at a time.
@MainActor
private final class Desk {
  final class Headphones {
    let address = "AA-BB-CC-DD-EE-FF"
    var holder: String?
  }

  let phone = Headphones()
  var routedAudio: [String] = []
  private var transports: [String: FakeTransport] = [:]
  /// Transports hold their Mac weakly, as the app does. The desk keeps them alive.
  private var macs: [HeadphoneHandoff] = []

  init(holder: String?) {
    phone.holder = holder
  }

  func mac(_ id: String, started: Bool = true) -> HeadphoneHandoff {
    let handoff = HeadphoneHandoff(
      bluetooth: FakeBluetooth(me: id, phone: phone),
      transport: FakeTransport(id: id, desk: self),
      name: "Mac \(id)",
      routeAudio: { [weak self] _ in
        self?.routedAudio.append(id)
        return true
      }
    )
    macs.append(handoff)
    if started { handoff.start() }
    return handoff
  }

  func join(_ transport: FakeTransport) {
    transports[transport.id] = transport
    for node in transports.values {
      let others = transports.filter { $0.key != node.id }.mapValues { "Mac \($0.id)" }
      Task { node.onPeers?(others) }
    }
  }

  func deliver(_ message: HandoffMessage, from sender: String, to peer: String?) {
    // Through JSON, like the real wire.
    let wire = try! JSONEncoder().encode(message)
    let decoded = try! JSONDecoder().decode(HandoffMessage.self, from: wire)
    for (id, node) in transports where id != sender && (peer == nil || peer == id) {
      Task { node.onMessage?(sender, decoded) }
    }
  }
}

@MainActor
private final class FakeBluetooth: BluetoothBackend {
  let me: String
  let phone: Desk.Headphones

  init(me: String, phone: Desk.Headphones) {
    self.me = me
    self.phone = phone
  }

  func devices() -> [BluetoothDevice] {
    [
      BluetoothDevice(
        address: phone.address,
        name: "Fake XM6",
        connected: phone.holder == me,
        isAudio: true
      )
    ]
  }

  func connect(_ address: String) async -> Bool {
    guard phone.holder == nil || phone.holder == me else { return false }
    phone.holder = me
    return true
  }

  func disconnect(_ address: String) -> Bool {
    if phone.holder == me { phone.holder = nil }
    return true
  }
}

@MainActor
private final class FakeTransport: PeerTransport {
  var onMessage: ((String, HandoffMessage) -> Void)?
  var onPeers: (([String: String]) -> Void)?
  let id: String
  private let desk: Desk

  init(id: String, desk: Desk) {
    self.id = id
    self.desk = desk
  }

  func start() {
    desk.join(self)
  }

  func send(_ message: HandoffMessage, to peer: String?) {
    desk.deliver(message, from: id, to: peer)
  }

  func updateKey(_ key: String) {}
}

private actor StubDisplayBackend: DisplayBackend {
  func listDisplays() async throws -> [DetectedDisplay] {
    [DetectedDisplay(index: 1, name: "Display", uuid: "display-uuid")]
  }

  func setInput(_ input: Int, for display: DetectedDisplay) async throws {}
}
