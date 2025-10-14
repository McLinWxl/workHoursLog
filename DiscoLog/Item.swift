//
//  Item.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/13.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
