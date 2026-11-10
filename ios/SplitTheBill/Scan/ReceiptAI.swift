import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Structuration du ticket avec Apple Intelligence.
///
/// Ordre d'essai :
/// 1. le modèle serveur **Private Cloud Compute** (iOS 27, plus gros, contexte 32K) ;
/// 2. le modèle **sur l'iPhone** (iOS 26, iPhone 15 Pro ou plus récent) ;
/// 3. sinon `nil`, et l'appelant se rabat sur la lecture classique (`TicketParser`).
enum ReceiptAI {
    struct Extraction: Sendable {
        var items: [ParsedItem]
        var totalCents: Int?
        var engine: ReadingEngine
    }

    static let instructions = """
    Tu lis des tickets de caisse de restaurants et de bars, en français ou dans une autre langue.
    On te donne le texte brut lu par l'appareil photo : il contient des erreurs de lecture, \
    des lignes coupées ou mélangées.
    Retrouve chaque article consommé avec sa quantité et le prix total de sa ligne.
    Règles :
    - Ignore les en-têtes, l'adresse, la date, le numéro de table, la TVA, les sous-totaux, \
    le rendu monnaie et les moyens de paiement.
    - Le prix de ligne est le montant payé pour toute la ligne (quantité × prix unitaire).
    - Une remise est un article avec un prix négatif.
    - Ne devine pas d'article qui n'est pas sur le ticket.
    """

    static func prompt(for text: String) -> String {
        "Texte du ticket :\n\"\"\"\n\(String(text.prefix(6000)))\n\"\"\""
    }

    /// Le statut à afficher sur l'écran d'accueil.
    static var statusLabel: String {
        #if canImport(FoundationModels)
        if #available(iOS 27.0, *), case .available = PrivateCloudComputeLanguageModel().availability {
            return "Apple Intelligence · Private Cloud Compute"
        }
        if case .available = SystemLanguageModel.default.availability {
            return "Apple Intelligence · sur l’iPhone"
        }
        #endif
        return "Lecture sur l’iPhone"
    }

    static func extract(from text: String) async -> Extraction? {
        #if canImport(FoundationModels)
        if #available(iOS 27.0, *) {
            let pcc = PrivateCloudComputeLanguageModel()
            if case .available = pcc.availability {
                do {
                    let session = LanguageModelSession(model: pcc, instructions: instructions)
                    let r = try await session.respond(to: prompt(for: text), generating: AIReceipt.self)
                    if let e = r.content.extraction(engine: .privateCloud) { return e }
                } catch {
                    // Quota atteint, pas de réseau, entitlement absent… on passe au modèle local.
                    print("PCC indisponible : \(error)")
                }
            }
        }
        if case .available = SystemLanguageModel.default.availability {
            do {
                let session = LanguageModelSession(instructions: instructions)
                let r = try await session.respond(
                    to: prompt(for: text),
                    generating: AIReceipt.self,
                    options: GenerationOptions(samplingMode: .greedy)
                )
                if let e = r.content.extraction(engine: .onDevice) { return e }
            } catch {
                print("Modèle local indisponible : \(error)")
            }
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
@Generable
struct AIReceipt {
    @Guide(description: "Les articles consommés, dans l'ordre du ticket, une entrée par ligne d'article.")
    var articles: [AIArticle]

    @Guide(description: "Le montant total à payer imprimé sur le ticket, en euros. 0 s'il n'apparaît pas.")
    var total: Double

    func extraction(engine: ReadingEngine) -> ReceiptAI.Extraction? {
        let items = articles.compactMap { a -> ParsedItem? in
            let name = a.nom.trimmed
            guard !name.isEmpty else { return nil }
            return ParsedItem(name: name, quantity: min(99, max(1, a.quantite)), cents: Money.cents(a.prixLigne))
        }
        guard !items.isEmpty else { return nil }
        return .init(items: items, totalCents: total > 0 ? Money.cents(total) : nil, engine: engine)
    }
}

@Generable
struct AIArticle {
    @Guide(description: "Le nom de l'article tel qu'écrit sur le ticket, sans la quantité ni le prix. Corrige les fautes de lecture évidentes.")
    var nom: String

    @Guide(description: "Le nombre d'unités sur la ligne, 1 si rien n'est indiqué.", .range(1...99))
    var quantite: Int

    @Guide(description: "Le prix total de la ligne en euros, pour toutes les unités. Négatif pour une remise.")
    var prixLigne: Double
}
#endif
