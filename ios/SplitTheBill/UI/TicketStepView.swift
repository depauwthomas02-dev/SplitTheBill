import SwiftUI
import PhotosUI

/// Étape 1 : accueil « ticket de caisse » et choix de la méthode.
struct TicketStepView: View {
    @Environment(BillStore.self) private var store
    @State private var scanning = false
    @State private var picking = false
    @State private var pick: PhotosPickerItem?
    @State private var textSheet = false
    @State private var engine = ""

    private var hasCamera: Bool { DocumentScanner.isSupported }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HeroTicket()
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                // L'action principale : une photo et c'est lu.
                Button {
                    if hasCamera { scanning = true } else { picking = true }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: hasCamera ? "camera.fill" : "photo.fill")
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(Theme.orange, in: .rect(cornerRadius: 18))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(hasCamera ? "PRENDRE LE TICKET EN PHOTO" : "CHOISIR UNE PHOTO DU TICKET")
                                .font(Theme.display(23))
                                .kerning(0.4)
                                .lineSpacing(1)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Une photo et c’est lu.")
                                .font(.footnote)
                                .opacity(0.8)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal, 18)
                    .contentShape(.rect(cornerRadius: 24))
                }
                .buttonStyle(SolidButtonStyle())
                .accessibilityLabel(hasCamera ? "Prendre le ticket en photo" : "Choisir une photo du ticket")
                .padding(.top, 30)

                // Les autres façons d'entrer un ticket, en verre.
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        if hasCamera {
                            GlassTile(icon: "photo.on.rectangle.angled", title: "Importer\nune photo") { picking = true }
                        }
                        GlassTile(icon: "doc.on.clipboard", title: "Coller\nle texte") { textSheet = true }
                        GlassTile(icon: "square.and.pencil", title: "Saisir\nà la main") { store.startManually() }
                    }
                }
                .padding(.top, 16)

                if !engine.isEmpty {
                    Label(engine, systemImage: "apple.intelligence")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.mute)
                        .padding(.top, 18)
                }

                HStack(spacing: 5) {
                    Text("Juste curieux ?")
                        .fontWeight(.bold)
                    Button {
                        Task { await store.analyze(text: TicketParser.demo) }
                    } label: {
                        Text("Essayer avec un exemple")
                            .fontWeight(.semibold)
                            .underline()
                            .foregroundStyle(Theme.mute)
                    }
                    .buttonStyle(.plain)
                }
                .font(.subheadline)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .fullScreenCover(isPresented: $scanning) {
            DocumentScanner { image in
                scanning = false
                Task { await store.read(image: image) }
            } onCancel: {
                scanning = false
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $picking, selection: $pick, matching: .images)
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

/// Une tuile de verre : pictogramme orange au-dessus d'un libellé sur deux lignes.
private struct GlassTile: View {
    var icon: String
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.orange)
                    .frame(height: 28)
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .contentShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
        .accessibilityLabel(title.replacingOccurrences(of: "\n", with: " "))
    }
}

/// Le ticket d'accueil « Bar des radins », imprimé à l'ouverture.
struct HeroTicket: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var printed = false
    @State private var signed = false

    private static let stamp: String = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "dd/MM · HH:mm"
        return "TABLE 4 · " + f.string(from: .now)
    }()

    var body: some View {
        VStack(spacing: 0) {
            Group {
                Text("★ BAR DES RADINS ★")
                Text(Self.stamp)
            }
            .font(Theme.mono(12))
            .kerning(1.4)

            DashedRule().padding(.vertical, 12)

            Text("L’ADDITION, MÊME POUR LES \(Text("RADINS.").foregroundStyle(Theme.orange))")
                .font(Theme.display(40))
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("L’addition, même pour les radins.")
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .trailing, spacing: 0) {
                Text("« J’ai bu que 2 bières, moi. »").font(Theme.hand(25))
                Text("Pauline, au moment de payer").font(Theme.hand(18))
            }
            .foregroundStyle(Theme.pen)
            .rotationEffect(.degrees(-3))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
            .padding(.leading, 4)
            .opacity(signed ? 1 : 0)
            .scaleEffect(signed ? 1 : 1.12, anchor: .leading)
        }
        .foregroundStyle(Theme.paperInk)
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(Theme.paper, in: ZigZag())
        .mask(alignment: .top) {
            // Le ticket sort de l'imprimante : on le dévoile du haut vers le bas.
            Rectangle().scaleEffect(x: 1, y: printed ? 1 : 0.02, anchor: .top)
        }
        .shadow(color: Theme.bordeaux.opacity(0.22), radius: 22, y: 20)
        .shadow(color: .black.opacity(0.06), radius: 1, y: 2)
        .rotationEffect(.degrees(-1.6))
        .onAppear {
            guard !printed else { return }
            if reduceMotion {
                printed = true
                signed = true
            } else {
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 1.1).delay(0.1)) { printed = true }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(1.0)) { signed = true }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Ligne de pointillés d'un ticket.
struct DashedRule: View {
    var body: some View {
        Line()
            .stroke(Color.black.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            .frame(height: 1.5)
    }

    private struct Line: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.midY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            return p
        }
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
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Pizza Margherita 12,50\n2 Spritz 17,00\nTiramisu 7,50\nTOTAL 37,00")
                                .foregroundStyle(Theme.paperMute)
                                .padding(.horizontal, 5).padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $text)
                            .scrollContentBackground(.hidden)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .font(Theme.mono(15))
                    .foregroundStyle(Theme.paperInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 18)
                    .frame(minHeight: 240)
                    .background(Theme.paper, in: ZigZag())
                    .shadow(color: Theme.bordeaux.opacity(0.14), radius: 14, y: 10)

                    HStack {
                        PasteButton(payloadType: String.self) { strings in
                            if let s = strings.first { text = s }
                        }
                        .labelStyle(.titleAndIcon)
                        .buttonBorderShape(.capsule)
                        Button("Exemple", systemImage: "sparkles") { text = TicketParser.demo }
                            .buttonStyle(.glass)
                    }

                    Text("Sur ce ticket, les prix sont").font(.subheadline.weight(.semibold))
                    Picker("Prix", selection: $unit) {
                        Text("Le total de la ligne").tag(false)
                        Text("Le prix à l’unité").tag(true)
                    }
                    .pickerStyle(.segmented)
                    Text(unit ? "Exemple : « 2 Spritz 8,50 » = 8,50 € chacun, 17 € en tout." : "Exemple : « 2 Spritz 17,00 » = 17 € pour les deux.")
                        .font(.caption).foregroundStyle(Theme.mute)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.bg)
            .foregroundStyle(Theme.ink)
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
        .tint(Theme.orange)
        .presentationDetents([.large])
    }
}
