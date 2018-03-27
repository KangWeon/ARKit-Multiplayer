//
//  ViewController.swift
//  ARKit Multiplayer Example
//
//  Created by Eugene Bokhan on 12/8/17.
//  Copyright © 2017 Eugene Bokhan. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController {
    
    // MARK: - UI Elements
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var messagePanel: UIVisualEffectView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var restartExperienceButton: BouncyButton!
    @IBOutlet weak var createCloudButton: BouncyButton!
    
    
    // MARK: - Intarface Actions
    
    @IBAction func restartExperience(_ sender: Any) {
        guard restartExperienceButtonIsEnabled else { return }
        
        DispatchQueue.main.async {
            
            self.restartExperienceButtonIsEnabled = false
            
            self.textManager.cancelAllScheduledMessages()
            self.textManager.dismissPresentedAlert()
            self.textManager.showMessage("Starting a new session")
            
            self.startSession()
        }
    }
    
    @IBAction func createCloudAction(_ sender: Any) {
        // Add new point node to the scene
        addNode()
    }
    
    // MARK: - Properties
    
    var textManager: TextManager!
    var restartExperienceButtonIsEnabled = true {
        didSet {
            if restartExperienceButtonIsEnabled == true {
                restartExperienceButton.setImage(#imageLiteral(resourceName: "restart"), for: [])
                restartExperienceButton.show()
                createCloudButton.show()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: {
                    self.showHitTestGeometry = false
                    self.inScanMode = true
                })
            } else {
                self.barcodeContent = ""
                self.sceneView.scene.rootNode.childNodes.forEach {
                    $0.removeFromParentNode()
                    $0.geometry = nil
                }
                restartExperienceButton.setImage(#imageLiteral(resourceName: "restartPressed"), for: [])
                restartExperienceButton.hide()
                createCloudButton.isSelected = false
                createCloudButton.hide()
            }
        }
    }
    
    private lazy var triangleView: TriangleView = {
        TriangleView(frame: view.bounds)
    }()
    private let connectivityService = MultiplayerConnectivityService()
    private lazy var drawLayer: CAShapeLayer = {
        let drawLayer = CAShapeLayer()
        self.sceneView.layer.addSublayer(drawLayer)
        drawLayer.frame = self.sceneView.bounds
        drawLayer.strokeColor = UIColor.green.cgColor
        drawLayer.lineWidth = 3
        drawLayer.lineJoin = kCALineJoinMiter
        drawLayer.fillColor = UIColor.clear.cgColor
        return drawLayer
    }()
    
    
    // MARK: - Scan Properties
    
    private var inScanMode = false
    private var requests = [VNRequest]()
    public let pnpSolver = PnPSolver()
    public var qrMarker = QRMarker()
    private var barcodeContent: String! {
        didSet {
            if barcodeContent != "" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                    self.inScanMode = false
                })
            }
        }
    }
    
    // MARK: - SceneKit Properties
    
    private var pointGeom: SCNGeometry = {
        let geo = SCNSphere(radius: 0.01)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.blue
        material.locksAmbientWithDiffuse = true
        geo.firstMaterial = material
        return geo
    }()
    
    private var cameraNode: SCNNode = {
        var cameraNode = SCNScene(named:"art.scnassets/Camera.dae")?.rootNode
        cameraNode?.name = "cameraNode"
        return cameraNode!
    }()
    
    public var axesNode = createAxesNode(quiverLength: 0.06, quiverThickness: 1.0)
    
    // MARK: - ARKit Properties
    
    let session = ARSession()
    var sessionConfig: ARConfiguration = ARWorldTrackingConfiguration()
    
    var screenCenter: CGPoint?
    // Config properties
    let standardConfiguration: ARWorldTrackingConfiguration = {
        let configuration = ARWorldTrackingConfiguration()
        if #available(iOS 11.3, *) {
            configuration.planeDetection = [.horizontal, .vertical]
        } else {
            configuration.planeDetection = .horizontal
        }
        return configuration
    }()
    var dragOnInfinitePlanesEnabled = false
    
    // MARK: - Hit Test Visualization
    
    private var showHitTestGeometry = false {
        didSet {
            if showHitTestGeometry == false {
                triangleView.clear()
            }
        }
    }
    
    // MARK: - Queues
    
    static let serialQueue = DispatchQueue(label: "com.eugenebokhan.example.serialSceneKitQueue")
    // Create instance variable for more readable access inside class
    let serialQueue: DispatchQueue = ViewController.serialQueue
    
    // MARK: - ScanViewController Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDelegates()
        setupARKitScene()
        setupVision()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.pause()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Prevent the screen from being dimmed after a while.
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Start the ARSession.
        startSession()
    }
    
    // MARK: - Setup UI
    
    func setupUI() {
        
        textManager = TextManager(viewController: self)
        
        // Set appearance of message output panel
        messagePanel.layer.cornerRadius = 5.0
        messagePanel.clipsToBounds = true
        messagePanel.isHidden = true
        messageLabel.text = ""
        
        // Setup buttons
        setupButtons()
        
        sceneView.addSubview(triangleView)
    }
    
    // MARK: - Setup Delegates
    
    func setupDelegates() {
        connectivityService.delegate = self
    }
    
    // MARK: - Setup ARKit Scene
    
    func setupARKitScene() {
        sceneView.delegate = self
        //        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, SCNDebugOptions.showBoundingBoxes]
        sceneView.autoenablesDefaultLighting = true
        sceneView.session = session
        sceneView.antialiasingMode = .multisampling4X
        sceneView.automaticallyUpdatesLighting = false
        
        sceneView.preferredFramesPerSecond = 60
        sceneView.contentScaleFactor = 1
        
        if let camera = sceneView.pointOfView?.camera {
            camera.wantsHDR = true
            camera.wantsExposureAdaptation = true
        }
    }
    
    // MARK: -  Setup SCNNodes
    
    func setupNodes() {
        
        sceneView.scene.rootNode.addChildNode(axesNode)
    }
    
    // MARK: - Setup Buttons
    
    func setupButtons() {
        restartExperienceButton.presentationType = .right
        createCloudButton.presentationType = .right
    }
    
    // MARK: - Setup Vision
    
    func setupVision() {
        let barcodeRequest = VNDetectBarcodesRequest(completionHandler: barcodeDetectionHandler)
        barcodeRequest.symbologies = [.QR] // VNDetectBarcodesRequest.supportedSymbologies
        requests = [barcodeRequest]
    }
    
    // MARK: - Vision Methods
    
    private func findQR() {
        guard let pixelBuffer = session.currentFrame?.capturedImage else { return }
        
        var requestOptions: [VNImageOption: Any] = [:]
        
        requestOptions = [.cameraIntrinsics: session.currentFrame?.camera.intrinsics as Any]
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: 6)!, options: requestOptions)
        
        do {
            try imageRequestHandler.perform(requests)
        } catch {
            print(error)
        }
    }
    
    func barcodeDetectionHandler(request: VNRequest, error: Error?) {
        guard let results = request.results else { return }
        
        DispatchQueue.main.async() {
            guard self.sceneView.session.currentFrame != nil else { return }
            
            for result in results {
                guard let barcode = result as? VNBarcodeObservation else { continue }
                
                //    v0 --------------v3
                //    |             __/ |
                //    |          __/    |
                //    |       __/       |
                //    |    __/          |
                //    | __/             |
                //    v1 --------------v2
                
                // This will be used to eliminate duplicate findings
                var barcodeObservations: [String : VNBarcodeObservation] = [:]
                for barcode in results {
                    if let potentialQRCode = barcode as? VNBarcodeObservation {
                        if potentialQRCode.symbology == .QR {
                            barcodeObservations[potentialQRCode.payloadStringValue!] = potentialQRCode
                        }
                    }
                }
                for (barcodeContent, _) in barcodeObservations {
                    if self.barcodeContent != barcodeContent {
                        self.barcodeContent = barcodeContent
                    }
                }
                
                self.qrMarker.topLeftCorner.screenPosition = self.convert(point: barcode.topLeft)
                self.qrMarker.topRightCorner.screenPosition = self.convert(point: barcode.topRight)
                self.qrMarker.bottomRightCorner.screenPosition = self.convert(point: barcode.bottomRight)
                self.qrMarker.bottomLeftCorner.screenPosition = self.convert(point: barcode.bottomLeft)
            }
        }
    }
    
    // MARK: - Add nodes to SceneView
    
    @objc private func addNode() {
        let nodeCount = String(self.sceneView.scene.rootNode.childNodes.count)
        createNode(name: nodeCount)
        connectivityService.sendData(dataString: "addNode sphereNode \(nodeCount)")
        sendTransform(nodeName: "sphereNode \(nodeCount)")
    }
    
    private func createNode(name: String) {
        guard let pointOfView = sceneView.pointOfView else { return }
        let mat = pointOfView.transform
        let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33)
        let currentPosition = pointOfView.position + (dir * 0.1)
        let sphereNode = SCNNode(geometry: pointGeom)
        sphereNode.name = "sphereNode \(name)"
        sphereNode.position = currentPosition
        sceneView.scene.rootNode.addChildNode(sphereNode)
    }
    
    // MARK: - Create geometry
    
    func createGeometries() {
        
        let vertexArray = createVertexArray()
        triangleView.recalculate(vertexes: vertexArray)
    }
    
    // MARK: - Help methods
    
    func createVertexArray() -> [Vertex] {
        
        var vertexArray: [Vertex] = [] {
            didSet {
                if vertexArray.count > 68 {
                    vertexArray.remove(at: 0)
                }
            }
        }
        
        if let features = self.session.currentFrame?.rawFeaturePoints {
            let points = features.__points
            for i in 0...features.__count {
                
                let feature = points.advanced(by: Int(i))
                let featurePos = SCNVector3(feature.pointee)
                let projectedPoint = self.sceneView.projectPoint(featurePos)
                let screenPoint = CGPoint(x: projectedPoint.x, y: projectedPoint.y)
                
                if fitsScreenPartRect(point: screenPoint, screenPart: 1.0) {
                    vertexArray.append( Vertex(point: screenPoint, scnVector: featurePos, id: i) )
                }
            }
        }
        
        return vertexArray
    }
    
    func fitsScreenPartRect(point: CGPoint, screenPart: CGFloat) -> Bool {
        
        let bounds = self.sceneView.bounds
        let minX = (bounds.width - (bounds.width * screenPart)) / 2
        let minY = (bounds.height - (bounds.height * screenPart)) / 2
        let maxX = (bounds.width * screenPart) + minX
        let maxY = (bounds.height * screenPart) + minY
        
        return point.x > minX && point.x < maxX && point.y > minY && point.y < maxY
    }
    
    private func convert(point: CGPoint) -> CGPoint {
        var convertedPoint = CGPoint()
        let height = sceneView.bounds.size.height
        let width = sceneView.bounds.size.width
        switch UIApplication.shared.statusBarOrientation {
        case .portrait:
            convertedPoint.x = point.x * width
            convertedPoint.y = (1 - point.y) * height
        case .portraitUpsideDown:
            convertedPoint.x = (1 - point.x) * width
            convertedPoint.y = point.y * height
        case .landscapeLeft:
            convertedPoint.x = point.y * width
            convertedPoint.y = point.x * height
        case .landscapeRight:
            convertedPoint.x = (1 - point.y) * width
            convertedPoint.y = (1 - point.x) * height
        case .unknown:
            convertedPoint.x = point.x * width
            convertedPoint.y = (1 - point.y) * height
        }
        return convertedPoint
    }
    
    // MARK: - Error handling
    
    func displayErrorMessage(title: String, message: String, allowRestart: Bool = false) {
        // Blur the background.
        textManager.blurBackground()
        
        if allowRestart {
            // Present an alert informing about the error that has occurred.
            let restartAction = UIAlertAction(title: "Reset", style: .default) { _ in
                self.textManager.unblurBackground()
            }
            textManager.showAlert(title: title, message: message, actions: [restartAction])
        } else {
            textManager.showAlert(title: title, message: message, actions: [])
        }
    }
    
}

