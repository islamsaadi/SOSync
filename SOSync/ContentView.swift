import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var selectedTab = 0
    @State private var navigationTarget: NavigationTarget?
    
    enum NavigationTarget: Equatable {
        case safetyCheck(groupId: String)
        case sosAlert(groupId: String)
        case invites
        case group(groupId: String)
    }
    
    var body: some View {
        if authViewModel.isAuthenticated {
            MainTabView(selectedTab: $selectedTab, navigationTarget: $navigationTarget)
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToSafetyCheck"))) { notification in
                    if let groupId = notification.userInfo?["groupId"] as? String {
                        navigationTarget = .safetyCheck(groupId: groupId)
                        selectedTab = 0 // Groups tab
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToSOSAlert"))) { notification in
                    if let groupId = notification.userInfo?["groupId"] as? String {
                        navigationTarget = .sosAlert(groupId: groupId)
                        selectedTab = 0 // Groups tab
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToInvites"))) { _ in
                    navigationTarget = .invites
                    selectedTab = 1 // Invites tab
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToGroup"))) { notification in
                    if let groupId = notification.userInfo?["groupId"] as? String {
                        navigationTarget = .group(groupId: groupId)
                        selectedTab = 0 // Groups tab
                    }
                }
        } else {
            AuthenticationView()
        }
    }
}

struct MainTabView: View {
    @Binding var selectedTab: Int
    @Binding var navigationTarget: ContentView.NavigationTarget?
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var invitesVM = InvitationsViewModel(
        userId: Auth.auth().currentUser?.uid ?? ""
    )
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GroupsListView(navigationTarget: $navigationTarget)
                .tabItem {
                    Label("Groups", systemImage: "person.3.fill")
                }
                .tag(0)
            
            InvitationsView()
                .environmentObject(invitesVM)
                .tabItem {
                    Label("Invites", systemImage: "envelope.fill")
                }
                .badge(invitesVM.pendingInvitations.count)
                .tag(1)
            
            SOSView()
                .tabItem {
                    Label("SOS", systemImage: "exclamationmark.triangle.fill")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
        .onAppear {
            Task {
                if let userId = authViewModel.currentUser?.id {
                    await invitesVM.loadPendingInvitations(for: userId)
                }
            }
        }
        .onChange(of: navigationTarget) { oldValue, newValue in
            handleNavigationTarget(newValue)
        }
    }
    
    private func handleNavigationTarget(_ target: ContentView.NavigationTarget?) {
        guard let target = target else { return }
        
        switch target {
        case .invites:
            selectedTab = 1
        case .safetyCheck(let groupId), .sosAlert(let groupId), .group(let groupId):
            selectedTab = 0
        }
        
        // Clear the navigation target after handling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            navigationTarget = nil
        }
    }
}
