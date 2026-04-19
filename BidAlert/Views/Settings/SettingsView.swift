
import SwiftData
import SwiftUI

/// 설정 화면
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    var notificationService: NotificationService

    @Query private var allHistory: [NotificationHistory]
    @Query private var allKeywords: [Keyword]

    @State private var showResetAlert = false
    @State private var showMailComposer = false

    var body: some View {
        List {
            // 알림 설정
            Section("알림 설정") {
                HStack {
                    Label("알림 상태", systemImage: "bell.fill")
                    Spacer()
                    Text(notificationService.isAuthorized ? "켜짐" : "꺼짐")
                        .foregroundStyle(
                            notificationService.isAuthorized
                                ? DS.Colors.success
                                : DS.Colors.danger
                        )
                        .fontWeight(.medium)
                    Image(systemName: notificationService.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(
                            notificationService.isAuthorized
                                ? DS.Colors.success
                                : DS.Colors.danger
                        )
                }

                Button {
                    notificationService.openSettings()
                } label: {
                    Label("알림 설정 변경", systemImage: "gear")
                }
            }

            // 데이터 관리
            Section("데이터 관리") {
                LabeledContent {
                    Text("\(allHistory.count)건")
                        .foregroundStyle(DS.Colors.textSecondary)
                } label: {
                    Label("저장된 알림", systemImage: "tray.full.fill")
                }

                LabeledContent {
                    Text("\(allKeywords.count)개")
                        .foregroundStyle(DS.Colors.textSecondary)
                } label: {
                    Label("등록된 키워드", systemImage: "tag.fill")
                }

                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    Label("전체 데이터 초기화", systemImage: "trash")
                }
            }



            // 면책 조항
            Section {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(DS.Colors.accentFallback)
                        Text("면책 조항")
                            .font(.subheadline.bold())
                    }
                    Text("본 앱은 조달청(나라장터)의 공식 앱이 아닙니다. 공공데이터포털 OpenAPI를 활용한 비공식 서비스이며, 데이터의 정확성은 원본 시스템(나라장터)을 기준으로 합니다.\n\n시스템 오류로 인한 알림 누락 시 책임을 지지 않으니 보조 수단으로만 활용 바랍니다. 중요 입찰 정보는 반드시 해당 기관의 공식 사이트에서 직접 확인해 주세요.")
                        .font(.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .alert("전체 데이터를 초기화합니다", isPresented: $showResetAlert) {
            Button("초기화", role: .destructive) { resetAllData() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("등록된 모든 키워드와 알림 히스토리가 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
        }
    }

    // MARK: - Helpers
    private func resetAllData() {
        // 1. 초기화 시점 기록 (이 시점 이전의 알림은 저장하지 않음)
        UserDefaults.standard.set(Date(), forKey: "lastDataResetDate")

        // 2. 시스템 알림 센터의 모든 알림 삭제 (다시 불러오기 방지)
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        // 3. 모든 키워드 토픽 구독 해제 후 삭제
        for keyword in allKeywords {
            KeywordManager.removeKeyword(keyword, context: modelContext)
        }
        // 4. 히스토리 전체 삭제
        for history in allHistory {
            modelContext.delete(history)
        }

        // 5. 명시적 저장 (삭제가 즉시 영속되도록 보장)
        try? modelContext.save()
    }
}
