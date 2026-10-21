import Foundation
import CoreLocation

/// تحديد أقرب محافظة من موقع الجهاز (مرة واحدة عند الطلب فقط، بدون تتبع مستمر)
final class LocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum Status: Equatable {
        case idle, locating, denied, failed, outsideKuwait
        case found(String)
    }

    @Published var status: Status = .idle
    var onRegion: ((Region) -> Void)?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func detect() {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            status = .denied
        case .notDetermined:
            status = .locating
            manager.requestWhenInUseAuthorization()
        default:
            status = .locating
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard status == .locating else { return }
        switch manager.authorizationStatus {
        case .denied, .restricted: status = .denied
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last else { return }
        if let r = Region.nearest(lat: l.coordinate.latitude, lng: l.coordinate.longitude) {
            status = .found(r.name)
            onRegion?(r)
        } else {
            status = .outsideKuwait
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        status = .failed
    }
}
