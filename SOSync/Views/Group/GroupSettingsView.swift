//
//  GroupSettingsView.swift
//  SOSync
//
//  Created by Islam Saadi on 26/06/2025.
//

import SwiftUI
import FirebaseDatabase

// MARK: - Group Settings View
struct GroupSettingsView: View {
    let group: SafetyGroup
    @ObservedObject var groupViewModel: GroupViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var safetyCheckInterval: Double
    @State private var sosInterval: Double
    
    init(group: SafetyGroup, groupViewModel: GroupViewModel) {
        self.group = group
        self.groupViewModel = groupViewModel
        _safetyCheckInterval = State(initialValue: Double(group.safetyCheckInterval))
        _sosInterval = State(initialValue: Double(group.sosInterval))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Safety Check Interval")
                        Spacer()
                        Text("\(Int(safetyCheckInterval)) minutes")
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(value: $safetyCheckInterval, in: 5...120, step: 5)
                } header: {
                    Text("Safety Check Settings")
                } footer: {
                    Text("Minimum time between safety check requests")
                }
                
                Section {
                    HStack {
                        Text("SOS Alert Interval")
                        Spacer()
                        Text("\(Int(sosInterval)) minutes")
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(value: $sosInterval, in: 1...30, step: 1)
                } header: {
                    Text("SOS Settings")
                } footer: {
                    Text("Minimum time between SOS alerts per member")
                }
                
                Section {
                    Text("Group ID: \(group.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("Created: \(Date(timeIntervalSince1970: group.createdAt), style: .date)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Group Information")
                }
            }
            .navigationTitle("Group Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                }
            }
        }
    }
    
    private func saveSettings() {
        Task {
            let database = Database.database().reference()
            try await database.child("groups").child(group.id).updateChildValues([
                "safetyCheckInterval": Int(safetyCheckInterval),
                "sosInterval": Int(sosInterval)
            ])
            
            await MainActor.run {
                dismiss()
            }
        }
    }
}
