import SwiftUI

/// Étape 4 : qui a pris quoi ?
struct AssignStepView: View {
    @Environment(BillStore.self) private var store
    @State private var allDoneFeedback = false

    var body: some View {
        let bill = store.bill
        let done = bill.items.count - bill.unassignedCount
        let result = SplitCalculator.compute(bill)

        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    StepHeader(step: .assign, title: "Qui a pris quoi ?",
                               subtitle: "Touche une personne pour lui donner une part, encore pour une part de plus. Le bouton − retire une part.")

                    VStack(spacing: 6) {
                        HStack {
                            Text("Articles attribués").font(.caption.weight(.semibold)).foregroundStyle(Theme.mute)
                            Spacer()
                            Text("\(done) / \(bill.items.count)").font(.caption.weight(.heavy).monospacedDigit())
                                .contentTransition(.numericText())
                        }
                        GeometryReader { g in
                            Capsule().fill(Theme.line)
                                .overlay(alignment: .leading) {
                                    Capsule().fill(done == bill.items.count ? Theme.ok : Theme.orange)
                                        .frame(width: bill.items.isEmpty ? 0 : g.size.width * CGFloat(done) / CGFloat(bill.items.count))
                                }
                        }
                        .frame(height: 8)
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: done)

                    ForEach(bill.items) { item in
                        AssignCard(item: item)
                    }
                }
                .padding(16)
            }

            SumBar(result: result)

            let u = bill.unassignedCount
            Dock(label: u > 0 ? "Encore \(u) article\(u > 1 ? "s" : "") à attribuer" : "Voir le résultat",
                 systemImage: u > 0 ? nil : "arrow.right",
                 disabled: u > 0) {
                store.go(.result)
            }
        }
        .onAppear { store.bill.dropEmptyItems() }
        .onChange(of: bill.unassignedCount) { old, new in
            if new == 0 && old > 0 {
                allDoneFeedback.toggle()
                store.show("Tout est attribué !")
            }
        }
        .sensoryFeedback(.success, trigger: allDoneFeedback)
    }
}

private struct AssignCard: View {
    @Environment(BillStore.self) private var store
    var item: BillItem
    @State private var tick = 0

    var body: some View {
        let bill = store.bill
        let complete = bill.isComplete(item)
        let anyone = bill.parts(item) > 0

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: complete ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(complete ? Theme.ok : Theme.mute)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 2) {
                    Text((item.quantity > 1 ? "\(item.quantity)× " : "") + (item.name.isEmpty ? "Article" : item.name))
                        .font(.system(size: 17, weight: .bold))
                    Text(bill.assignSummary(item))
                        .font(.caption)
                        .foregroundStyle(Theme.mute)
                        .contentTransition(.opacity)
                }
                Spacer()
                Text(Money.eur(item.cents)).font(.system(size: 16, weight: .heavy).monospacedDigit())
            }

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(bill.people) { p in
                        PersonToggle(person: p, shares: bill.shares(item, p)) {
                            tick += 1
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { store.bill.tap(item, p) }
                        } onMinus: {
                            tick += 1
                            withAnimation(.snappy) { store.bill.minus(item, p) }
                        }
                    }
                    let all = bill.everyoneSelected(item)
                    Button {
                        tick += 1
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { store.bill.toggleEveryone(item) }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 48, height: 48)
                                .foregroundStyle(all ? Theme.buttonInk : Theme.ink)
                                .background(all ? Theme.button : Theme.sunk, in: .circle)
                            Text("Tous").font(.caption2.weight(.semibold))
                        }
                    }
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(all ? .isSelected : [])
                }
                .padding(.top, 6).padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)

            if anyone {
                Button {
                    withAnimation(.snappy) { store.bill.clear(item) }
                    store.show("Article désélectionné")
                } label: {
                    Label("Tout désélectionner", systemImage: "arrow.uturn.backward")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Theme.mute)
                .transition(.opacity)
            }
        }
        .card()
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(complete ? Theme.ok.opacity(0.5) : .clear, lineWidth: 1.5))
        .sensoryFeedback(.selection, trigger: tick)
    }
}

private struct PersonToggle: View {
    var person: Person
    var shares: Int
    var onTap: () -> Void
    var onMinus: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Button(action: onTap) {
                Avatar(person: person, size: 48)
                    .overlay(Circle().stroke(Theme.button, lineWidth: shares > 0 ? 3 : 0).padding(-3))
                    .opacity(shares > 0 ? 1 : 0.55)
                    .scaleEffect(shares > 0 ? 1 : 0.92)
                    .overlay(alignment: .topTrailing) {
                        if shares > 1 {
                            Text("×\(shares)")
                                .font(.caption2.weight(.heavy))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .foregroundStyle(Theme.soft)
                                .background(Theme.bordeaux, in: .capsule)
                                .offset(x: 6, y: -6)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
            }
            .accessibilityLabel(person.name + (shares > 1 ? ", \(shares) parts" : ""))
            .accessibilityAddTraits(shares > 0 ? .isSelected : [])

            Text(person.name).font(.caption2.weight(.semibold)).lineLimit(1).frame(maxWidth: 60)

            Button(action: onMinus) {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .heavy))
                    .frame(width: 26, height: 20)
                    .background(Theme.sunk, in: .capsule)
            }
            .foregroundStyle(Theme.ink)
            .opacity(shares > 0 ? 1 : 0)
            .disabled(shares == 0)
            .accessibilityLabel("Retirer une part à \(person.name)")
        }
    }
}

/// Totaux en cours, en bas d'écran.
private struct SumBar: View {
    @Environment(BillStore.self) private var store
    var result: SplitResult

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(store.bill.people) { p in
                    let v = result.owed[p.id] ?? 0
                    HStack(spacing: 6) {
                        Avatar(person: p, size: 26)
                        Text(Money.eur(v))
                            .font(.system(size: 14, weight: .bold).monospacedDigit())
                            .contentTransition(.numericText(value: Double(v)))
                    }
                    .padding(.leading, 4).padding(.trailing, 10).padding(.vertical, 4)
                    .background(Theme.card, in: .capsule)
                    .overlay(Capsule().stroke(Theme.line))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(p.name) : \(Money.eur(v))")
                }
            }
            .padding(.horizontal, 16)
            .animation(.snappy, value: result.owed)
        }
        .scrollIndicators(.hidden)
        .padding(.vertical, 8)
        .background(Theme.bg)
    }
}
