import Foundation

/// Moves Bluetooth headphones between Macs.
///
/// Headphones can't be told to switch hosts by a Mac that isn't connected to
/// them, and most refuse a new host while another holds them. So the Mac that
/// has them always lets go first, and the other one connects after.
@MainActor
final class HeadphoneHandoff {
  struct LinkedMac: Equatable {
    var name: String
    var devices: [BluetoothDevice]
  }

  private(set) var devices: [BluetoothDevice] = []
  private(set) var linkedMacs: [String: LinkedMac] = [:]
  private(set) var busy: Set<String> = []
  /// Called after `devices`, `linkedMacs`, or `busy` change.
  var onChange: (() -> Void)?

  private let bluetooth: any BluetoothBackend
  private let transport: any PeerTransport
  private let name: String
  private let routeAudio: (String) -> Bool
  private var waiters: [String: (remaining: Set<String>, continuation: CheckedContinuation<Void, Never>)] = [:]
  private var poll: Task<Void, Never>?

  init(
    bluetooth: any BluetoothBackend,
    transport: any PeerTransport,
    name: String,
    routeAudio: @escaping (String) -> Bool = AudioOutput.setDefaultOutput(bluetoothAddress:)
  ) {
    self.bluetooth = bluetooth
    self.transport = transport
    self.name = name
    self.routeAudio = routeAudio
  }

  func start() {
    transport.onMessage = { [weak self] peer, message in
      self?.handle(message, from: peer)
    }
    transport.onPeers = { [weak self] names in
      self?.linkedMacsChanged(names)
    }
    transport.start()
    refresh()
    poll = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(2))
        self?.refresh()
      }
    }
  }

  func updateKey(_ key: String) {
    transport.updateKey(key)
  }

  func isConnected(_ address: String) -> Bool {
    devices.contains { $0.address == address && $0.connected }
  }

  /// Name of the other Mac the device is connected to, if any.
  func holder(of address: String) -> String? {
    linkedMacs.values.first { mac in
      mac.devices.contains { $0.address == address && $0.connected }
    }?.name
  }

  /// Sends a device connected here to the other Mac. Does nothing when no Mac
  /// is linked, so the headphones never end up connected to neither.
  @discardableResult
  func send(_ address: String) -> Bool {
    guard isConnected(address), !linkedMacs.isEmpty else { return false }
    guard bluetooth.disconnect(address) else { return false }
    transport.send(.take(address: address), to: nil)
    refresh()
    return true
  }

  /// Brings a device here, asking the other Mac to let go first.
  @discardableResult
  func bring(_ address: String) async -> Bool {
    guard !busy.contains(address) else { return false }
    setBusy(address, true)
    defer { setBusy(address, false) }

    await requestRelease(address)
    return await connect(address)
  }

  func refresh() {
    let current = bluetooth.devices()
    guard current != devices else { return }
    devices = current
    transport.send(.state(devices: current), to: nil)
    onChange?()
  }

  private func connect(_ address: String) async -> Bool {
    // The headphones need a moment after one Mac drops them before they answer another.
    var connected = false
    for attempt in 0..<4 {
      if attempt > 0 { try? await Task.sleep(for: .milliseconds(700)) }
      if await bluetooth.connect(address) {
        connected = true
        break
      }
    }
    refresh()
    guard connected else { return false }

    if devices.first(where: { $0.address == address })?.isAudio == true {
      for _ in 0..<12 {
        if routeAudio(address) { break }
        try? await Task.sleep(for: .milliseconds(400))
      }
    }
    return true
  }

  private func requestRelease(_ address: String) async {
    let targets = Set(linkedMacs.keys)
    guard !targets.isEmpty else { return }
    let request = UUID().uuidString

    await withCheckedContinuation { continuation in
      waiters[request] = (targets, continuation)
      transport.send(.release(request: request, address: address, by: name), to: nil)
      Task {
        try? await Task.sleep(for: .seconds(3))
        self.finish(request)
      }
    }
  }

  private func finish(_ request: String) {
    waiters.removeValue(forKey: request)?.continuation.resume()
  }

  private func handle(_ message: HandoffMessage, from peer: String) {
    switch message {
    case .hello:
      break
    case .state(let devices):
      linkedMacs[peer]?.devices = devices
      onChange?()
    case .take(let address):
      guard !busy.contains(address) else { return }
      Task {
        setBusy(address, true)
        _ = await connect(address)
        setBusy(address, false)
      }
    case .release(let request, let address, _):
      let ok = !isConnected(address) || bluetooth.disconnect(address)
      transport.send(.released(request: request, ok: ok), to: peer)
      refresh()
    case .released(let request, _):
      waiters[request]?.remaining.remove(peer)
      if waiters[request]?.remaining.isEmpty == true { finish(request) }
    }
  }

  private func linkedMacsChanged(_ names: [String: String]) {
    var next: [String: LinkedMac] = [:]
    for (id, name) in names {
      next[id] = LinkedMac(name: name, devices: linkedMacs[id]?.devices ?? [])
    }
    let joined = Set(next.keys).subtracting(linkedMacs.keys)
    linkedMacs = next
    for id in joined {
      transport.send(.state(devices: devices), to: id)
    }
    // A Mac that left will never answer.
    for request in Array(waiters.keys) {
      waiters[request]?.remaining.formIntersection(next.keys)
      if waiters[request]?.remaining.isEmpty == true { finish(request) }
    }
    onChange?()
  }

  private func setBusy(_ address: String, _ isBusy: Bool) {
    if isBusy {
      busy.insert(address)
    } else {
      busy.remove(address)
    }
    onChange?()
  }
}
