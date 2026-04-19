import FirebaseMessaging
import SwiftData
import SwiftUI

/// 키워드 관리 + FCM 토픽 구독/해제 서비스
@Observable
final class KeywordManager {
    static let maxKeywords = 20

    /// 키워드를 추가하고 FCM 토픽을 구독합니다
    static func addKeyword(_ text: String, notificationType: String = "all", bidCategories: String = "s,c,g", context: ModelContext) -> Result<Keyword, KeywordError> {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        // 입력 검증
        guard trimmed.count >= 2 else { return .failure(.tooShort) }
        guard trimmed.count <= 20 else { return .failure(.tooLong) }

        // 중복 체크
        let descriptor = FetchDescriptor<Keyword>(predicate: #Predicate { $0.text == trimmed })
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return .failure(.duplicate)
        }

        // 개수 제한
        let countDescriptor = FetchDescriptor<Keyword>()
        if let count = try? context.fetchCount(countDescriptor), count >= maxKeywords {
            return .failure(.limitReached)
        }

        // 키워드 생성 + 저장
        let keyword = Keyword(text: trimmed, notificationType: notificationType, bidCategories: bidCategories)
        context.insert(keyword)

        // FCM 토픽 구독
        subscribeTopics(for: keyword)

        return .success(keyword)
    }

    /// 키워드를 삭제하고 FCM 토픽을 해제합니다
    static func removeKeyword(_ keyword: Keyword, context: ModelContext) {
        // 모든 토픽 구독 해제
        unsubscribeAllTopics(for: keyword)
        context.delete(keyword)
    }

    /// 키워드 일시중지/해제
    static func toggleActive(_ keyword: Keyword) {
        keyword.isActive.toggle()
        if keyword.isActive {
            subscribeTopics(for: keyword)
        } else {
            unsubscribeAllTopics(for: keyword)
        }
    }

    /// 알림 유형 변경
    static func updateNotificationType(_ keyword: Keyword, type: String) {
        // 기존 토픽 모두 해제
        unsubscribeAllTopics(for: keyword)
        // 유형 변경
        keyword.notificationType = type
        // 새 토픽 구독
        if keyword.isActive {
            subscribeTopics(for: keyword)
        }
    }

    /// 업무구분 변경
    static func updateBidCategories(_ keyword: Keyword, categories: String) {
        // 기존 토픽 모두 해제
        unsubscribeAllTopics(for: keyword)
        // 업무구분 변경
        keyword.bidCategories = categories
        // 새 토픽 구독
        if keyword.isActive {
            subscribeTopics(for: keyword)
        }
    }

    // MARK: - FCM 토픽 구독

    private static func subscribeTopics(for keyword: Keyword) {
        for topic in keyword.activeTopics {
            Messaging.messaging().subscribe(toTopic: topic) { error in
                if let error {
                    print("❌ FCM 구독 실패: \(topic) - \(error.localizedDescription)")
                } else {
                    print("✅ FCM 구독 성공: \(topic)")
                }
            }
        }
    }

    private static func unsubscribeAllTopics(for keyword: Keyword) {
        for topic in keyword.allTopics {
            Messaging.messaging().unsubscribe(fromTopic: topic) { error in
                if let error {
                    print("❌ FCM 구독 해제 실패: \(topic) - \(error.localizedDescription)")
                } else {
                    print("✅ FCM 구독 해제: \(topic)")
                }
            }
        }
    }
}

// MARK: - Error Types

enum KeywordError: LocalizedError {
    case tooShort
    case tooLong
    case duplicate
    case limitReached

    var errorDescription: String? {
        switch self {
        case .tooShort: return "키워드는 2자 이상 입력해주세요."
        case .tooLong: return "키워드는 20자 이하로 입력해주세요."
        case .duplicate: return "이미 등록된 키워드입니다."
        case .limitReached: return "최대 \(KeywordManager.maxKeywords)개까지 등록 가능합니다."
        }
    }
}
