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
    private let hapticManager = HapticNotificationManager.shared

    // MARK: - State
    @Published var destination: CLLocationCoordinate2D?
    @Published var arrivalTime: Date = Date().addingTimeInterval(30 * 60)
    @Published var isNavigating: Bool = false
    @Published var hasArrived: Bool = false

    // ペース情報
    @Published var paceStatus: PaceStatus = .onPace
    @Published var remainingDistance: Double = 0.0
    @Published var remainingMinutes: Int = 0
    @Published var requiredSpeed: Double = 0.0
    @Published var currentSpeed: Double = 0.0

    // アラート
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()
    private var previousStatus: PaceStatus = .onPace

    init() {
        locationManager.requestAuthorization()
        hapticManager.requestPermission()
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

        hasArrived = false
        previousStatus = .onPace

        Task {
            do {
                try await routeManager.fetchRoute(from: currentCoordinate, to: destination)
                locationManager.startTracking()
                isNavigating = true
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
        hasArrived = false

        paceStatus = .onPace
        remainingDistance = 0.0
        remainingMinutes = 0
        requiredSpeed = 0.0
        currentSpeed = 0.0

        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Private

    private func setupLocationSubscription() {
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
                    self.showAlertMessage("位置情報が許可されていません。設定 → プライバシー → 位置情報サービス から許可してください。")
                }
            }
            .store(in: &cancellables)
    }

    private func recalculatePace(walkedDistance: Double, speed: Double) {
        guard routeManager.totalDistance > 0 else { return }

        // 到着判定（残り30m以内）
        let remaining = max(routeManager.totalDistance - walkedDistance, 0)
        if remaining < 30 && !hasArrived {
            hasArrived = true
            hapticManager.handleArrival()
            return
        }

        let result = paceCalculator.calculate(
            totalDistance: routeManager.totalDistance,
            walkedDistance: walkedDistance,
            arrivalTime: arrivalTime,
            currentSpeed: speed
        )

        // ステータスが悪化したらハプティクス＋通知
        if result.status != previousStatus {
            hapticManager.handleStatusChange(from: previousStatus, to: result.status)
            previousStatus = result.status
        }

        paceStatus = result.status
        remainingDistance = result.remainingDistance
        remainingMinutes = result.remainingMinutes
        requiredSpeed = result.requiredSpeed
        currentSpeed = result.currentSpeed
    }

    private func showAlertMessage(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}
