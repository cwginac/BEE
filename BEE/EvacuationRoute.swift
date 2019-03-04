//
//  EvacuationRoute.swift
//  BEE
//
//  Created by Chris on 3/3/19.
//  Copyright © 2019 Chris Ginac. All rights reserved.
//

import Foundation


class EvacuationRoute {
    var route_id: String = ""
    var status: RouteStatus = RouteStatus.closed
    var last_update: Date = NSDate.distantPast
    
    var waypoints: [BeeWaypoint] = []
    var checkpoints: [BeeWaypoint] = []
}
