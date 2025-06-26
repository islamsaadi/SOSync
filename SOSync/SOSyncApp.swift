//
//  SOSyncApp.swift
//  SOSync
//
//  Created by Islam Saadi on 26/06/2025.
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
struct SOSyncApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure push notifications
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                if let error = error {
                    print("Notification authorization error: \(error.localizedDescription)")
                } else {
                    print("Notification authorization granted: \(granted)")
                }
            }
        )
        
        application.registerForRemoteNotifications()
        Messaging.messaging().delegate = self
        
        return true
    }
    
    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        print("Device token registered successfully")
    }
    
    func application(_ application: UIApplication,
                    didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // MARK: - MessagingDelegate
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        
        // Store FCM token in UserDefaults and update user profile
        if let token = fcmToken {
            UserDefaults.standard.set(token, forKey: "FCMToken")
            
            // Update user's FCM token in Firebase Database
            // You can call your AuthViewModel method here to update the token
            Task {
                await updateUserFCMToken(token)
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // You can customize behavior based on notification content
        let userInfo = notification.request.content.userInfo
        print("Received notification while app in foreground: \(userInfo)")
        
        // Show notification even when app is in foreground
        completionHandler([.banner, .badge, .sound])
    }
    
    // Handle notification tap when app is in background/closed
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        print("User tapped notification: \(userInfo)")
        
        // Handle different notification types
        handleNotificationTap(userInfo: userInfo)
        
        completionHandler()
    }
    
    // MARK: - Helper Methods
    
    private func updateUserFCMToken(_ token: String) async {
        // You'll need to implement this in your AuthViewModel
        // Example: await AuthViewModel.shared.updateFCMToken(token)
        print("TODO: Update user FCM token in database: \(token)")
    }
    
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        // Handle different types of notifications
        if let notificationType = userInfo["type"] as? String {
            switch notificationType {
            case "safety_check":
                // Navigate to safety check
                print("Navigate to safety check")
            case "sos_alert":
                // Navigate to SOS alert
                print("Navigate to SOS alert")
            case "group_invite":
                // Navigate to group invite
                print("Navigate to group invite")
            default:
                print("Unknown notification type: \(notificationType)")
            }
        }
    }
}
