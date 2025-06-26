//
//  AuthenticationView.swift
//  SOSync
//
//  Created by Islam Saadi on 26/06/2025.
//

import SwiftUI

struct AuthenticationView: View {
    @State private var isSignUp = false
    
    var body: some View {
        if isSignUp {
            SignUpView(isSignUp: $isSignUp)
        } else {
            SignInView(isSignUp: $isSignUp)
        }
    }
}

struct SignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isSignUp: Bool
    
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Logo
                Image(systemName: "shield.checkered")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                    .padding(.top, 50)
                
                Text("I'm Safe")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Stay connected, Stay safe")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Form fields
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress) // ✅ Fix for password autofill
                        .autocorrectionDisabled(true)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .textContentType(.password) // ✅ Fix for password autofill
                }
                .padding(.horizontal)
                
                // Error message
                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .fixedSize(horizontal: false, vertical: true) // ✅ Fix for text layout
                }
                
                // Sign in button
                Button {
                    Task {
                        await authViewModel.signIn(email: email, password: password)
                    }
                } label: {
                    HStack {
                        if authViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Sign In")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50) // ✅ Fixed height to prevent layout issues
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(email.isEmpty || password.isEmpty || authViewModel.isLoading)
                .padding(.horizontal)
                
                Spacer()
                
                // Sign up link
                HStack {
                    Text("Don't have an account?")
                        .foregroundStyle(.secondary)
                    Button("Sign Up") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSignUp = true
                        }
                    }
                    .fontWeight(.semibold)
                }
                .padding(.bottom, 30)
            }
            .navigationBarHidden(true)
            .onTapGesture {
                // ✅ Dismiss keyboard when tapping outside
                hideKeyboard()
            }
        }
    }
}

struct SignUpView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isSignUp: Bool
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var phoneNumber = ""
    
    // ✅ Add focus state for better UX
    @FocusState private var focusedField: Field?
    
    enum Field {
        case username, email, phone, password, confirmPassword
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isSignUp = false
                            }
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.title2)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Logo
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                        .padding(.top, 20)
                    
                    Text("Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    // Form fields
                    VStack(spacing: 16) {
                        TextField("Username (unique)", text: $username)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .textInputAutocapitalization(.never)
                            .textContentType(.username) // ✅ Proper content type
                            .autocorrectionDisabled(true)
                            .focused($focusedField, equals: .username)
                            .onSubmit { focusedField = .email }
                        
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress) // ✅ Proper content type
                            .autocorrectionDisabled(true)
                            .focused($focusedField, equals: .email)
                            .onSubmit { focusedField = .phone }
                        
                        TextField("Phone Number", text: $phoneNumber)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber) // ✅ Proper content type
                            .focused($focusedField, equals: .phone)
                            .onSubmit { focusedField = .password }
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .textContentType(.newPassword) // ✅ Proper content type for new password
                            .focused($focusedField, equals: .password)
                            .onSubmit { focusedField = .confirmPassword }
                        
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .textContentType(.newPassword) // ✅ Proper content type
                            .focused($focusedField, equals: .confirmPassword)
                            .onSubmit { focusedField = nil }
                    }
                    .padding(.horizontal)
                    
                    // Error message
                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                            .fixedSize(horizontal: false, vertical: true) // ✅ Fix for text layout
                    }
                    
                    // Validation message
                    if password != confirmPassword && !confirmPassword.isEmpty {
                        Text("Passwords don't match")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true) // ✅ Fix for text layout
                    }
                    
                    // Sign up button
                    Button {
                        Task {
                            await authViewModel.signUp(
                                email: email,
                                password: password,
                                username: username,
                                phoneNumber: phoneNumber
                            )
                        }
                    } label: {
                        HStack {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Create Account")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50) // ✅ Fixed height to prevent layout issues
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(
                        email.isEmpty ||
                        password.isEmpty ||
                        username.isEmpty ||
                        phoneNumber.isEmpty ||
                        password != confirmPassword ||
                        authViewModel.isLoading
                    )
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Sign in link
                    HStack {
                        Text("Already have an account?")
                            .foregroundStyle(.secondary)
                        Button("Sign In") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isSignUp = false
                            }
                        }
                        .fontWeight(.semibold)
                    }
                    .padding(.vertical, 30)
                }
            }
            .navigationBarHidden(true)
            .onTapGesture {
                // ✅ Dismiss keyboard when tapping outside
                hideKeyboard()
            }
        }
    }
}

// ✅ Helper extension to dismiss keyboard
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// Custom styles - ENHANCED
struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.vertical, 12) // ✅ Specific vertical padding
            .padding(.horizontal, 16) // ✅ Specific horizontal padding
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.separator), lineWidth: 0.5) // ✅ Subtle border
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 50) // ✅ Fixed height for consistency
            .background(
                configuration.isPressed ? Color.blue.opacity(0.8) : Color.blue
            )
            .foregroundStyle(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1) // ✅ Reduced scale for better feel
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthViewModel())
}
