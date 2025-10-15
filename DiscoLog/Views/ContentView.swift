//
//  ContentView.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/13.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [WorkLogs]
    
    @State private var selectedTab = 0

    var body: some View {
        
        TabView(selection: $selectedTab) {
            
            Tab("Home", systemImage: "house.fill", value: 0) {
                HomeTab()
            }

            
            Tab("Static", systemImage: "clock", value: 1) {

            }
            
            Tab("List", systemImage: "house.fill", value: 2) {
                EditTab()
                    .navigationTitle("工时记录")
            }
            
            Tab("Settings", systemImage: "gear", value: 3, role: .search) {

            }
            
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewBottomAccessory {
            if selectedTab == 0 {
                tabBottomWindowForHome()
            } else if selectedTab == 1 {
                tabBottomWindowForStatic()
            } else if selectedTab == 2 {
                tabBottomWindowForList()
            } else if selectedTab ==  3 {
                tabBottomWindowForSettings()
            }
            
        }
        .tabBarMinimizeBehavior(.onScrollDown)
//        .onChange(of: showingLeft, initial: true) {
//            if showingLeft == true && 
//        }
        
    }

}


struct tabBottomWindowForHome: View {
    var body: some View {
        Text("Home bottom")
    }
}

struct tabBottomWindowForStatic: View {
    var body: some View {
        Text("Static bottom")
    }
}

struct tabBottomWindowForList: View {
    @State private var modalType: ModalType?

    var body: some View {
        HStack{
            Text("Good Day!")
                .padding(.leading)
            
            Spacer(minLength: 0)
            Button {
                modalType = .addLog
            } label: {
                Text("新增记录")
                    .foregroundStyle(.orange)
            }
            .padding(.trailing)
            .sheet(item: $modalType) {sheet in
                sheet
                    .presentationDetents([.medium,  .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

struct tabBottomWindowForSettings: View {
    var body: some View {
        Text("Setting bottom")
    }
}

#Preview {
    ContentView()
        .environment(\.locale, .init(identifier: "zh-Hans-CN"))
        .modelContainer(PreviewListData.container)
}
