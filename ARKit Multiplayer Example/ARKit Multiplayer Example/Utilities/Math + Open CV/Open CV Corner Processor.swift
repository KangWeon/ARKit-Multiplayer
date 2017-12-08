//
//  OpenCV Methods.swift
//  ARKit Multiplayer Example
//
//  Created by Eugene Bokhan on 12/8/17.
//  Copyright © 2017 Eugene Bokhan. All rights reserved.
//

import Foundation
import SceneKit

extension ViewController {
    
    // MARK: - Solve PnP
    
    @objc func processCorners(real_size: Float) {
        switch UIApplication.shared.statusBarOrientation {
        case .portrait:
            let imageResolution = self.session.currentFrame?.camera.imageResolution
            let viewSize = self.sceneView.bounds.size
            
            let xCoef = (imageResolution?.height)! / viewSize.width
            let yCoef = (imageResolution?.width)! / viewSize.height
            
            let _c1 = CGPoint(x: self.qrMarker.bottomRightCorner.screenPosition.x * xCoef, y: self.qrMarker.bottomRightCorner.screenPosition.y * yCoef)
            let _c2 = CGPoint(x: self.qrMarker.topRightCorner.screenPosition.x * xCoef, y: self.qrMarker.topRightCorner.screenPosition.y * yCoef)
            let _c3 = CGPoint(x: self.qrMarker.topLeftCorner.screenPosition.x * xCoef, y: self.qrMarker.topLeftCorner.screenPosition.y * yCoef)
            let _c0 = CGPoint(x: self.qrMarker.bottomLeftCorner.screenPosition.x * xCoef, y: self.qrMarker.bottomLeftCorner.screenPosition.y * yCoef)
            
            let f_x = self.session.currentFrame?.camera.intrinsics.columns.0.x // Focal length in x axis
            let f_y = self.session.currentFrame?.camera.intrinsics.columns.1.y // Focal length in y axis
            let c_x = self.session.currentFrame?.camera.intrinsics.columns.2.x // Camera primary point x
            let c_y = self.session.currentFrame?.camera.intrinsics.columns.2.y // Camera primary point y
            
            self.pnpSolver.processCorners(_c0, _c1, _c2, _c3, real_size, f_x!, f_y!, c_x!, c_y!)
            
            let qw = self.pnpSolver.qw
            let qx = self.pnpSolver.qy
            let qy = self.pnpSolver.qx
            let qz = -self.pnpSolver.qz
            let t0 = self.pnpSolver.t1
            let t1 = self.pnpSolver.t0
            let t2 = -self.pnpSolver.t2
            
            let r1 = vector_float4(x: 1 - 2*qy*qy - 2*qz*qz, y: (2*qx*qy + 2*qz*qw), z: (2*qx*qz - 2*qy*qw), w: 0)
            let r2 = vector_float4(x: (2*qx*qy - 2*qz*qw), y: 1 - 2*qx*qx - 2*qz*qz, z: (2*qy*qz + 2*qx*qw), w: 0)
            let r3 = vector_float4(x: (2*qx*qz + 2*qy*qw), y: (2*qy*qz - 2*qx*qw), z: 1 - 2*qx*qx - 2*qy*qy, w: 0)
            let r4 = vector_float4(x: t0, y: t1, z: t2, w: 1)
            
            let modelMatrix = matrix_float4x4(r1, r2, r3, r4)
            
            let cameraTransform = self.session.currentFrame?.camera.transform
            
            let pose = SCNMatrix4(matrix_multiply(cameraTransform!, modelMatrix))
            
            self.axesNode.transform = pose
            
        case .portraitUpsideDown:
            break
        case .landscapeLeft:
            
            let imageResolution = self.session.currentFrame?.camera.imageResolution
            let viewSize = self.sceneView.bounds.size
            
            let xCoef = (imageResolution?.width)! / viewSize.width
            let yCoef = (imageResolution?.height)! / viewSize.height
            
            let _c0 = CGPoint(x: self.qrMarker.bottomRightCorner.screenPosition.x * xCoef, y: self.qrMarker.bottomRightCorner.screenPosition.y * yCoef)
            let _c1 = CGPoint(x: self.qrMarker.topRightCorner.screenPosition.x * xCoef, y: self.qrMarker.topRightCorner.screenPosition.y * yCoef)
            let _c2 = CGPoint(x: self.qrMarker.topLeftCorner.screenPosition.x * xCoef, y: self.qrMarker.topLeftCorner.screenPosition.y * yCoef)
            let _c3 = CGPoint(x: self.qrMarker.bottomLeftCorner.screenPosition.x * xCoef, y: self.qrMarker.bottomLeftCorner.screenPosition.y * yCoef)
            
            let f_x = self.session.currentFrame?.camera.intrinsics.columns.0.x // Focal length in x axis
            let f_y = self.session.currentFrame?.camera.intrinsics.columns.1.y // Focal length in y axis
            let c_x = self.session.currentFrame?.camera.intrinsics.columns.2.x // Camera primary point x
            let c_y = self.session.currentFrame?.camera.intrinsics.columns.2.y // Camera primary point y
            
            self.pnpSolver.processCorners(_c0, _c1, _c2, _c3, real_size, f_x!, f_y!, c_x!, c_y!)
            
            let qw = self.pnpSolver.qw
            let qx = -self.pnpSolver.qx
            let qy = self.pnpSolver.qy
            let qz = -self.pnpSolver.qz
            let t0 = -self.pnpSolver.t0
            let t1 = self.pnpSolver.t1
            let t2 = -self.pnpSolver.t2
            
            let r1 = vector_float4(x: 1 - 2*qy*qy - 2*qz*qz, y: (2*qx*qy + 2*qz*qw), z: (2*qx*qz - 2*qy*qw), w: 0)
            let r2 = vector_float4(x: (2*qx*qy - 2*qz*qw), y: 1 - 2*qx*qx - 2*qz*qz, z: (2*qy*qz + 2*qx*qw), w: 0)
            let r3 = vector_float4(x: (2*qx*qz + 2*qy*qw), y: (2*qy*qz - 2*qx*qw), z: 1 - 2*qx*qx - 2*qy*qy, w: 0)
            let r4 = vector_float4(x: t0, y: t1, z: t2, w: 1)
            
            let modelMatrix = matrix_float4x4(r1, r2, r3, r4)
            
            let cameraTransform = self.session.currentFrame?.camera.transform
            
            let pose = SCNMatrix4(matrix_multiply(cameraTransform!, modelMatrix))
            
            self.axesNode.transform = pose
            
        case .landscapeRight:
            
            let imageResolution = self.session.currentFrame?.camera.imageResolution
            let viewSize = self.sceneView.bounds.size
            
            let xCoef = (imageResolution?.width)! / viewSize.width
            let yCoef = (imageResolution?.height)! / viewSize.height
            
            let _c0 = CGPoint(x: self.qrMarker.topLeftCorner.screenPosition.x * xCoef, y: self.qrMarker.topLeftCorner.screenPosition.y * yCoef)
            let _c1 = CGPoint(x: self.qrMarker.bottomLeftCorner.screenPosition.x * xCoef, y: self.qrMarker.bottomLeftCorner.screenPosition.y * yCoef)
            let _c2 = CGPoint(x: self.qrMarker.bottomRightCorner.screenPosition.x * xCoef, y: self.qrMarker.bottomRightCorner.screenPosition.y * yCoef)
            let _c3 = CGPoint(x: self.qrMarker.topRightCorner.screenPosition.x * xCoef, y: self.qrMarker.topRightCorner.screenPosition.y * yCoef)
            
            let f_x = self.session.currentFrame?.camera.intrinsics.columns.0.x // Focal length in x axis
            let f_y = self.session.currentFrame?.camera.intrinsics.columns.1.y // Focal length in y axis
            let c_x = self.session.currentFrame?.camera.intrinsics.columns.2.x // Camera primary point x
            let c_y = self.session.currentFrame?.camera.intrinsics.columns.2.y // Camera primary point y
            
            self.pnpSolver.processCorners(_c0, _c1, _c2, _c3, real_size, f_x!, f_y!, c_x!, c_y!)
            
            let qw = self.pnpSolver.qw
            let qx = self.pnpSolver.qx
            let qy = -self.pnpSolver.qy
            let qz = -self.pnpSolver.qz
            let t0 = self.pnpSolver.t0
            let t1 = -self.pnpSolver.t1
            let t2 = -self.pnpSolver.t2
            
            let r1 = vector_float4(x: 1 - 2*qy*qy - 2*qz*qz, y: (2*qx*qy + 2*qz*qw), z: (2*qx*qz - 2*qy*qw), w: 0)
            let r2 = vector_float4(x: (2*qx*qy - 2*qz*qw), y: 1 - 2*qx*qx - 2*qz*qz, z: (2*qy*qz + 2*qx*qw), w: 0)
            let r3 = vector_float4(x: (2*qx*qz + 2*qy*qw), y: (2*qy*qz - 2*qx*qw), z: 1 - 2*qx*qx - 2*qy*qy, w: 0)
            let r4 = vector_float4(x: t0, y: t1, z: t2, w: 1)
            
            let modelMatrix = matrix_float4x4(r1, r2, r3, r4)
            
            let cameraTransform = self.session.currentFrame?.camera.transform
            
            let pose = SCNMatrix4(matrix_multiply(cameraTransform!, modelMatrix))
            
            self.axesNode.transform = pose
            
        case .unknown: break
        }
    
    }
    
}

