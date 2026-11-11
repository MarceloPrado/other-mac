import Foundation
import IOBluetooth

@MainActor
protocol BluetoothBackend: AnyObject {
  func devices() -> [BluetoothDevice]
  func connect(_ address: String) async -> Bool
  func disconnect(_ address: String) -> Bool
}

/// Paired Bluetooth Classic devices via IOBluetooth.
@MainActor
final class SystemBluetoothBackend: NSObject, BluetoothBackend {
  private var pending: [String: (token: Int, continuation: CheckedContinuation<Bool, Never>)] = [:]
  private var nextToken = 0

  func devices() -> [BluetoothDevice] {
    let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
    return paired.compactMap { device -> BluetoothDevice? in
      guard let address = device.addressString?.uppercased() else { return nil }
      return BluetoothDevice(
        address: address,
        name: device.name ?? address,
        connected: device.isConnected(),
        isAudio: device.deviceClassMajor == 0x04  // kBluetoothDeviceClassMajorAudio
      )
    }
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  func connect(_ address: String) async -> Bool {
    guard let device = IOBluetoothDevice(addressString: address) else { return false }
    if device.isConnected() { return true }
    let key = address.uppercased()
    guard pending[key] == nil else { return false }
    nextToken += 1
    let token = nextToken

    return await withCheckedContinuation { continuation in
      pending[key] = (token, continuation)
      // Asynchronous variant: reports through connectionComplete(_:status:).
      guard device.openConnection(self) == kIOReturnSuccess else {
        resolve(key, token: token, ok: false)
        return
      }
      Task {
        try? await Task.sleep(for: .seconds(12))
        self.resolve(key, token: token, ok: false)
      }
    }
  }

  func disconnect(_ address: String) -> Bool {
    guard let device = IOBluetoothDevice(addressString: address) else { return false }
    if !device.isConnected() { return true }
    return device.closeConnection() == kIOReturnSuccess
  }

  private func resolve(_ key: String, token: Int?, ok: Bool) {
    guard let entry = pending[key], token == nil || entry.token == token else { return }
    pending[key] = nil
    entry.continuation.resume(returning: ok)
  }

  @objc nonisolated func connectionComplete(_ device: IOBluetoothDevice, status: IOReturn) {
    let key = (device.addressString ?? "").uppercased()
    let ok = status == kIOReturnSuccess
    Task { @MainActor in
      self.resolve(key, token: nil, ok: ok)
    }
  }
}
