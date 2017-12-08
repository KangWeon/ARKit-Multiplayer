//
//  QRMarker.swift
//  ARKit Multiplayer Example
//
//  Created by Eugene Bokhan on 12/8/17.
//  Copyright © 2017 Eugene Bokhan. All rights reserved.
//

import UIKit

class QRMarker: NSObject {
    
    struct corner {
        var screenPosition: CGPoint
    }
    
    var isVisible = false
    
    var size = 0.086
    
    var topLeftCorner = corner(screenPosition: CGPoint())
    var topRightCorner = corner(screenPosition: CGPoint())
    var bottomRightCorner = corner(screenPosition: CGPoint())
    var bottomLeftCorner = corner(screenPosition: CGPoint())
    
}
