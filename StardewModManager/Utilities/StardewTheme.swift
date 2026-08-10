import SwiftUI
import CoreText

// MARK: - Font Registration

func registerStardewFonts() {
    guard let fontURL = Bundle.appBundle.url(forResource: "VT323-Regular", withExtension: "ttf") else {
        return
    }
    CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
}

// MARK: - Stardew Font

extension Font {
    static func stardew(size: CGFloat) -> Font {
        .custom("VT323", size: size)
    }
}

// MARK: - Theme Palette

/// Every theme-dependent color, resolved once per theme into stored properties.
/// Accessing a themed color (e.g. `Color.parchment`) no longer re-reads
/// UserDefaults or rebuilds a `Color` on every call: `Palette.current` hands back
/// a cached value and only rebuilds when the active theme changes.
struct Palette {
    // Sidebar tones
    let sidebarWood: Color
    let sidebarWoodLight: Color
    let sidebarWoodDark: Color

    // Parchment backgrounds (warm sandy tones matching in-game UI)
    let parchment: Color
    let parchmentAlt: Color
    let parchmentHeader: Color

    // Frame borders (thick borders matching in-game panels)
    let frameBorder: Color
    let frameBorderDark: Color

    // Text
    let textDark: Color
    let textMedium: Color
    let textLight: Color
    let textMuted: Color

    // Accent
    let accentGold: Color
    let accentGoldBorder: Color
    let accentGoldDark: Color

    // UI
    let toggleOff: Color
    let stardewDivider: Color

    // Table row backgrounds (warmer to match parchment)
    let rowEven: Color
    let rowOdd: Color
    let rowHover: Color
    let rowSelected: Color
    let tableHeader: Color

    // Card
    let cardBorder: Color

    // Blue text tuned for legibility on the current surface. See `Color.stardewBlue`
    // for the on-dark/background blue that stays the same across every theme.
    let stardewBlueText: Color
}

extension Palette {
    static let stardew = Palette(
        sidebarWood: Color(hex: 0x5B3A21),
        sidebarWoodLight: Color(hex: 0x6B4226),
        sidebarWoodDark: Color(hex: 0x3E2218),
        parchment: Color(hex: 0xF5D6A0),
        parchmentAlt: Color(hex: 0xECC888),
        parchmentHeader: Color(hex: 0xE0B870),
        frameBorder: Color(hex: 0xB8741A),
        frameBorderDark: Color(hex: 0x8B5A14),
        textDark: Color(hex: 0x3E2218),
        textMedium: Color(hex: 0x5B3A21),
        // textLight/textMuted darkened from 0x7A6344/0xA0855C so muted text
        // clears ~4.5:1 on the lightest parchment.
        textLight: Color(hex: 0x6B5335),
        textMuted: Color(hex: 0x745B3C),
        accentGold: Color(hex: 0xD4A96A),
        accentGoldBorder: Color(hex: 0xB8842A),
        accentGoldDark: Color(hex: 0x8B6914),
        toggleOff: Color(hex: 0x8B7355),
        stardewDivider: Color(hex: 0xB8741A),
        rowEven: Color(hex: 0xF7DDB0),
        rowOdd: Color(hex: 0xF0CC95),
        rowHover: Color(hex: 0xE8C080),
        rowSelected: Color(hex: 0xE0B870),
        tableHeader: Color(hex: 0xDAAA60),
        cardBorder: Color(hex: 0xB8741A),
        stardewBlueText: Color(hex: 0x2C5F8A)
    )

    static let pink = Palette(
        sidebarWood: Color(hex: 0x9E4B6D),
        sidebarWoodLight: Color(hex: 0xB05A7E),
        sidebarWoodDark: Color(hex: 0x7A3555),
        parchment: Color(hex: 0xFFF0F3),
        parchmentAlt: Color(hex: 0xFFE4EA),
        parchmentHeader: Color(hex: 0xFFD6E0),
        frameBorder: Color(hex: 0xC46A8A),
        frameBorderDark: Color(hex: 0x9E4A6A),
        textDark: Color(hex: 0x5C1A33),
        textMedium: Color(hex: 0x8B3A5C),
        textLight: Color(hex: 0xB06A8A),
        textMuted: Color(hex: 0xC9879F),
        accentGold: Color(hex: 0xF2A0B5),
        accentGoldBorder: Color(hex: 0xD47A95),
        accentGoldDark: Color(hex: 0xB85A7A),
        toggleOff: Color(hex: 0xC9879F),
        stardewDivider: Color(hex: 0xC46A8A),
        rowEven: Color(hex: 0xFFFAFC),
        rowOdd: Color(hex: 0xFFF0F5),
        rowHover: Color(hex: 0xFFE4ED),
        rowSelected: Color(hex: 0xFFD6E3),
        tableHeader: Color(hex: 0xF5D0DE),
        cardBorder: Color(hex: 0xC46A8A),
        stardewBlueText: Color(hex: 0x2C5F8A)
    )

