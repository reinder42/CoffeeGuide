//
//  CoffeeAnnotation.swift
//  Coffee
//
//  Created by Reinder de Vries on 03-11-15.
//  Copyright © 2015 LearnAppMaking. All rights reserved.
//

import Foundation
import MapKit

class CoffeeAnnotation: NSObject, MKAnnotation
{
    let title:String?;
    let subtitle:String?;
    let coordinate: CLLocationCoordinate2D;
    
    init(title: String?, subtitle:String?, coordinate: CLLocationCoordinate2D)
    {
        self.title = title;
        self.subtitle = subtitle;
        self.coordinate = coordinate;
        
        super.init();
    }    
}