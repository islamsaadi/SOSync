import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
struct SOSyncApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(themeManager)
                .environmentObject(notificationManager)
                .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
                .onAppear {
                    Task {
                        await requestNotificationPermissionIfNeeded()
                    }
                }
        }
    }
    
    private func requestNotificationPermissionIfNeeded() async {
        if !notificationManager.isNotificationPermissionGranted {
           _ = await notificationManager.requestNotificationPermission()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure messaging and notifications
        setupNotifications(application)
        
        return true
    }
    
    // MARK: - Notification Setup
    
    private func setupNotifications(_ application: UIApplication) {
        // Set delegates
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        // Request permission (will be handled by NotificationManager in ContentView)
        application.registerForRemoteNotifications()
        
        print("✅ Notification setup completed")
    }
    
    // MARK: - Remote Notification Registration
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("✅ Device registered for remote notifications")
        print("📱 Device token: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
        
        // Set APNS token for Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // MARK: - MessagingDelegate
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔥 Firebase registration token received")
        
        guard let token = fcmToken else {
            print("❌ FCM token is nil")
            return
        }
        
        print("📝 FCM Token: \(token)")
        
        // Store token locally
        UserDefaults.standard.set(token, forKey: "FCMToken")
        
        // Update user's FCM token in database
        Task {
            await NotificationManager.shared.updateUserFCMToken(token)
        }
    }
    
    // ✅ FIX: Remove MessagingRemoteMessage (not available in iOS Firebase SDK)
    // The messaging(_:didReceive:) method is for Android only
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        print("📱 Notification received while app is in foreground")
        print("📋 UserInfo: \(userInfo)")
        
        // Determine presentation options based on notification type
        let options = getPresentationOptions(for: userInfo)
        completionHandler(options)
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("👆 User tapped notification")
        print("📋 UserInfo: \(userInfo)")
        
        // Handle notification tap
        handleNotificationTap(userInfo: userInfo)
        
        completionHandler()
    }
    
    // MARK: - Notification Handling
    
    private func getPresentationOptions(for userInfo: [AnyHashable: Any]) -> UNNotificationPresentationOptions {
        guard let notificationType = userInfo["type"] as? String else {
            return [.banner, .badge, .sound]
        }
        
        switch notificationType {
        case "sos_alert":
            // SOS alerts should be very prominent
            return [.banner, .badge, .sound, .list]
        case "safety_check":
            // Safety checks should be noticeable
            return [.banner, .badge, .sound]
        case "group_invite":
            // Group invites can be less intrusive
            return [.banner, .badge]
        default:
            return [.banner, .badge, .sound]
        }
    }
    
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let notificationType = userInfo["type"] as? String else {
            print("❌ No notification type in tapped notification")
            return
        }
        
        print("🎯 Handling notification tap for type: \(notificationType)")
        
        // Use NotificationCenter to communicate with SwiftUI views
        let notificationName = Notification.Name("HandleNotificationTap")
        NotificationCenter.default.post(
            name: notificationName,
            object: nil,
            userInfo: userInfo
        )
        
        // Specific handling based on type
        switch notificationType {
        case "safety_check":
            navigateToSafetyCheck(userInfo)
        case "sos_alert":
            navigateToSOSAlert(userInfo)
        case "group_invite":
            navigateToGroupInvites(userInfo)
        case "group_status":
            navigateToGroup(userInfo)
        default:
            print("⚠️ Unknown notification type for navigation: \(notificationType)")
        }
    }
    
    // MARK: - Navigation Helpers
    
    private func navigateToSafetyCheck(_ userInfo: [AnyHashable: Any]) {
        if let groupId = userInfo["groupId"] as? String {
            print("🎯 Navigate to safety check for group: \(groupId)")
            
            // Post notification for SwiftUI to handle navigation
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToSafetyCheck"),
                object: nil,
                userInfo: ["groupId": groupId]
            )
        }
    }
    
    private func navigateToSOSAlert(_ userInfo: [AnyHashable: Any]) {
        if let groupId = userInfo["groupId"] as? String {
            print("🎯 Navigate to SOS alert for group: \(groupId)")
            
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToSOSAlert"),
                object: nil,
                userInfo: ["groupId": groupId]
            )
        }
    }
    
    private func navigateToGroupInvites(_ userInfo: [AnyHashable: Any]) {
        print("🎯 Navigate to group invites")
        
        NotificationCenter.default.post(
            name: Notification.Name("NavigateToInvites"),
            object: nil,
            userInfo: userInfo
        )
    }
    
    private func navigateToGroup(_ userInfo: [AnyHashable: Any]) {
        if let groupId = userInfo["groupId"] as? String {
            print("🎯 Navigate to group: \(groupId)")
            
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToGroup"),
                object: nil,
                userInfo: ["groupId": groupId]
            )
        }
    }
}
