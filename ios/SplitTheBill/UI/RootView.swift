import SwiftUI

/// Une étape à l'écran, l'action principale collée au pouce (comme la web app).
struct RootView: View {
    @Environment(BillStore.self) private var store
    @State private var confirmReset = false

    var body: some View {
        ZStack(alignment: .top) {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ZStack {
                    stepView
                        .id(store.bill.step)
                        .transition(.asymmetric(
                            insertion: .move(edge: store.forward ? .trailing : .leading).combined(with: .opacity),
                            removal: .move(edge: store.forward ? .leading : .trailing).combined(with: .opacity)
                        ))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }

            if let reading = store.reading {
                ReadingOverlay(state: reading)
                    .transition(.opacity)
            }

            if let toast = store.toast {
                Text(toast)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.buttonInk)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Theme.button, in: .capsule)
                    .shadow(radius: 12, y: 6)
                    .padding(.top, 64)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .tint(Theme.orange)
        .foregroundStyle(Theme.ink)
        .confirmationDialog("Tout effacer et recommencer ?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Nouvelle addition", role: .destructive) { store.reset() }
        }
    }

    @ViewBuilder private var stepView: some View {
        switch store.bill.step {
        case .ticket: TicketStepView()
        case .items: ItemsStepView()
        case .people: PeopleStepView()
        case .assign: AssignStepView()
        case .result: ResultStepView()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "receipt")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.soft)
                    .frame(width: 30, height: 30)
                    .background(Theme.bordeaux, in: .rect(cornerRadius: 9))
                Text("Split\(Text("The").italic().foregroundStyle(Theme.orange))Bill")
                    .font(.system(size: 17, weight: .heavy))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("SplitTheBill")

            Spacer()

            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { s in
                    let reached = s.rawValue <= store.bill.step.rawValue
                    Button {
                        store.go(s)
                    } label: {
                        Capsule()
                            .fill(reached ? Theme.orange : Theme.line)
                            .frame(width: s == store.bill.step ? 20 : 8, height: 8)
                    }
                    .disabled(s == store.bill.step || s.rawValue > store.bill.maxStep.rawValue || !store.bill.canEnter(s))
                    .accessibilityLabel("Étape \(s.rawValue + 1) : \(s.title)")
                }
            }
            .animation(.snappy, value: store.bill.step)

            Button {
                confirmReset = true
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(Theme.card, in: .circle)
                    .overlay(Circle().stroke(Theme.line))
            }
            .accessibilityLabel("Recommencer")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

/// Bas d'écran commun : retour + bouton principal.
struct Dock<Leading: View>: View {
    @Environment(BillStore.self) private var store
    var label: String
    var systemImage: String?
    var disabled = false
    var action: () -> Void
    @ViewBuilder var leading: () -> Leading

    var body: some View {
        HStack(spacing: 10) {
            if store.bill.step != .ticket {
                Button { store.back() } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 19, weight: .bold))
                        .frame(width: 56, height: 56)
                        .background(Theme.card, in: .rect(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line))
                }
                .accessibilityLabel("Étape précédente")
            }
            leading()
            Button(action: action) {
                HStack(spacing: 8) {
                    Text(label).contentTransition(.opacity)
                    if let systemImage { Image(systemName: systemImage) }
                }
                .font(.system(size: 17, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(Theme.buttonInk)
                .background(disabled ? Theme.mute.opacity(0.45) : Theme.button, in: .rect(cornerRadius: 18))
            }
            .disabled(disabled)
            .sensoryFeedback(.impact(weight: .light), trigger: label)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
        .animation(.snappy, value: label)
        .animation(.snappy, value: disabled)
    }
}

extension Dock where Leading == EmptyView {
    init(label: String, systemImage: String? = nil, disabled: Bool = false, action: @escaping () -> Void) {
        self.init(label: label, systemImage: systemImage, disabled: disabled, action: action) { EmptyView() }
    }
}

/// Titre d'étape : « Étape 2 sur 5 » + grand titre + explication.
struct StepHeader: View {
    var step: Step
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Étape \(step.rawValue + 1) sur 5")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.orange)
            Text(title)
                .font(Theme.display(36))
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.mute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Pendant la lecture du ticket.
struct ReadingOverlay: View {
    var state: BillStore.ReadingState

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 18) {
                Group {
                    if case .done = state {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.ok)
                    } else if case .ai = state {
                        Image(systemName: "apple.intelligence")
                            .symbolEffect(.pulse)
                            .foregroundStyle(LinearGradient(colors: [Theme.orange, .pink, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    } else {
                        Image(systemName: "text.viewfinder").symbolEffect(.pulse).foregroundStyle(Theme.orange)
                    }
                }
                .font(.system(size: 54))
                .contentTransition(.symbolEffect(.replace))

                Text(title).font(Theme.display(28))
                Text(detail).font(.subheadline).foregroundStyle(Theme.mute).multilineTextAlignment(.center)
            }
            .padding(32)
            .card()
            .padding(32)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch state {
        case .ocr: "Lecture du ticket…"
        case .ai: "Analyse des articles…"
        case .done(let n): n == 0 ? "Rien trouvé" : "\(n) article\(n > 1 ? "s" : "") trouvé\(n > 1 ? "s" : "")"
        }
    }

    private var detail: String {
        switch state {
        case .ocr: "L’iPhone lit le texte de la photo."
        case .ai(let engine): engine
        case .done: "Vérifie-les à l’étape suivante."
        }
    }
}
