import SwiftUI

struct TasbihView: View {
    @EnvironmentObject var store: Store
    @AppStorage("tasbih.count") private var count: Int = 0
    @AppStorage("tasbih.target") private var target: Int = 33
    @AppStorage("tasbih.phrase") private var phraseIndex: Int = 0
    @AppStorage("tasbih.total") private var total: Int = 0

    private let phrases = ["سبحان الله", "الحمد لله", "الله أكبر", "لا إله إلا الله", "أستغفر الله", "اللهم صل على محمد"]

    private var beadCount: Int { target > 0 ? target : 33 }
    private var filled: Int { target > 0 ? count : count % 33 }

    var body: some View {
        let fmt = store.fmt
        let phrase = phrases[min(max(phraseIndex, 0), phrases.count - 1)]
        let n = beadCount
        let beadSize: CGFloat = n > 40 ? 5 : 10

        ZStack {
            AppBackground()
            VStack(spacing: 22) {
                Menu {
                    ForEach(0..<phrases.count, id: \.self) { i in
                        Button(phrases[i]) { phraseIndex = i }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(phrase).font(.system(size: 30, weight: .bold))
                        Image(systemName: "chevron.down").font(.footnote)
                    }
                    .foregroundStyle(Theme.gold)
                    .shadow(color: Theme.gold.opacity(0.5), radius: 10)
                }

                Picker("الهدف", selection: $target) {
                    Text("٣٣").tag(33)
                    Text("٩٩").tag(99)
                    Text("١٠٠").tag(100)
                    Text("حر").tag(0)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 30)

                Button {
                    count += 1
                    total += 1
                    if target > 0 && count > target { count = 1 }
                } label: {
                    ZStack {
                        ForEach(0..<n, id: \.self) { i in
                            let on = i < filled
                            Circle()
                                .fill(on ? Theme.gold : Color.primary.opacity(0.18))
                                .frame(width: beadSize, height: beadSize)
                                .shadow(color: on ? Theme.gold.opacity(0.8) : Color.clear, radius: 4)
                                .offset(y: -138)
                                .rotationEffect(.degrees(360.0 * Double(i) / Double(n)))
                        }
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 236, height: 236)
                        Circle()
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                            .frame(width: 236, height: 236)
                        VStack(spacing: 4) {
                            Text(fmt.number(count))
                                .font(.system(size: 78, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: count)
                            if target > 0 {
                                Text("من \(fmt.number(target))")
                                    .font(.callout)
                                    .opacity(0.7)
                            }
                        }
                    }
                    .frame(width: 300, height: 300)
                }
                .buttonStyle(PressStyle())
                .sensoryFeedback(.impact, trigger: count)

                Text("المجموع \(fmt.number(total))")
                    .font(.footnote)
                    .opacity(0.65)

                Button {
                    count = 0
                } label: {
                    Label("تصفير", systemImage: "arrow.counterclockwise")
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .glassCard(30)
                }
                .buttonStyle(PressStyle())
            }
            .foregroundStyle(Theme.ink)
        }
    }
}
