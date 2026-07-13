import SwiftUI
import Speech
import AVFoundation
import Translation
import Observation

enum ConversationSpeaker {
    case you
    case them
}

struct ConversationEntry: Identifiable {
    let id = UUID()
    let speaker: ConversationSpeaker
    let originalText: String
    var translatedText: String
    let language: AppLanguage
    let targetLanguage: AppLanguage
}

@MainActor
@Observable
final class ConversationState {
    var entries: [ConversationEntry] = []
    var isListening = false
    var currentSpeaker: ConversationSpeaker = .you
    var liveTranscript = ""
    var errorMessage: String?

    var forwardConfiguration: TranslationSession.Configuration?
    var reverseConfiguration: TranslationSession.Configuration?

    private var forwardPending: String = ""
    private var reversePending: String = ""
    private var pendingEntryID: UUID?

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?

    func setup(sourceLanguage: AppLanguage, targetLanguage: AppLanguage) {
        forwardConfiguration = TranslationSession.Configuration(
            source: sourceLanguage.locale,
            target: targetLanguage.locale
        )
        reverseConfiguration = TranslationSession.Configuration(
            source: targetLanguage.locale,
            target: sourceLanguage.locale
        )
    }

    func handleForward(session: TranslationSession) async {
        guard !forwardPending.isEmpty else { return }
        do {
            let response = try await session.translate(forwardPending)
            applyTranslation(response.targetText)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleReverse(session: TranslationSession) async {
        guard !reversePending.isEmpty else { return }
        do {
            let response = try await session.translate(reversePending)
            applyTranslation(response.targetText)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyTranslation(_ text: String) {
        guard let pendingEntryID, let index = entries.firstIndex(where: { $0.id == pendingEntryID }) else { return }
        entries[index].translatedText = text
    }

    func startListening(sourceLanguage: AppLanguage, targetLanguage: AppLanguage) {
        errorMessage = nil
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                guard status == .authorized else {
                    self.errorMessage = "Speech recognition permission denied"
                    return
                }
                self.beginRecognition(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
            }
        }
    }

    private func beginRecognition(sourceLanguage: AppLanguage, targetLanguage: AppLanguage) {
        let locale = currentSpeaker == .you ? sourceLanguage.speechRecognitionLocale : targetLanguage.speechRecognitionLocale
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            errorMessage = "Speech recognition unavailable for this language"
            return
        }
        self.recognizer = recognizer

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()
        isListening = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.liveTranscript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.finishUtterance(text: result.bestTranscription.formattedString, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
                    }
                }
                if error != nil {
                    self.stopListening()
                }
            }
        }
    }

    private func finishUtterance(text: String, sourceLanguage: AppLanguage, targetLanguage: AppLanguage) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        stopListening()
        guard !trimmed.isEmpty else { return }

        let entry = ConversationEntry(
            speaker: currentSpeaker,
            originalText: trimmed,
            translatedText: "",
            language: currentSpeaker == .you ? sourceLanguage : targetLanguage,
            targetLanguage: currentSpeaker == .you ? targetLanguage : sourceLanguage
        )
        entries.append(entry)
        pendingEntryID = entry.id

        if currentSpeaker == .you {
            forwardPending = trimmed
            forwardConfiguration?.invalidate()
        } else {
            reversePending = trimmed
            reverseConfiguration?.invalidate()
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        liveTranscript = ""
    }

}

struct LiveConversationView: View {
    @Environment(AppState.self) private var appState
    @State private var conversation = ConversationState()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 16) {
                    LanguageSelectorView()
                        .padding(.top, 8)

                    speakerToggle

                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(conversation.entries) { entry in
                                conversationBubble(entry)
                            }
                            if conversation.isListening, !conversation.liveTranscript.isEmpty {
                                Text(conversation.liveTranscript)
                                    .foregroundStyle(.gray)
                                    .italic()
                                    .frame(maxWidth: .infinity, alignment: conversation.currentSpeaker == .you ? .trailing : .leading)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    if let errorMessage = conversation.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .padding(.horizontal, 16)
                    }

                    micButton
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle("Live")
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                conversation.setup(sourceLanguage: appState.sourceLanguage, targetLanguage: appState.targetLanguage)
            }
            .onChange(of: appState.sourceLanguage) { _, _ in
                conversation.setup(sourceLanguage: appState.sourceLanguage, targetLanguage: appState.targetLanguage)
            }
            .onChange(of: appState.targetLanguage) { _, _ in
                conversation.setup(sourceLanguage: appState.sourceLanguage, targetLanguage: appState.targetLanguage)
            }
            .translationTask(conversation.forwardConfiguration) { session in
                await conversation.handleForward(session: session)
            }
            .translationTask(conversation.reverseConfiguration) { session in
                await conversation.handleReverse(session: session)
            }
        }
        .tint(.white)
    }

    private var speakerToggle: some View {
        HStack(spacing: 12) {
            speakerButton(title: appState.sourceLanguage.displayName, isActive: conversation.currentSpeaker == .you) {
                conversation.currentSpeaker = .you
            }
            speakerButton(title: appState.targetLanguage.displayName, isActive: conversation.currentSpeaker == .them) {
                conversation.currentSpeaker = .them
            }
        }
    }

    private func speakerButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isActive ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isActive ? .white : .white.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(conversation.isListening)
    }

    private var micButton: some View {
        Button {
            if conversation.isListening {
                conversation.stopListening()
            } else {
                conversation.startListening(sourceLanguage: appState.sourceLanguage, targetLanguage: appState.targetLanguage)
            }
        } label: {
            Image(systemName: conversation.isListening ? "stop.fill" : "mic.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 72, height: 72)
                .background(.white, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func conversationBubble(_ entry: ConversationEntry) -> some View {
        VStack(alignment: entry.speaker == .you ? .trailing : .leading, spacing: 4) {
            Text(entry.originalText)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            if !entry.translatedText.isEmpty {
                Text(entry.translatedText)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: entry.speaker == .you ? .trailing : .leading)
    }
}