// MARK: - ARKit / ARSCNView Methods

extension ViewController {
    
    func startSession() {
        if ARWorldTrackingConfiguration.isSupported {
            // Start the ARSession.
            resetTracking()
        } else {
            // This device does not support 6DOF world tracking.
            let sessionErrorMsg = "This app requires world tracking. World tracking is only available on iOS devices with A9 processor or newer. " +
            "Please quit the application."
            displayErrorMessage(title: "Unsupported platform", message: sessionErrorMsg, allowRestart: false)
        }
    }
    
    func resetTracking() {
        session.run(standardConfiguration, options: [.resetTracking, .removeExistingAnchors])
        showHitTestGeometry = true
        // Disable Restart button for a while in order to give the session enough time to restart.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: {
            self.restartExperienceButtonIsEnabled = true
        })
    }
    
    func enableEnvironmentMapWithIntensity(_ intensity: CGFloat) {
        sceneView.scene.lightingEnvironment.intensity = intensity
    }
    
}

// MARK: - ARSCNViewDelegate

extension ViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        DispatchQueue.main.async() {
            // If light estimation is enabled, update the intensity of the model's lights and the environment map
            if let lightEstimate = self.session.currentFrame?.lightEstimate {
                self.sceneView.scene.enableEnvironmentMapWithIntensity(lightEstimate.ambientIntensity / 40, queue: self.serialQueue)
            } else {
                self.sceneView.scene.enableEnvironmentMapWithIntensity(40, queue: self.serialQueue)
            }
        }
        
        DispatchQueue.main.async() {
            
            let qrCornerOldValue = self.qrMarker.topLeftCorner.screenPosition
            
            // Scan Methods
            if self.inScanMode {
                self.findQR()
                DispatchQueue.main.async() {
                    if qrCornerOldValue != self.qrMarker.topLeftCorner.screenPosition {
                        self.qrMarker.isVisible = true
                    } else {
                        self.qrMarker.isVisible = false
                    }
                    if self.qrMarker.isVisible == true {
                        self.textManager.showMessage("QR Mark is detected")
                        self.processCorners(real_size: Float(self.qrMarker.size))
                    } else {
                        self.textManager.showMessage("Scanning")
                    }
                }
            } else {
                self.qrMarker.isVisible = false
            }
            
            // Add QR node to root node if there is no one
            if (self.sceneView.scene.rootNode.childNode(withName: "QR Container Node", recursively: false) == nil && self.qrMarker.isVisible == true) {
                // Add axesNode with steps to scene
                self.setupNodes()
            }
        }
        
        DispatchQueue.main.async {
            self.sendTransform(nodeName: "cameraNode")
        }
        
        DispatchQueue.main.async {
            if self.showHitTestGeometry {
                self.createGeometries()
            }
        }
        
    }
}

