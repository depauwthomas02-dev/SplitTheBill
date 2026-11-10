import SwiftUI

/// Étape 3 : qui était à table ?
struct PeopleStepView: View {
    @Environment(BillStore.self) private var store
    @State private var name = ""
    @State private var shake = 0
    @FocusState private var focused: Bool

    var body: some View {
        let people = store.bill.people
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StepHeader(step: .people, title: "Qui était à table ?", subtitle: "Ajoute chaque personne qui partage l’addition.")

                HStack(spacing: 8) {
                    TextField("Prénom", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($focused)
                        .onSubmit(add)
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(Theme.card, in: .rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
                    Button("Ajouter", action: add)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.buttonInk)
                        .padding(.horizontal, 18)
                        .frame(height: 50)
                        .background(Theme.button, in: .rect(cornerRadius: 14))
                }
                .modifier(Shake(animatableData: CGFloat(shake)))

                let recent = store.recentNames
                if !recent.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            Text("Récemment").font(.caption.weight(.semibold)).foregroundStyle(Theme.mute)
                            ForEach(Array(recent.enumerated()), id: \.element) { i, n in
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { _ = store.bill.addPerson(n) }
                                } label: {
                                    HStack(spacing: 6) {
                                        Avatar(person: Person(id: -1, name: n, color: people.count + i), size: 24)
                                        Text(n).font(.subheadline.weight(.semibold))
                                    }
                                    .padding(.leading, 4).padding(.trailing, 12).padding(.vertical, 4)
                                    .background(Theme.card, in: .capsule)
                                    .overlay(Capsule().stroke(Theme.line))
                                }
                                .foregroundStyle(Theme.ink)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }

                if people.isEmpty {
                    VStack(spacing: 10) {
                        HStack(spacing: -10) {
                            ForEach(0..<3) { _ in Circle().fill(Theme.sunk).frame(width: 40, height: 40).overlay(Circle().stroke(Theme.bg, lineWidth: 3)) }
                        }
                        Text("Personne pour l’instant. Il faut au moins deux personnes.")
                            .font(.subheadline).foregroundStyle(Theme.mute).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(people) { p in
                        HStack(spacing: 10) {
                            Avatar(person: p, size: 40)
                            Text(p.name).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                            Spacer(minLength: 0)
                            Button {
                                withAnimation(.snappy) { store.bill.removePerson(p.id) }
                            } label: {
                                Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(Theme.mute)
                                    .frame(width: 28, height: 28)
                            }
                            .accessibilityLabel("Retirer \(p.name)")
                        }
                        .padding(10)
                        .background(Theme.card, in: .rect(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line))
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaBar(edge: .bottom) {
            Dock(label: people.isEmpty ? "Ajoute les participants" : people.count == 1 ? "Encore une personne" : "Attribuer les articles",
                 systemImage: people.count >= 2 ? "arrow.right" : nil,
                 disabled: people.count < 2) {
                store.go(.assign)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: people.count)
        .onAppear { if people.isEmpty { focused = true } }
    }

    private func add() {
        let n = name.trimmed
        if n.isEmpty || store.bill.hasPerson(named: n) {
            withAnimation(.default) { shake += 1 }
            if !n.isEmpty { store.show("\(n) est déjà dans la liste.") }
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { _ = store.bill.addPerson(n) }
        name = ""
        focused = true
    }
}

struct Shake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(animatableData * .pi * 4), y: 0))
    }
}
