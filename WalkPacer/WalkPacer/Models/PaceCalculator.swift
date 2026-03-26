import Foundation

enum PaceStatus: Equatable {
    case onPace          // 緑: 余裕で間に合います
    case slightlyBehind  // 黄: 急ぎ足が必要です
    case behind          // 赤: 間に合いません
    case overdue         // 赤: 時刻を過ぎています

    var message: String {
        switch self {
        case .onPace:         return "余裕で間に合います"
        case .slightlyBehind: return "急ぎ足で歩きましょう"
        case .behind:         return "間に合いません！"
        case .overdue:        return "時刻を過ぎています"
        }
    }

    var isRed: Bool {
        self == .behind || self == .overdue
    }
}

struct PaceCalculationResult {
    let status: PaceStatus
    let remainingDistance: Double  // メートル
    let remainingMinutes: Int      // 残り時間（分）
    let requiredSpeed: Double      // m/s
    let currentSpeed: Double       // m/s
}

struct PaceCalculator {

    // 徒歩の速度定義
    // 快適ウォーク ≤ 4.5 km/h → 緑
    // 早歩き ≤ 7.0 km/h       → 黄
    // それ以上                 → 赤（走らないと無理）
    private let comfortableSpeed: Double = 4.5 / 3.6  // m/s
    private let fastWalkSpeed: Double    = 7.0 / 3.6  // m/s

    func calculate(
        totalDistance: Double,
        walkedDistance: Double,
        arrivalTime: Date,
        currentSpeed: Double
    ) -> PaceCalculationResult {
        let safeCurrentSpeed = max(currentSpeed, 0.0)
        let remainingDistance = max(totalDistance - walkedDistance, 0.0)
        let remainingTime = arrivalTime.timeIntervalSinceNow  // 秒

        let remainingMinutes = max(Int(remainingTime / 60), 0)

        // 時刻超過
        guard remainingTime > 0 else {
            return PaceCalculationResult(
                status: .overdue,
                remainingDistance: remainingDistance,
                remainingMinutes: 0,
                requiredSpeed: 0.0,
                currentSpeed: safeCurrentSpeed
            )
        }

        // 必要速度 = 残り距離 ÷ 残り時間
        let requiredSpeed = remainingDistance / remainingTime

        // 現在速度ではなく「必要速度 vs 徒歩の標準速度」で判定
        let status: PaceStatus
        if requiredSpeed <= comfortableSpeed {
            status = .onPace          // 快適ウォークで間に合う
        } else if requiredSpeed <= fastWalkSpeed {
            status = .slightlyBehind  // 早歩きで間に合う
        } else {
            status = .behind          // 走っても難しい
        }

        return PaceCalculationResult(
            status: status,
            remainingDistance: remainingDistance,
            remainingMinutes: remainingMinutes,
            requiredSpeed: requiredSpeed,
            currentSpeed: safeCurrentSpeed
        )
    }
}
