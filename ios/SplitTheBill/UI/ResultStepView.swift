import SwiftUI

/// Étape 5 : chacun sa part.
struct ResultStepView: View {
    @Environment(BillStore.self) private var store
    @State private var shown = false
    @State private var open: Set<Int> = []
    @State private var confetti = 0

    var body: some View {
        let bill = store.bill
        let r = SplitCalculator.compute(bill)
        let ticket = bill.ticketTotalCents
        let ok = ticket == nil || ticket == r.totalCents
        let recap = SplitCalculator.recap(bill, r)

        ScrollView {
            VStack(spacing: 16) {
                StepHeader(step: .result, title: "Chacun sa part.", subtitle: "Touche une personne pour voir le détail de ce qu’elle doit.")

                VStack(alignment: .leading, spacing: 14) {
                    Text("TOTAL").font(Theme.mono(12, weight: .bold)).kerning(1.6).foregroundStyle(.white.opacity(0.7))
                    Text(Money.eur(shown ? r.totalCents : 0))
                        .font(Theme.display(56))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(value: Double(shown ? r.totalCents : 0)))
                    GeometryReader { g in
                        HStack(spacing: 3) {
                            ForEach(bill.people) { p in
                                let w = r.totalCents > 0 ? CGFloat(max(0, r.owed[p.id] ?? 0)) / CGFloat(r.totalCents) : 1 / CGFloat(max(1, bill.people.count))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.avatar(p).bg)
                                    .frame(width: max(0, (g.size.width - CGFloat(bill.people.count - 1) * 3) * (shown ? w : 0)))
                            }
                        }
                    }
                    .frame(height: 12)
                    FlowLegend(people: bill.people)
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(ok ? Theme.soft : Color(hex: 0xffd27d))
                        if ok {
                            Text("**Réparti au centime près**\(ticket != nil ? ", conforme au ticket." : ".")")
                        } else if let ticket {
                            Text("Le ticket indique **\(Money.eur(ticket))**, soit \(Money.eur(ticket - r.totalCents)) d’écart. Ajoute-le en frais à l’étape 2.")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.bordeaux, in: .rect(cornerRadius: 24))

                ForEach(Array(bill.people.enumerated()), id: \.element.id) { i, p in
                    PersonResult(person: p, result: r, shown: shown, isOpen: open.contains(p.id)) {
                        withAnimation(.snappy) {
                            if open.contains(p.id) { open.remove(p.id) } else { open.insert(p.id) }
                        }
                    }
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown ? 0 : 16)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25 + Double(i) * 0.08), value: shown)
                }

                HStack(spacing: 10) {
                    shareChip(title: "WhatsApp", icon: "bubble.left.and.bubble.right.fill",
                              url: URL(string: "https://wa.me/?text=" + (recap.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")))
                    shareChip(title: "Messages", icon: "message.fill",
                              url: URL(string: "sms:&body=" + (recap.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")))
                    Button {
                        UIPasteboard.general.string = recap
                        store.show("Récap copié")
                    } label: {
                        chip("Copier", "doc.on.doc.fill")
                    }
                }
                .foregroundStyle(Theme.ink)
            }
            .padding(16)
        }

        .safeAreaBar(edge: .bottom) {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    DockBackButton()
                    ShareLink(item: recap, subject: Text("SplitTheBill"), preview: SharePreview("SplitTheBill · l’addition")) {
                        DockLabel(text: "Partager le récap", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)
        }
        .overlay { ConfettiView(trigger: confetti).allowsHitTesting(false).ignoresSafeArea() }
        .sensoryFeedback(.success, trigger: confetti)
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(response: 1.0, dampingFraction: 0.9)) { shown = true }
            if ok {
                try? await Task.sleep(for: .milliseconds(300))
                confetti += 1
            }
        }
    }

    private func chip(_ title: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold))
            Text(title).font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(Theme.card, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line))
    }

    @ViewBuilder
    private func shareChip(title: String, icon: String, url: URL?) -> some View {
        if let url {
            Link(destination: url) { chip(title, icon) }
        }
    }
}