// MARK: - ARSessionDelegate

extension ViewController: ARSessionDelegate {
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        
        textManager.showTrackingQualityInfo(for: camera.trackingState, autoHide: true)
        
        switch camera.trackingState {
        case .notAvailable:
            resetTracking()
        case .limited:
            break
        case .normal:
            textManager.cancelScheduledMessage(forType: .trackingStateEscalation)
        }
        
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        
        guard let arError = error as? ARError else { return }
        
        let nsError = error as NSError
        var sessionErrorMsg = "\(nsError.localizedDescription) \(nsError.localizedFailureReason ?? "")"
        if let recoveryOptions = nsError.localizedRecoveryOptions {
            for option in recoveryOptions {
                sessionErrorMsg.append("\(option).")
            }
        }
        
        let isRecoverable = (arError.code == .worldTrackingFailed)
        if isRecoverable {
            sessionErrorMsg += "\nYou can try resetting the session or quit the application."
        } else {
            sessionErrorMsg += "\nThis is an unrecoverable error that requires to quit the application."
        }
        
        displayErrorMessage(title: "We're sorry!", message: sessionErrorMsg, allowRestart: isRecoverable)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        textManager.blurBackground()
        textManager.showAlert(title: "Session Interrupted", message: "The session will be reset after the interruption has ended.")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        textManager.unblurBackground()
        session.run(standardConfiguration, options: [.resetTracking, .removeExistingAnchors])
        textManager.showMessage("RESETTING SESSION")
    }
}

