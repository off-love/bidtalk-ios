import SwiftData
import SwiftUI

/// 키워드 Chip 뷰
struct KeywordChipView: View {
    let keyword: Keyword
    var onTap: () -> Void
    var onDelete: () -> Void

    /// 알림 유형에 따른 아이콘
    private var typeIcon: String? {
        switch keyword.notificationType {
        case "bid": return "doc.text.fill"
        case "pre": return "clipboard.fill"
        default: return nil  // "all"이면 아이콘 없음
        }
    }

    /// 알림 유형에 따른 색상
    private var typeColor: Color {
        switch keyword.notificationType {
        case "bid": return DS.Colors.primaryFallback
        case "pre": return DS.Colors.prebid
        default: return DS.Colors.primaryFallback
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            // 알림 유형 아이콘
            if let icon = typeIcon {
                Image(systemName: icon)
                    .font(.caption2)
            }

            Text(keyword.text)
                .font(.subheadline.weight(.medium))
                .strikethrough(!keyword.isActive, color: DS.Colors.textSecondary)

            // 업무구분 배지
            if keyword.isActive {
                Text(categoryBadgeText(categoryString: keyword.bidCategories))
                    .font(.system(size: 9))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.3))
                    .clipShape(Capsule())
            }

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption2.bold())
                    .foregroundStyle(keyword.isActive ? typeColor : DS.Colors.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            keyword.isActive
                ? typeColor.opacity(0.1)
                : Color.gray.opacity(0.1)
        )
        .foregroundStyle(
            keyword.isActive
                ? typeColor
                : DS.Colors.textSecondary
        )
        .clipShape(Capsule())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(keyword.text) 키워드, \(keyword.notificationType == "bid" ? "입찰공고" : keyword.notificationType == "pre" ? "사전규격" : "전체"), \(categoryBadgeText(categoryString: keyword.bidCategories))")
        .accessibilityHint("탭하여 설정을 변경하세요")
    }
    
    private func categoryBadgeText(categoryString: String) -> String {
        let cats = categoryString.split(separator: ",")
        var names = [String]()
        if cats.contains("c") { names.append("공사") }
        if cats.contains("s") { names.append("용역") }
        if cats.contains("g") { names.append("물품") }
        return names.joined(separator: "·")
    }
}

// MARK: - 키워드 상세 바텀시트

struct KeywordDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var keyword: Keyword

    var body: some View {
        NavigationStack {
            List {
                // 알림 유형
                Section("알림 유형") {
                    Picker("유형 선택", selection: Binding(
                        get: { keyword.notificationType },
                        set: { KeywordManager.updateNotificationType(keyword, type: $0) }
                    )) {
                        Text("전체").tag("all")
                        Text("입찰공고만").tag("bid")
                        Text("사전규격만").tag("pre")
                    }
                    .pickerStyle(.segmented)
                }

                // 업무구분
                Section("업무구분") {
                    Picker("업무구분", selection: Binding(
                        get: { 
                            let cats = keyword.bidCategories.split(separator: ",")
                            return cats.first.map(String.init) ?? "s"
                        },
                        set: { 
                            KeywordManager.updateBidCategories(keyword, categories: $0) 
                        }
                    )) {
                        Text("용역").tag("s")
                        Text("공사").tag("c")
                        Text("물품").tag("g")
                    }
                    .pickerStyle(.segmented)
                }

                // 일시중지
                Section {
                    Toggle("알림 받기", isOn: Binding(
                        get: { keyword.isActive },
                        set: { _ in KeywordManager.toggleActive(keyword) }
                    ))
                }

                // 토픽 정보 (디버그용)
                Section("구독 중인 토픽") {
                    if keyword.activeTopics.isEmpty {
                        Text("구독 중인 토픽 없음")
                            .font(.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                    } else {
                        ForEach(keyword.activeTopics, id: \.self) { topic in
                            Text(topic)
                                .font(.caption)
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                    }
                }

                // 삭제
                Section {
                    Button(role: .destructive) {
                        KeywordManager.removeKeyword(keyword, context: modelContext)
                        dismiss()
                    } label: {
                        Label("키워드 삭제", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(keyword.text)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }
}
