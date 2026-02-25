import Foundation
import Combine
import AVFoundation

#if os(macOS)
import AppKit
#endif

class AudioRecorderManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var permissionGranted = false
    
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
            }
        }
        #else
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
            }
        }
        #endif
    }
    
    func startRecording() {
        guard permissionGranted else { return }
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session")
            return
        }
        #endif
        
        let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Briefly", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupportPath, withIntermediateDirectories: true, attributes: nil)
        
        let audioFilename = appSupportPath.appendingPathComponent("\(UUID().uuidString).m4a")
        currentRecordingURL = audioFilename
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            isRecording = true
            startTimer()
            
            // Play system "Start Recording" sound for accessibility
            #if os(iOS)
            AudioServicesPlaySystemSound(1113)
            #elseif os(macOS)
            NSSound(named: "Hero")?.play()
            #endif
            
        } catch {
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
