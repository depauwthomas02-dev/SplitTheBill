import SwiftUI

/// Étape 2 : vérifier les articles lus, le pourboire et le total du ticket.
struct ItemsStepView: View {
    @Environment(BillStore.self) private var store
    @FocusState private var focus: Int?

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        StepHeader(step: .items, title: "Vérifie les articles.",
                                   subtitle: "Corrige ce que l’iPhone a mal lu. Le prix indiqué est celui de la ligne entière.")
                        if let engine = store.bill.engine {
                            Label(engine.label, systemImage: engine == .classic || engine == .manual ? "text.alignleft" : "apple.intelligence")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.mute)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        ForEach($store.bill.items) { $item in
                            ItemRow(item: $item, focus: $focus) {
                                withAnimation(.snappy) { store.bill.removeItem(item.id) }
                            }
                            .id(item.id)
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                        }

                        Button {
                            let id = withAnimation(.snappy) { store.bill.addItem() }
                            focus = id
                            withAnimation { proxy.scrollTo(id, anchor: .center) }
                        } label: {
                            Label("Ajouter un article", systemImage: "plus")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])).foregroundStyle(Theme.line))
                        }

                        CheckCard()

                        HStack(spacing: 12) {
                            MoneyField(title: "Pourboire, frais (€)", placeholder: "0,00", text: $store.bill.extraText)
                            MoneyField(title: "Total du ticket (€)", placeholder: "Si connu", text: $store.bill.ticketTotalText)
                        }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            Dock(label: "Continuer", systemImage: "arrow.right",
                 disabled: !store.bill.items.contains { !$0.name.trimmed.isEmpty || $0.cents != 0 }) {
                focus = nil
                store.bill.dropEmptyItems()
                if store.bill.items.isEmpty { store.bill.addItem(); return }
                store.go(.people)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") { focus = nil }.fontWeight(.bold)
            }
        }
    }
}

private struct ItemRow: View {
    @Binding var item: BillItem
    var focus: FocusState<Int?>.Binding
    var onDelete: () -> Void
    @State private var priceText = ""
    @FocusState private var priceFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                TextField("Nom de l’article", text: $item.name)
                    .font(.system(size: 17, weight: .semibold))
                    .focused(focus, equals: item.id)
                    .submitLabel(.next)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash").font(.subheadline)
                }
                .foregroundStyle(Theme.mute)
                .accessibilityLabel("Supprimer l’article")
            }
            HStack(spacing: 10) {
                HStack(spacing: 0) {
                    Button { item.quantity = max(1, item.quantity - 1) } label: { Image(systemName: "minus").frame(width: 34, height: 34) }
                        .accessibilityLabel("Une unité de moins")
                    Text("\(item.quantity)")
                        .font(.system(size: 16, weight: .bold).monospacedDigit())
                        .frame(minWidth: 22)
                        .contentTransition(.numericText())
                    Button { item.quantity = min(99, item.quantity + 1) } label: { Image(systemName: "plus").frame(width: 34, height: 34) }
                        .accessibilityLabel("Une unité de plus")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.ink)
                .background(Theme.sunk, in: .capsule)
                .sensoryFeedback(.selection, trigger: item.quantity)
                .animation(.snappy, value: item.quantity)

                Text(item.quantity > 1 ? "\(Money.eur(Double(item.cents) / Double(item.quantity) / 100)) l’unité" : "Prix de la ligne")
                    .font(.caption)
                    .foregroundStyle(Theme.mute)
                    .lineLimit(1)
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    TextField("0,00", text: $priceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 17, weight: .bold).monospacedDigit())
                        .frame(width: 84)
                        .focused($priceFocused)
                        .accessibilityLabel("Prix de la ligne en euros")
                    Text("€").foregroundStyle(Theme.mute)
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Theme.sunk, in: .rect(cornerRadius: 12))
            }
        }
        .card()
        .onAppear { priceText = Money.input(item.cents) }
        .onChange(of: priceText) { _, t in item.cents = Money.cents(t) }
        .onChange(of: priceFocused) { _, f in if !f { priceText = Money.input(item.cents) } }
    }
}

/// Anneau de contrôle : la somme des articles et des frais correspond-elle au ticket ?
private struct CheckCard: View {
    @Environment(BillStore.self) private var store

    var body: some View {
        let bill = store.bill
        let sum = bill.itemsCents + bill.extraCents
        let total = bill.ticketTotalCents
        let gap = bill.gapCents
        let ratio = total.map { $0 > 0 ? min(1, max(0, Double(sum) / Double($0))) : 0 } ?? 0
        let ok = gap == 0

        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(Theme.line, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: ratio)
                    .stroke(ok ? Theme.ok : Theme.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.ok)
                    .scaleEffect(ok ? 1 : 0.2)
                    .opacity(ok ? 1 : 0)
            }
            .frame(width: 54, height: 54)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: ratio)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: ok)

            VStack(alignment: .leading, spacing: 3) {
                Text(total.map { "Articles + frais, sur \(Money.eur($0))" } ?? "Articles + frais")
                    .font(.caption).foregroundStyle(Theme.mute)
                Text(Money.eur(sum))
                    .font(.system(size: 24, weight: .heavy).monospacedDigit())
                    .contentTransition(.numericText(value: Double(sum)))
                    .animation(.snappy, value: sum)
                Group {
                    if total == nil {
                        Text("Ajoute le total du ticket pour vérifier.").foregroundStyle(Theme.mute)
                    } else if let gap, gap == 0 {
                        Text("Tout correspond au ticket.").foregroundStyle(Theme.ok)
                    } else if let gap, gap > 0 {
                        HStack {
                            Text("Il manque \(Money.eur(gap)).").foregroundStyle(Theme.danger)
                            Button("Ajouter en frais") {
                                store.bill.addGapAsExtra()
                                store.show("\(Money.eur(gap)) ajoutés en frais")
                            }
                            .fontWeight(.bold)
                        }
                    } else if let gap {
                        Text("Dépasse le ticket de \(Money.eur(-gap)). Vérifie une ligne.").foregroundStyle(Theme.danger)
                    }
                }
                .font(.caption.weight(.semibold))
            }
            Spacer(minLength: 0)
        }
        .card()
        .sensoryFeedback(.success, trigger: ok) { _, new in new }
    }
}

/// Champ de montant : on garde le texte tel que saisi (« 12,5 ») pour ne pas gêner la frappe.
struct MoneyField: View {
    var title: String
    var placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.mute)
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .font(.system(size: 17, weight: .bold).monospacedDigit())
                .padding(12)
                .background(Theme.card, in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
        }
    }
}
