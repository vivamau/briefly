import Foundation
import AVFoundation

let semaphore = DispatchSemaphore(value: 0)

print("Starting permission request...")
if #available(macOS 14.0, *) {
    AVAudioApplication.requestRecordPermission { granted in
        print("AVAudioApplication granted: \(granted)")
        semaphore.signal()
    }
} else {
    AVCaptureDevice.requestAccess(for: .audio) { granted in
        print("AVCaptureDevice granted: \(granted)")
        semaphore.signal()
    }
}

_ = semaphore.wait(timeout: .now() + 5.0)
print("Finished.")
