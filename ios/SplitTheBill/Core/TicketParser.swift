import Foundation

/// Lecture « classique » d'un ticket en texte : portage fidèle de `parseTicket` et `cleanOcr`
/// de la web app. Sert de secours quand Apple Intelligence n'est pas disponible, et pour
/// le texte collé à la main.
struct ParsedItem: Equatable, Sendable {
    var name: String
    var quantity: Int
    /// Prix de la ligne entière, en centimes.
    var cents: Int
}

enum LineKind: Equatable, Sendable { case blank, item, total, skip }

struct ParsedLine: Equatable, Sendable {
    var text: String
    var kind: LineKind
}

struct ParsedTicket: Equatable, Sendable {
    var items: [ParsedItem]
    var lines: [ParsedLine]
    var totalCents: Int?
}

enum TicketParser {
    static let skip = #"^(sous[- ]?total|total|tva|btw|tax|bancontact|visa|mastercard|carte|cash|esp[eè]ces|rendu|monnaie|à payer|a payer|montant|table|merci|date|heure|cb\b|c\.b\.|paiement|r[eè]glement|sans contact|ticket[s]? resto|titre[s]? resto|avoir|siret|t[eé]l\b|n°)"#

    /// - Parameter unitPrices: `true` si le ticket affiche le prix à l'unité (« 2 Spritz 8,50 » = 17 €).
    static func parse(_ text: String, unitPrices: Bool) -> ParsedTicket {
        var items: [ParsedItem] = []
        var lines: [ParsedLine] = []
        var total: Int?

        func classify(_ orig: String) -> LineKind {
            var l = orig.trimmingCharacters(in: .whitespacesAndNewlines)
            l = Rx.replace(#"^[-•*·]\s*"#, in: l, with: "")
            l = l.replacingOccurrences(of: "**", with: "")
            if l.isEmpty { return .blank }

            // « Spritz x2 8,50 » / « Spritz - 2 x 8,50 = 17,00 » : quantité × prix unitaire explicite
            if let um = Rx.match(#"^(.*?)[\s:–-]+(\d{1,2})\s*[xX×]\s*(\d+[.,]\d{2})\s*(?:€|eur)?\s*(?:[=→]\s*\d+[.,]\d{2}\s*(?:€|eur)?)?$"#, l),
               let n = um[1], !n.isEmpty, !Rx.test(skip, n) {
                let q = max(1, Int(um[2] ?? "1") ?? 1)
                items.append(ParsedItem(name: n.trimmed, quantity: q, cents: Money.cents(Money.parse(um[3] ?? "0") * Double(q))))
                return .item
            }

            guard let m = Rx.match(#"^(.*?)\s*(-?\d+[.,]\d{2})\s*(?:€|eur)?\s*[A-Z]?$"#, l) else { return .skip }
            var name = Rx.replace(#"[.\s:|–-]+$"#, in: (m[1] ?? "").trimmed, with: "")
            var cents = Money.cents(m[2] ?? "0")

            if Rx.test(#"^(total|à payer|a payer|montant)"#, name) {
                if total == nil || cents > total! { total = cents }
                return .total
            }
            if name.isEmpty || Rx.test(skip, name) { return .skip }

            var q = 1
            var lineTotalGiven = false
            if let eq = Rx.match(#"^(.*?)\s*\d+[.,]\d{2}\s*(?:€|eur)?\s*[=→]$"#, name), let e = eq[1], !e.isEmpty {
                name = e.trimmed
                lineTotalGiven = true
            }
            if let qm = Rx.match(#"^(\d{1,2})\s*[xX×]\s*(.+)$"#, name) ?? Rx.match(#"^(\d{1,2})\s+(.+)$"#, name) {
                q = Int(qm[1] ?? "1") ?? 1
                name = qm[2] ?? name
            } else if let tm = Rx.match(#"^(.*?)[\s(–-]*[xX×]\s*(\d{1,2})\)?$"#, name), let t = tm[1], !t.isEmpty {
                name = t.trimmed
                q = Int(tm[2] ?? "1") ?? 1
            }
            q = max(1, q)
            if !lineTotalGiven && unitPrices { cents *= q }
            name = Rx.replace(#"[\s:–-]+$"#, in: name, with: "")
            items.append(ParsedItem(name: name, quantity: q, cents: cents))
            return .item
        }

        for orig in text.components(separatedBy: "\n") {
            lines.append(ParsedLine(text: orig, kind: classify(orig)))
        }
        while let last = lines.last, last.kind == .blank { lines.removeLast() }
        return ParsedTicket(items: items, lines: lines, totalCents: total)
    }

    /// Corrige les erreurs de lecture courantes sur les prix (O à la place de 0, espace à la place de la virgule…)
    static func cleanOCR(_ text: String) -> String {
        text.components(separatedBy: "\n").map { line -> String in
            var l = Rx.replace(#"[|_~«»“”]"#, in: line, with: " ")
            l = Rx.replace(#"\s+"#, in: l, with: " ").trimmed
            l = Rx.replace(#"(\d)[oO](?=\d|\b)"#, in: l, with: "$1\\0")
            l = Rx.replace(#"\b[oO](?=[.,]\d)"#, in: l, with: "0")
            l = Rx.replaceFirst(#"([A-Za-zÀ-ÿ].*?\s)(\d{1,4})\s?[.,'`]\s?(\d)\s?(\d)\s*(?:€|EUR|E)?\s*$"#, in: l, with: "$1$2,$3$4")
            l = Rx.replaceFirst(#"([A-Za-zÀ-ÿ].*?\s)(\d{1,4}) (\d{2})\s*(?:€|EUR)?\s*$"#, in: l, with: "$1$2,$3")
            return l
        }
        .filter { $0.count > 1 }
        .joined(separator: "\n")
    }

    static let demo = """
    TRATTORIA DA LUCA
    Table 12 - 4 couverts
    22/10 20:41

    Pizza Margherita 12,50
    2 Spritz 17,00
    Burrata 11,00
    3 x Bière pression 13,50
    Tiramisu 7,50
    Café 2,80

    TVA 10% 5,85
    TOTAL 64,30
    Merci de votre visite
    """
}

// MARK: - Petites aides regex (insensibles à la casse, comme le drapeau /i de la version web)

enum Rx {
    nonisolated(unsafe) private static var cache: [String: NSRegularExpression] = [:]
    private static let lock = NSLock()

    static func re(_ pattern: String) -> NSRegularExpression {
        lock.lock(); defer { lock.unlock() }
        if let r = cache[pattern] { return r }
        // Toutes les regex de ce fichier sont des constantes : un échec est une erreur de programmation.
        let r = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        cache[pattern] = r
        return r
    }

    static func test(_ pattern: String, _ s: String) -> Bool {
        re(pattern).firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    /// Groupes capturés (index 0 = correspondance entière), `nil` si pas de correspondance.
    static func match(_ pattern: String, _ s: String) -> [String?]? {
        guard let m = re(pattern).firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            let r = m.range(at: i)
            guard r.location != NSNotFound, let range = Range(r, in: s) else { return nil }
            return String(s[range])
        }
    }

    static func replace(_ pattern: String, in s: String, with template: String) -> String {
        re(pattern).stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
    }

    static func replaceFirst(_ pattern: String, in s: String, with template: String) -> String {
        let r = re(pattern)
        guard let m = r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let range = Range(m.range, in: s) else { return s }
        let rep = r.replacementString(for: m, in: s, offset: 0, template: template)
        var out = s
        out.replaceSubrange(range, with: rep)
        return out
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
