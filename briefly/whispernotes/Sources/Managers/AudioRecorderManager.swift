import Foundation
import Combine
import AVFoundation

#if os(macOS)
import AppKit
#endif

class AudioRecorderManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var permissionGranted = false
    @Published var errorMessage: String?
    
    private var audioRecorder: AVAudioRecorder?
    
    var currentRecordingURL: URL?
    var recordingTimer: Timer?
    @Published var recordingDuration: TimeInterval = 0
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func checkPermissions() {
        #if os(macOS)
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
                if !granted {
                    self?.errorMessage = "Microphone access denied. Please enable it in System Settings > Privacy & Security > Microphone."
                }
            }
        }
        #else
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
                if !granted {
                    self?.errorMessage = "Microphone access denied. Please enable it in Settings > Privacy > Microphone."
                }
            }
        }
        #endif
    }
    
    func startRecording() {
        errorMessage = nil
        
        guard permissionGranted else {
            errorMessage = "Microphone permission not granted. Please check System Settings > Privacy & Security > Microphone."
            print("Recording blocked: microphone permission not granted")
            return
        }
        
        // Check if a microphone is actually available (Mac Mini, Mac Pro, etc. have no built-in mic)
        #if os(macOS)
        if AVCaptureDevice.default(for: .audio) == nil {
            errorMessage = "No microphone found. Please connect an external microphone (USB, Bluetooth, or headset)."
            print("Recording blocked: no audio input device found (this Mac may not have a built-in microphone)")
            return
        }
        #endif
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            errorMessage = "Failed to set up audio session: \(error.localizedDescription)"
            print("Failed to set up audio session: \(error)")
            return
        }
        #endif
        
        let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Briefly", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupportPath, withIntermediateDirectories: true, attributes: nil)
        
        let audioFilename = appSupportPath.appendingPathComponent("\(UUID().uuidString).m4a")
        currentRecordingURL = audioFilename
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            let started = audioRecorder?.record() ?? false
            
            if started {
                isRecording = true
                startTimer()
                
                // Play system "Start Recording" sound for accessibility
                #if os(iOS)
                AudioServicesPlaySystemSound(1113)
                #elseif os(macOS)
                NSSound(named: "Hero")?.play()
                #endif
            } else {
                errorMessage = "Recording failed to start. No microphone is available — please connect an external microphone."
                print("AVAudioRecorder.record() returned false — no audio input device available")
                audioRecorder = nil
                currentRecordingURL = nil
            }
            
        } catch {
            errorMessage = "Could not start recording: \(error.localizedDescription)"
            print("Could not start recording: \(error)")
        }
    }
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        stopTimer()
        
        // Play system "Stop Recording" sound
        #if os(iOS)
        AudioServicesPlaySystemSound(1114)
        #elseif os(macOS)
        NSSound(named: "Pop")?.play()
        #endif
        
        let finalURL = currentRecordingURL
        currentRecordingURL = nil
        return finalURL
    }
    
    func cancelRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        stopTimer()
        
        #if os(iOS)
        AudioServicesPlaySystemSound(1114)
        #elseif os(macOS)
        NSSound(named: "Basso")?.play()
        #endif
        
        if let currentURL = currentRecordingURL {
            do {
                try FileManager.default.removeItem(at: currentURL)
            } catch {
                print("Could not delete cancelled info: \(error)")
            }
        }
        currentRecordingURL = nil
    }
    
    private func startTimer() {
        recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingDuration += 0.1
        }
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}
