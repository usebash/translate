import Foundation
import Speech
import AVFoundation
import Observation

@MainActor
@Observable
final class SpeechDictation {
    var isListening = false
    var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start(locale: Locale, onResult: @escaping (String, Bool) -> Void) {
        errorMessage = nil
        requestMicrophonePermission { granted in
            guard granted else {
                self.errorMessage = "Microphone access denied. Enable it in Settings > Privacy > Microphone."
                return
            }
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    guard status == .authorized else {
                        self.errorMessage = "Speech recognition access denied. Enable it in Settings > Privacy > Speech Recognition."
                        return
                    }
                    self.begin(locale: locale, onResult: onResult)
                }
            }
        }
    }

    private func requestMicrophonePermission(_ completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                Task { @MainActor in completion(granted) }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                Task { @MainActor in completion(granted) }
            }
        }
    }

    private func begin(locale: Locale, onResult: @escaping (String, Bool) -> Void) {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            errorMessage = "No speech recognizer available for \(locale.identifier)"
            return
        }
        guard recognizer.isAvailable else {
            errorMessage = "Speech recognizer is temporarily unavailable, try again shortly"
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            errorMessage = "Microphone input unavailable"
            return
        }
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            errorMessage = "Could not start audio engine: \(error.localizedDescription)"
            return
        }

        isListening = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    onResult(result.bestTranscription.formattedString, result.isFinal)
                    if result.isFinal {
                        self.stop()
                    }
                }
                if let error {
                    self.errorMessage = error.localizedDescription
                    self.stop()
                }
            }
        }
    }

    func stop() {
        guard isListening else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false
    }
}