extension ViewController: MultiplayerConnectivityServiceDelegate {
    
    // MARK: - Send information about camera transform relatively to axes node
    
    private func sendTransform(nodeName: String) {
        let nodeNameStringArray = nodeName.components(separatedBy: " ")
        
        if self.connectivityService.session.connectedPeers.count != 0 {
            var matrix = SCNMatrix4()
            var matrixString = String()
            
            if nodeNameStringArray[0] == "cameraNode" {
                if let cameraTransform = self.session.currentFrame?.camera.transform {
                    matrix = self.sceneView.scene.rootNode.convertTransform(SCNMatrix4(cameraTransform), to: self.axesNode) // Camera Matrix Relatively To Axes
                    matrixString = "\(matrix.m11) \(matrix.m12) \(matrix.m13) \(matrix.m14) \(matrix.m21) \(matrix.m22) \(matrix.m23) \(matrix.m24) \(matrix.m31) \(matrix.m32) \(matrix.m33) \(matrix.m34) \(matrix.m41) \(matrix.m42) \(matrix.m43) \(matrix.m44) cameraNode"
                }
            }
            
            if nodeNameStringArray[0] == "sphereNode" {
                let nodeTransform = self.sceneView.scene.rootNode.childNode(withName: nodeName, recursively: true)?.transform
                matrix = self.sceneView.scene.rootNode.convertTransform(nodeTransform!, to: self.axesNode) // Node Matrix Relatively To Axes
                matrixString = "\(matrix.m11) \(matrix.m12) \(matrix.m13) \(matrix.m14) \(matrix.m21) \(matrix.m22) \(matrix.m23) \(matrix.m24) \(matrix.m31) \(matrix.m32) \(matrix.m33) \(matrix.m34) \(matrix.m41) \(matrix.m42) \(matrix.m43) \(matrix.m44) sphereNode \(nodeNameStringArray[1])"
            }
            
            self.connectivityService.sendData(dataString : matrixString)
        }
    }
    
