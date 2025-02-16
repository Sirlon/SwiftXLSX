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
    
    func ind() -> UInt64 {
        switch self {
        case .general:
            return UInt64("general".hash)
        case .number(let decimalPlaces):
            return UInt64("number\(decimalPlaces)".hash)
        case .currency(let decimalPlaces, let sign, let red):
            return UInt64("currency\(decimalPlaces)\(sign)\(red ? "1" : "0")".hash)
        case .accounting(let decimalPlaces, let sign):
            return UInt64("accounting\(decimalPlaces)\(sign)".hash)
        case .date(let format):
            return UInt64("date\(format)".hash)
        case .time(let format):
            return UInt64("time\(format)".hash)
        case .percentage(let decimalPlaces):
            return UInt64("percentage\(decimalPlaces)".hash)
        case .fraction:
            return UInt64("fraction".hash)
        case .scientific(let decimalPlaces):
            return UInt64("scientific\(decimalPlaces)".hash)
        case .text:
            return UInt64("text".hash)
        case .custom(let format):
            return UInt64("custom\(format)".hash)
        }
    }
}
