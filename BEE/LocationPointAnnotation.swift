//
//  LocationPointAnnotation.swift
//  BEE
//
//  Created by Chris on 3/3/19.
//  Copyright © 2019 Chris Ginac. All rights reserved.
//

import Foundation
import Mapbox

// Location Annotation class, holds the type of Location it is.
class LocationPointAnnotation: MGLPointAnnotation {
    var typeOfLocation:LocationType = LocationType.other
}
