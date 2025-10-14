//
//  CustomModifiers.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/13.
//

import SwiftUI

struct CustomButtonComfirm: ButtonStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2.bold())
            .foregroundStyle(.green)
            .padding()
            .glassEffect(.regular.tint(.green.opacity(0.25)).interactive())
    }
}

struct CustomButtonDismiss: ButtonStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2.bold())
            .foregroundStyle(.red)
            .padding()
            .glassEffect(.regular.tint(.orange.opacity(0.3)).interactive())
    }
}

#Preview {
    Button ("确 认") {
        print("clicked")
    }
    .buttonStyle(CustomButtonComfirm())
    
    Button ("取 消") {
        print("clicked")
    }
    .buttonStyle(CustomButtonDismiss())
}
