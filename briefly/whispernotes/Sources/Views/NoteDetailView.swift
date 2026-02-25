import SwiftUI
import SwiftData

#if os(macOS)
import AppKit
#endif

struct NoteDetailView: View {
    let note: VoiceNote
    @ObservedObject var player: AudioPlayerManager
    @ObservedObject var summarizer: SummarizationService
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var isProcessing = false
    @State private var localTranscript: String?
    @State private var localSummary: String?
    @State private var isHoveringTitle = false
    @State private var isEditingSummary = false
    @State private var isEditingTranscript = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                HStack {
                    TextField("Note Title", text: Binding(
                        get: { note.title },
                        set: { newTitle in
                            note.title = newTitle
                        }
                    ))
                    .font(.largeTitle.bold())
                    .textFieldStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)
                    
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .opacity(isHoveringTitle ? 1.0 : 0.6)
                    
                    Spacer()
                    
                    if let audioURL = note.audioURL {
                        ShareLink(
                            item: audioURL,
                            subject: Text(note.title),
                            message: Text(combinedNoteText),
                            preview: SharePreview(note.title)
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body.bold())
                                .padding(10)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Share complete note with audio")
                    } else {
                        ShareLink(
                            item: combinedNoteText,
                            subject: Text(note.title),
                            preview: SharePreview(note.title)
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body.bold())
                                .padding(10)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Share complete note text")
                    }
                    
