import Foundation
import SwiftData

/// 사용자가 등록한 키워드
@Model
final class Keyword {
    @Attribute(.unique) var id: UUID
    var text: String               // 원본 키워드 ("CCTV")
    var bidTopicHash: String       // [Legacy] "bid_b29dbba57df61de7"
    var preTopicHash: String       // [Legacy] "pre_b29dbba57df61de7"
    var notificationType: String   // "bid" | "pre" | "all"
    var bidCategoriesOption: String? // "s,c,g" (용역:s, 공사:c, 물품:g) - v2 migration safe
    var isActive: Bool             // 일시중지 여부
    var createdAt: Date

    init(text: String, notificationType: String = "all", bidCategories: String = "s") {
        self.id = UUID()
        self.text = text
        let legacyTopics = TopicHasher.legacyTopics(for: text)
        self.bidTopicHash = legacyTopics[0]
        self.preTopicHash = legacyTopics[1]
        self.notificationType = notificationType
        self.bidCategoriesOption = bidCategories
        self.isActive = true
        self.createdAt = Date()
    }

    /// 안전한 업무구분 반환 (초기 마이그레이션 대비)
    var bidCategories: String {
        get { return bidCategoriesOption ?? "s" }
        set { bidCategoriesOption = newValue }
    }

    /// 이 키워드가 구독해야 하는 토픽 목록
    var activeTopics: [String] {
        guard isActive else { return [] }
        return TopicHasher.activeTopics(for: text, notificationType: notificationType, bidCategories: bidCategories)
    }

    /// 이 키워드의 모든 토픽 (구독 해제 시 사용)
    var allTopics: [String] {
        return TopicHasher.allPossibleTopics(for: text) + TopicHasher.legacyTopics(for: text)
    }
}
