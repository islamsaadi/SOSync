//
//  ActiveSafetyCheckCard.swift
//  SOSync
//
//  Created by Islam Saadi on 24/06/2025.
//

import SwiftUI
import FirebaseDatabase

struct ActiveSafetyCheckCard: View {
    let safetyCheck: SafetyCheck
    let group: SafetyGroup
    @ObservedObject var groupViewModel: GroupViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var showResponseView = false
    @State private var isResponding = false
    @State private var initiatorUser: User?
    @State private var responseOfUser: SafetyResponseStatus = .noResponse
    
    private var currentUserId: String {
        authViewModel.currentUser?.id ?? ""
    }
    
    private var userHasResponded: Bool {
        safetyCheck.responses[currentUserId] != nil
    }
    
    private var userIsInitiator: Bool {
        safetyCheck.initiatedBy == currentUserId
    }
    
    private var responseCount: Int {
        safetyCheck.responses.count
    }
    
    private var totalMembers: Int {
        group.members.count
    }
    
    private var safeResponseCount: Int {
        safetyCheck.responses.values.filter { $0.status == .safe }.count
    }
    
    private var sosResponseCount: Int {
        safetyCheck.responses.values.filter { $0.status == .sos }.count
    }
    
    private var pendingResponseCount: Int {
        totalMembers - responseCount
    }
    
    private var userResponse: SafetyResponse? {
        safetyCheck.responses[currentUserId]
    }
    
    private var progressPercentage: Double {
        guard totalMembers > 0 else { return 0 }
        return Double(responseCount) / Double(totalMembers)
    }
    
    var body: some View {
        mainCardContent
            .padding()
            .background(cardBackground)
            .padding(.horizontal)
            .sheet(isPresented: $showResponseView) {
                responseSheet
            }
            .onAppear {
                loadInitiatorInfo()
            }
    }
    
    // MARK: - Broken down sub-views
    
