import Foundation
import CoreLocation

/// تحديد موقع المستخدم لحساب الأوقات والقبلة (طلب واحد عند الحاجة، بدون تتبع مستمر)
final class LocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum Status: Equatable {
        case idle, locating, denied, failed
        case found(String)
    }

    @Published var status: Status = .idle
    /// موقع داخل الكويت: نستخدم أقرب محافظة (السلوك القديم)
    var onKuwait: ((Region) -> Void)?
    /// أي مكان آخر في العالم
    var onPlace: ((Place) -> Void)?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastRequest = Date.distantPast

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// force: من زر المستخدم. بدونها نتجاهل الطلبات المتكررة خلال ٣٠ دقيقة.
    func detect(force: Bool = true) {
        if !force && Date().timeIntervalSince(lastRequest) < 1800 { return }
        switch manager.authorizationStatus {
        case .denied, .restricted:
            status = .denied
        case .notDetermined:
            status = .locating
            manager.requestWhenInUseAuthorization()
        default:
            status = .locating
            lastRequest = Date()
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard status == .locating else { return }
        switch manager.authorizationStatus {
        case .denied, .restricted: status = .denied
        case .authorizedAlways, .authorizedWhenInUse:
            lastRequest = Date()
            manager.requestLocation()
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last else { return }
        let lat = l.coordinate.latitude, lng = l.coordinate.longitude
        if let r = Region.nearest(lat: lat, lng: lng) {
            status = .found("الكويت · \(r.name)")
            onKuwait?(r)
            return
        }
        geocoder.reverseGeocodeLocation(l, preferredLocale: Locale(identifier: "ar")) { [weak self] marks, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let m = marks?.first
                let name = m?.locality ?? m?.subAdministrativeArea ?? m?.administrativeArea ?? m?.country ?? "موقعك الحالي"
                let tz = m?.timeZone?.identifier ?? TimeZone.current.identifier
                self.status = .found(name)
                self.onPlace?(Place(name: name, lat: lat, lng: lng, tz: tz))
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        status = .failed
    }
}
