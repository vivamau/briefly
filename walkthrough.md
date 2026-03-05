# Walkthrough: Briefly Architecture

*2026-03-04T13:49:51Z by Showboat 0.6.1*
<!-- showboat-id: 08dfb83a-dd23-470d-8eae-c3dd021053de -->

Briefly is a macOS application that allows you to record voice notes and transcribe/summarize them. Let's explore how it works under the hood.

## 1. The Data Model

The core data model is `VoiceNote`, stored locally using SwiftData. It contains properties for the audio file, transcript, and summary.

```bash
sed -n '4,15p' briefly/whispernotes/Sources/Models/VoiceNote.swift
```

```output
@Model
final class VoiceNote {
    var id: UUID
    var title: String
    var audioURL: URL?
    var creationDate: Date
    var duration: TimeInterval
    var transcript: String?
    var summary: String?
    var isFavorite: Bool
    
    init(title: String, audioURL: URL?, duration: TimeInterval = 0) {
```

## 2. Audio Recording

`AudioRecorderManager` handles capturing audio from the microphone using `AVAudioRecorder`. It saves the audio to the app's Application Support directory.

```bash
sed -n '77,95p' briefly/whispernotes/Sources/Managers/AudioRecorderManager.swift
```

```output
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
```

## 3. Transcription and Summarization

The `SummarizationService` handles local transcription via `SFSpeechRecognizer` and delegates summarization to the chosen LLM provider (Ollama, Apple Local, OpenAI, etc.).

```bash
sed -n '65,82p' briefly/whispernotes/Sources/Managers/SummarizationService.swift
```

```output
    func transcribeAndSummarize(audioURL: URL) async throws -> (transcript: String, summary: String) {
        let transcript = try await performAppleSpeechTranscription(audioURL: audioURL)
        
        var summary = ""
        switch selectedProvider {
        case .appleLocal:
            summary = "Summary generation via Apple requires iOS 18 Apple Intelligence (if supported), or fallback to Extractive summarization. \nLength: \(transcript.components(separatedBy: .whitespacesAndNewlines).count) words."
        case .ollama:
            summary = try await summarizeWithOllama(transcript: transcript)
        case .openAI:
            summary = try await summarizeWithOpenAI(transcript: transcript)
        case .perplexity:
            summary = try await summarizeWithPerplexity(transcript: transcript)
        case .gemini:
            summary = try await summarizeWithGemini(transcript: transcript)
        }
        
        return (transcript, summary)
```

## 4. Main User Interface

The `ContentView` acts as the main screen, listing all notes. It features a pulsing record button at the bottom.

```bash
sed -n '106,128p' briefly/whispernotes/Sources/Views/ContentView.swift
```

```output
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
```

## 5. Detail View

Finally, the `NoteDetailView` presents the audio playback controls, the transcript, and the summary. It allows sharing, emailing, and inline editing.

```bash
sed -n '24,36p' briefly/whispernotes/Sources/Views/NoteDetailView.swift
```

```output
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
```