private struct FlowLegend: View {
    var people: [Person]
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(people) { p in
                    HStack(spacing: 5) {
                        Circle().fill(Theme.avatar(p).bg).frame(width: 9, height: 9)
                        Text(p.name).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityHidden(true)
    }
}

private struct PersonResult: View {
    var person: Person
    var result: SplitResult
    var shown: Bool
    var isOpen: Bool
    var toggle: () -> Void

    var body: some View {
        let lines = result.details[person.id] ?? []
        let extra = result.extras[person.id] ?? 0
        let owed = result.owed[person.id] ?? 0
        VStack(spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: 12) {
                    Avatar(person: person, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.name).font(.system(size: 17, weight: .bold))
                        Text("\(lines.count) article\(lines.count > 1 ? "s" : "")\(abs(extra) >= 0.5 ? " + frais" : "")")
                            .font(.caption).foregroundStyle(Theme.mute)
                    }
                    Spacer()
                    Text(Money.eur(shown ? owed : 0))
                        .font(.system(size: 22, weight: .heavy).monospacedDigit())
                        .contentTransition(.numericText(value: Double(shown ? owed : 0)))
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                        .foregroundStyle(Theme.mute)
                }
                .contentShape(.rect)
            }
            .foregroundStyle(Theme.ink)
            .accessibilityHint(isOpen ? "Masquer le détail" : "Voir le détail")

            if isOpen {
                VStack(spacing: 8) {
                    Divider().padding(.vertical, 6)
                    if lines.isEmpty {
                        row("Aucun article", 0)
                    }
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, l in
                        row(l.label, l.value)
                    }
                    if abs(extra) >= 0.5 { row("Pourboire et frais", extra) }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .card()
        .sensoryFeedback(.selection, trigger: isOpen)
    }

    private func row(_ label: String, _ cents: Double) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text(Money.eur(cents / 100)).font(.subheadline.weight(.semibold).monospacedDigit())
        }
    }
}

/// Petite pluie de confettis aux couleurs Spritz, quand tout tombe juste.
struct ConfettiView: View {
    var trigger: Int
    @State private var start: Date?

    private static let colors: [Color] = [0xff6a2b, 0x3a0f12, 0xffb37d, 0xf2b52e, 0xffc7e4, 0xbfe3ff, 0xffdf9e, 0xd9ccff].map { Color(hex: $0) }

    private struct Piece {
        var x0: Double, vx: Double, vy: Double, g: Double, w: Double, h: Double, spin: Double, color: Color, round: Bool
    }

    @State private var pieces: [Piece] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { tl in
            Canvas { ctx, size in
                guard let start else { return }
                let t = tl.date.timeIntervalSince(start) * 60
                let alpha = max(0, 1 - max(0, t - 120) / 54)
                for p in pieces {
                    let x = (p.x0 < 0.5 ? -10 : size.width + 10) + p.vx * t
                    let y = size.height * 0.62 + p.vy * t + 0.5 * p.g * t * t
                    var c = ctx
                    c.opacity = alpha
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(p.spin * t))
                    let rect = CGRect(x: -p.w / 2, y: -p.h / 2, width: p.w, height: p.h * abs(cos(p.spin * t * 1.7)) + 1)
                    c.fill(p.round ? Path(ellipseIn: CGRect(x: -p.w / 2, y: -p.w / 2, width: p.w, height: p.w)) : Path(rect), with: .color(p.color))
                }
            }
        }
        .onChange(of: trigger) {
            guard !reduceMotion else { return }
            pieces = (0..<150).map { i in
                let side = Double(i % 2)
                return Piece(x0: side, vx: (side == 1 ? -1 : 1) * Double.random(in: 3...11), vy: -Double.random(in: 9...19),
                             g: Double.random(in: 0.24...0.36), w: Double.random(in: 6...12), h: Double.random(in: 9...18),
                             spin: Double.random(in: -0.17...0.17), color: Self.colors[i % Self.colors.count], round: Double.random(in: 0...1) < 0.3)
            }
            start = .now
            Task {
                try? await Task.sleep(for: .seconds(3.2))
                start = nil
                pieces = []
            }
        }
    }
}
