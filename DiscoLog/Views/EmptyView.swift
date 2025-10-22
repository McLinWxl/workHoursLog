//
//  EmptyView.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/22.
//

import SwiftUI

struct EmptyView: View {
    @State private var modalType: ModalType?

    var body: some View {
        NavigationStack {
            VStack {
                Text("暂无工时记录")
                    .font(.title2)
                Text("点击右上角\(Image(systemName: "square.and.pencil"))以添加")
                    .font(.callout)
                    .foregroundStyle(.secondary)

            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        modalType = .addLog(defaultDate: Date())
                    } label: {
                        Label("添加", systemImage: "square.and.pencil")
                    }
                }
            }
            .sheet(item: $modalType) {sheet in
                ModalSheetView(modal: sheet)
                    .presentationDetents([.medium,  .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

#Preview {
    EmptyView()
}
