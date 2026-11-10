import Foundation

/// Toute l'app compte en centimes (Int) pour éviter les erreurs d'arrondi des Double.
enum Money {
    /// Équivalent de `num()` de la version web : « 12,50 », « 12.50 », « 1 234,00 » → 12.5
    static func parse(_ text: String) -> Double {
        let compact = text.filter { !$0.isWhitespace }
        guard let comma = compact.firstIndex(of: ",") else { return Double(prefixNumber(compact)) ?? 0 }
        var s = compact
        s.replaceSubrange(comma...comma, with: ".")
        return Double(prefixNumber(s)) ?? 0
    }

    /// Texte saisi → centimes.
    static func cents(_ text: String) -> Int { cents(parse(text)) }

    static func cents(_ value: Double) -> Int { Int((value * 100).rounded()) }

    /// 1234 → « 12,34 € » (espace fine pour les milliers, comme la version web).
    static func eur(_ cents: Int) -> String {
        let negative = cents < 0
        let a = abs(cents)
        let units = String(a / 100)
        var grouped = ""
        for (i, ch) in units.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { grouped.append(" ") }
            grouped.append(ch)
        }
        let s = String(grouped.reversed()) + "," + String(format: "%02d", a % 100) + " €"
        return negative ? "−" + s : s
    }

    static func eur(_ value: Double) -> String { eur(cents(value)) }

    /// Valeur pour un champ de saisie : 1250 → « 12,50 », 0 → « ».
    static func input(_ cents: Int) -> String {
        guard cents != 0 else { return "" }
        let a = abs(cents)
        return (cents < 0 ? "-" : "") + "\(a / 100)," + String(format: "%02d", a % 100)
    }

    /// parseFloat lit le plus long préfixe numérique ; on imite ce comportement.
    private static func prefixNumber(_ s: String) -> String {
        var out = ""
        var seenDot = false
        for (i, ch) in s.enumerated() {
            if ch == "-" && i == 0 { out.append(ch); continue }
            if ch == "." && !seenDot { seenDot = true; out.append(ch); continue }
            if ch.isASCII && ch.isNumber { out.append(ch); continue }
            break
        }
        return out
    }
}