    func connectedDevicesChanged(manager : MultiplayerConnectivityService, connectedDevices: [String]) {
        OperationQueue.main.addOperation {
            self.cameraNode.removeFromParentNode()
            self.sceneView.scene.rootNode.addChildNode(self.cameraNode)
            self.textManager.showMessage("Connections: \(connectedDevices)")
        }
    }
    
    func dataRecieved(manager : MultiplayerConnectivityService, data: String) {
        OperationQueue.main.addOperation {
            let dataArray = data.components(separatedBy: " ")
            
            if dataArray.count > 10 {
                let transform = SCNMatrix4(m11: Float(dataArray[0])!, m12: Float(dataArray[1])!, m13: Float(dataArray[2])!, m14: Float(dataArray[3])!, m21: Float(dataArray[4])!, m22: Float(dataArray[5])!, m23: Float(dataArray[6])!, m24: Float(dataArray[7])!, m31: Float(dataArray[8])!, m32: Float(dataArray[9])!, m33: Float(dataArray[10])!, m34: Float(dataArray[11])!, m41: Float(dataArray[12])!, m42: Float(dataArray[13])!, m43: Float(dataArray[14])!, m44: Float(dataArray[15])!)
                
                let relativeToAxesTransform = SCNMatrix4Mult(transform, self.axesNode.transform)
                
                if dataArray[16] == "cameraNode" {
                    self.cameraNode.transform = relativeToAxesTransform
                }
                
                if dataArray[16] == "sphereNode" {
                    self.sceneView.scene.rootNode.childNode(withName: "sphereNode \(dataArray[17])", recursively: true)?.transform = relativeToAxesTransform
                }
            }
            
            if dataArray[0] == "addNode" {
                if dataArray[1] == "sphereNode" {
                    self.createNode(name: dataArray[2])
                }
            }
            
        }
    }
}

