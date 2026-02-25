import Foundation
import AVFoundation

let engine = AVAudioEngine()
let inputFormat = engine.inputNode.inputFormat(forBus: 0)
print("Channels: \(inputFormat.channelCount)")
