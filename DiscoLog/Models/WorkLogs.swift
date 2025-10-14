//
//  Item.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/13.
//

import Foundation
import SwiftData

@Model
final class WorkLogs {
    var startTime: Date
    var endTime: Date
    
    
    init(startTime: Date, endTime: Date) {
        self.startTime = startTime
        self.endTime = endTime
    }
}
