import SwiftUI

/// اسم المطوّر بالذهبي العريض مع لمعان متحرك
struct DevCredit: View {
    private let gold = LinearGradient(
        colors: [Color(red: 1.0, green: 0.90, blue: 0.50), Color(red: 0.88, green: 0.64, blue: 0.14)],
        startPoint: .top, endPoint: .bottom)

    var body: some View {
        VStack(spacing: 2) {
            Text("إعداد وتطوير")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(red: 1.0, green: 0.87, blue: 0.5).opacity(0.85))
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let phase = (t.truncatingRemainder(dividingBy: 2.6)) / 2.6   // 0...1
                Text("راشد الشمِّري")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(gold)
                    .overlay(
                        GeometryReader { geo in
                            LinearGradient(
                                colors: [.clear, Color.white.opacity(0.95), .clear],
                                startPoint: .leading, endPoint: .trailing)
                                .frame(width: geo.size.width * 0.35)
                                .offset(x: -geo.size.width * 0.35 + (geo.size.width * 1.35) * phase)
                                .blendMode(.plusLighter)
                        }
                        .mask(Text("راشد الشمِّري").font(.system(size: 30, weight: .black)))
                    )
                    .shadow(color: Color(red: 0.95, green: 0.70, blue: 0.15).opacity(0.6), radius: 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
        .padding(.bottom, 96)
        .environment(\.layoutDirection, .rightToLeft)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("إعداد وتطوير راشد الشمِّري")
    }
}
