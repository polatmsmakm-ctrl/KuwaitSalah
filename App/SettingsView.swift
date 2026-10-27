import SwiftUI
import UserNotifications
import UIKit

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @EnvironmentObject var locator: LocationHelper
    @AppStorage("liveactivity.on") private var liveOn = true
    @AppStorage("adhan.customSound") private var customSound = true

    var body: some View {
        Form {
                Section {
                    Picker("تحديد الموقع", selection: $store.prefs.locMode) {
                        Text("تلقائي (حسب موقعي)").tag(0)
                        Text("محافظة في الكويت").tag(1)
                        Text("مدينة أخرى").tag(2)
                    }
                    if store.prefs.locMode == 0 {
                        Button {
                            locator.detect(force: true)
                        } label: {
                            Label("تحديث موقعي الآن", systemImage: "location.fill")
                        }
                        Text("الموقع الحالي: \(store.region.label)").font(.footnote)
                    } else if store.prefs.locMode == 1 {
                        Picker("المحافظة", selection: $store.prefs.regionID) {
                            ForEach(Region.all) { r in Text(r.name).tag(r.id) }
                        }
                    } else {
                        Picker("المدينة", selection: $store.prefs.cityID) {
                            ForEach(Region.cities) { r in Text(r.name).tag(r.id) }
                        }
                    }
                    if let msg = locationMessage {
                        Text(msg).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("الموقع")
                } footer: {
                    Text("الأوقات واتجاه القبلة تُحسب حسب موقعك (السعودية، الكويت، لبنان وغيرها) وبتوقيت بلدك. الموقع يُطلب عند فتح التطبيق ولا يُرسل لأي جهة.")
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
                    Toggle("حسب طريقة بلدي تلقائياً", isOn: $store.prefs.calcAuto)
                    if !store.prefs.calcAuto {
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
                    }
                    Picker("العصر", selection: $store.prefs.calc.hanafiAsr) {
                        Text("المثل (جمهور)").tag(false)
                        Text("المثلين (حنفي)").tag(true)
                    }
                    if !store.prefs.calcAuto {
                    Button("إعادة ضبط طريقة الكويت") {
                        store.prefs.calc.fajrAngle = 18
                        store.prefs.calc.ishaAngle = 17.5
                        store.prefs.calc.hanafiAsr = false
                    }
                    }
                } header: {
                    Text("طريقة الحساب")
                } footer: {
                    Text("الحساب فلكي داخل التطبيق بدون إنترنت. التلقائي: الكويت (فجر ١٨° وعشاء ١٧٫٥°)، السعودية والخليج (أم القرى)، لبنان والشام (رابطة العالم الإسلامي)، مصر (الهيئة المصرية). إذا اختلف وقت عن تقويم بلدك عدّله بالدقائق من الأسفل.")
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
                    Toggle("الصلاة القادمة على شاشة القفل", isOn: $liveOn)
                    Toggle("صوت مخصص لإشعار الأذان", isOn: $customSound)
                    Toggle("تتبع الصلوات والإحصائيات", isOn: $store.prefs.statsEnabled)
                    Toggle("نظام ٢٤ ساعة", isOn: $store.prefs.use24h)
                    Toggle("أرقام عربية (٠١٢٣)", isOn: $store.prefs.arabicDigits)
                    Picker("تصحيح التاريخ الهجري", selection: $store.prefs.hijriOffset) {
                        Text("-١ يوم").tag(-1)
                        Text("بدون").tag(0)
                        Text("+١ يوم").tag(1)
                    }
                }

                Section {
                    if authStatus == .denied {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("الإشعارات معطّلة، افتح إعدادات الجهاز لتفعيلها", systemImage: "bell.slash.fill")
                        }
                    } else if authStatus != .authorized && authStatus != .provisional {
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
        .scrollContentBackground(.hidden)
        .background(AppBackground(kind: .more))
        .navigationTitle("الإعدادات")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            authStatus = await Notifier.status()
        }
    }

    private var locationMessage: String? {
        switch locator.status {
        case .idle: return nil
        case .locating: return "جارٍ تحديد الموقع…"
        case .denied: return "صلاحية الموقع مرفوضة. اختر المدينة يدوياً أو فعّل الموقع من إعدادات الجهاز."
        case .failed: return "تعذّر تحديد الموقع. اختر المدينة يدوياً."
        case .found(let n): return "تم اختيار: \(n)"
        }
    }

    private func adjustText(_ v: Int) -> String {
        let f = store.fmt
        if v == 0 { return f.digits("0") + " د" }
        let sign = v > 0 ? "+" : "-"
        return "\(sign)\(f.number(abs(v))) د"
    }
}
