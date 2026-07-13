import SwiftUI
import PhotosUI
import UIKit

struct PhotoTranslateView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var fragments: [TextFragment] = []
    @State private var selectedFragmentIDs: Set<UUID> = []
    @State private var isRecognizing = false
    @State private var showCamera = false
    @State private var recognitionError: String?

    var body: some View {
        @Bindable var appState = appState
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        LanguageSelectorView()
                            .padding(.top, 8)

                        glassCard {
                            HStack(spacing: 12) {
                                PhotosPicker(selection: $selectedItem, matching: .images) {
                                    actionLabel("photo.on.rectangle", "Photo")
                                }

                                Button {
                                    showCamera = true
                                } label: {
                                    actionLabel("camera", "Camera")
                                }
                            }
                        }

                        if let selectedImage {
                            glassCard {
                                GeometryReader { proxy in
                                    let fitRect = aspectFitRect(imageSize: selectedImage.size, in: proxy.size)
                                    ZStack(alignment: .topLeading) {
                                        Image(uiImage: selectedImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: proxy.size.width, height: proxy.size.height)

                                        ForEach(fragments) { fragment in
                                            let rect = viewRect(for: fragment.boundingBox, fitRect: fitRect)
                                            Rectangle()
                                                .fill(selectedFragmentIDs.contains(fragment.id) ? .white.opacity(0.28) : .white.opacity(0.04))
                                                .overlay(
                                                    Rectangle().stroke(.white.opacity(selectedFragmentIDs.contains(fragment.id) ? 0.9 : 0.3), lineWidth: 1)
                                                )
                                                .frame(width: rect.width, height: rect.height)
                                                .position(x: rect.midX, y: rect.midY)
                                                .onTapGesture {
                                                    toggle(fragment.id)
                                                }
                                        }
                                    }
                                }
                                .frame(height: 320)

                                if !fragments.isEmpty {
                                    Text(selectedFragmentIDs.isEmpty ? "Tap fragments to select, or translate all" : "\(selectedFragmentIDs.count) fragment(s) selected")
                                        .font(.footnote)
                                        .foregroundStyle(.gray)
                                }
                            }
                        }

                        if isRecognizing {
                            glassCard {
                                HStack {
                                    ProgressView().tint(.white)
                                    Text("Recognizing text")
                                        .foregroundStyle(.white)
                                }
                            }
                        }

                        if !fragments.isEmpty {
                            glassCard {
                                Button {
                                    translateSelection()
                                } label: {
                                    HStack {
                                        if appState.isTranslating {
                                            ProgressView().tint(.white)
                                        } else {
                                            Image(systemName: "arrow.left.arrow.right")
                                        }
                                        Text(selectedFragmentIDs.isEmpty ? "Translate All" : "Translate Selected")
                                    }
                                    .foregroundStyle(.white)
                                }
                                .disabled(appState.isTranslating)
                            }
                        }

                        if !appState.translatedText.isEmpty {
                            glassCard {
                                Text("Translation")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.gray)
                                Text(appState.translatedText)
                                    .foregroundStyle(.white)
                                    .textSelection(.enabled)

                                Button {
                                    appState.speak(appState.translatedText, language: appState.targetLanguage)
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundStyle(.white)
                                }
                            }
                        }

                        if let recognitionError {
                            glassCard {
                                Text(recognitionError)
                                    .foregroundStyle(.red)
                                    .font(.footnote)
                            }
                        }

                        DiagnosticsSection()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Translate")
            .toolbarBackground(.hidden, for: .navigationBar)
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
        .tint(.white)
    }

    private func actionLabel(_ systemImage: String, _ title: String) -> some View {
        HStack {
            Image(systemName: systemImage)
            Text(title)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.1), in: Capsule())
    }

    private func toggle(_ id: UUID) {
        if selectedFragmentIDs.contains(id) {
            selectedFragmentIDs.remove(id)
        } else {
            selectedFragmentIDs.insert(id)
        }
    }

    private func translateSelection() {
        let chosen = selectedFragmentIDs.isEmpty
            ? fragments
            : fragments.filter { selectedFragmentIDs.contains($0.id) }
        let text = chosen.map(\.text).joined(separator: "\n")
        appState.requestTranslation(text: text)
    }

    private func aspectFitRect(imageSize: CGSize, in boundsSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: boundsSize)
        }
        let imageAspect = imageSize.width / imageSize.height
        let boundsAspect = boundsSize.width / boundsSize.height
        var fitSize = boundsSize
        if imageAspect > boundsAspect {
            fitSize.height = boundsSize.width / imageAspect
        } else {
            fitSize.width = boundsSize.height * imageAspect
        }
        let origin = CGPoint(x: (boundsSize.width - fitSize.width) / 2, y: (boundsSize.height - fitSize.height) / 2)
        return CGRect(origin: origin, size: fitSize)
    }

    private func viewRect(for boundingBox: CGRect, fitRect: CGRect) -> CGRect {
        let x = fitRect.origin.x + boundingBox.origin.x * fitRect.width
        let height = boundingBox.height * fitRect.height
        let y = fitRect.origin.y + (1 - boundingBox.origin.y - boundingBox.height) * fitRect.height
        let width = boundingBox.width * fitRect.width
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func process(image: UIImage) {
        selectedImage = image
        fragments = []
        selectedFragmentIDs = []
        recognitionError = nil
        appState.translatedText = ""
        isRecognizing = true
        appState.log("Recognizing text in photo")
        Task {
            defer { isRecognizing = false }
            do {
                let result = try await TextRecognizer.recognizeFragments(in: image)
                fragments = result
                appState.log("Recognized \(result.count) fragment(s)")
            } catch {
                recognitionError = error.localizedDescription
                appState.log("Recognition error: \(error.localizedDescription)")
            }
        }
    }

    private func process(videoURL: URL) {
        fragments = []
        selectedFragmentIDs = []
        recognitionError = nil
        appState.translatedText = ""
        isRecognizing = true
        appState.log("Extracting frame from video")
        Task {
            defer { isRecognizing = false }
            do {
                let frame = try TextRecognizer.extractFrame(from: videoURL)
                selectedImage = frame
                let result = try await TextRecognizer.recognizeFragments(in: frame)
                fragments = result
                appState.log("Recognized \(result.count) fragment(s) from video frame")
            } catch {
                recognitionError = error.localizedDescription
                appState.log("Video recognition error: \(error.localizedDescription)")
            }
        }
    }

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
    }
}
