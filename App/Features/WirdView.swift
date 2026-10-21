import SwiftUI

struct WirdView: View {
    @EnvironmentObject var wird: WirdStore
    @EnvironmentObject var store: Store

    private var reminderDate: Binding<Date> {
        Binding(
            get: {
                var c = DateComponents()
                c.hour = wird.state.reminderHour
                c.minute = wird.state.reminderMinute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                wird.state.reminderHour = c.hour ?? 20
                wird.state.reminderMinute = c.minute ?? 0
                wird.updateReminder()
            })
    }

    var body: some View {
        let fmt = store.fmt
        ZStack {
            AppBackground(kind: .quran, dim: 0.55)
            ScrollView {
                VStack(spacing: 14) {
                    ring(fmt)
                    todayCard(fmt)
                    NavigationLink(value: MushafTarget(page: wird.nextPage, focus: nil)) {
                        HStack {
                            Image(systemName: "book.pages.fill")
                            Text("تابع الورد من صفحة \(fmt.number(wird.nextPage))")
                                .font(.system(size: 17, weight: .bold))
                            Spacer()
                            Image(systemName: "chevron.left")
                        }
                        .foregroundStyle(Color.black.opacity(0.85))
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Theme.gold, in: RoundedRectangle(cornerRadius: 18))
                    }
                    planCard(fmt)
                    juzCard(fmt)
                    Button(role: .destructive) { wird.reset() } label: {
                        Text("بدء ختمة جديدة من الصفر").font(.footnote)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }
        }
        .navigationTitle("الختمة والورد")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func ring(_ fmt: Fmt) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: max(0.005, wird.progress))
                    .stroke(Theme.gold, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(fmt.number(Int((wird.progress * 100).rounded())))٪")
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle(Theme.gold)
                    Text("\(fmt.number(wird.readCount)) من \(fmt.number(WirdStore.totalPages)) صفحة")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .frame(width: 170, height: 170)
            HStack(spacing: 18) {
                Label("\(fmt.number(wird.state.khatmat)) ختمة", systemImage: "checkmark.seal.fill")
                if let d = wird.projectedDaysLeft {
                    Label("تختم بعد \(fmt.number(d)) يوم تقريباً", systemImage: "calendar")
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassCard(20)
    }

    private func todayCard(_ fmt: Fmt) -> some View {
        let goal = wird.dailyGoal
        let done = wird.pagesToday
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ورد اليوم").font(.headline)
                Spacer()
                Text("\(fmt.number(done)) / \(fmt.number(goal)) صفحة")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(done >= goal ? Color.green : Theme.accent)
            }
            ProgressView(value: min(1, Double(done) / Double(goal)))
                .tint(done >= goal ? Color.green : Theme.gold)
            Text(done >= goal ? "ما شاء الله، أتممت وردك اليوم" : "تُحسب الصفحة إذا بقيت فيها بضع ثوانٍ.")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
        }
        .foregroundStyle(Theme.ink)
        .padding(14)
        .glassCard(18)
    }

    private func planCard(_ fmt: Fmt) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("خطة الختمة").font(.headline)
            Picker("المدة", selection: Binding(get: { wird.state.targetDays },
                                               set: { wird.state.targetDays = $0; wird.updateReminder() })) {
                ForEach(WirdStore.dayOptions, id: \.self) { d in
                    Text("ختمة في \(fmt.number(d)) يوم").tag(d)
                }
            }
            .pickerStyle(.menu)
            Text("الهدف اليومي: \(fmt.number(wird.dailyGoal)) صفحة")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
            Toggle("تذكير يومي بالورد", isOn: Binding(get: { wird.state.reminderOn },
                                                      set: { wird.state.reminderOn = $0; wird.updateReminder() }))
            if wird.state.reminderOn {
                DatePicker("وقت التذكير", selection: reminderDate, displayedComponents: .hourAndMinute)
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(14)
        .glassCard(18)
    }

    private func juzCard(_ fmt: Fmt) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("الأجزاء").font(.headline)
            ForEach(0..<30, id: \.self) { j in
                let p = wird.juzProgress(j)
                HStack(spacing: 10) {
                    Text("الجزء \(fmt.number(j + 1))").font(.caption).frame(width: 64, alignment: .leading)
                    ProgressView(value: Double(p.read), total: Double(max(1, p.total)))
                        .tint(p.read == p.total ? Color.green : Theme.gold)
                    Text("\(fmt.number(p.read))/\(fmt.number(p.total))")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(width: 48, alignment: .trailing)
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(14)
        .glassCard(18)
    }
}
