import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        if authViewModel.isAuthenticated {
            MainTabView()
        } else {
            AuthenticationView()
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var invitesVM = InvitationsViewModel(
      userId: Auth.auth().currentUser?.uid ?? ""
    )
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GroupsListView()
                .tabItem {
                    Label("Groups", systemImage: "person.3.fill")
                }
                .tag(0)
            
            InvitationsView()
                    .environmentObject(invitesVM)
                    .tabItem { Label("Invites", systemImage: "envelope.fill") }
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
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
        .environmentObject(ThemeManager())
}
