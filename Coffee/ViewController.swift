//
//  ViewController.swift
//  Coffee
//
//  Created by Reinder de Vries on 29-10-15.
//  Copyright © 2015 LearnAppMaking. All rights reserved.
//

import UIKit
import MapKit
import RealmSwift

class ViewController: UIViewController, CLLocationManagerDelegate, UITableViewDataSource, UITableViewDelegate, MKMapViewDelegate
{
    /// Outlet for the map view (top)
    @IBOutlet var mapView:MKMapView?;
    
    /// Outlet for the table view (bottom)
    @IBOutlet var tableView:UITableView?;
    
    /// Location manager to get the user's location
    var locationManager:CLLocationManager?;
    
    /// Convenient property to remember the last location
    var lastLocation:CLLocation?;
    
    /// Stores venues from Realm as a Results instance, use if not using non-lazy / Realm sorting
    //var venues:Results<Venue>?;
    
    /// Stores venues from Realm, as a non-lazy list
    var venues:[Venue]?;
    
    /// Span in meters for map view and data filtering
    let distanceSpan:Double = 500;
    
    override func viewDidLoad()
    {
        super.viewDidLoad();
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("onVenuesUpdated:"), name: API.notifications.venuesUpdated, object: nil);
    }
    
    func refreshVenues(location: CLLocation?, getDataFromFoursquare:Bool = false)
    {
        // If location isn't nil, set it as the last location
        if location != nil
        {
            lastLocation = location;
        }
        
        // If the last location isn't nil, i.e. if a lastLocation was set OR parameter location wasn't nil
        if let location = lastLocation
        {
            // Make a call to Foursquare to get data
            if getDataFromFoursquare == true
            {
                CoffeeAPI.sharedInstance.getCoffeeShopsWithLocation(location);
            }
            
            // Convenience method to calculate the top-left and bottom-right GPS coordinates based on region (defined with distanceSpan)
            let (start, stop) = calculateCoordinatesWithRegion(location);
            
            // Set up a predicate that ensures the fetched venues are within the region
            let predicate = NSPredicate(format: "latitude < %f AND latitude > %f AND longitude > %f AND longitude < %f", start.latitude, stop.latitude, start.longitude, stop.longitude);
            
            // Initialize Realm (while supressing error handling)
            let realm = try! Realm();
            
            // Get the venues from Realm. Note that the "sort" isn't part of Realm, it's Swift, and it defeats Realm's lazy loading nature!
            venues = realm.objects(Venue).filter(predicate).sort {
                location.distanceFromLocation($0.coordinate) < location.distanceFromLocation($1.coordinate);
            };
            
            // Throw the found venues on the map kit as annotations
            for venue in venues!
            {
                let annotation = CoffeeAnnotation(title: venue.name, subtitle: venue.address, coordinate: CLLocationCoordinate2D(latitude: Double(venue.latitude), longitude: Double(venue.longitude)));
                
                mapView?.addAnnotation(annotation);
            }
            
            // RELOAD ALL THE DATAS !!!
            tableView?.reloadData();
        }
    }
    
    func calculateCoordinatesWithRegion(location:CLLocation) -> (CLLocationCoordinate2D, CLLocationCoordinate2D)
    {
        let region = MKCoordinateRegionMakeWithDistance(location.coordinate, distanceSpan, distanceSpan);
        
        var start:CLLocationCoordinate2D = CLLocationCoordinate2D();
        var stop:CLLocationCoordinate2D = CLLocationCoordinate2D();
        
        start.latitude  = region.center.latitude  + (region.span.latitudeDelta  / 2.0);
        start.longitude = region.center.longitude - (region.span.longitudeDelta / 2.0);
        stop.latitude   = region.center.latitude  - (region.span.latitudeDelta  / 2.0);
        stop.longitude  = region.center.longitude + (region.span.longitudeDelta / 2.0);
        
        return (start, stop);
    }
    
    override func viewWillAppear(animated: Bool)
    {
        super.viewWillAppear(animated);
        
        if let tableView = self.tableView
        {
            tableView.delegate = self;
            tableView.dataSource = self;
        }
        
        if let mapView = self.mapView
        {
            mapView.delegate = self;
        }
    }
    
    override func viewDidAppear(animated: Bool)
    {
        if locationManager == nil
        {
            locationManager = CLLocationManager();
            
            locationManager!.delegate = self;
            locationManager!.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
            locationManager!.requestAlwaysAuthorization();
            locationManager!.distanceFilter = 50; // Don't send location updates with a distance smaller than 50 meters between them
            locationManager!.startUpdatingLocation();
        }
    }
    
    func locationManager(manager: CLLocationManager, didUpdateToLocation newLocation: CLLocation, fromLocation oldLocation: CLLocation)
    {
        if let mapView = self.mapView
        {
            // setRegion sets both the center coordinate, and the "zoom level"
            let region = MKCoordinateRegionMakeWithDistance(newLocation.coordinate, distanceSpan, distanceSpan);
            mapView.setRegion(region, animated: true);
            
            // When a new location update comes in, reload from Realm and from Foursquare
            refreshVenues(newLocation, getDataFromFoursquare: true);
        }
    }
    
    func onVenuesUpdated(notification:NSNotification)
    {
        // When new data from Foursquare comes in, reload from local Realm
        refreshVenues(nil);
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        // When venues is nil, this will return 0 (nil-coalescing operator ??)
        return venues?.count ?? 0;
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        return 1;
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        var cell = tableView.dequeueReusableCellWithIdentifier("cellIdentifier");
        
        if cell == nil
        {
            cell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: "cellIdentifier");
        }
        
        if let venue = venues?[indexPath.row]
        {
            cell!.textLabel?.text = venue.name;
            cell!.detailTextLabel?.text = venue.address;
        }
        
        return cell!;
    }
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView?
    {
        if annotation.isKindOfClass(MKUserLocation)
        {
            return nil;
        }
        
        var view = mapView.dequeueReusableAnnotationViewWithIdentifier("annotationIdentifier");
        
        if view == nil
        {
            view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "annotationIdentifier");
        }
        
        view?.canShowCallout = true;
        
        return view;
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        // When the user taps a table view cell, attempt to pan to the pin in the map view        
        if let venue = venues?[indexPath.row]
        {
            let region = MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2D(latitude: Double(venue.latitude), longitude: Double(venue.longitude)), distanceSpan, distanceSpan);
            mapView?.setRegion(region, animated: true);
        }
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning();
    }
}

