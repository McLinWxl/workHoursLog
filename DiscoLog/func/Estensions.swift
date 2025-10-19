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

extension Collection {
    /// 将集合按 size 切成等份（最后一段可短）
    func chunked(into size: Int) -> [[Element]] {
        precondition(size > 0, "size 必须大于 0")
        var result: [[Element]] = []
        var idx = startIndex
        while idx != endIndex {
            let end = index(idx, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(Array(self[idx..<end]))
            idx = end
        }
        return result
    }
}
//Text("Hello")
//    .font(.title)
//    .if(condition) { view in
//        view
//            .foregroundStyle(.orange)
//            .shadow(color: .orange.opacity(0.3), radius: 5)
//    }

