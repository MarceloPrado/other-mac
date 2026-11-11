import Foundation

struct BluetoothDevice: Codable, Hashable, Identifiable, Sendable {
  /// Uppercase, dash-separated: `80-99-E7-D3-0C-03`.
  var address: String
  var name: String
  var connected: Bool
  var isAudio: Bool

  var id: String { address }
}

enum HandoffMessage: Codable, Equatable, Sendable {
  case hello(id: String, name: String)
  case state(devices: [BluetoothDevice])
  /// "I let go of this device. Connect it."
  case take(address: String)
  /// "Let go of this device, I'm about to connect it."
  case release(request: String, address: String, by: String)
  case released(request: String, ok: Bool)
}

@MainActor
protocol PeerTransport: AnyObject {
  var onMessage: ((_ peer: String, HandoffMessage) -> Void)? { get set }
  /// Linked Macs, id → display name.
  var onPeers: (([String: String]) -> Void)? { get set }
  func start()
  /// `peer == nil` broadcasts.
  func send(_ message: HandoffMessage, to peer: String?)
  func updateKey(_ key: String)
}
