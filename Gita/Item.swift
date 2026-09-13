//
//  Item.swift
//  Gita
//
//  Created by Kenzie Fubrianto on 13/09/26.
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
