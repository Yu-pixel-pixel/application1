import UIKit
import UserNotifications

/// ハプティクス（バイブ）とローカル通知を管理する
final class HapticNotificationManager {

    static let shared = HapticNotificationManager()
    private init() {}

    // MARK: - 権限リクエスト

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }
    }

    // MARK: - ステータス変化トリガー

    /// ステータスが悪化したときに呼び出す（緑→黄 / 黄→赤）
    func handleStatusChange(from oldStatus: PaceStatus, to newStatus: PaceStatus) {
        guard newStatus != oldStatus else { return }

        switch newStatus {
        case .slightlyBehind:
            // 黄: 中程度のバイブ
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            scheduleNotification(
                title: "⚡ ペースを上げましょう",
                body: "急ぎ足で歩くと間に合います"
            )
        case .behind:
            // 赤: 警告バイブ（3回）
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.warning)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { gen.notificationOccurred(.warning) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { gen.notificationOccurred(.warning) }
            scheduleNotification(
                title: "🚨 急いでください！",
                body: "このペースでは間に合いません"
            )
        case .overdue:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            scheduleNotification(
                title: "⏰ 時刻を過ぎました",
                body: "設定した到着時刻を超過しています"
            )
        case .onPace:
            // 改善したとき: 軽いバイブで知らせる
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    // MARK: - 到着検知

    /// 目的地に到着したとき
    func handleArrival() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        scheduleNotification(
            title: "🎉 到着しました！",
            body: "目的地に到着しました。お疲れ様でした！"
        )
    }

    // MARK: - Private

    private func scheduleNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}
