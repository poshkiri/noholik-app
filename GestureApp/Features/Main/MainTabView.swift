import SwiftUI

struct MainTabView: View {
    enum AppTab: Hashable {
        case feed, matches, clubs, chats, profile
    }

    @State private var selection: AppTab = .feed

    var body: some View {
        TabView(selection: $selection) {
            SwipeFeedView()
                .tabItem { Label("Лента", systemImage: "flame.fill") }
                .tag(AppTab.feed)

            MatchesListView()
                .tabItem { Label("Мэтчи", systemImage: "sparkles") }
                .tag(AppTab.matches)

            ClubsListView()
                .tabItem { Label("Клубы", systemImage: "person.3.fill") }
                .tag(AppTab.clubs)

            ChatListView()
                .tabItem { Label("Чаты", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(AppTab.chats)

            MyProfileView()
                .tabItem { Label("Профиль", systemImage: "person.crop.circle.fill") }
                .tag(AppTab.profile)
        }
        .tint(AppColor.accent)
    }
}

#Preview {
    MainTabView().environment(AppState())
}
