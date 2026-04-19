import SafariServices
import SwiftData
import SwiftUI

/// 메인 탭 뷰 (알림 → 키워드 → 설정)
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var notificationService = NotificationService()
    @State private var selectedTab = 0
    @State private var safariURL: URL?

    // 미확인 알림 수
    @Query(filter: #Predicate<NotificationHistory> { !$0.isRead })
    private var unreadNotifications: [NotificationHistory]

    var body: some View {
        TabView(selection: $selectedTab) {
            // 탭 1: 알림 히스토리
            HistoryListView(safariURL: $safariURL)
                .tabItem {
                    Label("알림", systemImage: "bell.fill")
                }
                .badge(unreadNotifications.count)
                .tag(0)

            // 탭 2: 키워드 설정
            KeywordListView(notificationService: notificationService)
                .tabItem {
                    Label("키워드", systemImage: "tag.fill")
                }
                .tag(1)

            // 탭 3: 설정
            NavigationStack {
                SettingsView(notificationService: notificationService)
            }
            .tabItem {
                Label("설정", systemImage: "gearshape.fill")
            }
            .tag(2)
        }
        .tint(DS.Colors.primaryFallback)
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    // 좌→우 스와이프: 이전 탭
                    if value.translation.width > 80 && abs(value.translation.height) < 100 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedTab = max(0, selectedTab - 1)
                        }
                    }
                    // 우→좌 스와이프: 다음 탭
                    if value.translation.width < -80 && abs(value.translation.height) < 100 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedTab = min(2, selectedTab + 1)
                        }
                    }
                }
        )
        .onReceive(NotificationCenter.default.publisher(for: .openNotificationDetail)) { notification in
            // 딥링크: 알림 탭 → URL 열기
            if let url = notification.userInfo?["url"] as? URL {
                safariURL = url
                selectedTab = 0
            }
        }
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            notificationService.checkAuthorizationStatus()
            Task {
                await NotificationService.syncDeliveredNotifications(context: modelContext)
                updateAppIconBadge()
            }
        }
        .onChange(of: unreadNotifications.count) {
            updateAppIconBadge()
        }
        .onAppear {
            Task {
                await NotificationService.syncDeliveredNotifications(context: modelContext)
                updateAppIconBadge()
            }
        }
    }

    private func updateAppIconBadge() {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(unreadNotifications.count)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = unreadNotifications.count
        }
    }
}

// MARK: - Safari View Wrapper

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredControlTintColor = UIColor(DS.Colors.primaryFallback)
        return safari
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
