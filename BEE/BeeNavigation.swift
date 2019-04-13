//
//  BeeNavigation.swift
//  BEE
//
//  Created by Chris on 3/3/19.
//  Copyright © 2019 Chris Ginac. All rights reserved.
//

import CoreLocation
import Foundation
import Mapbox
import MapboxCoreNavigation
import MapboxDirections
import MapboxNavigation

class BeeNavigation {
    
    var evacuationRoutes: [EvacuationRoute] = []
    var evacuationDirections: [Route] = []
    
    var closestWaypoint: [String: Waypoint] = [:]
    var doneFindingClosestWaypoint: [String: Bool] = [:]
    
    var shortestRoute: [String: Route] = [:]
    var doneFindingShortestRoute: [String: Bool] = [:]
    
    func parseEvacuation(routes: [Dictionary<String, AnyObject>]) {
        // Get Evacuation Routes
        for route in routes {
            let evacuationRoute: EvacuationRoute = EvacuationRoute()
            
            evacuationRoute.route_id = route["routeId"] as! String
            evacuationRoute.status = RouteStatus.init(rawValue: route["status"] as! String)!
            evacuationRoute.last_update = Date()

            let waypoints = route["waypoints"] as! [Dictionary<String, AnyObject>]
            for waypoint in waypoints {
                let newWaypoint = BeeWaypoint()
                newWaypoint.waypoint_id = waypoint["waypoint_id"] as! String
                newWaypoint.route_id = waypoint["route_id"] as! String
                newWaypoint.ordinal = waypoint["ordinal"] as! Int
                newWaypoint.checkpoint = waypoint["checkpoint"] as! Bool
                newWaypoint.latitude = waypoint["coordinate"]!["latitude"] as! Double
                newWaypoint.longitude = waypoint["coordinate"]!["longitude"] as! Double
                
                if (newWaypoint.checkpoint) {
                    evacuationRoute.checkpoints.append(newWaypoint)
                }
                else {
                    evacuationRoute.waypoints.append(newWaypoint)
                }
            }
            evacuationRoutes.append(evacuationRoute)
        }
    }
    
    func getClosestWaypoint(evacRoute: EvacuationRoute, viewController: MapViewController) {
        self.doneFindingClosestWaypoint[evacRoute.route_id] = false
        
        let origin = viewController.locationManager.location?.coordinate ?? viewController.mapView.userLocation?.coordinate
        let originWaypoint = Waypoint(coordinate: origin!)
        originWaypoint.heading = -1
        originWaypoint.separatesLegs = false;
        
        var mapboxWaypoints: [Waypoint] = []
        
        var distances: [Waypoint: Double] = [:]
        
        for waypoint in evacRoute.waypoints {
            if (!waypoint.checkpoint) {
                mapboxWaypoints.append(originWaypoint)
                let mapboxWaypoint = Waypoint(coordinate: CLLocationCoordinate2DMake(waypoint.latitude, waypoint.longitude))
                mapboxWaypoints.append(mapboxWaypoint)

                let options = NavigationRouteOptions(waypoints: mapboxWaypoints, profileIdentifier: MBDirectionsProfileIdentifier.automobile)
                Directions.shared.calculate(options) { (mapboxWaypoints, routes, error) in
                    if error?.localizedDescription != nil {
                        print (error?.localizedDescription as Any)
                        return
                    }
                    distances[mapboxWaypoint] = routes![0].distance
                    
                    if distances.count == evacRoute.waypoints.count {
                        self.closestWaypoint[evacRoute.route_id] = (distances.min {a, b in a.value < b.value}?.key)!
                        self.doneFindingClosestWaypoint[evacRoute.route_id] = true
                    }
                }
                
                mapboxWaypoints = []
            }
        }
    }
    
