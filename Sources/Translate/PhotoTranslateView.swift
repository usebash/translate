import SwiftUI
import PhotosUI
import UIKit

struct PhotoTranslateView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var recognizedText: String = ""
    @State private var isRecognizing = false
    @State private var showCamera = false
    @State private var recognitionError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Language") {
                    LanguageSelectorView()
                }

                Section("Source") {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Choose Photo", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        showCamera = true
                    } label: {
                        Label("Camera Photo or Video", systemImage: "camera")
                    }
                }

                if let selectedImage {
                    Section("Preview") {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                    }
                }

                if isRecognizing {
                    Section {
                        ProgressView("Recognizing text")
                    }
                }

                if !recognizedText.isEmpty {
                    Section("Recognized Text") {
                        Text(recognizedText)

                        Button {
                            appState.requestTranslation(text: recognizedText)
                        } label: {
                            if appState.isTranslating {
                                ProgressView()
                            } else {
                                Label("Translate", systemImage: "arrow.left.arrow.right")
                            }
                        }
                        .disabled(appState.isTranslating)
                    }
                }

                if !appState.translatedText.isEmpty {
                    Section("Result") {
                        Text(appState.translatedText)
                    }
                }

                if let recognitionError {
                    Section("Recognition Error") {
                        Text(recognitionError)
                            .foregroundStyle(.red)
                    }
                }

                DiagnosticsSection()
            }
            .navigationTitle("Translate")
            .sheet(isPresented: $showCamera) {
                CameraCaptureView(
                    onImage: { image in
                        process(image: image)
                    },
                    onVideo: { url in
                        process(videoURL: url)
                    }
                )
                .ignoresSafeArea()
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let newItem,
                       let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        process(image: image)
                    }
                }
            }
        }
    }

    private func process(image: UIImage) {
        selectedImage = image
        recognizedText = ""
        recognitionError = nil
        appState.translatedText = ""
        isRecognizing = true
        appState.log("Recognizing text in photo")
        Task {
            defer { isRecognizing = false }
            do {
                let text = try await TextRecognizer.recognizeText(in: image)
                recognizedText = text
                appState.log("Recognized \(text.count) characters")
            } catch {
                recognitionError = error.localizedDescription
                appState.log("Recognition error: \(error.localizedDescription)")
            }
        }
    }

    private func process(videoURL: URL) {
        recognizedText = ""
        recognitionError = nil
        appState.translatedText = ""
        isRecognizing = true
        appState.log("Extracting frame from video")
        Task {
            defer { isRecognizing = false }
            do {
                let frame = try TextRecognizer.extractFrame(from: videoURL)
                selectedImage = frame
                let text = try await TextRecognizer.recognizeText(in: frame)
                recognizedText = text
                appState.log("Recognized \(text.count) characters from video frame")
            } catch {
                recognitionError = error.localizedDescription
                appState.log("Video recognition error: \(error.localizedDescription)")
            }
        }
    }
}
