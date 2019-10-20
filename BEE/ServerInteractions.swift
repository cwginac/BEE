//
//  ServerInteractions.swift
//  BEE
//
//  Created by Chris on 3/3/19.
//  Copyright © 2019 Chris Ginac. All rights reserved.
//

import CoreLocation
import Foundation
import UIKit

class Server {
    var navigation: BeeNavigation = BeeNavigation()
    
    func updateLocationInBackground() {
        let locationManager = CLLocationManager()
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        var notificationToken = ""
        if (appDelegate.deviceToken != "") {
            notificationToken = appDelegate.deviceToken
        }
        
        let userToken = (UIDevice.current.identifierForVendor?.uuidString)!
        
        // prepare json data
        let location = locationManager.location?.coordinate
        var dataString = "id=" + userToken + "&latitude=" + String(format:"%f", (location?.latitude)!) + "&longitude=" + String(format:"%f", (location?.longitude)!)
        
        if (notificationToken != "") {
            dataString += "&notification_token=" + notificationToken
        }
        
        // create post request
        let url = URL(string: "http://bee-server.us-west-1.elasticbeanstalk.com/web-service/bee-server/update-location")!
        
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = dataString.data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            if let responseJSON = responseJSON as? [String: Any] {
                print(responseJSON)
            }
        }
        
