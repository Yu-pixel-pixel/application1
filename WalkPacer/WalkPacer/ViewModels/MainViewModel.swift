import Foundation
import CoreLocation
import MapKit
import Combine
import UIKit

@MainActor
class MainViewModel: ObservableObject {

    // MARK: - Dependencies
    let locationManager = LocationManager()
    let routeManager = RouteManager()
    private let paceCalculator = PaceCalculator()

    // MARK: - State
    @Published var destination: CLLocationCoordinate2D?
    @Published var arrivalTime: Date = Date().addingTimeInterval(30 * 60)  // デフォルト: 現在時刻+30分
    @Published var isNavigating: Bool = false

    // ペース情報
    @Published var paceStatus: PaceStatus = .onPace
    @Published var remainingDistance: Double = 0.0
    @Published var requiredSpeed: Double = 0.0
    @Published var currentSpeed: Double = 0.0

    // アラート
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()

    init() {
        locationManager.requestAuthorization()
        setupLocationSubscription()
        setupAuthorizationSubscription()
    }

    // MARK: - Navigation Control

    func startNavigation() {
        guard let destination = destination else { return }
        guard let currentCoordinate = locationManager.currentLocation?.coordinate else {
            showAlertMessage("現在地を取得できませんでした。位置情報の権限を確認してください。")
            return
        }

        Task {
            do {
                // 経路取得（1回のみ）
                try await routeManager.fetchRoute(from: currentCoordinate, to: destination)

                // トラッキング開始
                locationManager.startTracking()
                isNavigating = true

                // 画面スリープ防止
                UIApplication.shared.isIdleTimerDisabled = true
            } catch {
                showAlertMessage(error.localizedDescription)
            }
        }
    }

    func stopNavigation() {
        locationManager.stopTracking()
        routeManager.reset()
        isNavigating = false

        // 状態リセット
        paceStatus = .onPace
        remainingDistance = 0.0
        requiredSpeed = 0.0
        currentSpeed = 0.0

        // 画面スリープ防止を解除
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Private

    private func setupLocationSubscription() {
        // 位置情報が更新されるたびにペースを再計算する
        locationManager.$currentLocation
            .compactMap { $0 }
            .combineLatest(locationManager.$totalWalkedDistance, locationManager.$currentSpeed)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, walkedDistance, speed in
                guard let self = self, self.isNavigating else { return }
                self.recalculatePace(walkedDistance: walkedDistance, speed: speed)
            }
            .store(in: &cancellables)
    }

    private func setupAuthorizationSubscription() {
        locationManager.$authorizationStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                if status == .denied || status == .restricted {
                    self.showAlertMessage("位置情報の使用が許可されていません。設定アプリから「位置情報」を「このAppの使用中」に変更してください。")
                }
            }
            .store(in: &cancellables)
    }

    private func recalculatePace(walkedDistance: Double, speed: Double) {
        guard routeManager.totalDistance > 0 else { return }

        let result = paceCalculator.calculate(
            totalDistance: routeManager.totalDistance,
            walkedDistance: walkedDistance,
            arrivalTime: arrivalTime,
            currentSpeed: speed
        )

        paceStatus = result.status
        remainingDistance = result.remainingDistance
        requiredSpeed = result.requiredSpeed
        currentSpeed = result.currentSpeed
    }

    private func showAlertMessage(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}
