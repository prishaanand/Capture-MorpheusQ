import ARKit
import SceneKit
import UIKit

/// Size of the generated face texture
private let faceTextureSize = 1024 //px

/// Should the face mesh be filled in? (i.e. fill in the eye and mouth holes with geometry)
private let fillMesh = true

class ARViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
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
    
    /// Secondary scene view that shows the captured face
    private var secondPreviewSceneView: SCNView!
    private var secondPreviewFaceNode: SCNNode!
    private var secondPreviewFaceGeometry: ARSCNFaceGeometry!
    
    // MARK: View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView = ARSCNView(frame: self.view.bounds, options: nil)
        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = false
        sceneView.rendersCameraGrain = true
        self.view.addSubview(sceneView)
        
        self.scnFaceGeometry = ARSCNFaceGeometry(device: self.sceneView.device!, fillMesh: fillMesh)
        
        self.faceUvGenerator = FaceTextureGenerator(
            device: self.sceneView.device!,
            library: self.sceneView.device!.makeDefaultLibrary()!,
            viewportSize: self.view.bounds.size,
            face: self.scnFaceGeometry,
            textureSize: faceTextureSize)
        
        // Preview
        //TODO: update preview size
        
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
        let faceScale = Float(4.0)
        self.previewFaceNode.scale = SCNVector3(x: faceScale, y: faceScale, z: faceScale)
        self.previewFaceGeometry.firstMaterial!.diffuse.contents = faceUvGenerator.texture
        self.previewFaceGeometry.firstMaterial!.isDoubleSided = true

        previewSceneView.scene!.rootNode.addChildNode(self.previewFaceNode!)
        
        self.secondPreviewFaceGeometry = ARSCNFaceGeometry(device: self.sceneView.device!, fillMesh: true)
        self.secondPreviewFaceNode = SCNNode(geometry: self.secondPreviewFaceGeometry)
    
        //prevent aliasing
        let faceScale2 = Float(4.01)
        self.secondPreviewFaceNode.scale = SCNVector3(x: faceScale2, y: faceScale2, z: faceScale2)
        self.secondPreviewFaceGeometry.firstMaterial!.diffuse.contents = UIColor.lightGray
        self.secondPreviewFaceGeometry.firstMaterial!.fillMode = .lines
        //try
        self.secondPreviewFaceNode.geometry?.firstMaterial!.isLitPerPixel = false;

        self.secondPreviewFaceGeometry.firstMaterial!.lightingModel = .physicallyBased
        self.secondPreviewFaceGeometry.firstMaterial!.isDoubleSided = true

        previewSceneView.scene!.rootNode.addChildNode(self.secondPreviewFaceNode!)
        
        
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
        self.secondPreviewFaceGeometry.update(from: faceAnchor.geometry)

        scnFaceGeometry.update(from: faceAnchor.geometry)
        faceUvGenerator.update(frame: frame, scene: self.sceneView.scene, headNode: node, geometry: scnFaceGeometry)
        
        
    }
    
    // MARK: Export
    
    public func exportTextureMapToPhotos() {
        let close = {
            Timer.scheduledTimer(withTimeInterval: 2, repeats:false, block: {_ in
                self.dismiss(animated: true, completion: nil)
            })
            return
        }
        
        if let uiImage = textureToImage(faceUvGenerator.texture) {
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
            let alert = UIAlertController(title: "Export Successful", message: "Saved texture to photo album", preferredStyle: .alert)
            self.present(alert, animated: true, completion: close)
        } else {
            let alert = UIAlertController(title: "Export Failed", message: "Could not save texture to photo album", preferredStyle: .alert)
            self.present(alert, animated: true, completion: close)
        }
    }
    
    public func capture() {
        
        _ = {
            Timer.scheduledTimer(withTimeInterval: 2, repeats:false, block: {_ in
                self.dismiss(animated: true, completion: nil)
            })
            return
        }
        
        sceneView.session.pause()
        
    }
    
    //point cloud export
    public func exportFaceMap() {
            guard let a = session.currentFrame?.anchors[0] as? ARFaceAnchor else { return }
            
            let toprint = utilities.exportToSTL(geometry: a.geometry)
            
            let file = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("face.dae")
            do {
                try toprint.write(to: file!, atomically: true, encoding: String.Encoding.utf8)
            } catch  {
                
            }
            let vc = UIActivityViewController(activityItems: [file as Any], applicationActivities: [])
            present(vc, animated: true, completion: nil)
            
        }
    
}
