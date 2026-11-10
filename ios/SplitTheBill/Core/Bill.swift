import Foundation

struct BillItem: Identifiable, Codable, Equatable, Sendable {
    var id: Int
    var name: String
    var quantity: Int
    /// Prix de la ligne entière, en centimes.
    var cents: Int
}

struct Person: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: Int
    var name: String
    var color: Int
}

enum Step: Int, Codable, CaseIterable, Sendable {
    case ticket, items, people, assign, result

    var title: String {
        switch self {
        case .ticket: "Ticket"
        case .items: "Articles"
        case .people: "Participants"
        case .assign: "Attribution"
        case .result: "Résultat"
        }
    }
}

/// D'où viennent les articles : utile pour l'afficher et pour savoir quoi vérifier.
enum ReadingEngine: String, Codable, Sendable {
    case privateCloud, onDevice, classic, manual

    var label: String {
        switch self {
        case .privateCloud: "Lu par Apple Intelligence · Private Cloud Compute"
        case .onDevice: "Lu par Apple Intelligence · sur l’iPhone"
        case .classic: "Lecture exacte du ticket"
        case .manual: "Saisi à la main"
        }
    }
}

/// L'état complet d'une addition. Même modèle que `S` dans la web app.
struct Bill: Codable, Equatable, Sendable {
    var step: Step = .ticket
    var maxStep: Step = .ticket
    var rawText: String = ""
    var unitPrices = false
    var items: [BillItem] = []
    /// Pourboire / frais, tels que saisis.
    var extraText: String = ""
    /// Total imprimé sur le ticket, tel que saisi (vide si inconnu).
    var ticketTotalText: String = ""
    var people: [Person] = []
    /// assignments[itemID][personID] = nombre de parts (ou d'unités pour un article en plusieurs exemplaires).
    var assignments: [Int: [Int: Int]] = [:]
    var seq = 1
    var engine: ReadingEngine?

    mutating func nextID() -> Int { defer { seq += 1 }; return seq }

    var extraCents: Int { Money.cents(extraText) }
    var ticketTotalCents: Int? { ticketTotalText.trimmed.isEmpty ? nil : Money.cents(ticketTotalText) }
    var itemsCents: Int { items.reduce(0) { $0 + $1.cents } }

    // MARK: Articles

    mutating func setItems(_ parsed: [ParsedItem], total: Int?, engine: ReadingEngine) {
        items = parsed.map { BillItem(id: nextID(), name: $0.name, quantity: $0.quantity, cents: $0.cents) }
        if items.isEmpty { items.append(BillItem(id: nextID(), name: "", quantity: 1, cents: 0)) }
        assignments = [:]
        ticketTotalText = total.map(Money.input) ?? ""
        self.engine = engine
        maxStep = .items
    }

    @discardableResult
    mutating func addItem() -> Int {
        let id = nextID()
        items.append(BillItem(id: id, name: "", quantity: 1, cents: 0))
        return id
    }

    mutating func removeItem(_ id: Int) {
        items.removeAll { $0.id == id }
        assignments[id] = nil
    }

    /// Retire les lignes vides avant de passer à la suite.
    mutating func dropEmptyItems() {
        items.removeAll { $0.name.trimmed.isEmpty && $0.cents == 0 }
        for i in items.indices where items[i].name.trimmed.isEmpty { items[i].name = "Article" }
    }

    /// Écart entre le ticket et la somme saisie : > 0 s'il manque de l'argent.
    var gapCents: Int? { ticketTotalCents.map { $0 - itemsCents - extraCents } }

    mutating func addGapAsExtra() {
        guard let gap = gapCents, gap > 0 else { return }
        extraText = Money.input(extraCents + gap)
    }

    // MARK: Participants

    @discardableResult
    mutating func addPerson(_ raw: String) -> Person? {
        let name = raw.trimmed.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        guard !name.isEmpty, !hasPerson(named: name) else { return nil }
        let used = Set(people.map(\.color))
        let color = (0..<Palette.count).first { !used.contains($0) } ?? people.count % Palette.count
        let p = Person(id: nextID(), name: name, color: color)
        people.append(p)
        return p
    }