    // Dark, warm-brown night theme. Body text (textDark/textMedium) clears 4.5:1
    // on every surface; the gold and sidebar labels use the VT323 pixel font at
    // large sizes and clear WCAG AA-large (3:1) on the dark wood and under the
    // cream button text.
    static let night = Palette(
        sidebarWood: Color(hex: 0x1F1610),
        sidebarWoodLight: Color(hex: 0x281C10),
        sidebarWoodDark: Color(hex: 0x130D07),
        parchment: Color(hex: 0x2A1F14),
        parchmentAlt: Color(hex: 0x33261A),
        parchmentHeader: Color(hex: 0x3D2E1F),
        frameBorder: Color(hex: 0x8A6A3C),
        frameBorderDark: Color(hex: 0x5A421F),
        textDark: Color(hex: 0xF2E4CC),
        textMedium: Color(hex: 0xD8C3A0),
        textLight: Color(hex: 0xB89B72),
        textMuted: Color(hex: 0x9C835C),
        accentGold: Color(hex: 0x8F6A30),
        accentGoldBorder: Color(hex: 0xB89050),
        accentGoldDark: Color(hex: 0xD9B878),
        toggleOff: Color(hex: 0x5A4A32),
        stardewDivider: Color(hex: 0x8A6A3C),
        rowEven: Color(hex: 0x2E2216),
        rowOdd: Color(hex: 0x241A10),
        rowHover: Color(hex: 0x3A2C1C),
        rowSelected: Color(hex: 0x46351F),
        tableHeader: Color(hex: 0x3D2E1F),
        cardBorder: Color(hex: 0x8A6A3C),
        stardewBlueText: Color(hex: 0x7EC8E3)
    )

    /// Palette for the active theme, memoized so repeated color lookups during a
    /// render pass don't rebuild it. Rebuilds only when `AppTheme.current` differs
    /// from the last resolved theme.
    private static var cachedTheme: AppTheme?
    private static var cachedPalette = Palette.stardew

    static var current: Palette {
        let theme = AppTheme.current
        if theme != cachedTheme {
            switch theme {
            case .stardew: cachedPalette = .stardew
            case .pink: cachedPalette = .pink
            case .night: cachedPalette = .night
            }
            cachedTheme = theme
        }
        return cachedPalette
    }
}

// MARK: - Stardew Colors

extension Color {
    // Themed roles delegate to the active palette (see `Palette`), preserving the
    // existing `Color.parchment` / `Color.textDark` / ... accessor API.
    static var sidebarWood: Color { Palette.current.sidebarWood }
    static var sidebarWoodLight: Color { Palette.current.sidebarWoodLight }
    static var sidebarWoodDark: Color { Palette.current.sidebarWoodDark }

    static var parchment: Color { Palette.current.parchment }
    static var parchmentAlt: Color { Palette.current.parchmentAlt }
    static var parchmentHeader: Color { Palette.current.parchmentHeader }

    static var frameBorder: Color { Palette.current.frameBorder }
    static var frameBorderDark: Color { Palette.current.frameBorderDark }

    static var textDark: Color { Palette.current.textDark }
    static var textMedium: Color { Palette.current.textMedium }
    static var textLight: Color { Palette.current.textLight }
    static var textMuted: Color { Palette.current.textMuted }

    static var accentGold: Color { Palette.current.accentGold }
    static var accentGoldBorder: Color { Palette.current.accentGoldBorder }
    static var accentGoldDark: Color { Palette.current.accentGoldDark }

