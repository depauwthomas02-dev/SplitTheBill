import SwiftUI

/// Une étape à l'écran, l'action principale collée au pouce (comme la web app).
/// L'en-tête et la barre du bas flottent en verre au-dessus du contenu, qui défile dessous.
struct RootView: View {
    @Environment(BillStore.self) private var store
    @State private var confirmReset = false

    var body: some View {
        ZStack(alignment: .top) {
            AmbientBackground()

            stepView
                .id(store.bill.step)
                .transition(.asymmetric(
                    insertion: .move(edge: store.forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: store.forward ? .leading : .trailing).combined(with: .opacity)
                ))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaBar(edge: .top) { header }

            if let reading = store.reading {
                ReadingOverlay(state: reading)
                    .transition(.opacity)
            }

            if let toast = store.toast {
                Text(toast)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .glassEffect(.regular, in: .capsule)
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

    /// Sur l'accueil d'une addition vide, seul le logo est affiché.
    private var showsProgress: Bool {
        store.bill.step != .ticket || !store.bill.items.isEmpty
    }

    private var header: some View {
        HStack(spacing: 12) {
            Brand()
            Spacer(minLength: 0)
            if showsProgress {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            ForEach(Step.allCases, id: \.self) { s in
                                let reached = s.rawValue <= store.bill.step.rawValue
                                Button {
                                    store.go(s)
                                } label: {
                                    Capsule()
                                        .fill(reached ? Theme.orange : Theme.ink.opacity(0.18))
                                        .frame(width: s == store.bill.step ? 22 : 8, height: 8)
                                        .frame(height: 40)
                                        .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .disabled(s == store.bill.step || s.rawValue > store.bill.maxStep.rawValue || !store.bill.canEnter(s))
                                .accessibilityLabel("Étape \(s.rawValue + 1) : \(s.title)")
                            }
                        }
                        .padding(.horizontal, 14)
                        .glassEffect(.regular, in: .capsule)
                        .animation(.snappy, value: store.bill.step)

                        Button {
                            confirmReset = true
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .frame(width: 40, height: 40)
                                .contentShape(.circle)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .accessibilityLabel("Recommencer")
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .animation(.snappy, value: showsProgress)
    }
}

/// Barre du bas, en verre : retour + bouton principal.
struct Dock<Leading: View>: View {
    @Environment(BillStore.self) private var store
    var label: String
    var systemImage: String?
    var disabled = false
    var action: () -> Void
    @ViewBuilder var leading: () -> Leading
    @State private var keyboardUp = false

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                if keyboardUp {
                    // Le pavé numérique n'a pas de touche « OK » : on propose de fermer le clavier ici.
                    Button {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 58, height: 58)
                            .contentShape(.rect(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
                    .accessibilityLabel("Fermer le clavier")
                } else if store.bill.step != .ticket {
                    DockBackButton()
                }
                leading()
                Button(action: action) {
                    DockLabel(text: label, systemImage: systemImage, disabled: disabled)
                }
                .buttonStyle(.plain)
                .disabled(disabled)
                .sensoryFeedback(.impact(weight: .light), trigger: label)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .animation(.snappy, value: label)
        .animation(.snappy, value: disabled)
        .animation(.snappy, value: keyboardUp)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardUp = false }
    }
}

extension Dock where Leading == EmptyView {
    init(label: String, systemImage: String? = nil, disabled: Bool = false, action: @escaping () -> Void) {
        self.init(label: label, systemImage: systemImage, disabled: disabled, action: action) { EmptyView() }
    }
}

/// Le libellé du bouton principal : verre teinté aux couleurs de l'app, verre neutre s'il est inactif.
struct DockLabel: View {
    var text: String
    var systemImage: String?
    var disabled = false

    var body: some View {
        HStack(spacing: 10) {
            Text(text.uppercased())
                .font(Theme.display(19))
                .kerning(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.opacity)
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 16, weight: .heavy))
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: 58)
        .foregroundStyle(disabled ? Theme.mute : Theme.buttonInk)
        .contentShape(.rect(cornerRadius: 22))
        .glassEffect(disabled ? .regular : .regular.tint(Theme.button).interactive(), in: .rect(cornerRadius: 22))
    }
}

struct DockBackButton: View {
    @Environment(BillStore.self) private var store

    var body: some View {
        Button { store.back() } label: {
            Image(systemName: "arrow.left")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 58, height: 58)
                .contentShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
        .accessibilityLabel("Étape précédente")
    }
}

/// Titre d'étape : « Étape 2 sur 5 » + grand titre en capitales + explication.
struct StepHeader: View {
    var step: Step
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Étape \(step.rawValue + 1) sur 5".uppercased())
                .font(Theme.mono(12, weight: .bold))
                .kerning(1.6)
                .foregroundStyle(Theme.mute)
            Text(title.uppercased())
                .font(Theme.display(44))
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(title)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.mute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }
}

/// Pendant la lecture du ticket.
struct ReadingOverlay: View {
    var state: BillStore.ReadingState

    var body: some View {
        ZStack {
            Theme.bg.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
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
                .font(.system(size: 52))
                .contentTransition(.symbolEffect(.replace))

                Text(title.uppercased())
                    .font(Theme.display(30))
                    .multilineTextAlignment(.center)
                    .accessibilityLabel(title)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.mute)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28).padding(.vertical, 32)
            .frame(maxWidth: 320)
            .glassEffect(.regular, in: .rect(cornerRadius: 32))
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
