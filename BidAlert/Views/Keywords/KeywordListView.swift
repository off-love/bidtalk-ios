import SwiftData
import SwiftUI

/// 키워드 관리 화면 (홈 탭)
struct KeywordListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Keyword.createdAt, order: .reverse) private var keywords: [Keyword]
    var notificationService: NotificationService

    @State private var newKeyword = ""
    @State private var selectedBidCategory = "s"         // 업무구분 기본값 (용역)
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedKeyword: Keyword?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    // 알림 미허용 배너
                    if !notificationService.isAuthorized {
                        alertBanner
                    }

                    // 키워드 입력
                    keywordInput

                    // 내 키워드
                    if !keywords.isEmpty {
                        myKeywordsSection
                    }

                    // 추천 키워드
                    recommendedSection

                    // 안내 카드
                    infoCard
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
            }
            .background(DS.Colors.bgPrimary)
            .navigationTitle("키워드 설정")
            .navigationBarTitleDisplayMode(.inline)
            .alert("오류", isPresented: $showError) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(item: $selectedKeyword) { keyword in
                KeywordDetailSheet(keyword: keyword)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Subviews

    private var alertBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DS.Colors.accentFallback)
            Text("알림이 꺼져 있어요")
                .font(.subheadline.weight(.medium))
            Spacer()
            Button("켜기") {
                notificationService.openSettings()
            }
            .font(.subheadline.bold())
            .foregroundStyle(DS.Colors.accentFallback)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.accentFallback.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private var keywordInput: some View {
        VStack(spacing: DS.Spacing.sm) {
            // 검색 입력
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DS.Colors.textSecondary)

                TextField("관심 키워드를 입력하세요", text: $newKeyword)
                    .textInputAutocapitalization(.never)
                    .focused($isInputFocused)
                    .onSubmit { addKeyword() }
                    .disabled(keywords.count >= KeywordManager.maxKeywords)

                if !newKeyword.isEmpty {
                    Button("추가") { addKeyword() }
                        .font(.subheadline.bold())
                        .foregroundStyle(DS.Colors.primaryFallback)
                }
            }

            // 업무구분 선택
            HStack(spacing: DS.Spacing.xs) {
                Text("업무구분")
                    .font(.caption)
                    .foregroundStyle(DS.Colors.textSecondary)

                Picker("업무구분", selection: $selectedBidCategory) {
                    Text("용역").tag("s")
                    Text("공사").tag("c")
                    Text("물품").tag("g")
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    private var myKeywordsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("내 키워드")
                    .font(.headline)
                Spacer()
                Text("\(keywords.count)/\(KeywordManager.maxKeywords)")
                    .font(.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }

            // FlowLayout (chip tags)
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(keywords) { keyword in
                    KeywordChipView(keyword: keyword) {
                        selectedKeyword = keyword
                    } onDelete: {
                        withAnimation(.spring(duration: 0.3)) {
                            KeywordManager.removeKeyword(keyword, context: modelContext)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Label("추천 키워드", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(DS.Colors.accentFallback)

            ForEach(DS.recommendedKeywords, id: \.category) { group in
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(group.category)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DS.Colors.textSecondary)

                    FlowLayout(spacing: DS.Spacing.xs) {
                        ForEach(group.keywords, id: \.self) { kw in
                            let isAdded = keywords.contains { $0.text == kw }
                            Button {
                                if !isAdded {
                                    newKeyword = kw
                                    addKeyword()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if isAdded {
                                        Image(systemName: "checkmark")
                                            .font(.caption2)
                                    }
                                    Text(kw)
                                        .font(.subheadline)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isAdded ? DS.Colors.primaryFallback.opacity(0.1) : Color.gray.opacity(0.1))
                                .foregroundStyle(isAdded ? DS.Colors.primaryFallback : DS.Colors.textSecondary)
                                .clipShape(Capsule())
                            }
                            .disabled(isAdded)
                        }
                    }
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(DS.Colors.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private var infoCard: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(DS.Colors.primaryFallback)
            Text("새 공고는\n평일 30분, 주말 2시간마다 확인해요")
                .font(.caption)
                .foregroundStyle(DS.Colors.textSecondary)
            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.primaryFallback.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .padding(.bottom, DS.Spacing.xxl)
    }

    // MARK: - Actions

    private func addKeyword() {
        let result = KeywordManager.addKeyword(
            newKeyword,
            bidCategories: selectedBidCategory,
            context: modelContext
        )
        switch result {
        case .success:
            withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                newKeyword = ""
                isInputFocused = false
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += maxHeight + spacing
                maxHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            sizes.append(size)
            maxHeight = max(maxHeight, size.height)
            x += size.width + spacing
        }

        return LayoutResult(
            positions: positions,
            sizes: sizes,
            size: CGSize(width: maxWidth, height: y + maxHeight)
        )
    }

    struct LayoutResult {
        var positions: [CGPoint]
        var sizes: [CGSize]
        var size: CGSize
    }
}
