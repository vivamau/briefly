import Foundation
import Combine
import Speech
import AVFoundation
import SwiftUI

enum LLMProvider: String, CaseIterable, Identifiable {
    case appleLocal = "Apple Speech (Local)"
    case ollama = "Ollama (Local Network)"
    case openAI = "OpenAI"
    case perplexity = "Perplexity"
    case gemini = "Gemini"
    
    var id: String { self.rawValue }
}

class SummarizationService: ObservableObject {
    @AppStorage("selectedProvider") var selectedProvider: LLMProvider = .appleLocal
    @AppStorage("periodicSummaryProvider") var periodicSummaryProvider: LLMProvider = .appleLocal
    @AppStorage("openAIApiKey") var openAIApiKey: String = ""
    @AppStorage("perplexityApiKey") var perplexityApiKey: String = ""
    @AppStorage("geminiApiKey") var geminiApiKey: String = ""
    @AppStorage("ollamaURL") var ollamaURL: String = "http://localhost:11434"
    @AppStorage("ollamaModel") var ollamaModel: String = "llama3"
    
    @Published var ollamaAvailableModels: [String] = []
    @Published var ollamaFetchError: String?
    
    private var ollamaBaseURL: String {
        var base = ollamaURL
        if base.hasSuffix("/api/generate") {
            base = base.replacingOccurrences(of: "/api/generate", with: "")
        }
        if base.hasSuffix("/") {
            base.removeLast()
        }
        return base
    }
    
