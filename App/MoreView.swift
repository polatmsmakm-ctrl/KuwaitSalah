import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 10) {
                        row("الجدول الشهري", "calendar") { TimetableView() }
                        row("الإحصائيات", "chart.bar.fill") { StatsView() }
                        row("الإعدادات", "gearshape.fill") { SettingsView() }
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
            .background(AppBackground())
            if store.adhkarMode == 0 {
                AdhkarListView()
            } else {
                TasbihView()
            }
        }
    }
}
