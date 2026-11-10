import SwiftUI

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

    /// Titres façon affiche (Anton dans la web app) : système, très gras, condensé.
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .black).width(.condensed) }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight, design: .monospaced) }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light)) })
    }
}

/// Carte de base : fond crème, coins arrondis, ombre douce.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Theme.card, in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line))
            .shadow(color: Theme.bordeaux.opacity(0.10), radius: 14, y: 8)
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
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