    func getShortestRoute(evacRoute: EvacuationRoute, viewController: MapViewController) {
        self.doneFindingShortestRoute[evacRoute.route_id] = false
        let origin = viewController.locationManager.location?.coordinate ?? viewController.mapView.userLocation?.coordinate
        let originWaypoint = Waypoint(coordinate: origin!)
        originWaypoint.heading = -1
        originWaypoint.separatesLegs = false;
        
        self.closestWaypoint[evacRoute.route_id]!.heading = -1
        self.closestWaypoint[evacRoute.route_id]!.separatesLegs = false
        
        var mapboxWaypoints: [Waypoint] = []
        var routeDistance: [Route:Double] = [:]
        
        for (index, _) in evacRoute.checkpoints.enumerated() {
            mapboxWaypoints.append(originWaypoint)
            mapboxWaypoints.append(self.closestWaypoint[evacRoute.route_id]!)
            
            for i in index..<evacRoute.checkpoints.count {
                let mapboxWaypoint = Waypoint(coordinate: CLLocationCoordinate2DMake(evacRoute.checkpoints[i].latitude, evacRoute.checkpoints[i].longitude))
                mapboxWaypoint.heading = -1
                mapboxWaypoint.separatesLegs = false
                
                mapboxWaypoints.append(mapboxWaypoint)
            }
            
            let options = NavigationRouteOptions(waypoints: mapboxWaypoints, profileIdentifier: MBDirectionsProfileIdentifier.automobile)
            Directions.shared.calculate(options) { (mapboxWaypoints, routes, error) in
                if error?.localizedDescription != nil {
                    print (error?.localizedDescription as Any)
                    return
                }
                routeDistance[routes![0]] = routes![0].distance
                
                if routeDistance.count == evacRoute.checkpoints.count {
                    self.shortestRoute[evacRoute.route_id] = (routeDistance.min {a, b in a.value < b.value}?.key)!
                    self.doneFindingShortestRoute[evacRoute.route_id] = true
                }
            }
            
            mapboxWaypoints = []
        }
    }
    
    func drawRoute(route: Route, beeRoute: EvacuationRoute, viewController: MapViewController) {
        //Convert the route’s coordinates into a polyline
        var routeCoordinates = route.coordinates!
        let polyline = MGLPolylineFeature(coordinates: &routeCoordinates, count: route.coordinateCount)
        let identifier = beeRoute.route_id

        // If there's already a route line on the map, reset its shape to the new route
        let source = MGLShapeSource(identifier: identifier, features: [polyline], options: nil)

        // Customize the route line color and width
        let lineStyle = MGLLineStyleLayer(identifier: identifier,  source: source)

        if beeRoute.status == RouteStatus.open {
            lineStyle.lineColor = NSExpression(forConstantValue: #colorLiteral(red: 0.1897518039, green: 0.3010634184, blue: 0.7994888425, alpha: 1))

        }
        else if beeRoute.status == RouteStatus.congested {
            lineStyle.lineColor = NSExpression(forConstantValue: #colorLiteral(red: 0.9607843161, green: 0.7058823705, blue: 0.200000003, alpha: 1))
        }
        else if beeRoute.status == RouteStatus.closed {
            lineStyle.lineColor = NSExpression(forConstantValue: #colorLiteral(red: 0.8432787061, green: 0, blue: 0, alpha: 1))
        }
        lineStyle.lineWidth = NSExpression(forConstantValue: 3)

        // Add the source and style layer of the route line to the map
        viewController.mapView.style?.addSource(source)
        viewController.mapView.style?.addLayer(lineStyle)
    }
    
    func startNavigation (viewController: MapViewController) {
        var shortestRouteDistance: Double = Double(Int.max)
        var shortestActualRoute: Route? = nil
        
        for route in shortestRoute {
            if route.value.distance < shortestRouteDistance {
                shortestRouteDistance = route.value.distance
                shortestActualRoute = route.value
            }
        }
        
        // For demonstration purposes, simulate locations if the Simulate Navigation option is on.
        let navigationService = MapboxNavigationService(route: shortestActualRoute!, simulating: .always)
        
        let navigationController = NavigationViewController(for: shortestActualRoute!, navigationService: navigationService)
        navigationController.delegate = viewController
        
        viewController.present(navigationController, animated: true, completion: nil)
    
        viewController.g_timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { timer in
            viewController.server.updateLocation(inEvacuation: true, viewController: viewController)
        }
    }
}


