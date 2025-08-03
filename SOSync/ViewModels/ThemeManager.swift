
import SwiftUI

class ThemeManager: ObservableObject {
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    func toggleTheme() {
        isDarkMode.toggle()
    }
}
