import CryptoKit
import Foundation

/// 키워드 → FCM Topic 해시 변환
///
/// ⚠️ 서버(Python)의 `topic_hasher.py`와 반드시 동일한 결과를 생성해야 합니다.
///
/// 정규화 순서: trimmingCharacters → lowercased → SHA256 → hex prefix(16)
///
/// 검증 기준값 (keyword_hash):
/// - "cctv"     → "b29dbba57df61de7"
/// - "소프트웨어" → "465f222a27475e7f"
/// - "ai"       → "32e83e92d45d71f6"
/// - "측량"     → "5f66b02e337d9504"
enum TopicHasher {

    enum NotificationType: String {
        case bid = "bid"
        case prebid = "pre"
    }

    enum BidCategory: String, CaseIterable {
        case service = "s"
        case construction = "c"
        case goods = "g"
        
        var displayName: String {
            switch self {
            case .service: return "용역"
            case .construction: return "공사"
            case .goods: return "물품"
            }
        }
    }

    /// 키워드의 기본 해시값(16자 hex)을 생성합니다.
    static func keywordHash(for keyword: String) -> String {
        // ⚠️ Unicode NFD/NFC 불일치 문제 방지를 위해 NFC(precomposed)로 강제 변환
        let nfcKeyword = keyword.precomposedStringWithCanonicalMapping
        let normalized = nfcKeyword.trimmingCharacters(in: .whitespaces).lowercased()
        let hash = SHA256.hash(data: Data(normalized.utf8))
        let hex = hash.compactMap { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(16))
    }

    /// 특정 공고유형과 업무구분의 조합에 대한 FCM 토픽 이름을 생성합니다.
    /// - Parameters:
    ///   - keyword: 원본 키워드 (예: "CCTV", "소프트웨어")
    ///   - type: 알림 유형 (.bid 또는 .prebid)
    ///   - category: 업무구분 (.service, .construction, .goods)
    /// - Returns: FCM 토픽 이름 (예: "bid_s_b29dbba57df61de7")
    static func topicName(for keyword: String, type: NotificationType, category: BidCategory) -> String {
        let hash = keywordHash(for: keyword)
        return "\(type.rawValue)_\(category.rawValue)_\(hash)"
    }

    /// 선택된 업무구분과 알림유형의 모든 토픽 조합을 반환합니다.
    /// - Parameters:
    ///     - keyword: 원본 키워드
    ///     - notificationType: "bid", "pre", "all"
    ///     - bidCategories: 앱 저장값은 단일 업무구분("s", "c", "g")이며, 과거 데이터 호환을 위해 쉼표 구분도 처리
    static func activeTopics(for keyword: String, notificationType: String, bidCategories: String) -> [String] {
        var topics = [String]()
        
        let types: [NotificationType]
        switch notificationType {
        case "bid": types = [.bid]
        case "pre": types = [.prebid]
        default: types = [.bid, .prebid] // "all"
        }
        
        let categories = bidCategories.split(separator: ",").compactMap { BidCategory(rawValue: String($0)) }
        
        for type in types {
            for category in categories {
                topics.append(topicName(for: keyword, type: type, category: category))
            }
        }
        
        return topics
    }

    /// 이 키워드가 가질 수 있는 모든(6가지) 토픽 목록 (구독 해제용)
    static func allPossibleTopics(for keyword: String) -> [String] {
        var topics = [String]()
        for type in [NotificationType.bid, .prebid] {
            for category in BidCategory.allCases {
                topics.append(topicName(for: keyword, type: type, category: category))
            }
        }
        return topics
    }
    
    /// 레거시: 과거에 사용했던 토픽 해제용 (마이그레이션)
    static func legacyTopics(for keyword: String) -> [String] {
        let hash = keywordHash(for: keyword)
        return ["bid_\(hash)", "pre_\(hash)"]
    }
}