                    Button(action: sendEmail) {
                        Image(systemName: "envelope.fill")
                            .font(.body.bold())
                            .padding(10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Email note")
                    
                    Button(action: deleteCurrentNote) {
                        Image(systemName: "trash")
                            .font(.body.bold())
                            .padding(10)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete this voice note completely")
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHoveringTitle = hovering
                    }
                }
                
                Text("Recorded on \(note.creationDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Recording date: \(note.creationDate.formatted())")
                
                // Playback Controls
                if note.audioURL != nil {
                    HStack(spacing: 16) {
                        Button(action: togglePlayback) {
                            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(player.isPlaying ? "Pause audio" : "Play audio")
                        
                        Slider(value: Binding(get: {
                            player.currentTime
                        }, set: { newTime in
                            player.seek(to: newTime)
                        }), in: 0...(note.duration > 0 ? note.duration : 1))
                        .accessibilityLabel("Audio playback progress")
                        .accessibilityValue("\(Int(player.currentTime)) seconds of \(Int(note.duration))")
                        
                        Text(formatTime(player.currentTime))
                            .font(.caption.monospacedDigit())
                            .accessibilityLabel("Elapsed time: \(formatTime(player.currentTime))")
                            
                        if let audioURL = note.audioURL {
                            ShareLink(
                                item: audioURL,
                                subject: Text(note.title + " Audio"),
                                preview: SharePreview(note.title + " Audio")
                            ) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Share audio file")
                        }
                    }
                    .padding(.vertical)
                    
                    Divider()
                }
                
                // Summary Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Summary")
                            .font(.title2)
                            .bold()
                            
                        if let summaryText = localSummary ?? note.summary {
                            ShareLink(
                                item: summaryText,
                                subject: Text(note.title + " Summary"),
                                preview: SharePreview(note.title + " Summary")
                            ) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Share summary text")
                        }
                        
                        if note.audioURL != nil {
                            Spacer()
                            
                            Picker("Provider", selection: $summarizer.selectedProvider) {
                                ForEach(LLMProvider.allCases) { provider in
                                    Text(provider.rawValue).tag(provider)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .disabled(isProcessing)
                            
                            if isProcessing {
                                ProgressView()
                                    .accessibilityLabel("Generating summary")
                                    .padding(.leading, 8)
                            } else {
                                Button("Generate") {
                                    Task { await processAudio() }
                                }
                                .buttonStyle(.borderedProminent)
                                .accessibilityHint("Uses AI to generate a transcript and summary")
                            }
                        } else {
                            Spacer()
                        }
                        
                        if localSummary != nil || note.summary != nil {
                            Button(action: {
                                if isEditingSummary {
                                    if let local = localSummary { note.summary = local }
                                    try? modelContext.save()
                                } else {
                                    localSummary = note.summary
                                }
                                isEditingSummary.toggle()
                            }) {
                                Image(systemName: isEditingSummary ? "checkmark.circle.fill" : "pencil.circle")
                                    .foregroundColor(isEditingSummary ? .green : .blue)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .help(isEditingSummary ? "Save changes" : "Edit Markdown")
                        }
                    }
                    
                    if let summary = isEditingSummary ? localSummary : (localSummary ?? note.summary) {
                        if isEditingSummary {
                            TextEditor(text: Binding(
                                get: { summary },
                                set: { localSummary = $0 }
                            ))
                            .font(.system(.title3, design: .monospaced))
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                        } else {
                            Text(.init(summary))
                                .font(.title3)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(12)
                                .accessibilityLabel("Summary: \(summary)")
                        }
                    } else if !isProcessing {
                        Text("No summary generated yet.")
                            .italic()
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Transcript Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(note.audioURL == nil ? "Source Transcripts" : "Transcript")
                            .font(.title2)
                            .bold()
                            
                        if let transcriptText = localTranscript ?? note.transcript {
                            ShareLink(
                                item: transcriptText,
                                subject: Text(note.title + " Transcript"),
                                preview: SharePreview(note.title + " Transcript")
                            ) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Share transcript text")
                            
                            Spacer()
                            
                            Button(action: {
                                if isEditingTranscript {
                                    if let local = localTranscript { note.transcript = local }
                                    try? modelContext.save()
                                } else {
                                    localTranscript = note.transcript
                                }
                                isEditingTranscript.toggle()
                            }) {
                                Image(systemName: isEditingTranscript ? "checkmark.circle.fill" : "pencil.circle")
                                    .foregroundColor(isEditingTranscript ? .green : .blue)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .help(isEditingTranscript ? "Save changes" : "Edit Markdown")
                        }
                    }
                    
                    if let transcript = isEditingTranscript ? localTranscript : (localTranscript ?? note.transcript) {
                        if isEditingTranscript {
                            TextEditor(text: Binding(
                                get: { transcript },
                                set: { localTranscript = $0 }
                            ))
                            .font(.system(.title3, design: .monospaced))
                            .frame(minHeight: 200)
                            .padding(8)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                        } else {
                            Text(.init(transcript))
                                .font(.title3)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(12)
                                .accessibilityLabel("Transcript: \(transcript)")
                        }
                    } else {
                        Text("No transcript available.")
                            .italic()
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(note.title)
        .onAppear {
            if let url = note.audioURL {
                player.load(audioURL: url)
            }
        }
        .onChange(of: note.id) { _, _ in
            // When user taps a different note in the list, completely reset the view state
            player.stopPlayback()
            localTranscript = nil
            localSummary = nil
            isProcessing = false
            isEditingSummary = false
            isEditingTranscript = false
            
            if let url = note.audioURL {
                player.load(audioURL: url)
            }
        }
    }
    
    // Combined Note Text
    private var combinedNoteText: String {
        var text = "\(note.title)\nRecorded on \(note.creationDate.formatted(date: .abbreviated, time: .shortened))\n\n"
        if let summary = localSummary ?? note.summary {
            text += "--- Summary ---\n\(summary)\n\n"
        }
        if let transcript = localTranscript ?? note.transcript {
            text += "--- \(note.audioURL == nil ? "Source Transcripts" : "Transcript") ---\n\(transcript)\n"
        }
        return text
    }
    
    // Email export logic
    private func sendEmail() {
        #if os(macOS)
        var items: [Any] = [combinedNoteText]
        if let audioURL = note.audioURL {
            items.insert(audioURL, at: 0) // Attach file first, then body text
        }
        
        if let service = NSSharingService(named: .composeEmail) {
            service.subject = note.title
            service.perform(withItems: items)
        }
        #endif
    }
    
    // Play/Pause button logic
    private func togglePlayback() {
        if let url = note.audioURL {
            player.togglePlayback(audioURL: url)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func processAudio() async {
        guard let url = note.audioURL else { return }
        
        isProcessing = true
        do {
            let result = try await summarizer.transcribeAndSummarize(audioURL: url)
            DispatchQueue.main.async {
                self.localTranscript = result.transcript
                self.localSummary = result.summary
                // Here we would also update the SwiftData Note object
                self.note.transcript = result.transcript
                self.note.summary = result.summary
                self.isProcessing = false
            }
        } catch {
            print("Processing failed: \(error)")
            DispatchQueue.main.async { self.isProcessing = false }
        }
    }
    
    private func deleteCurrentNote() {
        // Clear the audio player out
        player.stopPlayback()
        
        // Delete audio file from disk
        if let url = note.audioURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        // Delete from SwiftData database
        modelContext.delete(note)
        
        // Return back to empty state
        dismiss()
    }
}
