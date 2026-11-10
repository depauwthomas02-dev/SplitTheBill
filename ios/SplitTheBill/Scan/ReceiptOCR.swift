import UIKit
@preconcurrency import Vision

/// Lecture du texte d'un ticket avec Vision, entièrement sur l'iPhone.
/// Vision rend des blocs de texte séparés (le nom à gauche, le prix à droite) :
/// on les recolle ligne par ligne d'après leur position verticale.
enum ReceiptOCR {
    struct Failure: LocalizedError {
        var errorDescription: String? { "Impossible de lire cette photo." }
    }

    static func recognize(_ image: UIImage) async throws -> String {
        guard let cg = image.normalizedCGImage() else { throw Failure() }
        let orientation = CGImagePropertyOrientation.up

        let observations: [VNRecognizedTextObservation] = try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["fr-FR", "en-US"]
                // La correction linguistique aide pour les noms d'articles ;
                // `cleanOCR` répare ensuite les erreurs courantes sur les prix.
                request.usesLanguageCorrection = true
                request.minimumTextHeight = 0.008
                do {
                    try VNImageRequestHandler(cgImage: cg, orientation: orientation).perform([request])
                    cont.resume(returning: request.results ?? [])
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
        return TicketParser.cleanOCR(assembleLines(observations))
    }

    /// Regroupe les blocs qui sont sur la même ligne du ticket.
    static func assembleLines(_ observations: [VNRecognizedTextObservation]) -> String {
        struct Piece { var text: String; var box: CGRect }
        let pieces = observations.compactMap { o -> Piece? in
            guard let t = o.topCandidates(1).first?.string, !t.trimmed.isEmpty else { return nil }
            return Piece(text: t, box: o.boundingBox)
        }
        // Repère Vision : origine en bas à gauche, donc on trie du haut (midY grand) vers le bas.
        let sorted = pieces.sorted { $0.box.midY > $1.box.midY }
        var rows: [[Piece]] = []
        for p in sorted {
            if let last = rows.last, let ref = last.first {
                let h = min(ref.box.height, p.box.height)
                if abs(ref.box.midY - p.box.midY) < h * 0.55 {
                    rows[rows.count - 1].append(p)
                    continue
                }
            }
            rows.append([p])
        }
        return rows
            .map { $0.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ") }
            .joined(separator: "\n")
    }
}

extension UIImage {
    /// Redresse l'orientation EXIF et limite la taille (2 000 px suffisent largement pour un ticket).
    func normalizedCGImage(maxSide: CGFloat = 2400) -> CGImage? {
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let img = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return img.cgImage
    }
}
