//
//  ViewController.swift
//  PokerHandRecognizer
//
//  Created by Ryan Gaines on 10/15/18.
//  Copyright © 2018 Team 4. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

import Vision


class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var textView: UITextView!
    // COREML
    var visionRequests = [VNRequest]()
    let dispatchQueueML = DispatchQueue(label: "com.hw.dispatchqueueml") // A Serial Queue
    
    var cardsRecognized = [String]()
    var currPair = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
        self.setUpARKit()
        self.setUpVision()
        self.coreMLLoop()
    }
    
    func setUpARKit(){
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = false
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Enable Default Lighting - makes the 3D text a bit poppier.
        sceneView.autoenablesDefaultLighting = true
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        // Enable plane detection
        configuration.planeDetection = .horizontal
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            // Do any desired updates to SceneKit here.
        }
    }
    
    func setUpVision(){
        guard let selectedModel = try? VNCoreMLModel(for: Recognizer().model) else {
            fatalError("Could not load model. Ensure model has been drag and dropped (copied) to XCode Project from the GitHub.")
        }
        let dectectionRequest = VNCoreMLRequest(model: selectedModel, completionHandler: {(request, error) in
            DispatchQueue.main.async(execute: {
                if let results = request.results{
                    self.processHands(results)
                }
            })
        })
        
        visionRequests = [dectectionRequest]
        
    }
    
    func processHands(_ results: [Any]){
        self.textView.text = ""
        var cards = [String]()
        var cardsLocation = [CGRect]()
        var nums = [String]()
        var numsLocation = [CGRect]()
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }
            // Select only the label with the highest confidence.
            let topLabelObservation = objectObservation.labels[0]
            let location = objectObservation.boundingBox
            let instance = topLabelObservation.identifier
            if ((instance == "Club") || (instance == "Heart") || (instance == "Diamond") || (instance == "Spade")){
                cards.append(instance)
                cardsLocation.append(location)
            }
            else{
                nums.append(instance)
                numsLocation.append(location)
            }
            
        }
        self.currPair = ""
        for c in 0..<cardsLocation.count{
            for n in 0..<numsLocation.count{
                if cardsLocation[c].contains(numsLocation[n]){
                    let id = cards[c] + " " + nums[n]
                    self.currPair = id
                    self.textView.text.append(id)
                }
            }
        }
    }
    
    
    func coreMLLoop(){
        dispatchQueueML.async {
            // 1. Run Update.
            self.updateCoreML()
            
            // 2. Loop this function.
            self.coreMLLoop()
        }
    }
    
    
    
    func updateCoreML(){
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)
        
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
        
    }
    
    
    @objc func handleTap(gestureRecognize: UITapGestureRecognizer) {
        if self.currPair != ""{
            self.cardsRecognized.append(self.currPair)
            print(self.cardsRecognized)
        }
        if self.cardsRecognized.count == 5{
            self.classify()
        }
    }
    
    func classify(){
        let cardorder = ["Two", "Three", "Four","Five","Six","Seven","Eight","Nine","Ten","Jack","Queen","King","Ace"]
        var sorted = [String]()
        for i in self.cardsRecognized{
            if sorted.count == 0{
                sorted.append(i)
            }
            else{
                let splitted = i.split(separator: " ")
                let indexOfI = cardorder.firstIndex(of: String(splitted[1]))
                var indexI = indexOfI?.distance(to: 0)
                indexI = indexI! * -1
                let currSplit = sorted[0].split(separator: " ")
                let indexOfJ = cardorder.firstIndex(of: String(currSplit[1]))
                var indexJ = indexOfJ?.distance(to: 0)
                indexJ = indexJ! * -1
                var appendHere = 0
                while indexI! < indexJ!{
                    appendHere += 1
                    let currSplit = sorted[appendHere].split(separator: " ")
                    let indexOfJ = cardorder.firstIndex(of: String(currSplit[1]))
                    var indexJ = indexOfJ?.distance(to: 0)
                    indexJ = indexJ! * -1
                }
                sorted.insert(i, at: appendHere)
            
                
            }
        }

    }
    
}

