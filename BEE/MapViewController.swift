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

class MapViewController: UIViewController, CLLocationManagerDelegate, MGLMapViewDelegate, NavigationViewControllerDelegate {
    let locationManager = CLLocationManager()
    let defaults = UserDefaults.standard

    @IBOutlet var navigateButton: UIButton!
    @IBOutlet var mapView: MGLMapView!
    @IBOutlet var evacType: UILabel!
    @IBOutlet var locationLabel: UILabel!
    
    var g_routes: [Route] = []
    var g_routeIds: [String] = []
    var g_instructions: String = ""
    var g_evacId: String = ""
    var g_timer: Timer = Timer.init()
    
    var userToken: String = ""
    
    var server: Server = Server()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.startMap()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.locationManager.delegate = self
        self.locationManager.requestAlwaysAuthorization()
        
        if CLLocationManager.authorizationStatus() != .denied {
            if self.defaults.string(forKey: "name") == nil {
                self.getName()
            }
            self.startMap()
        }
        else {
            let alertController = UIAlertController(title: "Location Services Disabled", message: "Location Services are disabled for this application, application will not function correctly.", preferredStyle: UIAlertController.Style.alert)
            self.present(alertController, animated: true, completion: nil)
        }
    }

    
    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .restricted, .denied, .notDetermined:
            self.locationManager.requestAlwaysAuthorization()
            break
        case .authorizedWhenInUse, .authorizedAlways:
            self.startMap()
            break
        }
    }
    
    func getName() {
        let alertController = UIAlertController(title: "Enter Name", message: "Please enter your name so that when needed others can know that you're safe.", preferredStyle: UIAlertController.Style.alert)
        
        alertController.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = "Enter Full Name"
        }
        
        let saveAction = UIAlertAction(title: "Save", style: UIAlertAction.Style.default, handler: { alert -> Void in
            let firstTextField = alertController.textFields![0] as UITextField
            self.defaults.set(firstTextField.text, forKey: "name")
            self.defaults.set(true, forKey: "infoEntered")
            
            print (self.defaults)
            
            self.startMap()
        })
        
        alertController.addAction(saveAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
        server.getEvents(viewController: self)
        server.getLocations(viewController: self)
    }
    
    @objc func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        print("Stopping Timer")
        self.g_timer.invalidate()
        navigationViewController.dismiss(animated: true, completion: nil)
        
        if canceled {
            let alert = UIAlertController(title: "Canceled Navigation", message: "You cancelled the navigation, are you safely out of the evacuation zone?", preferredStyle: .alert)
            // Create the actions
            let yesAction = UIAlertAction(title: "Yes I Am Safe", style: UIAlertAction.Style.default) {
                UIAlertAction in
                self.server.reportSafe(viewController: self)
            }
            
            let noAction = UIAlertAction(title: "I Am Not Out Of Zone Yet", style: UIAlertAction.Style.default) {
                UIAlertAction in
                self.server.updateLocation(inEvacuation: true, viewController: self)
            }
            
            alert.addAction(yesAction)
            alert.addAction(noAction)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func startMap() {
        self.mapView.showsUserLocation = true
        self.mapView.delegate = self
        self.updateLocationHeader()
        
        let camera = MGLMapCamera(lookingAtCenter: (self.mapView.userLocation!.coordinate), altitude: 30000, pitch: 0, heading: 0)
        self.mapView.fly(to: camera, completionHandler: nil)
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
        
        if alertSeverity == SeverityType.order {
            identifier = "order" + UUID().uuidString
            color = #colorLiteral(red: 0.6274509804, green: 0.01960784314, blue: 0, alpha: 1)
        }
        else if alertSeverity == SeverityType.warning {
            identifier = "warning" + UUID().uuidString
            color = #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)
        }
        else {
            identifier = "none" + UUID().uuidString
            color = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        }
        
        
        let source = MGLShapeSource(identifier: identifier, features: [shape], options: nil)
        self.mapView.style!.addSource(source)
        
        let layer = MGLFillStyleLayer(identifier: identifier + "layer", source: source)
        layer.fillColor = NSExpression(forConstantValue: color)
        layer.fillOpacity = NSExpression(forConstantValue: 0.5)
        
        self.mapView.style!.addLayer(layer)
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
            let icon = UIImage(named: castAnnotation?.typeOfLocation.rawValue ?? "other")
            let size = CGSize(width: 50, height: 50)
            UIGraphicsBeginImageContext(size)
            icon!.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            annotationImage = MGLAnnotationImage(image: resizedImage!, reuseIdentifier: castAnnotation?.typeOfLocation.rawValue ?? "other")
        }
        
        return annotationImage
    }
    
    func showInstructions () {
        let alert = UIAlertController(title: "Instructions", message: self.g_instructions, preferredStyle: .alert)
        // Create the actions
        let okAction = UIAlertAction(title: "Acknowledge Order", style: UIAlertAction.Style.default) {
            UIAlertAction in
            self.server.acknowledgeEvacuation(viewController: self)
        }
        
        alert.addAction(okAction)
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func showInstructionsButton(_ sender: Any) {
        self.showInstructions()
    }
    
    @IBAction func startNavigation(_ sender: Any) {
        server.navigation.startNavigation(viewController: self)
    }
    
    func updateLocationHeader() {
        guard let _: CLLocationCoordinate2D = self.locationManager.location?.coordinate else { return }
        
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
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.updateLocationHeader()
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
        if evac == SeverityType.order {
            self.view.backgroundColor = #colorLiteral(red: 0.6268994808, green: 0.02138105221, blue: 0.0009170532576, alpha: 1)
            self.evacType.text = "⚠︎ Evacuation Order\nissued for:"
            self.evacType.textColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            self.locationLabel.textColor = #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)
        }
        else if evac == SeverityType.warning {
            self.view.backgroundColor = #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)
            self.evacType.text = "⚠︎ Evacuation Warning\nissued for:"
            self.evacType.textColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            self.locationLabel.textColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        }
        else if evac == SeverityType.none {
            self.view.backgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            self.evacType.text = "No Alerts\nissued for:"
            self.evacType.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            self.locationLabel.textColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        }
    }
}

