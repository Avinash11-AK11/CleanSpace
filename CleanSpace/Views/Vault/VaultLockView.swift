//
//  VaultLockView.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 23/09/2026, 10:55 AM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import SwiftUI
import LocalAuthentication

struct VaultLockView: View {
    @ObservedObject var vaultManager = VaultManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var enteredPin = ""
    @State private var confirmPin = ""
    @State private var isConfirming = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 30) {
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(AppTheme.subtleGray)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            Spacer()
            
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentPurple.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 38))
                        .foregroundColor(AppTheme.accentPurple)
                }
                
                Text(vaultManager.hasPINConfigured ? "Private Vault" : "Set Vault PIN")
                    .font(.title2.bold())
                
                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.subtleGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // PIN Dots
            HStack(spacing: 18) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < currentPinLength ? AppTheme.accentPurple : Color.gray.opacity(0.3))
                        .frame(width: 18, height: 18)
                        .scaleEffect(index < currentPinLength ? 1.2 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: currentPinLength)
                }
            }
            .padding(.vertical, 8)
            
            if showError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .transition(.opacity)
            }
            
            Spacer()
            
            // Number Pad
            VStack(spacing: 16) {
                ForEach(0..<3) { row in
                    HStack(spacing: 28) {
                        ForEach(1..<4) { col in
                            let num = row * 3 + col
                            PinButton(title: "\(num)") {
                                appendDigit("\(num)")
                            }
                        }
                    }
                }
                
                HStack(spacing: 28) {
                    if vaultManager.hasPINConfigured {
                        Button {
                            HapticManager.shared.impact(.medium)
                            authenticateWithBiometrics()
                        } label: {
                            Image(systemName: "faceid")
                                .font(.system(size: 28))
                                .foregroundColor(AppTheme.accentPurple)
                                .frame(width: 75, height: 75)
                                .background(AppTheme.accentPurple.opacity(0.1))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(AppTheme.accentPurple.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .buttonStyle(BounceButtonStyle())
                    } else {
                        Spacer()
                            .frame(width: 75, height: 75)
                    }
                    
                    PinButton(title: "0") {
                        appendDigit("0")
                    }
                    
                    Button {
                        deleteDigit()
                    } label: {
                        Image(systemName: "delete.left.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.subtleGray)
                            .frame(width: 75, height: 75)
                            .background(AppTheme.cardBackground.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(BounceButtonStyle())
                }
            }
            .padding(.bottom, 24)
        }
        .background(AppTheme.primaryBackground.ignoresSafeArea())
        .onAppear {
            if vaultManager.hasPINConfigured {
                authenticateWithBiometrics()
            }
        }
    }
    
    private var currentPinLength: Int {
        isConfirming ? confirmPin.count : enteredPin.count
    }
    
    private var subtitleText: String {
        if !vaultManager.hasPINConfigured {
            return isConfirming ? "Re-enter your 4-digit PIN to confirm" : "Create a 4-digit PIN to secure private photos"
        }
        return "Enter your 4-digit PIN or use Face ID"
    }
    
    private func appendDigit(_ digit: String) {
        HapticManager.shared.impact(.light)
        showError = false
        if !vaultManager.hasPINConfigured {
            if !isConfirming {
                if enteredPin.count < 4 {
                    enteredPin.append(digit)
                    if enteredPin.count == 4 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            isConfirming = true
                        }
                    }
                }
            } else {
                if confirmPin.count < 4 {
                    confirmPin.append(digit)
                    if confirmPin.count == 4 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            validateNewPin()
                        }
                    }
                }
            }
        } else {
            if enteredPin.count < 4 {
                enteredPin.append(digit)
                if enteredPin.count == 4 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        validateExistingPin()
                    }
                }
            }
        }
    }
    
    private func deleteDigit() {
        HapticManager.shared.selection()
        showError = false
        if !vaultManager.hasPINConfigured {
            if isConfirming {
                if !confirmPin.isEmpty {
                    confirmPin.removeLast()
                } else {
                    isConfirming = false
                }
            } else {
                if !enteredPin.isEmpty {
                    enteredPin.removeLast()
                }
            }
        } else {
            if !enteredPin.isEmpty {
                enteredPin.removeLast()
            }
        }
    }
    
    private func validateNewPin() {
        if enteredPin == confirmPin {
            HapticManager.shared.notification(.success)
            vaultManager.setPIN(enteredPin)
            _ = vaultManager.verifyPIN(enteredPin)
            dismiss()
        } else {
            HapticManager.shared.notification(.error)
            errorMessage = "PINs do not match. Try again."
            showError = true
            enteredPin = ""
            confirmPin = ""
            isConfirming = false
        }
    }
    
    private func validateExistingPin() {
        if vaultManager.verifyPIN(enteredPin) {
            HapticManager.shared.notification(.success)
            dismiss()
        } else {
            HapticManager.shared.notification(.error)
            errorMessage = "Incorrect PIN"
            showError = true
            enteredPin = ""
        }
    }
    
    private func authenticateWithBiometrics() {
        Task {
            let success = await vaultManager.authenticateWithBiometrics()
            if success {
                HapticManager.shared.notification(.success)
                dismiss()
            }
        }
    }
}

private struct PinButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .frame(width: 75, height: 75)
                .background(AppTheme.cardBackground)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(BounceButtonStyle())
    }
}
