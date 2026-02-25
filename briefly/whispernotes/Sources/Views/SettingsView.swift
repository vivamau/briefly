import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var summarizer: SummarizationService
    
    @AppStorage("selectedProvider") private var selectedProvider: LLMProvider = .appleLocal
    @AppStorage("periodicSummaryProvider") private var periodicSummaryProvider: LLMProvider = .appleLocal
    @AppStorage("openAIApiKey") private var openAIApiKey: String = ""
    @AppStorage("perplexityApiKey") private var perplexityApiKey: String = ""
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    @AppStorage("ollamaURL") private var ollamaURL: String = "http://localhost:11434"
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Providers"), footer: Text("Choose which AI to use for individual notes versus generating daily, weekly, or monthly summaries.")) {
                    Picker("Default Provider", selection: $selectedProvider) {
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    
                    Picker("Periodic Summary Provider", selection: $periodicSummaryProvider) {
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                }
                
                if selectedProvider == .ollama || periodicSummaryProvider == .ollama {
                    Section(header: Text("Local Configuration"), footer: Text("Ollama base URL (e.g., http://localhost:11434) is used for local summaries.")) {
                        TextField("Server URL", text: $ollamaURL)
                            #if os(iOS)
                            .autocapitalization(.none)
                            #endif
                            .disableAutocorrection(true)
                            .onChange(of: ollamaURL) { _ in
                                Task { await summarizer.fetchOllamaModels() }
                            }
                        
                        Picker("Model", selection: $summarizer.ollamaModel) {
                            if summarizer.ollamaAvailableModels.isEmpty {
                                Text(summarizer.ollamaModel.isEmpty ? "No models found" : summarizer.ollamaModel).tag(summarizer.ollamaModel)
                            } else {
                                ForEach(summarizer.ollamaAvailableModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                        }
                        .onAppear {
                            Task { await summarizer.fetchOllamaModels() }
                        }
                    }
                }
                
                if selectedProvider == .openAI || periodicSummaryProvider == .openAI {
                    Section(header: Text("OpenAI Configuration"), footer: Text("This key is securely stored locally and used when generating summaries with OpenAI.")) {
                        SecureField("API Key", text: $openAIApiKey)
                    }
                }
                
                if selectedProvider == .gemini || periodicSummaryProvider == .gemini {
                    Section(header: Text("Gemini Configuration"), footer: Text("This key is securely stored locally and used when generating summaries with Gemini.")) {
                        SecureField("API Key", text: $geminiApiKey)
                    }
                }
                
                if selectedProvider == .perplexity || periodicSummaryProvider == .perplexity {
                    Section(header: Text("Perplexity Configuration"), footer: Text("This key is securely stored locally and used when generating summaries with Perplexity.")) {
                        SecureField("API Key", text: $perplexityApiKey)
                    }
                }
                
                Section(header: Text("Export Cadence")) {
                    Text("Custom scheduled email backup features coming soon...")
                        .italic()
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 500)
        #endif
    }
}
