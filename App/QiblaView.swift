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
            LinearGradient(colors: Theme.night, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 28) {
                Text("اتجاه القبلة")
                    .font(.system(size: 28, weight: .bold))

                CompassDial(heading: hp.heading, bearing: bearing, aligned: aligned)

                VStack(spacing: 8) {
                    if !hp.available {
                        Text("البوصلة غير متوفرة على هذا الجهاز")
                    } else if !hp.gotReading {
                        Text("جارٍ قراءة البوصلة…")
                    } else if aligned {
                        Text("أنت باتجاه القبلة")
                            .font(.title3.bold())
                            .foregroundStyle(Color.green)
                    } else {
                        Text(diff > 0 ? "أدر الجهاز لليمين" : "أدر الجهاز لليسار")
                            .font(.title3.weight(.semibold))
                    }
                    Text("القبلة \(fmt.number(Int(bearing.rounded())))° من الشمال")
                        .font(.footnote)
                        .opacity(0.7)
                    Text("ابعد الجهاز عن المعادن والمغناطيس، وحرّكه على شكل ٨ للمعايرة.")
                        .font(.caption)
                        .opacity(0.55)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
            }
            .foregroundStyle(.white)
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

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 290, height: 290)

            ZStack {
                ForEach(0..<72, id: \.self) { i in
                    let major = i % 6 == 0
                    Rectangle()
                        .fill(Color.white.opacity(major ? 0.9 : 0.35))
                        .frame(width: major ? 3 : 1.5, height: major ? 14 : 8)
                        .offset(y: -138)
                        .rotationEffect(.degrees(Double(i) * 5.0))
                }
                Text("ش")
                    .font(.headline)
                    .offset(y: -112)

                ZStack {
                    Rectangle()
                        .fill(Theme.gold.opacity(0.55))
                        .frame(width: 2, height: 100)
                        .offset(y: -50)
                    Image(systemName: "moon.stars.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.gold)
                        .offset(y: -118)
                }
                .rotationEffect(.degrees(bearing))
            }
            .rotationEffect(.degrees(-heading))
            .animation(.easeOut(duration: 0.15), value: heading)

            Image(systemName: "arrowtriangle.down.fill")
                .font(.title3)
                .foregroundStyle(aligned ? Color.green : Color.white)
                .offset(y: -160)

            Circle()
                .fill(aligned ? Color.green : Color.white.opacity(0.8))
                .frame(width: 10, height: 10)
        }
        .frame(width: 320, height: 320)
    }
}
