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
    @State private var processingError: String?
    @State private var generationTask: Task<Void, Never>?
    @FocusState private var isTranscriptFocused: Bool
    
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
                        
                        Spacer()
                        
                        Picker("Provider", selection: $summarizer.selectedProvider) {
                            ForEach(LLMProvider.allCases) { provider in
                                Text(provider.id == LLMProvider.ollama.id ? "Ollama (\(summarizer.ollamaModel))" : provider.rawValue).tag(provider)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .disabled(isProcessing)
                        
                        if isProcessing {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .accessibilityLabel("Generating process running")
                                    
                                Button(action: {
                                    generationTask?.cancel()
                                    isProcessing = false
                                    processingError = "Generation stopped by user."
                                }) {
                                    HStack {
                                        Image(systemName: "xmark.circle.fill")
                                        Text("Stop Generate")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                                .accessibilityHint("Stops the active transcription or summmarization")
                            }
                        } else {
                            Button("Generate") {
                                generationTask = Task { await processAudio() }
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityHint("Uses AI to generate a transcript and summary")
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
                            Text(formatMarkdown(summary))
                                .font(.title3)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        if let duration = note.summaryDuration {
                            Text("Generated in \(formatDuration(duration))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else if let error = processingError {
                        Text("Error generating summary: \(error)")
                            .font(.callout)
                            .foregroundColor(.red)
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
                            .focused($isTranscriptFocused)
                            .font(.system(.title3, design: .monospaced))
                            .frame(minHeight: 200)
                            .padding(8)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                        } else {
                            Text(formatMarkdown(transcript))
                                .font(.title3)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        if let duration = note.transcriptionDuration {
                            Text("Generated in \(formatDuration(duration))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
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
            } else if note.transcript == "" {
                localTranscript = ""
                isEditingTranscript = true
            }
        }
        .onChange(of: note.id) { _, _ in
            // When user taps a different note in the list, completely reset the view state
            player.stopPlayback()
            localTranscript = nil
            localSummary = nil
            isProcessing = false
            processingError = nil
            isEditingSummary = false
            
            let isTextNote = (note.audioURL == nil && note.transcript == "")
            if isTextNote {
                localTranscript = ""
            }
            isEditingTranscript = isTextNote
            generationTask?.cancel()
            generationTask = nil
            
            if let url = note.audioURL {
                player.load(audioURL: url)
            }
        }
        .onChange(of: isEditingTranscript) { _, isEditing in
            if isEditing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTranscriptFocused = true
                }
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
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration) / 60
            let seconds = duration.truncatingRemainder(dividingBy: 60)
            return String(format: "%dm %.1fs", minutes, seconds)
        }
    }
    
    private func formatMarkdown(_ text: String) -> LocalizedStringKey {
        let lines = text.components(separatedBy: .newlines)
        var formattedLines: [String] = []
        
        for line in lines {
            var modifiedLine = line
            
            // 1. Convert Markdown headers (### Header) to Bold text (**Header**)
            if let range = modifiedLine.range(of: "^#{1,6}\\s+", options: .regularExpression) {
                modifiedLine = "**" + modifiedLine[range.upperBound...] + "**"
            }
            
            // 2. Convert Markdown list items (* Item or - Item) to visual bullets (• Item) to prevent them 
            // from being interpreted as broken italic tags or stripped entirely.
            if let range = modifiedLine.range(of: "^(\\s*)[\\*\\-]\\s+", options: .regularExpression) {
                let leadingWhitespace = modifiedLine[...range.lowerBound].dropLast() // Keep indentation
                modifiedLine = String(leadingWhitespace) + "• " + modifiedLine[range.upperBound...]
            }
            
            formattedLines.append(modifiedLine)
        }
        
        // Pass the cleaned string explicitly as a LocalizedStringKey to trigger SwiftUI's robust inline markdown renderer
        // which brilliantly preserves raw \n line breaks (unlike AttributedString block parsing).
        return LocalizedStringKey(formattedLines.joined(separator: "\n"))
    }
    
    private func processAudio() async {
        isProcessing = true
        processingError = nil
        do {
            let transcriptText: String
            let tStart = Date()
            
            if let existingTranscript = localTranscript ?? note.transcript, !existingTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                transcriptText = existingTranscript
            } else if let url = note.audioURL {
                transcriptText = try await summarizer.transcribe(audioURL: url) { partialText in
                    DispatchQueue.main.async {
                        self.localTranscript = partialText
                    }
                }
                
                let tDuration = Date().timeIntervalSince(tStart)
                DispatchQueue.main.async {
                    self.localTranscript = transcriptText
                    self.note.transcript = transcriptText
                    self.note.transcriptionDuration = tDuration
                    try? self.modelContext.save()
                }
            } else {
                DispatchQueue.main.async {
                    self.processingError = "Please write a transcript first."
                    self.isProcessing = false
                }
                return
            }
            
            let sStart = Date()
            let summaryText = try await summarizer.summarize(transcript: transcriptText)
            let sDuration = Date().timeIntervalSince(sStart)
            
            DispatchQueue.main.async {
                self.localSummary = summaryText
                self.note.summary = summaryText
                self.note.summaryDuration = sDuration
                self.isProcessing = false
                try? self.modelContext.save()
            }
        } catch is CancellationError {
            // Task was cancelled, ignore
        } catch {
            print("Processing failed: \(error)")
            DispatchQueue.main.async { 
                self.processingError = error.localizedDescription
                self.isProcessing = false 
            }
        }
        
        DispatchQueue.main.async {
            self.generationTask = nil
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
