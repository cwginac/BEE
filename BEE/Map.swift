//
//  Map.swift
//  BEE
//
//  Created by Chris on 12/26/18.
//  Copyright © 2018 Chris Ginac. All rights reserved.
//

import Foundation

func drawOpenRoutes(evacuationRoutes: [[CLLocationCoordinate2D]]) {
    let origin = self.locationManager.location?.coordinate ?? self.mapView.userLocation?.coordinate
    for evacuationRoute in evacuationRoutes {
        var distances: [Double] = []
        
        for coordinate in evacuationRoute {
            distances.append((origin?.distance(to: coordinate))!)
        }
        let index = distances.firstIndex(of: distances.min()!)
        var waypoints: [Waypoint] = []
        waypoints.append(Waypoint(coordinate: origin!, coordinateAccuracy: 100, name: ""))
        for i in index!..<evacuationRoute.count {
            waypoints.append(Waypoint(coordinate: evacuationRoute[i], coordinateAccuracy: 100, name: ""))
        }
        
        let options = NavigationRouteOptions(waypoints: waypoints, profileIdentifier: MBDirectionsProfileIdentifier.automobile)
        Directions.shared.calculate(options) { (waypoints, routes, error) in
            if error?.localizedDescription != nil {
                print (error?.localizedDescription as Any)
            }
            let route = routes![0]
            guard route.coordinateCount > 0 else { return }
            
            self.g_routes.append(route)
            
            // Convert the route’s coordinates into a polyline
            var routeCoordinates = route.coordinates!
            let polyline = MGLPolylineFeature(coordinates: &routeCoordinates, count: route.coordinateCount)
            let uuid = UUID().uuidString
            // If there's already a route line on the map, reset its shape to the new route
            let source = MGLShapeSource(identifier: "route-source-open" + uuid, features: [polyline], options: nil)
            
            // Customize the route line color and width
            let lineStyle = MGLLineStyleLayer(identifier: "route-style-open" + uuid,  source: source)
            lineStyle.lineColor = NSExpression(forConstantValue: #colorLiteral(red: 0.1897518039, green: 0.3010634184, blue: 0.7994888425, alpha: 1))
            lineStyle.lineWidth = NSExpression(forConstantValue: 3)
            
            // Add the source and style layer of the route line to the map
            self.mapView.style?.addSource(source)
            self.mapView.style?.addLayer(lineStyle)
        }
    }
}
