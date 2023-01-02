import ARKit
import SceneKit
import UIKit

/// Size of the generated face texture
private let faceTextureSize = 1024 //px

/// Should the face mesh be filled in? (i.e. fill in the eye and mouth holes with geometry)
private let fillMesh = true

class ARViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, UIGestureRecognizerDelegate {
    
    var utilities = Utilities()
    var session: ARSession {
        return sceneView.session
    }
    
    private var faceUvGenerator: FaceTextureGenerator!
    private var scnFaceGeometry: ARSCNFaceGeometry!
    
    // MARK: AR View
    
    /// Primary AR view
    private var sceneView: ARSCNView!
    
    // MARK: Preview scene
    
    /// Secondary scene view that shows the captured face
    private var previewSceneView: SCNView!
    private var previewFaceNode: SCNNode!
    private var previewFaceGeometry: ARSCNFaceGeometry!
    
    // MARK: Measurement
    /// Dot Node
    private var spheres: [SCNNode] = []
    private var sphereCoordinate: [SCNVector3] = []
    // Measurement label
    private var measurementLabel = UILabel()
    
    // MARK: Panning
    //var singlePanRecognizer: UIPanGestureRecognizer!
//    var doublePanRecognizer: UIPanGestureRecognizer!
    var lastTapLocation: CGPoint?
    var selectedNode: SCNNode?
    
    // MARK: View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
            
        sceneView = ARSCNView(frame: self.view.bounds, options: nil)
        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = false
        sceneView.rendersCameraGrain = true
        view.addSubview(sceneView)
        
        self.scnFaceGeometry = ARSCNFaceGeometry(device: self.sceneView.device!, fillMesh: fillMesh)
        
        self.faceUvGenerator = FaceTextureGenerator(
            device: self.sceneView.device!,
            library: self.sceneView.device!.makeDefaultLibrary()!,
            viewportSize: self.view.bounds.size,
            face: self.scnFaceGeometry,
            textureSize: faceTextureSize)
        
        // Preview
        
        previewSceneView = SCNView(frame: self.view.bounds, options: nil)
        previewSceneView.rendersContinuously = true
        previewSceneView.allowsCameraControl = true
        self.view.addSubview(previewSceneView)
        previewSceneView.scene = SCNScene()

        let camera = SCNCamera()
        camera.zNear = 0.001
        camera.zFar = 1000

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3Make(0, 0, 1)
        previewSceneView.scene!.rootNode.addChildNode(cameraNode)
        cameraNode.look(at: SCNVector3Zero)

        self.previewFaceGeometry = ARSCNFaceGeometry(device: self.sceneView.device!, fillMesh: true)
        self.previewFaceNode = SCNNode(geometry: self.previewFaceGeometry)
        self.previewFaceNode.renderingOrder = -1
        let faceScale = Float(4.0)
        self.previewFaceNode.scale = SCNVector3(x: faceScale, y: faceScale, z: faceScale)
        self.previewFaceGeometry.firstMaterial!.diffuse.contents = faceUvGenerator.texture
        self.previewFaceGeometry.firstMaterial!.isDoubleSided = true

        previewSceneView.scene!.rootNode.addChildNode(self.previewFaceNode!)
        
        measurementLabel.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: 100)
               
        // Makes the background white
        measurementLabel.backgroundColor = .white

        // Sets some default text
        measurementLabel.text = "0 mm"
        
        measurementLabel.textColor = .black

        // Centers the text
        measurementLabel.textAlignment = .center

        // Adds the text to the
        view.addSubview(measurementLabel)
        
        //PANNING
        // Disable Rotation for the view
