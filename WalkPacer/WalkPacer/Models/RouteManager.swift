import Foundation
import MapKit
import Combine

enum RouteError: LocalizedError {
    case noRouteFound
    case requestFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noRouteFound:
            return "経路が見つかりませんでした"
        case .requestFailed(let error):
            return "経路取得に失敗しました: \(error.localizedDescription)"
        }
    }
}

class RouteManager: ObservableObject {

    @Published var route: MKRoute?
    @Published var totalDistance: Double = 0.0  // 総道のり（メートル）
    @Published var isLoading: Bool = false

    /// 経路を1回だけ取得する。歩行中に再呼び出しはしないこと。
    func fetchRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws {
        await MainActor.run {
            isLoading = true
        }

        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .walking

        let directions = MKDirections(request: request)

        do {
            let response = try await directions.calculate()
            guard let firstRoute = response.routes.first else {
                throw RouteError.noRouteFound
            }
            await MainActor.run {
                self.route = firstRoute
                self.totalDistance = firstRoute.distance
            }
        } catch {
            if let routeError = error as? RouteError {
                throw routeError
            }
            throw RouteError.requestFailed(error)
        }
    }

    func reset() {
        route = nil
        totalDistance = 0.0
    }
}
