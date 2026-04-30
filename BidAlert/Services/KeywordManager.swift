import FirebaseMessaging
import SwiftData
import SwiftUI

/// 키워드 관리 + FCM 토픽 구독/해제 서비스
@Observable
final class KeywordManager {
    static let maxKeywords = 3

    private static let broadKeywordBlocklist: Set<String> = [
        "공고", "공사", "계약", "구매", "관리", "나라장터", "물품", "사업", "설계",
        "시스템", "신축", "용역", "유지", "유지보수", "입찰", "조달",
    ]

    /// 키워드를 추가하고 입찰공고/사전규격 FCM 토픽을 함께 구독합니다
    static func addKeyword(_ text: String, bidCategories: String = "s", context: ModelContext) -> Result<Keyword, KeywordError> {
        let trimmed = text.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)

        // 입력 검증
        guard trimmed.count >= 2 else { return .failure(.tooShort) }
        guard trimmed.count <= 20 else { return .failure(.tooLong) }
        guard !isBroadKeyword(trimmed) else { return .failure(.tooBroad) }

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
        let keyword = Keyword(
            text: trimmed,
            bidCategories: singleBidCategory(from: bidCategories)
        )
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

    /// 업무구분 변경
    static func updateBidCategories(_ keyword: Keyword, categories: String) {
        // 기존 토픽 모두 해제
        unsubscribeAllTopics(for: keyword)
        // 업무구분 변경
        keyword.bidCategories = singleBidCategory(from: categories)
        // 새 토픽 구독
        if keyword.isActive {
            subscribeTopics(for: keyword)
        }
    }

    /// 현재 저장된 활성 키워드들의 토픽 구독을 복구합니다.
    @MainActor
    static func restoreSubscriptions(context: ModelContext) {
        let descriptor = FetchDescriptor<Keyword>()
        guard let keywords = try? context.fetch(descriptor) else {
            print("❌ 키워드 조회 실패: 토픽 구독 복구 건너뜀")
            return
        }

        var migratedLegacyNotificationType = false
        for keyword in keywords where keyword.notificationType != "all" {
            keyword.notificationType = "all"
            migratedLegacyNotificationType = true
        }
        if migratedLegacyNotificationType {
            try? context.save()
        }

        let activeKeywords = keywords.filter(\.isActive)
        if activeKeywords.isEmpty {
            print("ℹ️ 복구할 활성 키워드가 없습니다")
            return
        }

        for keyword in activeKeywords {
            reconcileSubscriptions(for: keyword)
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

    private static func reconcileSubscriptions(for keyword: Keyword) {
        let activeTopics = Set(keyword.activeTopics)
        for topic in keyword.allTopics where !activeTopics.contains(topic) {
            Messaging.messaging().unsubscribe(fromTopic: topic) { error in
                if let error {
                    print("❌ FCM 구독 정리 실패: \(topic) - \(error.localizedDescription)")
                } else {
                    print("✅ FCM 구독 정리: \(topic)")
                }
            }
        }

        subscribeTopics(for: keyword)
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

    private static func isBroadKeyword(_ text: String) -> Bool {
        broadKeywordBlocklist.contains(normalizedKeyword(text))
    }

    private static func normalizedKeyword(_ text: String) -> String {
        text
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func singleBidCategory(from categories: String) -> String {
        let firstCategory = categories
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap { TopicHasher.BidCategory(rawValue: $0) }
            .first

        return firstCategory?.rawValue ?? TopicHasher.BidCategory.service.rawValue
    }
}

// MARK: - Error Types

enum KeywordError: LocalizedError {
    case tooShort
    case tooLong
    case tooBroad
    case duplicate
    case limitReached

    var errorDescription: String? {
        switch self {
        case .tooShort: return "키워드는 2자 이상 입력해주세요."
        case .tooLong: return "키워드는 20자 이하로 입력해주세요."
        case .tooBroad: return "너무 넓은 키워드입니다. 조금 더 구체적으로 입력해주세요."
        case .duplicate: return "이미 등록된 키워드입니다."
        case .limitReached: return "최대 \(KeywordManager.maxKeywords)개까지 등록 가능합니다."
        }
    }
}
