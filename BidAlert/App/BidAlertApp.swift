import FirebaseCore
import FirebaseMessaging
import SwiftData
import SwiftUI

@main
struct BidAlertApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    /// 앱 전체에서 공유하는 단일 ModelContainer
    static let sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: Keyword.self, NotificationHistory.self)
        } catch {
            fatalError("❌ ModelContainer 생성 실패: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .modelContainer(Self.sharedModelContainer)
    }
}

// MARK: - AppDelegate (Firebase + FCM 설정)

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        // FCM 설정
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // 원격 알림 등록
        application.registerForRemoteNotifications()

        return true
    }

    // APNs 토큰 수신
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // FCM 토큰 갱신
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("📱 FCM Token: \(fcmToken ?? "nil")")
    }

    // 포그라운드 알림 표시 + SwiftData 저장
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 알림 데이터를 SwiftData에 저장
        saveNotificationToHistory(userInfo: notification.request.content.userInfo)
        
        // 앱 아이콘 배지 업데이트
        updateBadgeCount()

        completionHandler([.banner, .sound])
    }

    // 알림 탭 처리 (딥링크) + SwiftData 저장
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // 알림 데이터를 SwiftData에 저장 (중복 체크 포함)
        saveNotificationToHistory(userInfo: userInfo)

        // data payload에서 detailUrl 추출
        if let urlString = userInfo["detailUrl"] as? String,
           let url = URL(string: urlString) {
            // 딥링크 처리 → NotificationCenter로 전달
            NotificationCenter.default.post(
                name: .openNotificationDetail,
                object: nil,
                userInfo: ["url": url, "data": userInfo]
            )
        }

        // 앱 아이콘 배지 업데이트
        updateBadgeCount()

        completionHandler()
    }

    // MARK: - 알림 → SwiftData 저장

    /// userInfo 딕셔너리에서 데이터를 추출하여 SwiftData에 저장 (공유 ModelContainer 사용)
    @MainActor
    private func saveNotificationToHistory(userInfo: [AnyHashable: Any]) {
        // [AnyHashable: Any] → [String: String] 변환
        var data: [String: String] = [:]
        for (key, value) in userInfo {
            if let k = key as? String {
                data[k] = "\(value)"
            }
        }

        guard !data.isEmpty, data["noticeId"] != nil else {
            print("⚠️ 알림 데이터에 noticeId 없음, 저장 건너뜀")
            return
        }

        let context = BidAlertApp.sharedModelContainer.mainContext
        NotificationService.saveNotification(data: data, context: context)
        print("✅ 알림 히스토리 저장 완료: \(data["title"] ?? "")")
    }

    /// 앱 아이콘 배지 카운트 업데이트
    @MainActor
    private func updateBadgeCount() {
        let context = BidAlertApp.sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<NotificationHistory>(
            predicate: #Predicate { $0.isRead == false }
        )
        let count = (try? context.fetchCount(descriptor)) ?? 0
        
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(count)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openNotificationDetail = Notification.Name("openNotificationDetail")
}
