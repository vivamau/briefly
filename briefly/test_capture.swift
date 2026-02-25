import Foundation
import AVFoundation

let session = AVCaptureSession()
if let device = AVCaptureDevice.default(for: .audio) {
    print("Found device: \(device.localizedName)")
    do {
        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) {
            session.addInput(input)
            print("Successfully added audio input to AVCaptureSession")
        } else {
            print("Cannot add input")
        }
    } catch {
        print("Error creating input: \(error)")
    }
} else {
    print("No audio device found")
}
