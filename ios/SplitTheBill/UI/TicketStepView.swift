import SwiftUI
import PhotosUI

/// Étape 1 : accueil « ticket de caisse » et choix de la méthode.
struct TicketStepView: View {
    @Environment(BillStore.self) private var store
    @State private var scanning = false
    @State private var pick: PhotosPickerItem?
    @State private var textSheet = false
    @State private var engine = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HeroTicket()
                    .padding(.top, 8)

                VStack(spacing: 12) {
                    if DocumentScanner.isSupported {
                        Button { scanning = true } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .frame(width: 52, height: 52)
                                    .background(Theme.orange, in: .rect(cornerRadius: 16))
                                    .foregroundStyle(.white)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Prendre le ticket en photo").font(.system(size: 18, weight: .bold))
                                    Text("Une photo et c’est lu.").font(.subheadline).opacity(0.75)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.headline)
                            }
                            .padding(14)
                            .foregroundStyle(Theme.buttonInk)
                            .background(Theme.button, in: .rect(cornerRadius: 22))
                        }
                        .accessibilityHint("Ouvre le scanner de documents")
                    }

                    PhotosPicker(selection: $pick, matching: .images) {
                        Label(DocumentScanner.isSupported ? "ou choisir une photo déjà prise" : "Choisir une photo du ticket",
                              systemImage: "photo.on.rectangle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.orange)
                    }

                    Label(engine, systemImage: "apple.intelligence")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.mute)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Theme.card, in: .capsule)
                        .overlay(Capsule().stroke(Theme.line))
                        .opacity(engine.isEmpty ? 0 : 1)
                }

                DisclosureGroup {
                    VStack(spacing: 10) {
                        MethodTile(icon: "doc.on.clipboard", title: "J’ai déjà le texte", subtitle: "Colle-le directement.") { textSheet = true }
                        MethodTile(icon: "square.and.pencil", title: "Saisir à la main", subtitle: "Ajoute les articles un par un.") { store.startManually() }
                    }
                    .padding(.top, 10)
                } label: {
                    Text("Autres méthodes").font(.subheadline.weight(.semibold))
                }
                .tint(Theme.ink)
                .card()

                HStack(spacing: 4) {
                    Text("Juste curieux ?").fontWeight(.bold)
                    Button("Essayer avec un exemple") {
                        Task { await store.analyze(text: TicketParser.demo) }
                    }
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .fullScreenCover(isPresented: $scanning) {
            DocumentScanner { image in
                scanning = false
                Task { await store.read(image: image) }
            } onCancel: {
                scanning = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            pick = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    await store.read(image: img)
                } else {
                    store.show("Impossible d’ouvrir cette photo.")
                }
            }
        }
        .sheet(isPresented: $textSheet) { PasteTextSheet() }
        .task { engine = ReceiptAI.statusLabel }
    }
}

private struct MethodTile: View {
    var icon: String
    var title: String
    var subtitle: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(Theme.sunk, in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.bold))
                    Text(subtitle).font(.caption).foregroundStyle(Theme.mute)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.mute)
            }
            .foregroundStyle(Theme.ink)
            .contentShape(.rect)
        }
    }
}

/// Le ticket d'accueil « Bar des radins ».
struct HeroTicket: View {
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 10) {
            Text("★ Bar des radins ★").font(Theme.mono(13, weight: .bold))
            Text(Date.now.formatted(.dateTime.day().month(.twoDigits).hour().minute()).uppercased())
                .font(Theme.mono(12))
                .foregroundStyle(Theme.paperMute)
            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .frame(height: 1)
                .foregroundStyle(Theme.paperMute)
            Text("L’addition, même pour les \(Text("radins.").foregroundStyle(Theme.orange))")
                .font(Theme.display(42))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 2) {
                Text("« J’ai bu que 2 bières, moi. »")
                    .font(.system(size: 22, weight: .semibold, design: .serif)).italic()
                Text("Pauline, au moment de payer").font(.caption)
            }
            .foregroundStyle(Theme.pen)
            .rotationEffect(.degrees(-2))
            .padding(.top, 4)
        }
        .foregroundStyle(Theme.paperInk)
        .padding(.horizontal, 22).padding(.vertical, 28)
        .frame(maxWidth: 360)
        .background(Theme.paper, in: ZigZag())
        .shadow(color: Theme.bordeaux.opacity(0.18), radius: 18, y: 12)
        .rotationEffect(.degrees(appeared ? -1.6 : 0))
        .offset(y: appeared ? 0 : 24)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { appeared = true } }
    }
}

/// « J'ai déjà le texte » : coller le texte du ticket, choisir le format des prix, analyser.
struct PasteTextSheet: View {
    @Environment(BillStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var unit = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Pizza Margherita 12,50\n2 Spritz 17,00\nTiramisu 7,50\nTOTAL 37,00")
                            .foregroundStyle(Theme.paperMute)
                            .padding(.horizontal, 5).padding(.vertical, 8)
                    }
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .font(Theme.mono(15))
                .foregroundStyle(Theme.paperInk)
                .padding(12)
                .frame(minHeight: 220)
                .background(Theme.paper, in: .rect(cornerRadius: 14))

                HStack {
                    PasteButton(payloadType: String.self) { strings in
                        if let s = strings.first { text = s }
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonBorderShape(.capsule)
                    Button("Exemple", systemImage: "sparkles") { text = TicketParser.demo }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                }

                Text("Sur ce ticket, les prix sont").font(.subheadline.weight(.semibold))
                Picker("Prix", selection: $unit) {
                    Text("Le total de la ligne").tag(false)
                    Text("Le prix à l’unité").tag(true)
                }
                .pickerStyle(.segmented)
                Text(unit ? "Exemple : « 2 Spritz 8,50 » = 8,50 € chacun, 17 € en tout." : "Exemple : « 2 Spritz 17,00 » = 17 € pour les deux.")
                    .font(.caption).foregroundStyle(Theme.mute)
                Text("Apple Intelligence lit le texte quand elle est disponible. Ce réglage sert à la lecture classique.")
                    .font(.caption2).foregroundStyle(Theme.mute)
                Spacer()
            }
            .padding(16)
            .background(Theme.bg)
            .navigationTitle("Texte du ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Analyser") {
                        store.bill.unitPrices = unit
                        let t = text
                        dismiss()
                        Task { await store.analyze(text: t) }
                    }
                    .fontWeight(.bold)
                    .disabled(text.trimmed.isEmpty)
                }
            }
            .onAppear { text = store.bill.rawText; unit = store.bill.unitPrices }
        }
        .presentationDetents([.large])
    }
}