    // Game colors (semantic, identical across themes)
    static let stardewGreen = Color(hex: 0x5D8A3C)
    static let stardewGreenDark = Color(hex: 0x4A7030)
    static let stardewPurple = Color(hex: 0x7B4FA2)
    static let stardewPurpleDark = Color(hex: 0x5C3A7A)
    static let stardewOrange = Color(hex: 0xE8891C)
    static let stardewOrangeDark = Color(hex: 0xC07018)
    static let stardewBlue = Color(hex: 0x7EC8E3)
    static let stardewRed = Color(hex: 0xC0392B)

    // Blue text tuned per theme: a dark blue for text on the light tan/pink
    // parchment, and the light 0x7EC8E3 blue on Night. Use `stardewBlue` for the
    // on-dark/background blue that stays constant across themes.
    static var stardewBlueText: Color { Palette.current.stardewBlueText }

    // UI
    static var toggleOff: Color { Palette.current.toggleOff }
    static var stardewDivider: Color { Palette.current.stardewDivider }

    // Table row backgrounds
    static var rowEven: Color { Palette.current.rowEven }
    static var rowOdd: Color { Palette.current.rowOdd }
    static var rowHover: Color { Palette.current.rowHover }
    static var rowSelected: Color { Palette.current.rowSelected }
    static var tableHeader: Color { Palette.current.tableHeader }

    // Card
    static var cardBorder: Color { Palette.current.cardBorder }

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Stardew Toggle Style

struct StardewToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        // The Button gives the whole row a hit area, keyboard activation, and a
        // focus ring; accessibilityRepresentation re-exposes it to VoiceOver as a
        // real switch that announces its on/off value. The pixel-art visual and
        // the 0.15s toggle animation are unchanged.
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                configuration.isOn.toggle()
            }
        } label: {
            HStack {
                configuration.label
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(configuration.isOn ? Color.stardewGreen : Color.toggleOff)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(configuration.isOn ? Color.stardewGreenDark : Color(hex: 0x6B5535), lineWidth: 1)
                        )
                        .frame(width: 34, height: 18)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(configuration.isOn ? Color.parchment : Color(hex: 0xD4C4A8))
                        .frame(width: 14, height: 14)
                        .padding(2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) {
                configuration.label
            }
        }
    }
}

// MARK: - Stardew Icon

enum StardewIconType {
    case chest
    case globe
    case arrowBox
    case gear
    case scroll
    case star
}

