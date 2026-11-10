import SwiftUI
import Observation

/// L'état de l'app, sauvegardé à chaque changement (comme le localStorage de la web app).
@MainActor
@Observable
final class BillStore {
    private static let key = "splitthebill.bill.v1"
    private static let recentKey = "splitthebill.recent"

    var bill: Bill { didSet { save() } }
    /// Direction de la dernière navigation, pour l'animation de glissement.
    var forward = true
    var reading: ReadingState?
    var toast: String?

    enum ReadingState: Equatable {
        case ocr, ai(String), done(Int)
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(Bill.self, from: data) {
            bill = saved
            if !bill.canEnter(bill.step) { bill.step = .ticket }
        } else {
            bill = Bill()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(bill) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    // MARK: Navigation

    func go(_ step: Step) {
        guard step != bill.step, bill.canEnter(step) else { return }
        forward = step.rawValue > bill.step.rawValue
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            bill.step = step
            if step.rawValue > bill.maxStep.rawValue { bill.maxStep = step }
        }
        if step == .result { rememberPeople() }
    }

    func back() {
        guard let prev = Step(rawValue: bill.step.rawValue - 1) else { return }
        go(prev)
    }

    func reset() {
        forward = false
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { bill = Bill() }
        show("Nouvelle addition")
    }

    func show(_ message: String) {
        withAnimation(.snappy) { toast = message }
        let current = message
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            if toast == current { withAnimation(.snappy) { toast = nil } }
        }
    }

    // MARK: Lecture du ticket

    /// Photo → Vision (texte) → Apple Intelligence (articles), avec repli sur la lecture classique.
    func read(image: UIImage) async {
        withAnimation { reading = .ocr }
        do {
            let text = try await ReceiptOCR.recognize(image)
            bill.rawText = text
            await analyze(text: text, fromPhoto: true)
        } catch {
            withAnimation { reading = nil }
            show("La lecture a échoué. Reprends une photo plus nette.")
        }
    }

    /// Texte → articles. Utilisé après une photo, ou pour un texte collé.
    ///
    /// La lecture de la web app (`TicketParser`) passe en premier : elle est exacte et prévisible
    /// sur un texte propre. L'IA ne prend la main que si cette lecture ne trouve rien, ou si,
    /// sur une photo, ses articles ne retombent pas sur le total du ticket.
    func analyze(text: String, fromPhoto: Bool = false) async {
        let text = text.trimmed
        guard !text.isEmpty else { show("Colle d’abord le texte du ticket."); return }
        bill.rawText = text

        let classic = TicketParser.parse(text, unitPrices: bill.unitPrices)
        var items = classic.items
        var total = classic.totalCents
        var engine = ReadingEngine.classic

        let printedTotal = classic.totalCents
        func matchesTotal(_ list: [ParsedItem]) -> Bool {
            guard let printedTotal, !list.isEmpty else { return false }
            return list.reduce(0) { $0 + $1.cents } == printedTotal
        }

        let classicIsEnough = fromPhoto ? matchesTotal(classic.items) : !classic.items.isEmpty
        if classicIsEnough {
            withAnimation { reading = .ai("Lecture du ticket") }
        } else {
            withAnimation { reading = .ai(ReceiptAI.statusLabel) }
            if let ai = await ReceiptAI.extract(from: text) {
                // On garde l'IA si elle retombe sur le total, si la lecture classique n'a rien trouvé,
                // ou si c'est le modèle cloud (plus fiable que les règles sur une photo abîmée).
                if classic.items.isEmpty || matchesTotal(ai.items) || ai.engine == .privateCloud {
                    items = ai.items
                    engine = ai.engine
                    if total == nil { total = ai.totalCents }
                }
            }
        }

        withAnimation { reading = .done(items.count) }
        try? await Task.sleep(for: .milliseconds(900))
        bill.setItems(items, total: total, engine: engine)
        withAnimation { reading = nil }
        if items.isEmpty { show("Aucun article reconnu. Saisis-les à la main.") }
        go(.items)
    }

    /// Démarrer sans ticket : une ligne vide à remplir.
    func startManually() {
        bill.setItems([], total: nil, engine: .manual)
        go(.items)
    }

    // MARK: Participants récents

    var recentNames: [String] {
        (UserDefaults.standard.stringArray(forKey: Self.recentKey) ?? [])
            .filter { !bill.hasPerson(named: $0) }
            .prefix(6)
            .map { $0 }
    }

    private func rememberPeople() {
        var names = bill.people.map(\.name)
        for n in UserDefaults.standard.stringArray(forKey: Self.recentKey) ?? [] where !names.contains(n) {
            names.append(n)
        }
        UserDefaults.standard.set(Array(names.prefix(12)), forKey: Self.recentKey)
    }

    // MARK: Lien depuis le raccourci iPhone : splitthebill://ticket?t=…

    func handle(url: URL) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let t = comps.queryItems?.first(where: { $0.name == "t" })?.value, !t.trimmed.isEmpty else { return }
        bill = Bill()
        Task { await analyze(text: t) }
    }
}