    private var mainCardContent: some View {
        VStack(spacing: 16) {
            cardHeader
            Divider()
            actionSection
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.orange.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
    }
    
    private var responseSheet: some View {
        SafetyCheckResponseView(
            safetyCheck: safetyCheck,
            group: group,
            groupViewModel: groupViewModel,
            initialResponseStatus: responseOfUser
        )
    }
    
    private var cardHeader: some View {
        VStack(spacing: 12) {
            headerTopSection
            progressBar
            responseBreakdown
        }
    }
    
    private var headerTopSection: some View {
        HStack {
            headerLeftContent
            Spacer()
            progressCircle
        }
    }
    
    private var headerLeftContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerTitle
            timeStamp
            initiatorInfo
        }
    }
    
    private var headerTitle: some View {
        HStack {
            animatedIcon
            titleText
        }
    }
    
    private var animatedIcon: some View {
        Image(systemName: "clock.arrow.circlepath")
            .foregroundStyle(Color.orange)
            .font(.title2)
            .scaleEffect(1.1)
            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: true)
    }
    
    private var titleText: some View {
        Text("Active Safety Check")
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundStyle(Color.orange)
    }
    
    private var timeStamp: some View {
        Text("Started \(Date(timeIntervalSince1970: safetyCheck.timestamp), style: .relative) ago")
            .font(.caption)
            .foregroundStyle(Color.secondary)
    }
    
    private var initiatorInfo: some View {
        Group {
            if let initiator = initiatorUser {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.blue)
                    Text(userIsInitiator ? "You started this check" : "Started by \(initiator.username)")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }
    
    private var progressCircle: some View {
        VStack(spacing: 4) {
            circleProgress
            circleLabel
        }
    }
    
    private var circleProgress: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 4)
                .frame(width: 50, height: 50)
            
            Circle()
                .trim(from: 0, to: progressPercentage)
                .stroke(
                    sosResponseCount > 0 ? Color.red : Color.orange,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progressPercentage)
            
            Text("\(responseCount)")
                .font(.headline)
                .fontWeight(.bold)
        }
    }
    
    private var circleLabel: some View {
        Text("of \(totalMembers)")
            .font(.caption2)
            .foregroundStyle(Color.secondary)
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                safeProgressSegment(geometry: geometry)
                sosProgressSegment(geometry: geometry)
                pendingProgressSegment(geometry: geometry)
            }
        }
        .frame(height: 8)
        .background(Color(.systemGray6))
        .cornerRadius(4)
    }
    
    private func safeProgressSegment(geometry: GeometryProxy) -> some View {
        Group {
            if safeResponseCount > 0 {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.green)
                    .frame(width: geometry.size.width * CGFloat(safeResponseCount) / CGFloat(totalMembers))
            }
        }
    }
    
    private func sosProgressSegment(geometry: GeometryProxy) -> some View {
        Group {
            if sosResponseCount > 0 {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red)
                    .frame(width: geometry.size.width * CGFloat(sosResponseCount) / CGFloat(totalMembers))
            }
        }
    }
    
    private func pendingProgressSegment(geometry: GeometryProxy) -> some View {
        Group {
            if pendingResponseCount > 0 {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(.systemGray4))
                    .frame(width: geometry.size.width * CGFloat(pendingResponseCount) / CGFloat(totalMembers))
            }
        }
    }
    
    private var responseBreakdown: some View {
        HStack(spacing: 20) {
            ResponseCounter(
                icon: "checkmark.circle.fill",
                count: safeResponseCount,
                color: Color.green,
                label: "Safe"
            )
            
            ResponseCounter(
                icon: "exclamationmark.triangle.fill",
                count: sosResponseCount,
                color: Color.red,
                label: "SOS"
            )
            
            ResponseCounter(
                icon: "clock",
                count: pendingResponseCount,
                color: Color.orange,
                label: "Pending"
            )
        }
    }
    
    private var actionSection: some View {
        Group {
            if userHasResponded {
                userResponseSection
            } else {
                responseOptionsSection
            }
        }
    }
    
    private var userResponseSection: some View {
        HStack(spacing: 12) {
            responseIcon
            responseDetails
            Spacer()
            detailsButton
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var responseIcon: some View {
        Image(systemName: userResponse?.status == .safe ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
            .font(.title2)
            .foregroundStyle(userResponse?.status == .safe ? Color.green : Color.red)
    }
    
    private var responseDetails: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(userResponse?.status == .safe ? "You marked yourself as SAFE" : "You sent an SOS alert")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Responded \(Date(timeIntervalSince1970: userResponse?.timestamp ?? 0), style: .relative) ago")
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
    }
    
    private var detailsButton: some View {
        Button("Details") {
            showResponseView = true
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
    
    private var responseOptionsSection: some View {
        VStack(spacing: 12) {
            responsePrompt
            responseButtons
            contextMessage
        }
    }
    
    private var responsePrompt: some View {
        Text("Please confirm your safety status")
            .font(.subheadline)
            .fontWeight(.medium)
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.primary)
    }
    
    private var responseButtons: some View {
        HStack(spacing: 12) {
            safeButton
            sosButton
        }
    }
    
    private var safeButton: some View {
        Button {
            responseOfUser = .safe
            showResponseView = true
        } label: {
            Label("I'm Safe", systemImage: "checkmark.shield.fill")
                .frame(maxWidth: .infinity)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.green)
        .controlSize(.large)
        .disabled(isResponding)
    }
    
    private var sosButton: some View {
        Button {
            responseOfUser = .sos
            showResponseView = true
        } label: {
            Label("SOS", systemImage: "exclamationmark.triangle.fill")
                .frame(maxWidth: .infinity)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .buttonStyle(.bordered)
        .tint(Color.red)
        .controlSize(.large)
    }
    
    private var contextMessage: some View {
        Group {
            if userIsInitiator {
                Text("You started this check - please respond to show you're safe")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Respond to let your group know you're okay")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Helper methods
    
    private func loadInitiatorInfo() {
        Task {
            do {
                let database = Database.database().reference()
                let userData = try await database.child("users").child(safetyCheck.initiatedBy).getData()
                if let userDict = userData.value as? [String: Any],
                   let jsonData = try? JSONSerialization.data(withJSONObject: userDict),
                   let user = try? JSONDecoder().decode(User.self, from: jsonData) {
                    await MainActor.run {
                        self.initiatorUser = user
                    }
                }
            } catch {
                print("Error loading initiator info:", error)
            }
        }
    }
}

struct ResponseCounter: View {
    let icon: String
    let count: Int
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text("\(count)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.secondary)
        }
        .frame(minWidth: 60)
    }
}
