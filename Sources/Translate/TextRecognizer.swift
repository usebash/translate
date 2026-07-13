import Vision
import UIKit
import AVFoundation

enum TextRecognizer {
    static func recognizeText(in image: UIImage, languages: [String] = ["en-US", "ru-RU", "de-DE"]) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "TextRecognizer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image"])
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = languages

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    static func extractFrame(from videoURL: URL, at seconds: Double = 1.0) throws -> UIImage {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
        return UIImage(cgImage: cgImage)
    }
}
