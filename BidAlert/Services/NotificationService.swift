import SwiftData
import SwiftUI
import UserNotifications

/// 알림 권한 및 히스토리 관리 서비스
@Observable
final class NotificationService {
    var isAuthorized: Bool = false
    var unreadCount: Int = 0

    init() {
        checkAuthorizationStatus()
    }

    /// 알림 권한 상태 확인 (포그라운드 복귀 시마다 호출)
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    /// 알림 권한 요청
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run { self.isAuthorized = granted }
            return granted
        } catch {
            print("❌ 알림 권한 요청 실패: \(error)")
            return false
        }
    }

    /// 시스템 설정 앱으로 이동
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// 시스템 알림 센터에 있는 수신된 알림들을 일괄 동기화
    @MainActor
    static func syncDeliveredNotifications(context: ModelContext) async {
        let notifications = await UNUserNotificationCenter.current().deliveredNotifications()
        
        var savedCount = 0
        for notification in notifications {
            let userInfo = notification.request.content.userInfo
            var data: [String: String] = [:]
            for (key, value) in userInfo {
                if let k = key as? String {
                    data[k] = "\(value)"
                }
            }
            NotificationService.saveNotification(data: data, context: context)
            savedCount += 1
        }
        
        if savedCount > 0 {
            print("✅ 시스템 알림 동기화 완료: \(savedCount)건 처리")
        }
    }

    /// 시스템 알림 센터에서 특정 알림 삭제 (사용자가 앱에서 삭제 시 호출)
    @MainActor
    static func removeDeliveredNotifications(noticeIds: [String]) async {
        let notifications = await UNUserNotificationCenter.current().deliveredNotifications()
        let identifiersToRemove = notifications.compactMap { notification -> String? in
            guard let id = notification.request.content.userInfo["noticeId"] as? String else { return nil }
            return noticeIds.contains(id) ? notification.request.identifier : nil
        }
        
        if !identifiersToRemove.isEmpty {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
        }
    }
    
    @MainActor
    static func removeDeliveredNotification(noticeId: String) async {
        await removeDeliveredNotifications(noticeIds: [noticeId])
    }

    /// FCM data payload → NotificationHistory로 변환 후 SwiftData에 저장
    static func saveNotification(data: [String: String], context: ModelContext) {
        let noticeId = data["noticeId"] ?? ""
        guard !noticeId.isEmpty else { return }

        // ✅ 초기화 시점 이후의 알림만 저장 (초기화 복원 방지)
        if let resetDate = UserDefaults.standard.object(forKey: "lastDataResetDate") as? Date {
            // 서버에서 보낸 receivedTimestamp가 있으면 사용, 없으면 현재 시간
            let receivedTime: Date
            if let ts = data["receivedTimestamp"], let interval = Double(ts) {
                receivedTime = Date(timeIntervalSince1970: interval)
            } else {
                receivedTime = Date()
            }
            // 초기화 시점 이전에 수신된 알림이면 무시
            if receivedTime < resetDate {
                print("⏭️ 초기화 이전 알림 무시: \(data["title"] ?? noticeId)")
                return
            }
        }

        // 중복 체크
        let descriptor = FetchDescriptor<NotificationHistory>(
            predicate: #Predicate { $0.noticeId == noticeId }
        )
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return // 이미 저장된 알림
        }

        let history = NotificationHistory(from: data)
        context.insert(history)

        // 명시적 저장 (백그라운드/앱 종료 시에도 데이터 유실 방지)
        do {
            try context.save()
        } catch {
            print("❌ 알림 히스토리 저장 실패: \(error)")
        }

        // 오래된 데이터 정리 (30일 이상)
        cleanupOldRecords(context: context)
    }


    /// 미확인 알림 수 업데이트
    func updateUnreadCount(context: ModelContext) {
        let descriptor = FetchDescriptor<NotificationHistory>(
            predicate: #Predicate { $0.isRead == false }
        )
        unreadCount = (try? context.fetchCount(descriptor)) ?? 0
    }

    /// 30일 이상 된 알림 자동 삭제
    private static func cleanupOldRecords(context: ModelContext) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        var deletedCount = 0

        let descriptor = FetchDescriptor<NotificationHistory>(
            predicate: #Predicate { $0.receivedAt < cutoff }
        )

        if let oldRecords = try? context.fetch(descriptor) {
            for record in oldRecords {
                context.delete(record)
                deletedCount += 1
            }
        }

        // 최대 1,000건 제한
        let allDescriptor = FetchDescriptor<NotificationHistory>(
            sortBy: [SortDescriptor(\.receivedAt, order: .reverse)]
        )

        if let all = try? context.fetch(allDescriptor), all.count > 1000 {
            for record in all.suffix(from: 1000) {
                context.delete(record)
                deletedCount += 1
            }
        }

        // 삭제 건이 있으면 명시적 저장
        if deletedCount > 0 {
            do {
                try context.save()
                print("🗑️ 오래된 알림 \(deletedCount)건 정리 완료")
            } catch {
                print("❌ 오래된 알림 정리 저장 실패: \(error)")
            }
        }
    }
}