    @MainActor
    func fetchOllamaModels() async {
        guard let url = URL(string: "\(ollamaBaseURL)/api/tags") else { return }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10 // Moderate timeout for local network check
            
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let modelsArray = json["models"] as? [[String: Any]] {
                
                let fetchedModels = modelsArray.compactMap { $0["name"] as? String }
                self.ollamaAvailableModels = fetchedModels
                
                // If the selected model isn't in the list, default to the first one available
                if !fetchedModels.isEmpty && !fetchedModels.contains(ollamaModel) {
                    self.ollamaModel = fetchedModels[0]
                }
                self.ollamaFetchError = nil
            } else {
                self.ollamaFetchError = "Failed to parse Ollama response."
            }
        } catch {
            print("Failed to fetch Ollama models: \(error)")
            self.ollamaAvailableModels = []
            self.ollamaFetchError = error.localizedDescription
        }
    }
    
    func transcribe(audioURL: URL, onProgress: ((String) -> Void)? = nil) async throws -> String {
        return try await performAppleSpeechTranscription(audioURL: audioURL, onProgress: onProgress)
    }

    func summarize(transcript: String) async throws -> String {
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
        
        return summary
    }
    
    // MARK: - Multi-Note Summarization
    func summarizeMultiple(notes: [VoiceNote], period: String) async throws -> String {
        let combinedText = notes.compactMap { note -> String? in
            guard let content = note.transcript ?? note.summary else { return nil }
            let dateStr = note.creationDate.formatted(date: .abbreviated, time: .shortened)
            return "--- Note from \(dateStr) ---\n\(content)"
        }.joined(separator: "\n\n")
        
        guard !combinedText.isEmpty else {
            return "No content found in the selected time period to summarize."
        }
        
        let promptConfig = "Please provide a comprehensive \(period) summary of the following voice notes. Synthesize the key themes, decisions, and action items discussed across all the notes:\n\n\(combinedText)"
        
        var summary = ""
        switch periodicSummaryProvider {
        case .appleLocal:
            summary = "Local Apple summarization placeholder for multiple notes. Focus: \(period)."
        case .ollama:
            summary = try await summarizeWithOllama(transcript: combinedText, customPrompt: promptConfig)
        case .openAI:
            summary = try await summarizeWithOpenAI(transcript: combinedText, customPrompt: promptConfig)
        case .perplexity:
            summary = try await summarizeWithPerplexity(transcript: combinedText, customPrompt: promptConfig)
        case .gemini:
            summary = try await summarizeWithGemini(transcript: combinedText, customPrompt: promptConfig)
        }
        return summary
    }
    
    // MARK: - Local Speech Transcription
    private func performAppleSpeechTranscription(audioURL: URL, onProgress: ((String) -> Void)? = nil) async throws -> String {
        return try await withTaskCancellationHandler {
            return try await withCheckedThrowingContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { authStatus in
                    guard authStatus == .authorized else {
                        continuation.resume(throwing: NSError(domain: "Speech", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech Recognition not authorized"]))
                        return
                    }
                    
                    guard let recognizer = SFSpeechRecognizer() else {
                        continuation.resume(throwing: NSError(domain: "Speech", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech Recognizer not available on this locale"]))
                        return
                    }
                    
                    let request = SFSpeechURLRecognitionRequest(url: audioURL)
                    request.shouldReportPartialResults = true
                    
                    var hasResumed = false
                    _ = recognizer.recognitionTask(with: request) { result, error in
                        var isFinished = false
                        
                        if let result = result {
                            isFinished = result.isFinal
                            
                            if isFinished {
                                if !hasResumed {
                                    hasResumed = true
                                    continuation.resume(returning: result.bestTranscription.formattedString)
                                }
                            } else {
                                onProgress?(result.bestTranscription.formattedString)
                            }
                        }
                        
                        if let error = error {
                            if !hasResumed {
                                hasResumed = true
                                if let lastResult = result?.bestTranscription.formattedString, !lastResult.isEmpty {
                                    continuation.resume(returning: lastResult)
                                } else {
                                    continuation.resume(throwing: error)
                                }
                            }
                        }
                    }
                    
                    // We store the task pointer in a local object that can cancel it, but withCheckedThrowingContinuation doesn't easily expose an async handle. 
                    // However, we rely on the parent task cancellation handler.
                }
            }
        } onCancel: {
            // Because SFSpeechRecognizer isn't fully thread-safe for direct cancellation without a handle, we primarily rely on URLSession for LLMs, but can't easily cancel the Apple speech task directly without a global/class wrapper.
            // The Swift underlying Task is cancelled, which is what we need for URLSession.
        }
    }
    
    // MARK: - API Calls
    private func summarizeWithOllama(transcript: String, customPrompt: String? = nil) async throws -> String {
        guard let url = URL(string: "\(ollamaBaseURL)/api/generate") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // Local models on big transcripts can take multiple minutes. URLSession default is 60s.
        request.timeoutInterval = 600 
        
        let promptText = customPrompt ?? "Summarize the following voice note transcript:\n\n\(transcript)"
        
        let body: [String: Any] = [
            "model": ollamaModel,
            "prompt": promptText,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let responseText = json["response"] as? String {
            return responseText
        }
        throw URLError(.cannotParseResponse)
    }
    
    private func summarizeWithOpenAI(transcript: String, customPrompt: String? = nil) async throws -> String {
        // Basic OpenAI implementation placeholder
        return "OpenAI Summary placeholder. Implement direct API call."
    }
    
    private func summarizeWithPerplexity(transcript: String, customPrompt: String? = nil) async throws -> String {
        // Basic Perplexity implementation placeholder
        return "Perplexity Summary placeholder. Implement direct API call."
    }
    
    private func summarizeWithGemini(transcript: String, customPrompt: String? = nil) async throws -> String {
        guard !geminiApiKey.isEmpty else {
            return "Error: Gemini API Key is missing. Please add it in Settings."
        }
        
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(geminiApiKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        
        let promptText = customPrompt ?? "Please provide a concise and well-structured summary of the following voice note transcript:\n\n\(transcript)"
        
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": promptText]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown HTTP Error"
            print("Gemini Error: \(errorString)")
            throw URLError(.badServerResponse)
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let content = firstCandidate["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let firstPart = parts.first,
           let text = firstPart["text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        throw URLError(.cannotParseResponse)
    }
}
