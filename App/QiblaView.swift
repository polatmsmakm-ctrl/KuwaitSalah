import SwiftUI
import CoreLocation
import UIKit

final class HeadingProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var heading: Double = 0
    @Published var available: Bool = CLLocationManager.headingAvailable()
    @Published var gotReading: Bool = false

    private let manager = CLLocationManager()
    /// الانحراف المغناطيسي التقريبي في الكويت
    private let declination: Double = 4.5

    override init() {
        super.init()
        manager.delegate = self
        manager.headingFilter = 1
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stop() {
        manager.stopUpdatingHeading()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let h = (newHeading.magneticHeading + declination).truncatingRemainder(dividingBy: 360.0)
        DispatchQueue.main.async {
            self.heading = h
            self.gotReading = true
        }
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }
}

struct QiblaView: View {
    @EnvironmentObject var store: Store
    @StateObject private var hp = HeadingProvider()

    private func normalized(_ a: Double) -> Double {
        var d = a.truncatingRemainder(dividingBy: 360.0)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }

    var body: some View {
        let fmt = store.fmt
        let bearing = PrayerCalc.qiblaBearing(lat: store.region.lat, lng: store.region.lng)
        let diff = normalized(bearing - hp.heading)
        let aligned = hp.gotReading && abs(diff) < 3

        ZStack {
            AppBackground(kind: .qibla)
            VStack(spacing: 26) {
                Text("اتجاه القبلة")
                    .font(.system(size: 30, weight: .bold))
                    .shadow(color: Color.black.opacity(0.3), radius: 6)

                CompassDial(heading: hp.heading, bearing: bearing, aligned: aligned)

                VStack(spacing: 8) {
                    if !hp.available {
                        Text("البوصلة غير متوفرة على هذا الجهاز")
                            .font(.title3.weight(.semibold))
                        Text("اتجاه القبلة المحسوب \(fmt.number(Int(bearing.rounded())))° من الشمال؛ استخدم بوصلة خارجية أو ابحث عن الشمال.")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    } else if !hp.gotReading {
                        Text("جارٍ قراءة البوصلة…")
                    } else if aligned {
                        Text("أنت باتجاه القبلة")
                            .font(.title2.bold())
                            .foregroundStyle(Color.green)
                    } else {
                        Text(diff > 0 ? "أدر الجهاز لليمين" : "أدر الجهاز لليسار")
                            .font(.title3.weight(.semibold))
                    }
                    Text("القبلة \(fmt.number(Int(bearing.rounded())))° من الشمال · محسوبة لـ\(store.region.name)")
                        .font(.footnote)
                        .opacity(0.7)
                    Text("ابعد الجهاز عن المعادن والمغناطيس، وحرّكه على شكل ٨ للمعايرة.")
                        .font(.caption)
                        .opacity(0.55)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                DevCredit().padding(.top, -8).padding(.bottom, -60)
            }
            .foregroundStyle(Theme.ink)
        }
        .onAppear { hp.start() }
        .onDisappear { hp.stop() }
        .onChange(of: aligned) { _, isAligned in
            if isAligned {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}

struct CompassDial: View {
    let heading: Double
    let bearing: Double
    let aligned: Bool

    private let cardinals: [(String, Double)] = [("ش", 0), ("شرق", 90), ("ج", 180), ("غرب", 270)]

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 290, height: 290)
            Circle()
                .stroke(
                    AngularGradient(colors: [Theme.gold, Theme.gold.opacity(0.25), Theme.gold],
                                    center: .center),
                    lineWidth: 3
                )
                .frame(width: 290, height: 290)
            Circle()
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                .frame(width: 190, height: 190)

            ZStack {
                ForEach(0..<72, id: \.self) { i in
                    let major = i % 6 == 0
                    Rectangle()
                        .fill(Theme.ink.opacity(major ? 0.9 : 0.35))
                        .frame(width: major ? 3 : 1.5, height: major ? 14 : 8)
                        .offset(y: -132)
                        .rotationEffect(.degrees(Double(i) * 5.0))
                }

                ForEach(0..<4, id: \.self) { i in
                    Text(cardinals[i].0)
                        .font(.system(size: i == 0 ? 17 : 13, weight: .bold))
                        .foregroundStyle(i == 0 ? Color.red.opacity(0.9) : Theme.ink.opacity(0.8))
                        .rotationEffect(.degrees(-cardinals[i].1))
                        .offset(y: -106)
                        .rotationEffect(.degrees(cardinals[i].1))
                }

                ZStack {
                    Rectangle()
                        .fill(LinearGradient(colors: [Theme.gold, Theme.gold.opacity(0.0)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 3, height: 90)
                        .offset(y: -62)
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.gold)
                        .shadow(color: Theme.gold, radius: 10)
                        .offset(y: -86)
                }
                .rotationEffect(.degrees(bearing))
            }
            .rotationEffect(.degrees(-heading))
            .animation(.easeOut(duration: 0.15), value: heading)

            Image(systemName: "arrowtriangle.down.fill")
                .font(.title3)
                .foregroundStyle(aligned ? Color.green : Theme.ink)
                .offset(y: -160)

            Circle()
                .fill(aligned ? Color.green : Theme.ink.opacity(0.85))
                .frame(width: 12, height: 12)
        }
        .frame(width: 320, height: 320)
        .shadow(color: aligned ? Color.green.opacity(0.7) : Color.clear, radius: 24)
        .animation(.easeInOut(duration: 0.3), value: aligned)
    }
}