//        if let gestureRecognizers = sceneView.gestureRecognizers {
//            for gesture in gestureRecognizers {
//                if let g = gesture as? UIRotationGestureRecognizer {
//                    g.isEnabled = false
//                }
//            }
//        }
//        singlePanRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleSinglePan(_:)))
//        singlePanRecognizer.maximumNumberOfTouches = 1
//        singlePanRecognizer.minimumNumberOfTouches = 1
//        sceneView.addGestureRecognizer(singlePanRecognizer)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        resetTracking()
    }
    
    // MARK: AR
    
    private func resetTracking() {
        sceneView.session.run(ARFaceTrackingConfiguration(),
                              options: [.removeExistingAnchors,
                                        .resetTracking,
                                        .resetSceneReconstruction,
                                        .stopTrackedRaycasts])
    }
    
    public func renderer(_: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard anchor is ARFaceAnchor else {
            return nil
        }
                
        let node = SCNNode(geometry: scnFaceGeometry)
        scnFaceGeometry.firstMaterial?.diffuse.contents = faceUvGenerator.texture
        return node
    }
     
    public func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor,
              let frame = sceneView.session.currentFrame
        else {
            return
        }
        
        self.previewFaceGeometry.update(from: faceAnchor.geometry)

        scnFaceGeometry.update(from: faceAnchor.geometry)
        faceUvGenerator.update(frame: frame, scene: self.sceneView.scene, headNode: node, geometry: scnFaceGeometry)
        
        
    }
    
    // MARK: Export
    public func capture() {
        sceneView.session.pause()
        
        //set up the tap recognizer
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapRecognizer.numberOfTapsRequired = 1
        previewSceneView.addGestureRecognizer(tapRecognizer)
        
        //set up drag recognizer
        //var singlePanRecognizer: UIPanGestureRecognizer!
        //var doublePanRecognizer: UIPanGestureRecognizer!
        
//        singlePanRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleSinglePan(_:)))
//        singlePanRecognizer.maximumNumberOfTouches = 1
//        singlePanRecognizer.minimumNumberOfTouches = 1
//        previewSceneView.addGestureRecognizer(singlePanRecognizer)
        
    }
    
    
    //TODO: need to fix so that can only drag the pointers itself
    @objc func handleTap(sender: UITapGestureRecognizer) {
        
        //---- handle the tapping ------
        // Gets the location of the tap and assigns it to a constant
        let location = sender.location(in: previewSceneView)
        let hitTest = previewSceneView.hitTest(location)
        // Assigns the most accurate result to a constant if it is non-nil
        guard let result = hitTest.first else { return }

        // Creates an SCNVector3 with certain indexes in the matrix
        let worldCoord = result.worldCoordinates
        let localCoord = result.localCoordinates

        // Makes a new sphere with the created method
        let sphere = createSphere(at: worldCoord)
        
        // Checks if there is at least one sphere in the array
        if let firstSphere = spheres.first, let firstCoord = sphereCoordinate.first {
            
            // Adds a second sphere to the array
            spheres.append(sphere)
            sphereCoordinate.append(localCoord)
            let distance = distance(fromLocalCoord: localCoord, toLocalCoord: firstCoord)
            measurementLabel.text = "\(distance) mm"
            
            //TODO: allow for spheres to be draggable
          //  singlePanRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleSinglePan(_:)))
//                   singlePanRecognizer.maximumNumberOfTouches = 1
//                   singlePanRecognizer.minimumNumberOfTouches = 1
//                   previewSceneView.addGestureRecognizer(singlePanRecognizer)
            
            
            // If more that two are present
            if spheres.count > 2 {
                
                // Iterate through spheres array
                for sphere in spheres {
                    
                    // Remove all spheres
                    sphere.removeFromParentNode()
                }
                
                sphereCoordinate.removeAll()
                spheres.removeAll()
                measurementLabel.text = "0 mm"

            }
            
            if spheres.count == 2 {
                let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
                previewSceneView.addGestureRecognizer(panRecognizer)
            }
        
        // If there are no spheres
        } else {
            // Add the sphere
            sphere.name = "addedSphere"
            spheres.append(sphere)
            sphereCoordinate.append(localCoord)
            
        }
        
        // Iterate through spheres array
        for sphere in spheres {
            
            // Add all spheres in the array
            self.previewSceneView.scene!.rootNode.addChildNode(sphere)
        }
    }
    
    func createSphere(at position: SCNVector3) -> SCNNode {
        
        // Creates an SCNSphere with a radius of 0.4
        let capsule = SCNCapsule(capRadius: 0.002, height: 0.06)
      
        // Converts the sphere into an SCNNode
        let handle  = SCNNode(geometry: capsule)
        //handle.name = "landmarkNode"
        
        // Positions nodes based on the passed in position
        handle.position = position
        
        // Raise handles so they are not buried in the mesh
        handle.eulerAngles = SCNVector3( (-CGFloat.pi/CGFloat(6.0)) , 0, (CGFloat.pi/CGFloat(6.0)))
        
        // Creates a material that is recognized by SceneKit
        let material = SCNMaterial()

        // Converts the contents of the PNG file into the material
        material.diffuse.contents = UIColor.red

        // Creates realistic shadows around the sphere
        material.lightingModel = .blinn

        // Wraps the newly made material around the sphere
        capsule.firstMaterial = material

        // Returns the node to the function
        return handle
            
    }
    // Gets distance between two SCNNodes
    func distance(fromLocalCoord: SCNVector3, toLocalCoord: SCNVector3) -> CGFloat {
        
        // Meters to inches conversion
        let millimeter: Int = 1000
        
        // Difference between x-positions
        let dx = toLocalCoord.x - fromLocalCoord.x
        
        // Difference between x-positions
        let dy = toLocalCoord.y - fromLocalCoord.y
        
        // Difference between x-positions
        let dz = toLocalCoord.z - fromLocalCoord.z
        
        // Formula to get meters
        let meters = sqrt(dx*dx + dy*dy + dz*dz)
    
        // Returns inches
        return CGFloat(meters * Float(millimeter))
    }
    
    @objc func handlePan(sender: UIPanGestureRecognizer) {
        let location = sender.location(in: previewSceneView)
        let hitTest = previewSceneView.hitTest(location)
    }
    
}


