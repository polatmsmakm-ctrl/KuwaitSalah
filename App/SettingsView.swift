import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            Form {
                Section("المنطقة") {
                    Picker("المحافظة", selection: $store.prefs.regionID) {
                        ForEach(Region.all) { r in
                            Text(r.name).tag(r.id)
                        }
                    }
                }

                Section {
                    ForEach(Array(Prayer.fivePrayers.enumerated()), id: \.offset) { idx, p in
                        Stepper(value: $store.prefs.iqama[idx], in: 0...60) {
                            HStack {
                                Text(p.arabicName)
                                Spacer()
                                Text("\(store.fmt.number(store.prefs.iqama[idx])) دقيقة")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                    Button("القيم الافتراضية") {
                        store.prefs.iqama = Iqama.defaults
                    }
                } header: {
                    Text("الإقامة بعد الأذان")
                } footer: {
                    Text("اضبطها حسب مسجدك. تظهر في الصفحة الرئيسية وفي الإشعارات.")
                }

                Section {
                    Stepper(value: $store.prefs.calc.fajrAngle, in: 14...20, step: 0.5) {
                        HStack {
                            Text("زاوية الفجر")
                            Spacer()
                            Text(store.fmt.digits(String(format: "%.1f", store.prefs.calc.fajrAngle)) + "°")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Stepper(value: $store.prefs.calc.ishaAngle, in: 14...20, step: 0.5) {
                        HStack {
                            Text("زاوية العشاء")
                            Spacer()
                            Text(store.fmt.digits(String(format: "%.1f", store.prefs.calc.ishaAngle)) + "°")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Picker("العصر", selection: $store.prefs.calc.hanafiAsr) {
                        Text("المثل (جمهور)").tag(false)
                        Text("المثلين (حنفي)").tag(true)
                    }
                    Button("إعادة ضبط طريقة الكويت") {
                        store.prefs.calc.fajrAngle = 18
                        store.prefs.calc.ishaAngle = 17.5
                        store.prefs.calc.hanafiAsr = false
                    }
                } header: {
                    Text("طريقة الحساب")
                } footer: {
                    Text("الحساب فلكي داخل التطبيق بدون إنترنت (فجر ١٨° وعشاء ١٧٫٥°). إذا اختلف وقت عن تقويم الأوقاف عدّله بالدقائق من الأسفل.")
                }

                Section("تعديل الدقائق") {
                    ForEach(Prayer.allCases) { p in
                        Stepper(value: $store.prefs.calc.adjust[p.rawValue], in: -15...15) {
                            HStack {
                                Text(p.arabicName)
                                Spacer()
                                Text(adjustText(store.prefs.calc.adjust[p.rawValue]))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                Section("العرض") {
                    Toggle("نظام ٢٤ ساعة", isOn: $store.prefs.use24h)
                    Toggle("أرقام عربية (٠١٢٣)", isOn: $store.prefs.arabicDigits)
                    Picker("تصحيح التاريخ الهجري", selection: $store.prefs.hijriOffset) {
                        Text("-١ يوم").tag(-1)
                        Text("بدون").tag(0)
                        Text("+١ يوم").tag(1)
                    }
                }

                Section {
                    if authStatus != .authorized && authStatus != .provisional {
                        Button("تفعيل الإشعارات") {
                            Task {
                                await Notifier.requestAuth()
                                authStatus = await Notifier.status()
                                store.refreshNotifications()
                            }
                        }
                    }
                    ForEach(Array(Prayer.fivePrayers.enumerated()), id: \.offset) { idx, p in
                        Toggle(p.arabicName, isOn: $store.prefs.adhanOn[idx])
                    }
                    Toggle("الشروق", isOn: $store.prefs.notifySunrise)
                    Toggle("تنبيه الإقامة", isOn: $store.prefs.notifyIqama)
                    Picker("تنبيه قبل الأذان", selection: $store.prefs.preMinutes) {
                        Text("بدون").tag(0)
                        Text("٥ دقائق").tag(5)
                        Text("١٠ دقائق").tag(10)
                        Text("١٥ دقيقة").tag(15)
                        Text("٣٠ دقيقة").tag(30)
                    }
                } header: {
                    Text("الإشعارات")
                } footer: {
                    Text("تُجدول الإشعارات لأسبوع قادم وتتجدد كل ما فتحت التطبيق. افتحه مرة بالأسبوع على الأقل.")
                }
            }
            .navigationTitle("الإعدادات")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                authStatus = await Notifier.status()
            }
        }
    }

    private func adjustText(_ v: Int) -> String {
        let f = store.fmt
        if v == 0 { return f.digits("0") + " د" }
        let sign = v > 0 ? "+" : "-"
        return "\(sign)\(f.number(abs(v))) د"
    }
}
