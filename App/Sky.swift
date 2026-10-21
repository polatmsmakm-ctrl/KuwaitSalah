import SwiftUI

private func fracPart(_ v: Double) -> Double { v - floor(v) }

/// نجوم تلمع بهدوء
struct StarField: View {
    var intensity: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { ctx in
            Canvas { gc, size in
                let t = ctx.date.timeIntervalSinceReferenceDate
                for i in 0..<80 {
                    let seed = Double(i)
                    let x = fracPart(sin(seed * 12.9898) * 43758.5453) * size.width
                    let y = fracPart(sin(seed * 78.233) * 12543.1234) * size.height * 0.75
                    let tw = 0.5 + 0.5 * sin(t * (0.7 + fracPart(seed * 0.37)) + seed)
                    let r = 0.8 + fracPart(seed * 0.91) * 1.7
                    gc.opacity = intensity * (0.2 + 0.8 * tw)
                    gc.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// خلفية السماء حسب وقت اليوم
struct SkyBackground: View {
    let now: Date
    let today: DayTimes

    var body: some View {
        ZStack {
            Theme.gradient(now: now, today: today)
            Circle()
                .fill(Theme.gold.opacity(0.14))
                .frame(width: 300, height: 300)
                .blur(radius: 70)
                .offset(x: 110, y: -260)
            StarField(intensity: Theme.starIntensity(now: now, today: today))
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.0), value: Theme.starIntensity(now: now, today: today))
    }
}

/// خلفية ليلية ثابتة للشاشات الأخرى
struct NightBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: Theme.night, startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(Theme.gold.opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: -110, y: -280)
            StarField(intensity: 1.0)
        }
        .ignoresSafeArea()
    }
}

extension View {
    func glassCard(_ radius: CGFloat = 22) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.white.opacity(0.12), lineWidth: 1))
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
