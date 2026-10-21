import SwiftUI
import UIKit

/// خلفيات الفضاء: صورة لكل قسم مع طبقة تعتيم لوضوح النص
struct AppBackground: View {
    enum Kind {
        case home, quran, adhkar, qibla, more

        var file: String {
            switch self {
            case .home: return "bg_pillar"
            case .quran: return "bg_eagle"
            case .adhkar: return "bg_milkyway"
            case .qibla: return "bg_jwst"
            case .more: return "bg_milkyway"
            }
        }
    }

    var kind: Kind = .more
    var dim: Double = 0.45

    private static var cache: [String: UIImage] = [:]

    private var image: UIImage? {
        if let c = Self.cache[kind.file] { return c }
        guard let p = Bundle.main.path(forResource: kind.file, ofType: "jpg"),
              let img = UIImage(contentsOfFile: p) else { return nil }
        Self.cache[kind.file] = img
        return img
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: Theme.night, startPoint: .top, endPoint: .bottom)
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .accessibilityHidden(true)
            }
            LinearGradient(colors: [Color.black.opacity(dim + 0.1), Color.black.opacity(dim)],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }
}

extension View {
    func glassCard(_ radius: CGFloat = 22) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.primary.opacity(0.10), lineWidth: 1))
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// مسار الشمس (نهاراً) أو القمر (ليلاً) في السماء
struct SkyArc: View {
    let progress: Double
    let isDay: Bool
    let leftLabel: String
    let rightLabel: String

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let r = min(w / 2 - 30, 150.0)
            let cx = w / 2
            let cy = geo.size.height - 30
            let p = min(1.0, max(0.0, progress))
            let th = Double.pi * (1.0 - p)
            let pos = CGPoint(x: cx + r * cos(th), y: cy - r * sin(th))

            ZStack {
                Path { path in
                    for i in 0...60 {
                        let a = Double.pi * (1.0 - Double(i) / 60.0)
                        let pt = CGPoint(x: cx + r * cos(a), y: cy - r * sin(a))
                        if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                    }
                }
                .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [3, 7]))

                Path { path in
                    path.move(to: CGPoint(x: cx - r - 18, y: cy))
                    path.addLine(to: CGPoint(x: cx + r + 18, y: cy))
                }
                .stroke(Color.white.opacity(0.25), lineWidth: 1)

                Image(systemName: isDay ? "sun.max.fill" : "moon.stars.fill")
                    .font(.title)
                    .foregroundStyle(Theme.gold)
                    .shadow(color: Theme.gold.opacity(0.9), radius: 14)
                    .position(pos)

                Text(leftLabel)
                    .font(.caption2)
                    .opacity(0.8)
                    .position(x: cx - r, y: cy + 16)
                Text(rightLabel)
                    .font(.caption2)
                    .opacity(0.8)
                    .position(x: cx + r, y: cy + 16)
            }
        }
        .frame(height: 150)
    }
}
