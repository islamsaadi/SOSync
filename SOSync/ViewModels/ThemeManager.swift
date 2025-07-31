//
//  ThemeManager.swift
//  SOSync
//
//  Created by Islam Saadi on 26/06/2025.
//

import SwiftUI

class ThemeManager: ObservableObject {
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    func toggleTheme() {
        isDarkMode.toggle()
    }
}
