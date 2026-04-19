import SwiftData
import SwiftUI

/// 알림 히스토리 화면 (알림 탭)
struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NotificationHistory.receivedAt, order: .reverse) private var allHistory: [NotificationHistory]
    @Binding var safariURL: URL?

    @State private var selectedFilter: NoticeFilter = .all
    @State private var searchText = ""
    @State private var isEditing = false
    @State private var selectedItems: Set<PersistentIdentifier> = []
    @State private var showDeleteConfirm = false

    private var filteredHistory: [NotificationHistory] {
        var result = allHistory

        // 유형 필터
        switch selectedFilter {
        case .all: break
        case .bid: result = result.filter { $0.noticeType == "bid" }
        case .prebid: result = result.filter { $0.noticeType == "prebid" }
        }

        // 검색
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.keyword.localizedCaseInsensitiveContains(searchText) ||
                $0.agency.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    /// 날짜별 그룹핑
    private var groupedHistory: [(key: String, items: [NotificationHistory])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredHistory) { item -> String in
            if calendar.isDateInToday(item.receivedAt) { return "오늘" }
            if calendar.isDateInYesterday(item.receivedAt) { return "어제" }

            let days = calendar.dateComponents([.day], from: item.receivedAt, to: Date()).day ?? 0
            if days < 7 { return "이번 주" }
            return "이전"
        }

        let order = ["오늘", "어제", "이번 주", "이전"]
        return order.compactMap { key in
            guard let items = grouped[key] else { return nil }
            return (key: key, items: items)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 세그먼트 필터
                Picker("필터", selection: $selectedFilter) {
                    Text("전체").tag(NoticeFilter.all)
                    Text("입찰공고").tag(NoticeFilter.bid)
                    Text("사전규격").tag(NoticeFilter.prebid)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)

                if filteredHistory.isEmpty {
                    emptyState
                } else {
                    // 편집 모드 시 하단 액션 바
                    if isEditing {
                        editingActionBar
                    }

                    List(selection: isEditing ? $selectedItems : nil) {
                        ForEach(groupedHistory, id: \.key) { group in
                            Section(group.key) {
                                ForEach(group.items) { item in
                                    HistoryCardView(item: item)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                        .listRowSeparator(.hidden)
                                        .tag(item.persistentModelID)
                                        .onTapGesture {
                                            if !isEditing {
                                                markAsRead(item)
                                                if let url = URL(string: item.detailUrl) {
                                                    safariURL = url
                                                }
                                            }
                                        }
                                        .swipeActions(edge: .trailing) {
                                            if !isEditing {
                                                Button(role: .destructive) {
                                                    withAnimation {
                                                        let noticeIdToRemove = item.noticeId
                                                        modelContext.delete(item)
                                                        // 명시적 저장으로 삭제 영속화
                                                        try? modelContext.save()
                                                        
                                                        Task {
                                                            await NotificationService.removeDeliveredNotification(noticeId: noticeIdToRemove)
                                                        }
                                                    }
                                                } label: {
                                                    Label("삭제", systemImage: "trash")
                                                }
                                            }
                                        }
                                        .swipeActions(edge: .leading) {
                                            if !isEditing {
                                                ShareLink(item: shareText(for: item)) {
                                                    Label("공유", systemImage: "square.and.arrow.up")
                                                }
                                                .tint(DS.Colors.primaryFallback)
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .environment(\.editMode, .constant(isEditing ? .active : .inactive))
                }
            }
            .background(DS.Colors.bgPrimary)
            .navigationTitle("알림 히스토리")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "공고명, 키워드, 기관 검색")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !filteredHistory.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isEditing.toggle()
                                if !isEditing {
                                    selectedItems.removeAll()
                                }
                            }
                        } label: {
                            Text(isEditing ? "완료" : "편집")
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .alert("선택한 알림을 삭제합니다", isPresented: $showDeleteConfirm) {
                Button("삭제 (\(selectedItems.count)건)", role: .destructive) {
                    deleteSelectedItems()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("선택한 \(selectedItems.count)건의 알림 히스토리를 삭제합니다. 이 작업은 되돌릴 수 없습니다.")
            }
        }
    }

    // MARK: - Editing Action Bar

    private var editingActionBar: some View {
        HStack(spacing: DS.Spacing.lg) {
            Button {
                if selectedItems.count == filteredHistory.count {
                    selectedItems.removeAll()
                } else {
                    selectedItems = Set(filteredHistory.map { $0.persistentModelID })
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: selectedItems.count == filteredHistory.count
                          ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(DS.Colors.primaryFallback)
                    Text(selectedItems.count == filteredHistory.count ? "전체 해제" : "전체 선택")
                        .font(.subheadline.weight(.medium))
                }
            }

            Spacer()

            if !selectedItems.isEmpty {
                Text("\(selectedItems.count)건 선택")
                    .font(.subheadline)
                    .foregroundStyle(DS.Colors.textSecondary)
            }

            Spacer()

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("삭제")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(selectedItems.isEmpty ? DS.Colors.textSecondary : DS.Colors.danger)
            }
            .disabled(selectedItems.isEmpty)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.bgSurface)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundStyle(DS.Colors.textSecondary.opacity(0.5))

            Text("아직 도착한 알림이 없어요")
                .font(.title3.weight(.medium))
                .foregroundStyle(DS.Colors.textSecondary)

            Text("키워드를 등록하면\n알림을 받을 수 있어요")
                .font(.subheadline)
                .foregroundStyle(DS.Colors.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding()
    }

    // MARK: - Actions

    private func markAsRead(_ item: NotificationHistory) {
        if !item.isRead {
            item.isRead = true
        }
    }

    private func deleteSelectedItems() {
        let itemsToDelete = allHistory.filter { selectedItems.contains($0.persistentModelID) }
        let noticeIdsToRemove = itemsToDelete.map { $0.noticeId }
        
        for item in itemsToDelete {
            modelContext.delete(item)
        }
        // 명시적 저장으로 삭제 영속화
        do {
            try modelContext.save()
        } catch {
            print("❌ 선택 삭제 저장 실패: \(error)")
        }
        selectedItems.removeAll()
        isEditing = false
        
        Task {
            await NotificationService.removeDeliveredNotifications(noticeIds: noticeIdsToRemove)
        }
    }

    private func shareText(for item: NotificationHistory) -> String {
        var lines = [
            "📋 나라장터 \(item.isBid ? "입찰공고" : "사전규격") 공유",
            "",
            "공고명: \(item.title)",
            "기관: \(item.agency)",
            "추정가격: \(item.priceDisplay)",
        ]
        if let closing = item.closingDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            lines.append("마감: \(formatter.string(from: closing))")
        }
        if !item.detailUrl.isEmpty {
            lines.append("상세: \(item.detailUrl)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Filter Enum

enum NoticeFilter: String, CaseIterable {
    case all, bid, prebid
}