        task.resume()
    }
    
    func report(viewController: MapViewController, type: ReportType, info: String) {
        let locationManager = CLLocationManager()
        
        let userToken = (UIDevice.current.identifierForVendor?.uuidString)!
        
        // prepare json data
        let location = locationManager.location?.coordinate
        var dataString = "userId=" + userToken
        dataString += "&latitude=" + String(format:"%f", (location?.latitude)!) + "&longitude=" + String(format:"%f", (location?.longitude)!)
        dataString += "&type=" + type.rawValue
        dataString += "&info=" + info
        dataString += "&evacId=" + viewController.g_evacId
        
        // create post request
        let url = URL(string: "http://bee-server.us-west-1.elasticbeanstalk.com/web-service/bee-server/report")!
        
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = dataString.data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            if let responseJSON = responseJSON as? [String: Any] {
                print(responseJSON)
            }
        }
        
        task.resume()
    }

    func reportSafe(viewController: MapViewController) {
        print("Marking Safe")
        
        let userToken = (UIDevice.current.identifierForVendor?.uuidString)!
        
        // prepare json data
        let dataString = "userId=" + userToken + "&evacId=" + viewController.g_evacId
        
        // create post request
        let url = URL(string: "http://bee-server.us-west-1.elasticbeanstalk.com/web-service/bee-server/evacuation-safe")!
        
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = dataString.data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            if let responseJSON = responseJSON as? [String: Any] {
                print(responseJSON)
            }
        }
        
        task.resume()
    }
    
    func updateLocation(inEvacuation: Bool, viewController: MapViewController) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        var notificationToken = ""
        if (appDelegate.deviceToken != "") {
            notificationToken = appDelegate.deviceToken
        }
        
        let userToken = (UIDevice.current.identifierForVendor?.uuidString)!

        
        // prepare json data
        let location = viewController.locationManager.location?.coordinate ?? viewController.mapView.userLocation?.coordinate
        var dataString = "id=" + userToken + "&latitude=" + String(format:"%f", (location?.latitude)!) + "&longitude=" + String(format:"%f", (location?.longitude)!)
        
        if (notificationToken != "") {
            dataString += "&notification_token=" + notificationToken
        }
        
        // create post request
        var url = URL(string: "http://bee-server.us-west-1.elasticbeanstalk.com/web-service/bee-server/update-location")!
        
        if (inEvacuation) {
            dataString = "userId=" + userToken
            dataString += "&name=" + viewController.defaults.string(forKey: "name")!
            dataString += "&latitude=" + String(format:"%f", (location?.latitude)!) + "&longitude=" + String(format:"%f", (location?.longitude)!)
            dataString += "&evacId=" + viewController.g_evacId;
            if (notificationToken != "") {
                dataString += "&notification_token=" + notificationToken
            }
            url = URL(string: "http://bee-server.us-west-1.elasticbeanstalk.com/web-service/bee-server/evacuation-update-location")!
            print("updating location for evacuation")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = dataString.data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            if let responseJSON = responseJSON as? [String: Any] {
                print(responseJSON)
            }
        }
        
        task.resume()
    }

    func getLocations(viewController: MapViewController) {
        // Set the URL the request is being made to.
        let request = URLRequest(url: NSURL(string: "http://bee-server.us-west-1.elasticbeanstalk.com/web-service/bee-server/get-locations?id=" + (UIDevice.current.identifierForVendor?.uuidString)!)! as URL)
        do {
            // Perform the request
            let response: AutoreleasingUnsafeMutablePointer<URLResponse?>? = nil
            let data = try NSURLConnection.sendSynchronousRequest(request, returning: response)
            
            // Get the JSON Object
            let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
            if let jsonResult = jsonResult as? Dictionary<String, AnyObject>{
                // Get all locations
                let locations = jsonResult["locations"] as? [Dictionary<String, AnyObject>]
                // For each event...
                for location in locations! {
                    let type = LocationType(rawValue: (location["type"] as? String)!)
                    let locationPoint = LocationPointAnnotation()
                    locationPoint.typeOfLocation = type!
                    locationPoint.coordinate = CLLocationCoordinate2DMake((location["coordinate"]!["latitude"] as! NSNumber).doubleValue, (location["coordinate"]!["longitude"] as! NSNumber).doubleValue)
                    locationPoint.title = location["name"] as? String
                    locationPoint.subtitle = location["info"] as? String ?? ""
                    viewController.mapView.addAnnotation(locationPoint)
                }
            }
        } catch {
            // handle error
        }
    }

    func getEvents(viewController: MapViewController) {
        
        let userToken = (UIDevice.current.identifierForVendor?.uuidString)!
        
        // Set the URL the request is being made to.
        let request = URLRequest(url: NSURL(string: "http://bee-server.us-west-1.elasticbeanstalk.com/web-service/bee-server/get-events?id=" + userToken)! as URL)
        do {
            // Perform the request
            let response: AutoreleasingUnsafeMutablePointer<URLResponse?>? = nil
            let data = try NSURLConnection.sendSynchronousRequest(request, returning: response)
            
            // Get the JSON Object
            let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
            if let jsonResult = jsonResult as? Dictionary<String, AnyObject>{
                
                // Get all alerts
                let alerts = jsonResult["events"] as? [Dictionary<String, AnyObject>]
                // For each alert...
                for alert in alerts! {
                    let severity = SeverityType(rawValue: (alert["severity"] as? String)!)
                    
                    // Draw the alert zone
                    var coordinateValues: [CLLocationCoordinate2D] = []
                    let coordinates = alert["boundaryPoints"] as? [Dictionary<String, AnyObject>]
                    for coordinate in coordinates! {
                        coordinateValues.append(CLLocationCoordinate2DMake(coordinate["coordinate"]!["latitude"] as! Double, coordinate["coordinate"]!["longitude"] as! Double))
                    }
                    // Must close polygon (to fix bug in MapBox framework where at closer zoom levels, polygons will not close themselves)
                    coordinateValues.append(coordinateValues[0])
                    viewController.drawZones(coordinates: coordinateValues, alertSeverity: severity ?? SeverityType.none)
                    
                    // Display Instructions
                    let inUsersArea = alert["inUsersArea"] as? Bool ?? true
                    if inUsersArea {
                        // Update header
                        viewController.updateHeader(evac: severity ?? SeverityType.none)
                        viewController.g_instructions = alert["instructions"] as! String
                        viewController.showInstructions()
                        viewController.g_evacId = alert["eventId"] as? String ?? ""
                        
                        // Get Evacuation Routes
                        navigation.parseEvacuation(routes: alert["routes"] as! [Dictionary<String, AnyObject>])
                        for route in navigation.evacuationRoutes {
                            navigation.getClosestWaypoint(evacRoute: route, viewController: viewController)
                            
                            _ = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                                if self.navigation.doneFindingClosestWaypoint[route.route_id] ?? false {
                                    timer.invalidate()
                                    self.navigation.getShortestRoute(evacRoute: route, viewController: viewController)
                                    _ = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                                        if self.navigation.doneFindingShortestRoute[route.route_id] ?? false {
                                            timer.invalidate()
                                            self.navigation.drawRoute(route: self.navigation.shortestRoute[route.route_id]!, beeRoute: route, viewController: viewController)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            // handle error
        }
    }
    
    func acknowledgeEvacuation(viewController: MapViewController) {
        let userToken = (UIDevice.current.identifierForVendor?.uuidString)!
        
        // prepare json data
        let dataString = "userId=" + userToken + "&evacId=" + viewController.g_evacId
        
        // create post request
        let url = URL(string: "http://bee-server.us-west-1.elasticbeanstalk.com/web-service/bee-server/acknowledge-evacuation")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = dataString.data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            if let responseJSON = responseJSON as? [String: Any] {
                print(responseJSON)
            }
        }
        
        task.resume()
    }
}
