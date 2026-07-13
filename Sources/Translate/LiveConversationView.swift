import SwiftUI
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
}

@MainActor
@Observable
final class ConversationState {
    var entries: [ConversationEntry] = []
    var currentSpeaker: ConversationSpeaker = .you
    var liveTranscript = ""

    var forwardConfiguration: TranslationSession.Configuration?
    var reverseConfiguration: TranslationSession.Configuration?

    private var forwardPending: String = ""
    private var reversePending: String = ""
    private var pendingEntryID: UUID?

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
        if let response = try? await session.translate(forwardPending) {
            applyTranslation(response.targetText)
        }
    }

    func handleReverse(session: TranslationSession) async {
        guard !reversePending.isEmpty else { return }
        if let response = try? await session.translate(reversePending) {
            applyTranslation(response.targetText)
        }
    }

    private func applyTranslation(_ text: String) {
        guard let pendingEntryID, let index = entries.firstIndex(where: { $0.id == pendingEntryID }) else { return }
        entries[index].translatedText = text
    }

    func handleUtterance(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let entry = ConversationEntry(speaker: currentSpeaker, originalText: trimmed, translatedText: "")
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
}

struct LiveConversationView: View {
    @Environment(AppState.self) private var appState
    @State private var conversation = ConversationState()
    @State private var dictation = SpeechDictation()

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
                            if dictation.isListening, !conversation.liveTranscript.isEmpty {
                                Text(conversation.liveTranscript)
                                    .foregroundStyle(.gray)
                                    .italic()
                                    .frame(maxWidth: .infinity, alignment: conversation.currentSpeaker == .you ? .trailing : .leading)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    if let errorMessage = dictation.errorMessage {
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
            .navigationBarTitleDisplayMode(.inline)
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
        .disabled(dictation.isListening)
    }

    private var micButton: some View {
        Button {
            if dictation.isListening {
                dictation.stop()
            } else {
                let locale = conversation.currentSpeaker == .you
                    ? appState.sourceLanguage.speechRecognitionLocale
                    : appState.targetLanguage.speechRecognitionLocale
                dictation.start(locale: locale) { text, isFinal in
                    conversation.liveTranscript = text
                    if isFinal {
                        conversation.handleUtterance(text)
                        conversation.liveTranscript = ""
                    }
                }
            }
        } label: {
            Image(systemName: dictation.isListening ? "stop.fill" : "mic.fill")
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
