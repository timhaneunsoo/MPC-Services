//
//  Extensions.swift
//

import Foundation

extension Date {
    func toFirestoreDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
}
