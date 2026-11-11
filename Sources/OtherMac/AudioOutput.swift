import CoreAudio
import Foundation

enum AudioOutput {
  /// Makes the Bluetooth device the system output. CoreAudio UIDs for Bluetooth
  /// devices start with the MAC address (`80-99-E7-D3-0C-03:output`).
  /// Returns false until CoreAudio has published the device.
  static func setDefaultOutput(bluetoothAddress: String) -> Bool {
    let prefix = bluetoothAddress.uppercased()
    let system = AudioObjectID(kAudioObjectSystemObject)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else {
      return false
    }
    var ids = [AudioDeviceID](
      repeating: 0,
      count: Int(size) / MemoryLayout<AudioDeviceID>.size
    )
    guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else {
      return false
    }
    guard
      var target = ids.first(where: {
        uid($0).uppercased().hasPrefix(prefix) && hasOutput($0)
      })
    else {
      return false
    }

    address.mSelector = kAudioHardwarePropertyDefaultOutputDevice
    let idSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    return AudioObjectSetPropertyData(system, &address, 0, nil, idSize, &target) == noErr
  }

  private static func uid(_ id: AudioDeviceID) -> String {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceUID,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard
      AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr,
      let value
    else {
      return ""
    }
    return value.takeRetainedValue() as String
  }

  private static func hasOutput(_ id: AudioDeviceID) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreams,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
  }
}
