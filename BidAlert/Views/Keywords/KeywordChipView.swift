import SwiftData
import SwiftUI

/// 키워드 Chip 뷰
struct KeywordChipView: View {
    let keyword: Keyword
    var onTap: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 5) {
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
                    .foregroundStyle(keyword.isActive ? DS.Colors.primaryFallback : DS.Colors.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            keyword.isActive
                ? DS.Colors.primaryFallback.opacity(0.1)
                : Color.gray.opacity(0.1)
        )
        .foregroundStyle(
            keyword.isActive
                ? DS.Colors.primaryFallback
                : DS.Colors.textSecondary
        )
        .clipShape(Capsule())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(keyword.text) 키워드, 입찰공고와 사전규격, \(categoryBadgeText(categoryString: keyword.bidCategories))")
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
