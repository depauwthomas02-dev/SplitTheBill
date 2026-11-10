import SwiftUI
import CoreText

/// Identité « Spritz » de la web app : orange apéro, bordeaux, papier de ticket de caisse.
enum Theme {
    static let bg = Color(light: 0xfbf1e4, dark: 0x170d08)
    static let card = Color(light: 0xfffaf3, dark: 0x22150e)
    static let sunk = Color(light: 0xf3e4d0, dark: 0x2e1d14)
    static let ink = Color(light: 0x2a1206, dark: 0xfbefe2)
    static let mute = Color(light: 0x7a5a44, dark: 0xc2a690)
    static let line = Color(light: 0x3a0f12, dark: 0xffffff).opacity(0.12)
    static let bordeaux = Color(hex: 0x3a0f12)
    static let orange = Color(hex: 0xff6a2b)
    static let soft = Color(hex: 0xffb37d)
    /// Bouton principal : bordeaux en clair, orange en sombre.
    static let button = Color(light: 0x3a0f12, dark: 0xff6a2b)
    static let buttonInk = Color(light: 0xffffff, dark: 0x2a1206)
    /// La tranche sous le bouton principal, qui lui donne son relief.
    static let buttonEdge = Color(light: 0x1d0608, dark: 0xa83a0c)
    static let paper = Color(light: 0xfffdf8, dark: 0xfbf6ec)
    static let paperInk = Color(hex: 0x24140c)
    static let paperMute = Color(hex: 0x9a8676)
    static let pen = Color(hex: 0x1f47b8)
    static let danger = Color(light: 0xc62f35, dark: 0xff8a8f)
    static let ok = Color(light: 0x2f7d32, dark: 0x8fd694)

    static let avatars: [(Color, Color)] = [
        (0xffb38a, 0x5a1d00), (0xffc7e4, 0x5c0e3a), (0xbfe3ff, 0x0a3a5c), (0xffdf9e, 0x5a3800), (0xd9ccff, 0x2d1a66),
        (0xa9f0dc, 0x0b4a3a), (0xffc2b6, 0x5c1a10), (0xeef09a, 0x3f4200), (0xc9d4ff, 0x16245e), (0xf3c9ff, 0x4b0f5c),
    ].map { (Color(hex: $0.0), Color(hex: $0.1)) }

    static func avatar(_ p: Person) -> (bg: Color, fg: Color) { avatars[p.color % avatars.count] }

    // MARK: Polices (les mêmes que la web app)

    /// Titres façon affiche : Anton, toujours en capitales.
    static func display(_ size: CGFloat) -> Font { .custom("Anton-Regular", size: size, relativeTo: .title) }
    /// Texte de ticket de caisse : Courier Prime.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(weight == .regular ? "CourierPrime-Regular" : "CourierPrime-Bold", size: size, relativeTo: .footnote)
    }
    /// Écriture au stylo : Caveat.
    static func hand(_ size: CGFloat) -> Font { .custom("Caveat-Bold", size: size, relativeTo: .title3) }

    /// Enregistre les polices du dossier Fonts/ au lancement.
    static func registerFonts() {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light)) })
    }
}

/// Fond de l'app : crème, avec deux halos de couleur très doux qui donnent de la matière au verre.
struct AmbientBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let k = scheme == .dark ? 0.55 : 1.0
        ZStack {
            Theme.bg
            Circle()
                .fill(Theme.orange.opacity(0.26 * k))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: -150, y: -300)
            Circle()
                .fill(Color(hex: 0xffc7e4).opacity(0.40 * k))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 160, y: 120)
            Circle()
                .fill(Color(hex: 0xffdf9e).opacity(0.45 * k))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: -120, y: 420)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Carte de contenu : fond crème, coins arrondis, ombre douce.
/// Le contenu reste opaque ; le verre est réservé aux commandes qui flottent au-dessus.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Theme.card, in: .rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line))
            .shadow(color: Theme.bordeaux.opacity(0.10), radius: 14, y: 8)
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

