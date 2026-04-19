import SwiftUI

/// 온보딩 플로우 (3장 슬라이드)
struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @State private var showSettingsAlert = false

    private let pages: [(icon: String, title: String, subtitle: String)] = [
        (
            "bell.badge.fill",
            "입찰톡에\n오신 것을 환영합니다",
            "나라장터 입찰공고와 사전규격을\n가장 빠르게 알려드려요"
        ),
        (
            "tag.fill",
            "관심 키워드를\n등록하세요",
            "키워드만 등록하면\n새 공고가 올라올 때 자동으로 알림이 와요"
        ),
        (
            "iphone.badge.play",
            "알림을 켜야\n놓치지 않아요",
            "입찰 기회를 놓치지 않으려면\n알림을 반드시 켜주세요"
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 슬라이드
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    VStack(spacing: DS.Spacing.xl) {
                        Spacer()

                        Image(systemName: pages[index].icon)
                            .font(.system(size: 80))
                            .foregroundStyle(
                                index == 2
                                    ? DS.Colors.accentFallback
                                    : DS.Colors.primaryFallback
                            )
                            .symbolEffect(.pulse, options: .repeating)

                        VStack(spacing: DS.Spacing.md) {
                            Text(pages[index].title)
                                .font(.title.bold())
                                .multilineTextAlignment(.center)

                            Text(pages[index].subtitle)
                                .font(.body)
                                .foregroundStyle(DS.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        Spacer()
                        Spacer()
                    }
                    .padding(.horizontal, DS.Spacing.xxl)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)

            // 하단 버튼
            VStack(spacing: DS.Spacing.md) {
                if currentPage == pages.count - 1 {
                    // 마지막 페이지: 알림 허용 버튼
                    Button {
                        Task {
                            let granted = await NotificationService().requestAuthorization()
                            if !granted {
                                showSettingsAlert = true
                            }
                            hasCompletedOnboarding = true
                        }
                    } label: {
                        Text("알림 허용하고 시작하기")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(DS.Colors.accentFallback)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }

                    Button("나중에 설정할게요") {
                        hasCompletedOnboarding = true
                    }
                    .font(.subheadline)
                    .foregroundStyle(DS.Colors.textSecondary)
                } else {
                    Button {
                        withAnimation { currentPage += 1 }
                    } label: {
                        Text("다음")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(DS.Colors.primaryFallback)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }

                    Button("건너뛰기") {
                        hasCompletedOnboarding = true
                    }
                    .font(.subheadline)
                    .foregroundStyle(DS.Colors.textSecondary)
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .alert("알림 권한이 필요합니다", isPresented: $showSettingsAlert) {
            Button("설정으로 이동") {
                NotificationService().openSettings()
            }
            Button("나중에", role: .cancel) {}
        } message: {
            Text("설정 앱에서 알림을 허용해주세요.\n알림이 없으면 입찰 기회를 놓칠 수 있어요.")
        }
    }
}
