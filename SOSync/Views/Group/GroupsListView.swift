
import SwiftUI
import FirebaseAuth

struct GroupsListView: View {
    // Add navigationTarget binding parameter
    @Binding var navigationTarget: ContentView.NavigationTarget?
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var groupViewModel = GroupViewModel()
    @State private var showCreateGroup = false
    @State private var selectedGroup: SafetyGroup?
    
    // Cache sorted groups to avoid recomputation on every view refresh
    @State private var sortedGroups: [SafetyGroup] = []

    var body: some View {
        NavigationStack {
            List {
                if sortedGroups.isEmpty && !groupViewModel.isLoading {
                    ContentUnavailableView {
                        Label("No Groups", systemImage: "person.3")
                    } description: {
                        Text("Create or join a group to get started")
                    } actions: {
                        Button("Create Group") {
                            showCreateGroup = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    // Use cached sorted groups
                    ForEach(sortedGroups) { group in
                        GroupRowView(group: group)
                            .onTapGesture {
                                selectedGroup = group
                            }
                    }
                }
            }
            .navigationTitle("My Groups")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateGroup = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .task(id: authViewModel.currentUser?.id) {
                guard let userId = authViewModel.currentUser?.id else { return }
                await groupViewModel.loadUserGroups(userId: userId)
            }
            .refreshable {
                if let userId = authViewModel.currentUser?.id {
                    await groupViewModel.loadUserGroups(userId: userId)
                }
            }
            .onChange(of: groupViewModel.groups) { _, newGroups in
                updateSortedGroups(newGroups)
            }
            .onAppear {
                updateSortedGroups(groupViewModel.groups)
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupView(groupViewModel: groupViewModel)
                    .environmentObject(authViewModel)
            }
            .navigationDestination(item: $selectedGroup) { group in
                GroupDetailView(group: group, groupViewModel: groupViewModel)
            }
        }
    }
    
    private func updateSortedGroups(_ groups: [SafetyGroup]) {
        let newSortedGroups = groups.sorted { group1, group2 in
            // Sort by status priority (higher priority number = shown first)
            let priority1 = group1.currentStatus.priority
            let priority2 = group2.currentStatus.priority
            
            if priority1 != priority2 {
                return priority1 > priority2  // Higher priority first
            }
            
            // If same priority, sort by most recent activity (lastSafetyCheck)
            let time1 = group1.lastSafetyCheck ?? 0
            let time2 = group2.lastSafetyCheck ?? 0
            
            if time1 != time2 {
                return time1 > time2  // Most recent first
            }
            
            // If same priority and time, sort alphabetically by name
            return group1.name.lowercased() < group2.name.lowercased()
        }
        
        // Only update if the sorted order actually changed
        if sortedGroups != newSortedGroups {
            sortedGroups = newSortedGroups
        }
    }
}

extension GroupsListView {
    init() {
        self._navigationTarget = .constant(nil)
    }
}

struct GroupRowView: View {
    let group: SafetyGroup
    
    private var statusColor: Color {
        switch group.currentStatus {
            case .normal:          return .gray
            case .checkingStatus:  return .orange
            case .allSafe:         return .green
            case .emergency:       return .red
        }
    }

    private var statusIcon: String {
        switch group.currentStatus {
            case .normal:          return "shield"
            case .checkingStatus:  return "clock.arrow.circlepath"
            case .allSafe:         return "checkmark.shield.fill"
            case .emergency:       return "exclamationmark.triangle.fill"
        }
    }
    
    private var isHighPriority: Bool {
        group.currentStatus.priority > 2
    }
    
    private var isEmergency: Bool {
        group.currentStatus == .emergency
    }

    var body: some View {
        HStack {
            
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .font(.title2)
                .scaleEffect(isEmergency ? 1.2 : 1.0)
                .animation(
                    isEmergency
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: group.currentStatus
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(group.name)
                        .font(.headline)
                        .fontWeight(isHighPriority ? .semibold : .regular)
                    
                    if isEmergency {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if group.currentStatus == .checkingStatus {
                        Image(systemName: "clock.badge")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                HStack {
                    Image(systemName: "person.3.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(group.members.count) members")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Text(group.currentStatus.displayName.capitalized)
                        .font(.caption)
                        .fontWeight(isHighPriority ? .semibold : .regular)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(isEmergency ? 0.3 : 0.2))
                        .foregroundStyle(statusColor)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(statusColor.opacity(0.5), lineWidth: isEmergency ? 2 : 1)
                        )
                }

                if let lastCheck = group.lastSafetyCheck,
                   group.currentStatus.priority > 1 {
                    Text(Date(timeIntervalSince1970: lastCheck), style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CreateGroupView: View {
    @ObservedObject var groupViewModel: GroupViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var groupName = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Group Name", text: $groupName)
                } header: {
                    Text("Group Information")
                } footer: {
                    Text("Choose a name that describes your group's purpose")
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            isCreating = true
                            if let userId = authViewModel.currentUser?.id {
                                await groupViewModel.createGroup(name: groupName, userId: userId)
                                dismiss()
                            }
                            isCreating = false
                        }
                    }
                    .disabled(groupName.isEmpty || isCreating)
                }
            }
        }
    }
}
