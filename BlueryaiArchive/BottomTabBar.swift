import SwiftUI

struct BottomTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 19, weight: .medium))
                        Text(tab.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(selectedTab == tab ? Color(hex: "#58a6ff") : Color(hex: "#8b949e"))
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 2)
        .background(
            Color(hex: "#161b22")
                .overlay(
                    Rectangle()
                        .fill(Color(hex: "#21262d"))
                        .frame(height: 1),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }
}