struct StardewIcon: View {
    let type: StardewIconType
    var size: CGFloat = 20

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width
            switch type {
            case .chest:
                drawChest(context: context, size: s)
            case .globe:
                drawGlobe(context: context, size: s)
            case .arrowBox:
                drawArrowBox(context: context, size: s)
            case .gear:
                drawGear(context: context, size: s)
            case .scroll:
                drawScroll(context: context, size: s)
            case .star:
                drawStar(context: context, size: s)
            }
        }
        .frame(width: size, height: size)
    }

    private func drawChest(context: GraphicsContext, size: CGFloat) {
        let s = size
        // Chest body
        let body = Path(roundedRect: CGRect(x: s * 0.05, y: s * 0.3, width: s * 0.9, height: s * 0.65), cornerRadius: s * 0.05)
        context.fill(body, with: .color(Color(hex: 0x8B5E3C)))
        context.stroke(body, with: .color(Color(hex: 0x5B3A21)), lineWidth: 1)
        // Lid
        let lid = Path(roundedRect: CGRect(x: s * 0.05, y: s * 0.05, width: s * 0.9, height: s * 0.35), cornerRadius: s * 0.05)
        context.fill(lid, with: .color(Color(hex: 0xA0724A)))
        context.stroke(lid, with: .color(Color(hex: 0x5B3A21)), lineWidth: 1)
        // Upper half lighter
        let upper = Path(CGRect(x: s * 0.05, y: s * 0.3, width: s * 0.9, height: s * 0.25))
        context.fill(upper, with: .color(Color(hex: 0xA0724A)))
        // Gold latch
        let latch = Path(roundedRect: CGRect(x: s * 0.38, y: s * 0.4, width: s * 0.24, height: s * 0.22), cornerRadius: s * 0.03)
        context.fill(latch, with: .color(Color(hex: 0xFFD700)))
        context.stroke(latch, with: .color(Color(hex: 0xB8860B)), lineWidth: 0.5)
    }

    private func drawGlobe(context: GraphicsContext, size: CGFloat) {
        let s = size
        let center = CGPoint(x: s / 2, y: s / 2)
        let r = s * 0.4
        // Globe circle
        let circle = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        context.fill(circle, with: .color(Color(hex: 0x4A90A0)))
        context.stroke(circle, with: .color(Color(hex: 0x2C5F6E)), lineWidth: 1.5)
        // Meridian
        let meridian = Path(ellipseIn: CGRect(x: center.x - r * 0.45, y: center.y - r, width: r * 0.9, height: r * 2))
        context.stroke(meridian, with: .color(Color(hex: 0x2C5F6E)), lineWidth: 0.8)
        // Equator
        var eq = Path()
        eq.move(to: CGPoint(x: center.x - r, y: center.y))
        eq.addLine(to: CGPoint(x: center.x + r, y: center.y))
        context.stroke(eq, with: .color(Color(hex: 0x2C5F6E)), lineWidth: 0.8)
        // Land masses (simplified green patches)
        let land1 = Path(ellipseIn: CGRect(x: s * 0.25, y: s * 0.25, width: s * 0.2, height: s * 0.15))
        context.fill(land1, with: .color(Color(hex: 0x5DAA5A)))
        let land2 = Path(ellipseIn: CGRect(x: s * 0.45, y: s * 0.5, width: s * 0.25, height: s * 0.15))
        context.fill(land2, with: .color(Color(hex: 0x5DAA5A)))
    }

    private func drawArrowBox(context: GraphicsContext, size: CGFloat) {
        let s = size
        // Box/crate
        let box = Path(roundedRect: CGRect(x: s * 0.1, y: s * 0.5, width: s * 0.8, height: s * 0.4), cornerRadius: s * 0.03)
        context.fill(box, with: .color(Color(hex: 0x8B5E3C)))
        context.stroke(box, with: .color(Color(hex: 0x5B3A21)), lineWidth: 1)
        // Inner darker area
        let inner = Path(CGRect(x: s * 0.2, y: s * 0.6, width: s * 0.6, height: s * 0.2))
        context.fill(inner, with: .color(Color(hex: 0x6B4226)))
        // Down arrow
        var arrow = Path()
        arrow.move(to: CGPoint(x: s * 0.5, y: s * 0.08))
        arrow.addLine(to: CGPoint(x: s * 0.5, y: s * 0.5))
        context.stroke(arrow, with: .color(Color(hex: 0xD4A96A)), lineWidth: 2)
        // Arrowhead
        var head = Path()
        head.move(to: CGPoint(x: s * 0.5, y: s * 0.52))
        head.addLine(to: CGPoint(x: s * 0.35, y: s * 0.38))
        head.move(to: CGPoint(x: s * 0.5, y: s * 0.52))
        head.addLine(to: CGPoint(x: s * 0.65, y: s * 0.38))
        context.stroke(head, with: .color(Color(hex: 0xD4A96A)), lineWidth: 2)
    }

    private func drawGear(context: GraphicsContext, size: CGFloat) {
        let s = size
        let center = CGPoint(x: s / 2, y: s / 2)
        // Outer gear body
        let outerCircle = Path(ellipseIn: CGRect(x: center.x - s * 0.3, y: center.y - s * 0.3, width: s * 0.6, height: s * 0.6))
        context.fill(outerCircle, with: .color(.stardewPurple))
        // Inner hole
        let innerCircle = Path(ellipseIn: CGRect(x: center.x - s * 0.12, y: center.y - s * 0.12, width: s * 0.24, height: s * 0.24))
        context.fill(innerCircle, with: .color(.stardewPurpleDark))
        // Teeth (4 cardinal + 4 diagonal)
        let toothSize = s * 0.16
        for angle in stride(from: 0.0, to: 360.0, by: 45.0) {
            let rad = angle * .pi / 180
            let tx = center.x + cos(rad) * s * 0.35 - toothSize / 2
            let ty = center.y + sin(rad) * s * 0.35 - toothSize / 2
            let tooth = Path(CGRect(x: tx, y: ty, width: toothSize, height: toothSize))
            context.fill(tooth, with: .color(.stardewPurple))
        }
    }

    private func drawScroll(context: GraphicsContext, size: CGFloat) {
        let s = size
        // Main scroll body
        let body = Path(roundedRect: CGRect(x: s * 0.15, y: s * 0.1, width: s * 0.7, height: s * 0.8), cornerRadius: s * 0.04)
        context.fill(body, with: .color(Color(hex: 0xE8A84C)))
        context.stroke(body, with: .color(.stardewOrangeDark), lineWidth: 1)
        // Curl top
        let topCurl = Path(ellipseIn: CGRect(x: s * 0.08, y: s * 0.02, width: s * 0.2, height: s * 0.2))
        context.fill(topCurl, with: .color(Color(hex: 0xE8A84C)))
        context.stroke(topCurl, with: .color(.stardewOrangeDark), lineWidth: 1)
        // Curl bottom
        let botCurl = Path(ellipseIn: CGRect(x: s * 0.08, y: s * 0.78, width: s * 0.2, height: s * 0.2))
        context.fill(botCurl, with: .color(Color(hex: 0xE8A84C)))
        context.stroke(botCurl, with: .color(.stardewOrangeDark), lineWidth: 1)
        // Text lines
        for i in 0..<3 {
            let y = s * (0.3 + CGFloat(i) * 0.18)
            let width = s * (0.45 - CGFloat(i) * 0.05)
            let line = Path(CGRect(x: s * 0.28, y: y, width: width, height: s * 0.06))
            context.fill(line, with: .color(Color(hex: 0xC07018).opacity(0.4)))
        }
    }

    private func drawStar(context: GraphicsContext, size: CGFloat) {
        let s = size
        let center = CGPoint(x: s / 2, y: s / 2)
        var star = Path()
        for i in 0..<5 {
            let outerAngle = (CGFloat(i) * 72 - 90) * .pi / 180
            let innerAngle = (CGFloat(i) * 72 + 36 - 90) * .pi / 180
            let outerPoint = CGPoint(x: center.x + cos(outerAngle) * s * 0.45, y: center.y + sin(outerAngle) * s * 0.45)
            let innerPoint = CGPoint(x: center.x + cos(innerAngle) * s * 0.2, y: center.y + sin(innerAngle) * s * 0.2)
            if i == 0 {
                star.move(to: outerPoint)
            } else {
                star.addLine(to: outerPoint)
            }
            star.addLine(to: innerPoint)
        }
        star.closeSubpath()
        context.fill(star, with: .color(Color(hex: 0xFFD700)))
        context.stroke(star, with: .color(Color(hex: 0xB8860B)), lineWidth: 0.5)
    }
}

