import Foundation

enum PaceStatus: Equatable {
    case onPace          // 青: このペースで間に合います
    case slightlyBehind  // 黄: 少し早歩きしましょう
    case behind          // 赤: 急ぎましょう！
    case overdue         // 赤: 設定時刻を過ぎています

    var message: String {
        switch self {
        case .onPace:         return "このペースで間に合います"
        case .slightlyBehind: return "少し早歩きしましょう"
        case .behind:         return "急ぎましょう！"
        case .overdue:        return "設定時刻を過ぎています"
        }
    }
}

struct PaceCalculationResult {
    let status: PaceStatus
    let remainingDistance: Double  // メートル
    let requiredSpeed: Double      // m/s
    let currentSpeed: Double       // m/s
}

struct PaceCalculator {

    /// ペースを計算する
    /// - Parameters:
    ///   - totalDistance: 総道のり（メートル）
    ///   - walkedDistance: 累計歩行距離（メートル）
    ///   - arrivalTime: 到着希望時刻
    ///   - currentSpeed: 現在速度（m/s）、負値は0として扱う
    /// - Returns: PaceCalculationResult
    func calculate(
        totalDistance: Double,
        walkedDistance: Double,
        arrivalTime: Date,
        currentSpeed: Double
    ) -> PaceCalculationResult {
        let safeCurrentSpeed = max(currentSpeed, 0.0)
        let remainingDistance = max(totalDistance - walkedDistance, 0.0)
        let remainingTime = arrivalTime.timeIntervalSinceNow  // 秒

        // 残り時間が0以下 → 時刻超過
        guard remainingTime > 0 else {
            return PaceCalculationResult(
                status: .overdue,
                remainingDistance: remainingDistance,
                requiredSpeed: 0.0,
                currentSpeed: safeCurrentSpeed
            )
        }

        // 必要速度 = 残り距離 / 残り時間
        let requiredSpeed = remainingDistance / remainingTime

        let status: PaceStatus
        if safeCurrentSpeed >= requiredSpeed {
            status = .onPace
        } else if safeCurrentSpeed >= requiredSpeed * 0.8 {
            status = .slightlyBehind
        } else {
            status = .behind
        }

        return PaceCalculationResult(
            status: status,
            remainingDistance: remainingDistance,
            requiredSpeed: requiredSpeed,
            currentSpeed: safeCurrentSpeed
        )
    }
}
