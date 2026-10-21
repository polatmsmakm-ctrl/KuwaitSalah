import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(kind: .more)
                ScrollView {
                    VStack(spacing: 10) {
                        row("الأحاديث: البخاري ومسلم", "text.book.closed.fill") { HadithHomeView() }
                        row("الجدول الشهري", "calendar") { TimetableView() }
                        row("الإحصائيات", "chart.bar.fill") { StatsView() }
                        row("الإعدادات", "gearshape.fill") { SettingsView() }
                        VStack(spacing: 4) {
                            Text("تطوير")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.inkSecondary)
                            Text("راشد الشمِّري")
                                .font(.system(size: 34, weight: .black))
                                .foregroundStyle(LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.87, blue: 0.40),
                                             Color(red: 0.85, green: 0.62, blue: 0.14)],
                                    startPoint: .top, endPoint: .bottom))
                                .shadow(color: Color(red: 0.85, green: 0.62, blue: 0.14).opacity(0.55), radius: 6)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 26)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("المزيد")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row<D: View>(_ title: String, _ symbol: String, @ViewBuilder _ dest: () -> D) -> some View {
        NavigationLink {
            dest()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.title3).foregroundStyle(Theme.accent).frame(width: 34)
                Text(title).font(.system(size: 18, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.left").foregroundStyle(Theme.inkSecondary)
            }
            .foregroundStyle(Theme.ink)
            .padding(14)
            .glassCard(18)
        }
        .buttonStyle(.plain)
    }
}

/// تبويب الأذكار والمسبحة
struct AdhkarTab: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $store.adhkarMode) {
                Text("الأذكار").tag(0)
                Text("المسبحة").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppBackground(kind: .more))
            if store.adhkarMode == 0 {
                AdhkarListView()
            } else {
                TasbihView()
            }
        }
    }
}
