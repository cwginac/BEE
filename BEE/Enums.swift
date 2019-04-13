//
//  Enums.swift
//  BEE
//
//  Created by Chris on 3/3/19.
//  Copyright © 2019 Chris Ginac. All rights reserved.
//

import Foundation

enum SeverityType: String {
    case order
    case warning
    case none
}

enum LocationType: String {
    case fire
    case hurricane
    case tropicalStorm
    case humanShelter
    case smallAnimalShelter
    case largeAnimalShelter
    case hospital
    case police
    case other
    case roadBlocked
    case information
}

enum RouteStatus: String {
    case open
    case congested
    case closed
}

enum ReportType: String {
    case fire
    case danger
    case roadBlocked
    case other
}
