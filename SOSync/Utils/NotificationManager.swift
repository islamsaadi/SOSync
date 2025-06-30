//
//  NotificationManager.swift
//  SOSync
//
//  Created by Islam Saadi on 28/06/2025.
//

import Foundation
import FirebaseDatabase
import FirebaseAuth
import UserNotifications
import SwiftUI

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private let database = Database.database().reference()
    @Published var isNotificationPermissionGranted = false
    
    private init() {
        checkNotificationPermission()
    }
    
    // MARK: - Permission Management
    
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                self.isNotificationPermissionGranted = granted
            }
            
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                print("✅ Notification permission granted")
            } else {
                print("❌ Notification permission denied")
            }
            
            return granted
        } catch {
            print("❌ Error requesting notification permission: \(error)")
            return false
        }
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isNotificationPermissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - FCM Token Management
    
    func updateUserFCMToken(_ token: String) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user found")
            return
        }
        
        do {
            try await database
                .child("users")
                .child(userId)
                .child("fcmToken")
                .setValue(token)
            
            print("✅ FCM token updated for user: \(userId)")
        } catch {
            print("❌ Error updating FCM token: \(error)")
        }
    }
    
    // MARK: - Send Notifications
    
    func sendSafetyCheckNotification(to groupId: String, initiatedBy userId: String) async {
        await sendNotificationToGroup(
            groupId: groupId,
            title: "🔔 Safety Check",
            body: "Please confirm if you are safe",
            data: [
                "type": "safety_check",
                "groupId": groupId,
                "initiatedBy": userId
            ],
            excludeUserId: userId // Don't send to the person who initiated
        )
    }
    
    func sendSOSAlertNotification(to groupId: String, from userId: String, location: String?) async {
        do {
            // Get user info
            let userSnapshot = try await database.child("users").child(userId).getData()
            guard let userData = userSnapshot.value as? [String: Any],
                  let username = userData["username"] as? String else {
                print("❌ Could not get user info for SOS alert")
                return
            }
            
            let locationText = location ?? "Unknown location"
            
            await sendNotificationToGroup(
                groupId: groupId,
                title: "🚨 SOS ALERT",
                body: "\(username) needs help! Location: \(locationText)",
                data: [
                    "type": "sos_alert",
                    "groupId": groupId,
                    "userId": userId,
                    "location": locationText
                ],
                excludeUserId: userId,
                isUrgent: true
            )
        } catch {
            print("❌ Error sending SOS notification: \(error)")
        }
    }
    
    func sendGroupInviteNotification(to userId: String, groupName: String, inviterName: String) async {
        await sendNotificationToUser(
            userId: userId,
            title: "📨 Group Invitation",
            body: "\(inviterName) invited you to join '\(groupName)'",
            data: [
                "type": "group_invite",
                "groupName": groupName,
                "inviterName": inviterName
            ]
        )
    }
    
    func sendGroupStatusNotification(to groupId: String, status: String, message: String) async {
        let (title, emoji) = getStatusTitleAndEmoji(status: status)
        
        await sendNotificationToGroup(
            groupId: groupId,
            title: "\(emoji) \(title)",
            body: message,
            data: [
                "type": "group_status",
                "groupId": groupId,
                "status": status
            ]
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func sendNotificationToGroup(
        groupId: String,
        title: String,
        body: String,
        data: [String: String],
        excludeUserId: String? = nil,
        isUrgent: Bool = false
    ) async {
        do {
            // Get group members
            let groupSnapshot = try await database.child("groups").child(groupId).getData()
            guard let groupData = groupSnapshot.value as? [String: Any],
                  let members = groupData["members"] as? [String] else {
                print("❌ Could not get group members for notification")
                return
            }
            
            // Filter out excluded user if specified
            let targetMembers = excludeUserId != nil
                ? members.filter { $0 != excludeUserId }
                : members
            
            // Send to each member
            for memberId in targetMembers {
                await sendNotificationToUser(
                    userId: memberId,
                    title: title,
                    body: body,
                    data: data,
                    isUrgent: isUrgent
                )
            }
            
            print("✅ Sent notification to \(targetMembers.count) group members")
            
        } catch {
            print("❌ Error sending group notification: \(error)")
        }
    }
    
    private func sendNotificationToUser(
        userId: String,
        title: String,
        body: String,
        data: [String: String],
        isUrgent: Bool = false
    ) async {
        do {
            // Get user's FCM token
            let tokenSnapshot = try await database
                .child("users")
                .child(userId)
                .child("fcmToken")
                .getData()
            
            guard let fcmToken = tokenSnapshot.value as? String else {
                print("❌ No FCM token found for user: \(userId)")
                return
            }
            
            // Create notification payload
            var notificationData = data
            notificationData["userId"] = userId
            notificationData["timestamp"] = String(Date().timeIntervalSince1970)
            
            let payload: [String: Any] = [
                "to": fcmToken,
                "notification": [
                    "title": title,
                    "body": body,
                    "sound": isUrgent ? "emergency_sound.wav" : "default"
                ],
                "data": notificationData,
                "priority": isUrgent ? "high" : "normal",
                "content_available": true
            ]
            
            // Send via Firebase Cloud Functions or your backend
            await sendPushNotification(payload: payload)
            
        } catch {
            print("❌ Error sending notification to user \(userId): \(error)")
        }
    }
    
    private func sendPushNotification(payload: [String: Any]) async {
        // This should be sent through your backend/Cloud Functions
        // For now, we'll save it to Firebase for a Cloud Function to process
        do {
            let notificationRef = database.child("pendingNotifications").childByAutoId()
            try await notificationRef.setValue(payload)
            print("✅ Notification queued for processing")
        } catch {
            print("❌ Error queuing notification: \(error)")
        }
    }
    
    private func getStatusTitleAndEmoji(status: String) -> (String, String) {
        switch status {
        case "emergency":
            return ("EMERGENCY", "🚨")
        case "allSafe":
            return ("All Safe", "✅")
        case "checkingStatus":
            return ("Safety Check", "🔔")
        default:
            return ("Update", "📢")
        }
    }
    
    // MARK: - Local Notifications (for testing/offline)
    
    func scheduleLocalNotification(
        title: String,
        body: String,
        userInfo: [String: Any] = [:],
        delay: TimeInterval = 1
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Local notification scheduled")
        } catch {
            print("❌ Error scheduling local notification: \(error)")
        }
    }
}
