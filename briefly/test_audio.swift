import Foundation
import AVFoundation

let engine = AVAudioEngine()
let inputNode = engine.inputNode
let inputFormat = inputNode.inputFormat(forBus: 0)

print("Input format: \(inputFormat)")

let audioFilename = URL(fileURLWithPath: "/tmp/test.m4a")

let settings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
    AVSampleRateKey: inputFormat.sampleRate > 0 ? inputFormat.sampleRate : 44100.0,
    AVNumberOfChannelsKey: max(1, inputFormat.channelCount),
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
]

do {
    let audioFile = try AVAudioFile(forWriting: audioFilename, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
    print("Success")
} catch {
    print("Failed to init AVAudioFile: \(error)")
}