// MARK: - Junimo Icon

struct JunimoIcon: View {
    let name: String
    var size: CGFloat = 20

    // Junimo PNGs cached by name so re-renders don't re-read them from disk. NSCache is
    // thread-safe and may evict under memory pressure (in which case it reloads on demand).
    private static let cache = NSCache<NSString, NSImage>()

    private static func image(named name: String) -> NSImage? {
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let url = Bundle.appBundle.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    var body: some View {
        if let nsImage = Self.image(named: name) {
            Image(nsImage: nsImage)
                .renderingMode(.original)
                .resizable()
                .interpolation(.none)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "play.fill")
                .font(.system(size: size * 0.7))
        }
    }
}

// MARK: - Stardew Segmented Picker

struct StardewSegmentedPicker<T: Hashable & Identifiable & CaseIterable>: View where T.AllCases: RandomAccessCollection {
    @Binding var selection: T
    let label: (T) -> String

    var body: some View {
        let allItems = Array(T.allCases)
        HStack(spacing: 0) {
            ForEach(Array(allItems.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Color.accentGoldBorder.opacity(0.3)
                        .frame(width: 1)
                        .padding(.vertical, 6)
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = item
                    }
                } label: {
                    Text(label(item))
                        .font(.stardew(size: 18))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            selection == item
                                ? RoundedRectangle(cornerRadius: 4).fill(Color.accentGold)
                                    .padding(4)
                                : nil
                        )
                        .foregroundStyle(
                            selection == item
                                ? Color.textDark
                                : Color.textMuted
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.parchmentAlt)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.frameBorder, lineWidth: 2)
                )
        )
    }
}
