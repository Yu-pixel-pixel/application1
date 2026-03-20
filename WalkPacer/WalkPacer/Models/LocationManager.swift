import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    @Published var currentLocation: CLLocation?
    @Published var totalWalkedDistance: Double = 0.0  // 累計歩行距離（メートル）
    @Published var currentSpeed: Double = 0.0          // 現在速度（m/s）
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: Error?

    private var previousLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5.0  // 5メートル以上移動した場合のみ更新
        authorizationStatus = manager.authorizationStatus
    }

    func requestAuthorization() {
        // バックグラウンド追跡のため「常に許可」をリクエスト
        manager.requestAlwaysAuthorization()
    }

    func startTracking() {
        totalWalkedDistance = 0.0
        previousLocation = nil
        currentSpeed = 0.0
        // 画面OFFでも位置情報を取得し続ける
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.startUpdatingLocation()
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        previousLocation = nil
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }

        // 精度が悪すぎる場合はスキップ
        guard latest.horizontalAccuracy >= 0, latest.horizontalAccuracy < 50 else { return }

        currentLocation = latest

        // 速度の更新（負値の場合は0として扱う）
        currentSpeed = max(latest.speed, 0.0)

        // 累計歩行距離の加算
        if let previous = previousLocation {
            let distance = latest.distance(from: previous)
            // 非現実的な大きな距離はスキップ（GPS誤差対策）
            if distance < 100 {
                totalWalkedDistance += distance
            }
        }
        previousLocation = latest
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = error
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}
