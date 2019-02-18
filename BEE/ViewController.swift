//
//  ViewController.swift
//  BEE
//
//  Created by Christopher Ginac on 11/13/18.
//  Copyright © 2018 Chris Ginac. All rights reserved.
//

import UIKit
import CoreLocation
import Mapbox
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections

class ViewController: UIViewController, CLLocationManagerDelegate, MGLMapViewDelegate, NavigationViewControllerDelegate {
    let locationManager = CLLocationManager()

    @IBOutlet var navigateButton: UIButton!
    @IBOutlet var mapView: MGLMapView!
    @IBOutlet var evacType: UILabel!
    @IBOutlet var locationLabel: UILabel!
    
    var g_routes: [Route] = []
    var g_routeIds: [String] = []
    var g_instructions: String = ""
    var g_evacId: String = ""
    var g_timer: Timer = Timer.init()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.enableLocationServices()
        self.startMap()
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
        self.updateLocation(inEvacuation: false)
        self.getResponse()
    }
    
    @objc func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        print("Stopping Timer")
        self.g_timer.invalidate()
        navigationViewController.dismiss(animated: true, completion: nil)
    }
    
    func drawRoutes(evacuationRoutes: [[CLLocationCoordinate2D]], routeStatus: RouteStatus) {
        let origin = self.locationManager.location?.coordinate ?? self.mapView.userLocation?.coordinate
        for evacuationRoute in evacuationRoutes {
            var waypoints: [Waypoint] = []
            var index = 0
            
            // Only route from current location if the route is not closed
            if routeStatus != RouteStatus.closed {
                var distances: [Double] = []
                
                for coordinate in evacuationRoute {
                    distances.append((origin?.distance(to: coordinate))!)
                }
                index = distances.firstIndex(of: distances.min()!) ?? 0
                
                waypoints.append(Waypoint(coordinate: origin!, coordinateAccuracy: 100, name: ""))
            }
            
            // Add in rest of waypoints from the evacutation route.  If route is closed, this will just draw the entire closed route.
            for i in index..<evacuationRoute.count {
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
                let identifier = "route-source-" + UUID().uuidString
                self.g_routeIds.append(identifier)
                // If there's already a route line on the map, reset its shape to the new route
                let source = MGLShapeSource(identifier: identifier, features: [polyline], options: nil)
                
                // Customize the route line color and width
                let lineStyle = MGLLineStyleLayer(identifier: identifier,  source: source)
                
                if routeStatus == RouteStatus.open {
                    lineStyle.lineColor = NSExpression(forConstantValue: #colorLiteral(red: 0.1897518039, green: 0.3010634184, blue: 0.7994888425, alpha: 1))
                    
                }
                else if routeStatus == RouteStatus.congested {
                    lineStyle.lineColor = NSExpression(forConstantValue: #colorLiteral(red: 0.9607843161, green: 0.7058823705, blue: 0.200000003, alpha: 1))
                }
                else if routeStatus == RouteStatus.closed {
                    lineStyle.lineColor = NSExpression(forConstantValue: #colorLiteral(red: 0.8432787061, green: 0, blue: 0, alpha: 1))
                }
                lineStyle.lineWidth = NSExpression(forConstantValue: 3)
                
                // Add the source and style layer of the route line to the map
                self.mapView.style?.addSource(source)
                self.mapView.style?.addLayer(lineStyle)
            }
        }
    }
    
    func updateLocation(inEvacuation: Bool) {
        // prepare json data
        let location = self.locationManager.location?.coordinate ?? self.mapView.userLocation?.coordinate
        var dataString = "id=" + (UIDevice.current.identifierForVendor?.uuidString)! + "&latitude=" + String(format:"%f", (location?.latitude)!) + "&longitude=" + String(format:"%f", (location?.longitude)!)
        
        // create post request
        var url = URL(string: "http://bee-server.us-west-1.elasticbeanstalk.com/web-service/bee-server/update-location")!
        
        if (inEvacuation) {
            dataString = "userId=" + (UIDevice.current.identifierForVendor?.uuidString)! + "&latitude=" + String(format:"%f", (location?.latitude)!) + "&longitude=" + String(format:"%f", (location?.longitude)!)
            dataString += "&evacId=" + self.g_evacId;
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
    
    func getResponse() {
        // Set the URL the request is being made to.
        let request = URLRequest(url: NSURL(string: "http://bee-server.us-west-1.elasticbeanstalk.com/web-service/bee-server/get-events?id=" + (UIDevice.current.identifierForVendor?.uuidString)!)! as URL)
        do {
            // Perform the request
            let response: AutoreleasingUnsafeMutablePointer<URLResponse?>? = nil
            let data = try NSURLConnection.sendSynchronousRequest(request, returning: response)
            
                // Get the JSON Object
                let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
                if let jsonResult = jsonResult as? Dictionary<String, AnyObject>{
                    
                    // Get all alerts
                    let alerts = jsonResult["alerts"] as? [Dictionary<String, AnyObject>]
                    // For each alert...
                    for alert in alerts! {
                        let severity = SeverityType(rawValue: (alert["severity"] as? String)!)

                        // Draw the alert zone
                        var coordinateValues: [CLLocationCoordinate2D] = []
                        let coordinates = alert["boundaryCoordinates"] as? [Dictionary<String, AnyObject>]
                        for coordinate in coordinates! {
                            coordinateValues.append(CLLocationCoordinate2DMake((coordinate["latitude"] as! NSString).doubleValue, (coordinate["longitude"] as! NSString).doubleValue))
                        }
                        // Must close polygon (to fix bug in MapBox framework where at closer zoom levels, polygons will not close themselves)
                        coordinateValues.append(coordinateValues[0])
                        self.drawZones(coordinates: coordinateValues, alertSeverity: severity ?? SeverityType.None)
                        
                        // Display Instructions
                        let inUsersArea = (alert["inUsersArea"] as? NSString)?.boolValue
                        if inUsersArea ?? false {
                            // Update header
                            self.updateHeader(evac: severity ?? SeverityType.None)
                            self.g_instructions = alert["instructions"] as! String
                            self.showInstructions()
                            self.g_evacId = alert["evacId"] as? String ?? ""
                        
                            // Get Evacuation Routes
                            var evacuationRoute: [CLLocationCoordinate2D] = []
                            var openRoutes: [[CLLocationCoordinate2D]] = []
                            var congestedRoutes: [[CLLocationCoordinate2D]] = []
                            var closedRoutes: [[CLLocationCoordinate2D]] = []
                            let routes = alert["evacuationRoutes"] as? [Dictionary<String, AnyObject>]
                            for route in routes! {
                                let status = RouteStatus.init(rawValue: route["status"] as! String)
                                let intersections = route["intersections"] as? [Dictionary<String, AnyObject>]
                                for intersection in intersections! {
                                    evacuationRoute.append(CLLocationCoordinate2DMake((intersection["latitude"] as! NSString).doubleValue, (intersection["longitude"] as! NSString).doubleValue))
                                }
                                if status == RouteStatus.open {
                                    openRoutes.append(evacuationRoute)
                                }
                                else if status == RouteStatus.congested {
                                    congestedRoutes.append(evacuationRoute)
                                }
                                else { // closed
                                    closedRoutes.append(evacuationRoute)
                                }
                                evacuationRoute = []
                            }
                            
                            self.drawRoutes(evacuationRoutes: closedRoutes, routeStatus: RouteStatus.closed)
                            self.drawRoutes(evacuationRoutes: congestedRoutes, routeStatus: RouteStatus.congested)
                            self.drawRoutes(evacuationRoutes: openRoutes, routeStatus: RouteStatus.open)
                        }
                    }
                    
                    // Get all locations
                    let locations = jsonResult["locations"] as? [Dictionary<String, AnyObject>]
                    // For each event...
                    for location in locations! {
                        let type = LocationType(rawValue: (location["type"] as? String)!)
                        let locationPoint = LocationPointAnnotation()
                        locationPoint.typeOfLocation = type!
                        locationPoint.coordinate = CLLocationCoordinate2DMake((location["coordinates"]!["latitude"] as! NSString).doubleValue, (location["coordinates"]!["longitude"] as! NSString).doubleValue)
                        locationPoint.title = location["name"] as? String
                        locationPoint.subtitle = location["information"] as? String ?? ""
                        self.mapView.addAnnotation(locationPoint)
                    }
                    
                }
            } catch {
                // handle error
            }
    }
    func startMap() {
        self.mapView.showsUserLocation = true
        self.mapView.delegate = self
    }
    
    // Only move the map to user's location when map first loads.
    func mapViewDidFinishLoadingMap(_ mapView: MGLMapView) {
        let camera = MGLMapCamera(lookingAtCenter: (self.mapView.userLocation!.coordinate), altitude: 30000, pitch: 0, heading: 0)
        mapView.fly(to: camera, completionHandler: nil)
    }
    
    func drawZones(coordinates:[CLLocationCoordinate2D], alertSeverity: SeverityType) {
        let shape = MGLPolygonFeature(coordinates: coordinates, count: UInt(coordinates.count))
        var identifier: String = ""
        var color: UIColor = #colorLiteral(red: 0.6268994808, green: 0.02138105221, blue: 0.0009170532576, alpha: 1)
        
        if alertSeverity == SeverityType.Order {
            identifier = "order"
            color = #colorLiteral(red: 0.6274509804, green: 0.01960784314, blue: 0, alpha: 1)
        }
        else if alertSeverity == SeverityType.Warning {
            identifier = "warning"
            color = #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)
        }
        else {
            identifier = "none"
            color = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        }
        
        
        let source = MGLShapeSource(identifier: identifier, features: [shape], options: nil)
        self.mapView.style!.addSource(source)
        
        let layer = MGLFillStyleLayer(identifier: identifier + "layer", source: source)
        layer.fillColor = NSExpression(forConstantValue: color)
        layer.fillOpacity = NSExpression(forConstantValue: 0.5)
        
        self.mapView.style!.addLayer(layer)
    }
    
    // Location Annotation class, holds the type of Location it is.
    class LocationPointAnnotation: MGLPointAnnotation {
        var typeOfLocation:LocationType = LocationType.other
    }
    
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        // Always allow callouts to popup when annotations are tapped.
        return true
    }
    
    func mapView(_ mapView: MGLMapView, imageFor annotation: MGLAnnotation) -> MGLAnnotationImage? {
        let castAnnotation = annotation as? LocationPointAnnotation
        
        // For better performance, always try to reuse existing annotations.
        var annotationImage = mapView.dequeueReusableAnnotationImage(withIdentifier: (castAnnotation?.typeOfLocation.rawValue)!)
        
        // If there is no reusable annotation image available, initialize a new one.
        if(annotationImage == nil) {
            annotationImage = MGLAnnotationImage(image: UIImage(named: castAnnotation?.typeOfLocation.rawValue ?? "other")!, reuseIdentifier: castAnnotation?.typeOfLocation.rawValue ?? "other")
        }
        
        return annotationImage
    }
    
    func enableLocationServices() {
        self.locationManager.requestAlwaysAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
        }
    }
    
    func showInstructions () {
        let alert = UIAlertController(title: "Instructions", message: self.g_instructions, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Got it!", comment: "Default action"), style: .default, handler: { _ in
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func showInstructionsButton(_ sender: Any) {
        self.showInstructions()
    }
    
    @IBAction func startNavigation(_ sender: Any) {
        var shortestRoute: Double = Double(Int.max)
        var shortestIndex: Int = -1
        for (index, route) in g_routes.enumerated() {
            if route.expectedTravelTime < shortestRoute {
                shortestRoute = route.expectedTravelTime
                shortestIndex = index
            }
        }
        
        // For demonstration purposes, simulate locations if the Simulate Navigation option is on.
        let navigationService = MapboxNavigationService(route: g_routes[shortestIndex], simulating: .always)
        
        let navigationController = NavigationViewController(for: g_routes[shortestIndex], navigationService: navigationService)
        navigationController.delegate = self
        
        self.present(navigationController, animated: true, completion: nil)
        
        self.g_timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { timer in
            self.updateLocation(inEvacuation: true)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let _: CLLocationCoordinate2D = manager.location?.coordinate else { return }
        
        lookUpCurrentLocation(completionHandler: { (location) in
            var locString = ""
            let name = location?.name
            
            let sub = location?.subThoroughfare
            let thoroughfare = location?.thoroughfare

            var address = ""
            if sub != nil && thoroughfare != nil {
                address = sub! + " " + thoroughfare!
            }
            
            if address != "" && name != nil {
                if address.elementsEqual(name!) {
                    locString += name! + ", "
                }
                else {
                    locString += name! + ", " + address + ", "
                }
            }
            else if address != "" {
                locString += address + ", "
            }
            else if name != nil {
                locString += name! + ", "
            }
            
            if let subLoc = location?.subLocality {
                locString += subLoc + ",\n"
            }
            
            if let loc = location?.locality {
                locString += loc + ", "
            }
            
            if let subAdmin = location?.subAdministrativeArea {
                locString += subAdmin + ", "
            }
            
            if let admin = location?.administrativeArea {
                locString += admin + ", "
            }
            
            if let zip = location?.postalCode {
                locString += zip + " "
            }
            
            if let country = location?.isoCountryCode {
                locString += country
            }
            
            
            self.locationLabel.text = locString
        })
    }
    
    func lookUpCurrentLocation(completionHandler: @escaping (CLPlacemark?)
        -> Void ) {
        // Use the last reported location.
        if let lastLocation = self.locationManager.location {
            let geocoder = CLGeocoder()
            
            // Look up the location and pass it to the completion handler
            geocoder.reverseGeocodeLocation(lastLocation,
                                            completionHandler: { (placemarks, error) in
                                                if error == nil {
                                                    let firstLocation = placemarks?[0]
                                                    completionHandler(firstLocation)
                                                }
                                                else {
                                                    // An error occurred during geocoding.
                                                    completionHandler(nil)
                                                }
            })
        }
        else {
            // No location was available.
            completionHandler(nil)
        }
    }
    
    func updateHeader(evac: SeverityType) {
        if evac == SeverityType.Order {
            self.view.backgroundColor = #colorLiteral(red: 0.6268994808, green: 0.02138105221, blue: 0.0009170532576, alpha: 1)
            self.evacType.text = "⚠︎ Evacuation Order\nissued for:"
            self.evacType.textColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            self.locationLabel.textColor = #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)
        }
        else if evac == SeverityType.Warning {
            self.view.backgroundColor = #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)
            self.evacType.text = "⚠︎ Evacuation Warning\nissued for:"
            self.evacType.textColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            self.locationLabel.textColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        }
        else if evac == SeverityType.None {
            self.view.backgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            self.evacType.text = "No Alerts\nissued for:"
            self.evacType.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            self.locationLabel.textColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        }
    }
    
    enum SeverityType: String {
        case Order
        case Warning
        case None
    }
    
    enum LocationType: String {
        case fire
        case hurricane
        case tropicalStorm
        case humanShelter
        case smallAnimalsShelter
        case largeAnimalsShelter
        case hospital
        case police
        case other
    }
    
    enum RouteStatus: String {
        case open
        case congested
        case closed
    }
}

