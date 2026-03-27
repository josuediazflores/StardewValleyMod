import SwiftUI
import CoreText

// MARK: - Font Registration

func registerStardewFonts() {
    guard let fontURL = Bundle.module.url(forResource: "VT323-Regular", withExtension: "ttf") else {
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

// MARK: - Stardew Colors

extension Color {
    // Sidebar wood tones
    static let sidebarWood = Color(hex: 0x5B3A21)
    static let sidebarWoodLight = Color(hex: 0x6B4226)
    static let sidebarWoodDark = Color(hex: 0x3E2218)

    // Parchment backgrounds
    static let parchment = Color(hex: 0xFFF8E1)
    static let parchmentAlt = Color(hex: 0xF5EDD5)
    static let parchmentHeader = Color(hex: 0xEDE0C8)

    // Text browns
    static let textDark = Color(hex: 0x3E2218)
    static let textMedium = Color(hex: 0x5B3A21)
    static let textLight = Color(hex: 0x7A6344)
    static let textMuted = Color(hex: 0xA0855C)

    // Accent gold
    static let accentGold = Color(hex: 0xD4A96A)
    static let accentGoldBorder = Color(hex: 0xB8842A)
    static let accentGoldDark = Color(hex: 0x8B6914)

    // Game colors
    static let stardewGreen = Color(hex: 0x5D8A3C)
    static let stardewGreenDark = Color(hex: 0x4A7030)
    static let stardewPurple = Color(hex: 0x7B4FA2)
    static let stardewPurpleDark = Color(hex: 0x5C3A7A)
    static let stardewOrange = Color(hex: 0xE8891C)
    static let stardewOrangeDark = Color(hex: 0xC07018)
    static let stardewBlue = Color(hex: 0x7EC8E3)
    static let stardewRed = Color(hex: 0xC0392B)

    // UI
    static let toggleOff = Color(hex: 0x8B7355)
    static let stardewDivider = Color(hex: 0xC9B896)

    fileprivate init(hex: UInt32) {
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
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    configuration.isOn.toggle()
                }
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

    var body: some View {
        if let url = Bundle.module.url(forResource: name, withExtension: "png"),
           let nsImage = NSImage(contentsOf: url) {
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
                    Color.accentGoldBorder.opacity(0.4)
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
                        .padding(.horizontal, 14)
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
                                : Color.textLight
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
