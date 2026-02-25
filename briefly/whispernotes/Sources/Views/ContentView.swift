import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VoiceNote.creationDate, order: .reverse) private var notes: [VoiceNote]
    
    @State private var selectedNote: VoiceNote?
    @State private var showingSettings = false
    
    @StateObject private var recorder = AudioRecorderManager()
    @StateObject private var player = AudioPlayerManager()
    @StateObject private var summarizer = SummarizationService()
    
    @State private var isGeneratingSummary = false
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedNote) {
                ForEach(notes) { note in
                    NavigationLink(value: note) {
                        VStack(alignment: .leading) {
                            Text(note.title)
                                .font(.headline)
                            Text(note.creationDate, format: Date.FormatStyle(date: .numeric, time: .standard))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteNote(note)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .safeAreaInset(edge: .bottom) {
                if isGeneratingSummary {
                    ProgressView("Generating Summary...")
                        .padding()
                        .frame(maxWidth: .infinity)
                } else {
                    Menu {
                        Button("Daily") { generatePeriodicSummary(period: "Daily", days: 1) }
                        Button("Weekly") { generatePeriodicSummary(period: "Weekly", days: 7) }
                        Button("Monthly") { generatePeriodicSummary(period: "Monthly", days: 30) }
                    } label: {
                        Label("Create Summary", systemImage: "sparkles.rectangle.stack")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
            .navigationTitle("WhisperNotes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                        .accessibilityHint("Edit the list of voice notes")
                }
                #endif
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(summarizer: summarizer)
            }
        } detail: {
            Group {
                if let note = selectedNote {
                    NoteDetailView(note: note, player: player, summarizer: summarizer)
                        .id(note.id)
                } else {
                    Text("Select a Voice Note")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .safeAreaInset(edge: .bottom) {
                recordButtonView
            }
        }
        .onAppear {
            recorder.checkPermissions()
        }
    }
    
    @State private var isPulsing = false
    
    private var recordButtonView: some View {
        HStack {
            Spacer()
            
            VStack {
                if recorder.isRecording {
                    Text(formatTime(recorder.recordingDuration))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.red)
                        .padding(.bottom, 4)
                        .accessibilityLabel("Recording for \(formatTime(recorder.recordingDuration))")
                }
                
                HStack(spacing: 30) {
                    if recorder.isRecording {
                        Button(action: {
                            isPulsing = false
                            recorder.cancelRecording()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Cancel Recording")
                        .accessibilityHint("Discard the current voice note")
                    }
                    
                    Button(action: toggleRecording) {
                        ZStack {
                            if recorder.isRecording {
                                Circle()
                                    .fill(Color.red.opacity(0.3))
                                    .frame(width: 85, height: 85)
                                    .scaleEffect(isPulsing ? 1.2 : 0.8)
                                    .opacity(isPulsing ? 0 : 1)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false), value: isPulsing)
                            }
                            
                            Circle()
                                .fill(recorder.isRecording ? Color.red : Color.red.opacity(0.8))
                                .frame(width: 70, height: 70)
                            
                            if recorder.isRecording {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white)
                                    .frame(width: 25, height: 25)
                            } else {
                                Image(systemName: "mic.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(recorder.isRecording ? "Stop Recording" : "Start Recording")
                    .accessibilityHint(recorder.isRecording ? "Double tap to stop and save the voice note" : "Double tap to start recording a new voice note")
                    
                    if recorder.isRecording {
                        // Invisible placeholder to keep the main button perfectly centered
                        Color.clear
                            .frame(width: 40, height: 40)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func toggleRecording() {
        if recorder.isRecording {
            isPulsing = false
            if let audioURL = recorder.stopRecording() {
                saveNote(audioURL: audioURL, duration: recorder.recordingDuration)
            }
        } else {
            recorder.startRecording()
            isPulsing = true
        }
    }
    
    // Save recording into SwiftData
    private func saveNote(audioURL: URL, duration: TimeInterval) {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        let newTitle = "Note \(formatter.string(from: Date()))"
        let newNote = VoiceNote(title: newTitle, audioURL: audioURL, duration: duration)
        modelContext.insert(newNote)
    }
    
    // Generate Periodic Summary
    private func generatePeriodicSummary(period: String, days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let filteredNotes = notes.filter { $0.creationDate >= cutoffDate }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        let dateStr = formatter.string(from: Date())
        
        let newNote = VoiceNote(title: "\(period) Summary - \(dateStr)", audioURL: nil, duration: 0)
        
        if filteredNotes.isEmpty {
            newNote.summary = "No voice notes found in the last \(days) days."
            modelContext.insert(newNote)
            selectedNote = newNote
            return
        }
        
        newNote.summary = "Generating \(period) summary of \(filteredNotes.count) notes..."
        modelContext.insert(newNote)
        selectedNote = newNote
        isGeneratingSummary = true
        
        Task {
            do {
                var missingCount = 0
                for note in filteredNotes {
                    if (note.transcript == nil || note.summary == nil) {
                        missingCount += 1
                    }
                }
                
                if missingCount > 0 {
                    await MainActor.run {
                        newNote.summary = "Processing \(missingCount) missing notes before generating \(period) summary..."
                    }
                    
                    for note in filteredNotes {
                        if (note.transcript == nil || note.summary == nil), let url = note.audioURL {
                            let result = try await summarizer.transcribeAndSummarize(audioURL: url)
                            await MainActor.run {
                                note.transcript = result.transcript
                                note.summary = result.summary
                            }
                        }
                    }
                    
                    await MainActor.run {
                        newNote.summary = "Generating \(period) summary of \(filteredNotes.count) notes..."
                    }
                }
                
                let combinedText = filteredNotes.compactMap { note -> String? in
                    guard let content = note.transcript ?? note.summary else { return nil }
                    let dateStr = note.creationDate.formatted(date: .abbreviated, time: .shortened)
                    return "### Note from \(dateStr)\n\(content)"
                }.joined(separator: "\n\n")
                
                let summaryText = try await summarizer.summarizeMultiple(notes: filteredNotes, period: period)
                
                await MainActor.run {
                    newNote.transcript = combinedText
                    newNote.summary = summaryText
                    isGeneratingSummary = false
                }
            } catch {
                print("Failed to generate \(period) summary: \(error)")
                await MainActor.run { 
                    newNote.summary = "Failed to generate summary: \(String(describing: error))"
                    isGeneratingSummary = false 
                }
            }
        }
    }
    
    // Swipe to delete or Edit mode delete
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let note = notes[index]
                if let url = note.audioURL {
                    try? FileManager.default.removeItem(at: url)
                }
                modelContext.delete(note)
            }
        }
    }
    
    // Context menu singular delete
    private func deleteNote(_ note: VoiceNote) {
        withAnimation {
            if let url = note.audioURL {
                try? FileManager.default.removeItem(at: url)
            }
            if selectedNote?.id == note.id {
                selectedNote = nil
            }
            modelContext.delete(note)
        }
    }
}
