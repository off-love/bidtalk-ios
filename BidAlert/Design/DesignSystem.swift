import SwiftUI

/// 입찰알리미 디자인 시스템
enum DS {
    // MARK: - Colors

    enum Colors {
        static let primary = Color("Primary", bundle: nil)
        static let accent = Color("AccentColor", bundle: nil)
        static let danger = Color(light: .init(hex: "E53E3E"), dark: .init(hex: "FC8181"))
        static let success = Color(light: .init(hex: "10B981"), dark: .init(hex: "6EE7B7"))
        static let prebid = Color(light: .init(hex: "7C3AED"), dark: .init(hex: "A78BFA"))
        
        // Category Colors
        static let construction = Color(light: .init(hex: "F97316"), dark: .init(hex: "FB923C"))
        static let goods = Color(light: .init(hex: "059669"), dark: .init(hex: "34D399"))

        static let bgPrimary = Color(light: .init(hex: "F8F9FA"), dark: .init(hex: "1A1A2E"))
        static let bgSurface = Color(light: .white, dark: .init(hex: "16213E"))
        static let textPrimary = Color(light: .init(hex: "1A1A2E"), dark: .init(hex: "F0F0F5"))
        static let textSecondary = Color(light: .init(hex: "6B7280"), dark: .init(hex: "9CA3AF"))

        // 하드코딩 fallback (Asset Catalog 없을 때)
        static let primaryFallback = Color(light: .init(hex: "1A56B8"), dark: .init(hex: "5B9AFF"))
        static let accentFallback = Color(light: .init(hex: "FF6B00"), dark: .init(hex: "FFB366"))
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let full: CGFloat = 999
    }

    // MARK: - Recommended Keywords

    static let recommendedKeywords: [(category: String, keywords: [String])] = [
        ("IT/SW", ["소프트웨어", "정보시스템", "클라우드", "AI", "빅데이터", "홈페이지"]),
        ("건설", ["시설물", "도로", "건축", "설계", "감리"]),
        ("보안", ["CCTV", "보안", "영상", "출입통제"]),
        ("측량", ["지적측량", "확정측량", "측량"]),
        ("기타", ["용역", "컨설팅", "교육", "홍보", "청소", "경비"]),
    ]
}

// MARK: - Color Helpers

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}
