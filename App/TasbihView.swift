import SwiftUI

struct TasbihView: View {
    @EnvironmentObject var store: Store
    @AppStorage("tasbih.count") private var count: Int = 0
    @AppStorage("tasbih.target") private var target: Int = 33
    @AppStorage("tasbih.phrase") private var phraseIndex: Int = 0
    @AppStorage("tasbih.total") private var total: Int = 0

    private let phrases = ["سبحان الله", "الحمد لله", "الله أكبر", "لا إله إلا الله", "أستغفر الله", "اللهم صل على محمد"]

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(count) / Double(target))
    }

    var body: some View {
        let fmt = store.fmt
        let phrase = phrases[min(max(phraseIndex, 0), phrases.count - 1)]

        ZStack {
            LinearGradient(colors: Theme.night, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 22) {
                Menu {
                    ForEach(0..<phrases.count, id: \.self) { i in
                        Button(phrases[i]) { phraseIndex = i }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(phrase).font(.system(size: 28, weight: .bold))
                        Image(systemName: "chevron.down").font(.footnote)
                    }
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
                        Circle().fill(.ultraThinMaterial)
                        Circle().stroke(Color.white.opacity(0.15), lineWidth: 12)
                        Circle()
                            .trim(from: 0, to: target > 0 ? progress : 1)
                            .stroke(Theme.gold, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 4) {
                            Text(fmt.number(count))
                                .font(.system(size: 76, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            if target > 0 {
                                Text("من \(fmt.number(target))")
                                    .font(.callout)
                                    .opacity(0.7)
                            }
                        }
                    }
                    .frame(width: 270, height: 270)
                }
                .buttonStyle(.plain)
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
                        .background(Color.white.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
        }
    }
}
