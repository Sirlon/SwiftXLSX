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
    case currency(decimalPlaces: Int = 1, red: Bool)
    case accounting(decimalPlaces: Int = 0)
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
            return 0
        case .number(let decimalPlaces):
            if decimalPlaces == 2 {
                return 2
            } else if decimalPlaces <= 0 {
                return 1
            } else {
                return 0
            }
        case .currency(let decimalPlaces, let red):
            if decimalPlaces == 2 {
                if red {
                    return 40
                }
                return 39
            } else if decimalPlaces <= 1 {
                if red {
                    return 38
                }
                return 37
            } else {
                return 0
            }
        case .accounting(let decimalPlaces):
            return 40
        case .date(let format):
            switch format {
            case "d/m/yyyy":
                return 14
            case "d-mmm-yy":
                return 15
            case "d-mmm":
                return 16
            case "mmm-yy":
                return 17
            case "m/d/yyyy H:mm":
                return 22
            default:
                return UInt64.max
            }
        case .time(let format):
            switch format {
            case "h:mm tt":
                return 18
            case "h:mm:ss tt":
                return 19
            case "h:mm":
                return 20
            case "h:mm:ss":
                return 21
            case "mm:ss":
                return 45
            case "[h]:mm:ss":
                return 46
            case "mmss.0":
                return 47
            default:
                return UInt64.max
            }
        case .percentage(let decimalPlaces):
            if decimalPlaces == 2 {
                return 10
            } else if decimalPlaces <= 0 {
                return 9
            } else {
                return 0
            }
        case .fraction:
            return 12
        case .scientific(let decimalPlaces):
            if decimalPlaces == 1 {
                return 48
            } else if decimalPlaces == 2 {
                return  11
            } else {
                return 0
            }
        case .text:
            return 49
        case .custom(let format):
            return UInt64.max
        }
    }
}
