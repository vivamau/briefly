import Foundation
import SwiftData

@Model
final class VoiceNote {
    var id: UUID
    var title: String
    var audioURL: URL?
    var creationDate: Date
    var duration: TimeInterval
    var transcript: String?
    var summary: String?
    var transcriptionDuration: TimeInterval?
    var summaryDuration: TimeInterval?
    var isFavorite: Bool
    
    init(title: String, audioURL: URL?, duration: TimeInterval = 0) {
        self.id = UUID()
        self.title = title
        self.audioURL = audioURL
        self.creationDate = Date()
        self.duration = duration
        self.isFavorite = false
    }
}
