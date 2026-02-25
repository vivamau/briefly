import Foundation
import CoreAudio

func getDefaultInputDevice() -> AudioDeviceID? {
    var deviceID: AudioDeviceID = 0
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        0,
        nil,
        &size,
        &deviceID
    )
    return status == noErr ? deviceID : nil
}

func getDeviceName(deviceID: AudioDeviceID) -> String? {
    var name: CFString = "" as CFString
    var size = UInt32(MemoryLayout<CFString>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioObjectPropertyName,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectGetPropertyData(
        deviceID,
        &address,
        0,
        nil,
        &size,
        &name
    )
    return status == noErr ? (name as String) : nil
}

if let defaultInput = getDefaultInputDevice(), let name = getDeviceName(deviceID: defaultInput) {
    print("Default Input Device: \(name) (ID: \(defaultInput))")
} else {
    print("No default input device found.")
}
