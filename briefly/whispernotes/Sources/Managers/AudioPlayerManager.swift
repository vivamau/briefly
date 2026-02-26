import Foundation
import Combine
import AVFoundation

class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    var audioPlayer: AVAudioPlayer?
    var playbackTimer: Timer?
    
    func load(audioURL: URL) {
        if audioPlayer?.url == audioURL { return }
        stopPlayback()
        
        // Validate file exists and has content before attempting playback
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("Playback failed: Audio file does not exist at \(audioURL.path)")
            return
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
            let fileSize = attributes[.size] as? Int ?? 0
            if fileSize == 0 {
                print("Playback failed: Audio file is empty (0 bytes) at \(audioURL.path)")
                return
            }
        } catch {
            print("Playback failed: Could not read file attributes: \(error.localizedDescription)")
            return
        }
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Playback session failed: \(error.localizedDescription)")
        }
        #endif
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = self
            duration = audioPlayer?.duration ?? 0
            currentTime = 0
            audioPlayer?.prepareToPlay()
        } catch {
            print("Playback failed: \(error.localizedDescription)")
        }
    }
    
    func togglePlayback(audioURL: URL) {
        if audioPlayer?.url != audioURL {
            load(audioURL: audioURL)
        }
        
        if isPlaying {
            pausePlayback()
        } else {
            resumePlayback()
        }
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func resumePlayback() {
        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        stopTimer()
        currentTime = 0
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    private func startTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
        }
    }
    
    private func stopTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        stopTimer()
        currentTime = 0
    }
}
