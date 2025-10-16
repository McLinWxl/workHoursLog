//
//  Estensions.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/15.
//
import SwiftUI
import Foundation

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool,
                             apply modifier: (Self) -> Content) -> some View {
        if condition {
            modifier(self)
        } else {
            self
        }
    }
}

extension Color {
    static var inversePrimary: Color {
        let scheme = UITraitCollection.current.userInterfaceStyle
        return scheme == .dark ? .black : .white
    }
}
//Text("Hello")
//    .font(.title)
//    .if(condition) { view in
//        view
//            .foregroundStyle(.orange)
//            .shadow(color: .orange.opacity(0.3), radius: 5)
//    }

