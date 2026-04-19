import SwiftUI

/// 히스토리 카드 뷰 (단일 공고 카드)
struct HistoryCardView: View {
    let item: NotificationHistory

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            // 읽음/안읽음 인디케이터
            if !item.isRead {
                Circle()
                    .fill(DS.Colors.primaryFallback)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            } else {
                Spacer()
                    .frame(width: 8)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // 키워드 뱃지 + 마감 임박
                HStack(spacing: DS.Spacing.xs) {
                    // 유형 뱃지
                    Text(item.isBid ? "입찰공고" : "사전규격")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.isBid ? DS.Colors.primaryFallback.opacity(0.15) : DS.Colors.prebid.opacity(0.15))
                        .foregroundStyle(item.isBid ? DS.Colors.primaryFallback : DS.Colors.prebid)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    // 키워드 태그
                    Text(item.keyword)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DS.Colors.success.opacity(0.15))
                        .foregroundStyle(DS.Colors.success)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Spacer()

                    // 마감 임박
                    if item.isDeadlineSoon {
                        HStack(spacing: 2) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                            Text("마감임박")
                                .font(.caption2.bold())
                        }
                        .foregroundStyle(DS.Colors.danger)
                    }
                }

                // 공고명
                highlightedTitle(title: item.title, keyword: item.keyword)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                // 기관 + 업종
                HStack(spacing: 4) {
                    Image(systemName: "building.2.fill")
                        .font(.caption2)
                    Text(item.agency)
                    if !item.bidTypeDisplay.isEmpty {
                        Text("(\(item.bidTypeDisplay))")
                    }
                }
                .font(.caption)
                .foregroundStyle(DS.Colors.textSecondary)

                // 수요기관 (있는 경우)
                if !item.demandAgency.isEmpty && item.demandAgency != item.agency {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text("수요: \(item.demandAgency)")
                    }
                    .font(.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                }

                HStack {
                    // 금액
                    HStack(spacing: 4) {
                        Image(systemName: "wonsign.circle.fill")
                            .font(.caption)
                        Text(item.priceDisplay)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(DS.Colors.success)

                    Spacer()

                    // D-day
                    if !item.dDayText.isEmpty {
                        Text(item.dDayText)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                item.isDeadlineSoon
                                    ? DS.Colors.danger.opacity(0.15)
                                    : DS.Colors.textSecondary.opacity(0.1)
                            )
                            .foregroundStyle(
                                item.isDeadlineSoon
                                    ? DS.Colors.danger
                                    : DS.Colors.textSecondary
                            )
                            .clipShape(Capsule())
                    }

                    // 상대 시간
                    Text(item.relativeTimeText)
                        .font(.caption2)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.keyword) 키워드, \(item.title), \(item.agency), \(item.priceDisplay)")
    }

    // MARK: - Helpers

    private func highlightedTitle(title: String, keyword: String) -> Text {
        var attrString = AttributedString(title)
        
        guard !keyword.isEmpty, title.localizedCaseInsensitiveContains(keyword) else {
            return Text(attrString)
        }
        
        var searchRange = attrString.startIndex..<attrString.endIndex
        while let matchRange = attrString[searchRange].range(of: keyword, options: .caseInsensitive) {
            attrString[matchRange].backgroundColor = .yellow
            attrString[matchRange].foregroundColor = .black // 형광색 위에서 잘 보이도록
            
            searchRange = matchRange.upperBound..<attrString.endIndex
        }
        
        return Text(attrString)
    }
}
