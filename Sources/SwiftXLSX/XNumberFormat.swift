//
//  File.swift
//  
//
//  Created by Alexander Rauscha on 06.12.23.
//

import Foundation


public enum XNumberFormat {
    case general
    case number(decimalPlaces: Int = 0)
    case currency(decimalPlaces: Int = 1, sign: String = "$", red: Bool = false)
    case accounting(decimalPlaces: Int = 0, sign: String = "$")
    case date(format: String)
    case time(format: String)
    case percentage(decimalPlaces: Int = 0)
    case fraction
    case scientific(decimalPlaces: Int = 1)
    case text
    case custom(format: String)
    
    func ind() -> String {
        switch self {
        case .general:
            return "general"
        case .number(let decimalPlaces):
            return "number\(decimalPlaces)"
        case .currency(let decimalPlaces, let sign, let red):
            return "currency\(decimalPlaces)\(sign)\(red ? "1" : "0")"
        case .accounting(let decimalPlaces, let sign):
            return "accounting\(decimalPlaces)\(sign)"
        case .date(let format):
            return "date\(format)"
        case .time(let format):
            return "time\(format)"
        case .percentage(let decimalPlaces):
            return "percentage\(decimalPlaces)"
        case .fraction:
            return "fraction"
        case .scientific(let decimalPlaces):
            return "scientific\(decimalPlaces)"
        case .text:
            return "text"
        case .custom(let format):
            return "custom\(format)"
        }
    }
}
