//
//  Settings.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/13.
//
import SwiftUI
import Combine

class UserSettings: ObservableObject {
    @Published var username: String = "Guest"
    
    @Published var DefaultWorkDurationMinutes: Int = 480
}
