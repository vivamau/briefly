import Foundation
import AVFoundation

let engine = AVAudioEngine()
if let format = AVAudioFormat(standardFormatWithSampleRate: 0, channels: 0) {
    print("Format created")
    engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { _, _ in }
    print("Tap installed")
} else {
    print("Failed to create format")
    let format2 = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 0, interleaved: false)!
    engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format2) { _, _ in }
    print("Tap installed format2")
}