    func hasPerson(named name: String) -> Bool {
        people.contains { $0.name.lowercased() == name.lowercased() }
    }

    mutating func removePerson(_ id: Int) {
        people.removeAll { $0.id == id }
        for k in assignments.keys { assignments[k]?[id] = nil }
    }

    // MARK: Attribution (mêmes règles que la web app)

    func shares(_ item: BillItem, _ person: Person) -> Int { assignments[item.id]?[person.id] ?? 0 }

    func parts(_ item: BillItem) -> Int { people.reduce(0) { $0 + shares(item, $1) } }

    func everyoneSelected(_ item: BillItem) -> Bool {
        !people.isEmpty && people.allSatisfy { shares(item, $0) > 0 }
    }

    /// Article en plusieurs unités : chaque toucher compte une unité (prix ÷ quantité).
    /// Il reste « à attribuer » tant que toutes les unités ne sont pas prises,
    /// sauf si toute la table est cochée : on partage alors au prorata.
    func isPartial(_ item: BillItem) -> Bool {
        let t = parts(item)
        return item.quantity > 1 && t > 0 && t < item.quantity && !everyoneSelected(item)
    }

    func isComplete(_ item: BillItem) -> Bool { parts(item) > 0 && !isPartial(item) }

    func denominator(_ item: BillItem) -> Int { isPartial(item) ? item.quantity : parts(item) }

    var unassignedCount: Int { items.filter { !isComplete($0) }.count }

    mutating func tap(_ item: BillItem, _ person: Person) {
        var a = assignments[item.id] ?? [:]
        a[person.id] = min(99, (a[person.id] ?? 0) + 1)
        assignments[item.id] = a
    }

    mutating func minus(_ item: BillItem, _ person: Person) {
        var a = assignments[item.id] ?? [:]
        a[person.id] = max(0, (a[person.id] ?? 0) - 1)
        assignments[item.id] = a
    }

    mutating func toggleEveryone(_ item: BillItem) {
        let allOn = everyoneSelected(item)
        var a = assignments[item.id] ?? [:]
        for p in people { a[p.id] = allOn ? 0 : 1 }
        assignments[item.id] = a
    }

    mutating func clear(_ item: BillItem) { assignments[item.id] = [:] }

    /// Le petit texte sous chaque article dans l'étape d'attribution.
    func assignSummary(_ item: BillItem) -> String {
        let t = parts(item)
        let who = people.filter { shares(item, $0) > 0 }
        if t == 0 {
            return item.quantity > 1 ? "Touche une fois par unité prise, − pour corriger" : "Qui l’a pris ? Touche 2 fois pour 2 parts"
        }
        if isPartial(item) {
            let left = item.quantity - t
            return (who.map { "\($0.name) \(shares(item, $0))" } + ["Reste \(left) sur \(item.quantity) (\(Money.eur(Double(left * item.cents) / Double(item.quantity) / 100)))"]).joined(separator: " · ")
        }
        if who.count == 1 { return "Pour \(who[0].name)" }
        if who.allSatisfy({ shares(item, $0) == shares(item, who[0]) }) {
            return "Partagé à \(who.count) · \(Money.eur(Double(item.cents) / Double(who.count) / 100)) chacun"
        }
        if item.quantity > 1 && t == item.quantity {
            return who.map { "\($0.name) \(shares(item, $0))" }.joined(separator: " · ")
        }
        return who.map { "\($0.name) \(shares(item, $0))/\(t)" }.joined(separator: " · ")
    }

    // MARK: Navigation

    func canEnter(_ s: Step) -> Bool {
        switch s {
        case .ticket: true
        case .items: !items.isEmpty
        case .people: !items.isEmpty
        case .assign: !items.isEmpty && people.count >= 2
        case .result: !items.isEmpty && people.count >= 2 && unassignedCount == 0
        }
    }
}

enum Palette {
    static let count = 10
}
