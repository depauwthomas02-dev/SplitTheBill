import Foundation

/// Une ligne du détail d'une personne : « 1/3 · Pizza 4,17 € ».
struct ShareLine: Equatable, Sendable {
    var item: BillItem
    var shares: Int
    var denominator: Int
    /// Montant exact (non arrondi), en centimes.
    var value: Double

    var label: String {
        let q = item.quantity > 1 ? "\(item.quantity)× " : ""
        let name = item.name.isEmpty ? "Article" : item.name
        if shares == denominator { return q + name }
        if item.quantity > 1 && denominator == item.quantity { return "\(shares)× \(name)" }
        let g = gcd(shares, denominator)
        return "\(shares / g)/\(denominator / g) · \(q)\(name)"
    }
}

struct SplitResult: Equatable, Sendable {
    /// Ce que chacun doit, arrondi au centime. La somme tombe exactement sur `totalCents`.
    var owed: [Int: Int]
    var details: [Int: [ShareLine]]
    /// Part des frais de chacun (centimes, non arrondie).
    var extras: [Int: Double]
    var totalCents: Int
    var extraCents: Int
}

enum SplitCalculator {
    /// Même algorithme que `calc()` de la web app : partage au prorata des parts,
    /// frais répartis au prorata de ce que chacun a pris, puis arrondi « plus grand reste »
    /// pour que la somme des parts tombe pile sur le total.
    static func compute(_ bill: Bill) -> SplitResult {
        let people = bill.people
        var sub: [Int: Double] = [:]
        var det: [Int: [ShareLine]] = [:]
        for p in people { sub[p.id] = 0; det[p.id] = [] }

        for item in bill.items {
            let t = bill.denominator(item)
            guard t > 0 else { continue }
            for p in people {
                let k = bill.shares(item, p)
                guard k > 0 else { continue }
                let v = Double(item.cents) * Double(k) / Double(t)
                sub[p.id, default: 0] += v
                det[p.id, default: []].append(ShareLine(item: item, shares: k, denominator: t, value: v))
            }
        }

        let ex = Double(bill.extraCents)
        let base = people.reduce(0.0) { $0 + (sub[$1.id] ?? 0) }
        var extras: [Int: Double] = [:]
        var raw: [Int: Double] = [:]
        for p in people {
            let s = sub[p.id] ?? 0
            extras[p.id] = base != 0 ? ex * s / base : (people.isEmpty ? 0 : ex / Double(people.count))
            raw[p.id] = s + (extras[p.id] ?? 0)
        }

        let target = Int((base + ex).rounded())
        var cents: [Int: Int] = [:]
        var acc = 0
        var rem: [(id: Int, f: Double)] = []
        for p in people {
            let r = raw[p.id] ?? 0
            let c = Int((r + 1e-6).rounded(.down))
            cents[p.id] = c
            acc += c
            rem.append((p.id, r - Double(c)))
        }
        rem.sort { $0.f > $1.f }
        var i = 0
        while acc < target && !rem.isEmpty && i < rem.count * 4 {
            cents[rem[i % rem.count].id, default: 0] += 1
            acc += 1
            i += 1
        }
        return SplitResult(owed: cents, details: det, extras: extras, totalCents: target, extraCents: bill.extraCents)
    }

    /// Texte à partager dans Messages / WhatsApp.
    static func recap(_ bill: Bill, _ r: SplitResult) -> String {
        let lines = bill.people.map { "• \($0.name) : \(Money.eur(r.owed[$0.id] ?? 0))" }.joined(separator: "\n")
        return "SplitTheBill · l’addition\n\n\(lines)\n\nTotal : \(Money.eur(r.totalCents))"
    }
}

func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