/// Bouton plein avec une tranche en dessous, qui s'enfonce quand on appuie (le bouton « photo » de la web app).
struct SolidButtonStyle: ButtonStyle {
    var radius: CGFloat = 24

    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed
        configuration.label
            .foregroundStyle(Theme.buttonInk)
            .background(Theme.button, in: .rect(cornerRadius: radius))
            .offset(y: down ? 4 : 0)
            .background {
                RoundedRectangle(cornerRadius: radius)
                    .fill(Theme.buttonEdge)
                    .offset(y: 6)
                    .shadow(color: Theme.bordeaux.opacity(down ? 0.15 : 0.40), radius: down ? 6 : 16, y: down ? 4 : 14)
            }
            .padding(.bottom, 6)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: down)
    }
}

/// Bord dentelé d'un ticket de caisse.
struct ZigZag: Shape {
    var tooth: CGFloat = 7
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + tooth))
        var x = r.minX
        while x < r.maxX {
            p.addLine(to: CGPoint(x: min(r.maxX, x + tooth), y: r.minY))
            p.addLine(to: CGPoint(x: min(r.maxX, x + tooth * 2), y: r.minY + tooth))
            x += tooth * 2
        }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - tooth))
        x = r.maxX
        while x > r.minX {
            p.addLine(to: CGPoint(x: max(r.minX, x - tooth), y: r.maxY))
            p.addLine(to: CGPoint(x: max(r.minX, x - tooth * 2), y: r.maxY - tooth))
            x -= tooth * 2
        }
        p.closeSubpath()
        return p
    }
}

/// Le pictogramme « ticket » du logo (même tracé que le SVG de la web app, sur une grille de 24).
struct ReceiptGlyph: Shape {
    func path(in r: CGRect) -> Path {
        let s = min(r.width, r.height) / 24
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.midX + (x - 12) * s, y: r.midY + (y - 12) * s) }
        var p = Path()
        p.move(to: pt(6, 3))
        p.addLine(to: pt(18, 3))
        p.addLine(to: pt(18, 21))
        for (x, y) in [(16, 19.5), (14, 21), (12, 19.5), (10, 21), (8, 19.5), (6, 21)] as [(CGFloat, CGFloat)] {
            p.addLine(to: pt(x, y))
        }
        p.closeSubpath()
        p.move(to: pt(9.5, 8)); p.addLine(to: pt(14.5, 8))
        p.move(to: pt(9.5, 12)); p.addLine(to: pt(14.5, 12))
        return p
    }
}

/// Le logo : pastille bordeaux + « SPLIT THE BILL » en Anton.
struct Brand: View {
    var body: some View {
        HStack(spacing: 10) {
            ReceiptGlyph()
                .stroke(Theme.soft, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .frame(width: 20, height: 20)
                .frame(width: 36, height: 36)
                .background(Theme.bordeaux, in: .rect(cornerRadius: 11))
                .shadow(color: Theme.orange.opacity(0.35), radius: 9, y: 6)
            Text("SPLIT\(Text("THE").foregroundStyle(Theme.orange))BILL")
                .font(Theme.display(21))
                .kerning(0.4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("SplitTheBill")
    }
}

struct Avatar: View {
    var person: Person
    var size: CGFloat = 40

    var body: some View {
        let c = Theme.avatar(person)
        Text(initials(person.name))
            .font(.system(size: size * 0.38, weight: .heavy))
            .foregroundStyle(c.fg)
            .frame(width: size, height: size)
            .background(c.bg, in: .circle)
            .accessibilityHidden(true)
    }

    private func initials(_ n: String) -> String {
        let w = n.split(separator: " ")
        let a = w.first?.first.map(String.init) ?? "?"
        let b = w.count > 1 ? (w[1].first.map(String.init) ?? "") : ""
        return (a + b).uppercased()
    }
}
