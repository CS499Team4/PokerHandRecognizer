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

    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var textView: UITextView!
    // COREML
    var visionRequests = [VNRequest]()
    let dispatchQueueML = DispatchQueue(label: "com.hw.dispatchqueueml") // A Serial Queue
    
    var cardsRecognized = [String]()
    var currPair = ""
    var sceneText = ["Currently predicting this card as:", "", "", "", "", "", "","", ""]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
        self.textView.text = sceneText[0]
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
                }
            }
        }
        
        self.sceneText[1] = self.currPair
        self.updateText()
    }
    
    
    func updateText(){
        self.textView.text = ""
        var skip1 = false
        if self.sceneText[1] == ""{
            skip1 = true
        }
        for i in self.sceneText{
            if i != ""{
                if i == self.sceneText[0] && !skip1{
                    self.textView.text.append(i)
                    self.textView.text.append("\n")
                }
                else if i != self.sceneText[0]{
                    self.textView.text.append(i)
                    self.textView.text.append("\n")
                }
                else{
                    if self.cardsRecognized.count != 5{
                        self.textView.text.append("Place card in front to classify\n")
                    }
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
        if self.currPair != "" && self.cardsRecognized.count != 5 && !self.cardsRecognized.contains(self.currPair){
            self.cardsRecognized.append(self.currPair)
            self.sceneText[self.cardsRecognized.count+2] = "Card " + String(self.cardsRecognized.count) + ": " + self.currPair
            self.updateText()
            print(self.cardsRecognized)
        }
        if self.cardsRecognized.count == 5{
            self.classify()
        }
    }
    
    @IBAction func reset(_ sender: Any) {
        self.cardsRecognized = [String]()
        self.sceneText = ["Currently predicting this card as:", "", "", "", "", "", "", "",""]
        self.updateText()
    }
    
    @IBAction func popLast(_ sender: UIBarButtonItem) {
        if self.cardsRecognized.count != 0{
            self.sceneText[self.cardsRecognized.count + 2] = ""
            self.cardsRecognized.removeLast()
            self.updateText()
        }
    }
    
    func classify(){
        var suit = [String]()
        var num = [String]()
        for i in self.cardsRecognized{
            let split = i.split(separator: " ")
            suit.append(String(split[0]))
            num.append(String(split[1]))
        }
        var newNum = [Int]()
        for i in num{
            switch i {
            case "Two":
                newNum.append(0)
                break
            case "Three":
                newNum.append(1)
                break
            case "Four":
                newNum.append(2)
                break
            case "Five":
                newNum.append(3)
                break
            case "Six":
                newNum.append(4)
                break
            case "Seven":
                newNum.append(5)
                break
            case "Eight":
                newNum.append(6)
                break
            case "Nine":
                newNum.append(7)
                break
            case "Ten":
                newNum.append(8)
                break
            case "Jack":
                newNum.append(9)
                break
            case "Queen":
                newNum.append(10)
                break
            case "King":
                newNum.append(11)
                break
            default: //Ace
                newNum.append(12)
            }
        }
        if isRoyalFlush(suits: suit, nums: newNum){
            print("Royal Flush")
            self.sceneText[8] = "Royal Flush"
        }
        else if isStraightFlush(suits: suit, nums: newNum){
            print("Straight Flush")
            self.sceneText[8] = "Straight Flush"
        }
        else if isFourOfAKind(nums: newNum){
            print("Four of a kind")
            self.sceneText[8] = "Four of a Kind"
        }
        else if isFullHouse(nums: newNum){
            print("Full House")
            self.sceneText[8] = "Full House"
        }
        else if isFlush(suits: suit){
            print("Flush")
            self.sceneText[8] = "Flush"
        }
        else if isStraight(nums: newNum){
            print("Straight")
            self.sceneText[8] = "Straight"
        }
        else if isThreeOfAKind(nums: newNum){
            print("Three of a Kind")
            self.sceneText[8] = "Three of A Kind"
        }
        else if isTwoPair(nums: newNum){
            print("Two Pair")
            self.sceneText[8] = "Two Pair"
        }
        else if isPair(nums: newNum){
            print("Pair")
            self.sceneText[8] = "Pair"
        }
        else{
            let max = newNum.max()
            let indexOfMax = newNum.firstIndex(of: max!)
            print("High Card of" + String(max!) + " " + suit[indexOfMax!])
            self.sceneText[8] = "High Card of" + String(max!) + " " + suit[indexOfMax!]
        }
        
        self.updateText()
    }
    
    func isRoyalFlush(suits: [String], nums: [Int])->Bool{
        let mainSuit = suits[0]
        for i in suits{
            if i != mainSuit{
                return false
            }
        }
        let neededForFlush = [12,11,10,9,8]
        for i in neededForFlush{
            if !nums.contains(i){
                return false
            }
        }
        return true
    }
    
    func isStraightFlush(suits: [String], nums: [Int])->Bool{
        let mainSuit = suits[0]
        for i in suits{
            if i != mainSuit{
                return false
            }
        }
        var numsCopy = nums
        numsCopy.sort()
        for i in 0..<numsCopy.count - 1{
            if numsCopy[i+1] - numsCopy[i] != 1{
                return false
            }
        }
        return true
    }
    
    func isFourOfAKind(nums: [Int])->Bool{
        var numsCopy = nums
        numsCopy.sort()
        if numsCopy[0] == numsCopy[1] && nums[1] == numsCopy[2]  && numsCopy[2] == numsCopy[3]{
            return true
        }
        else if numsCopy[1] == numsCopy[2] && numsCopy[2] == numsCopy[3]  && numsCopy[3] == numsCopy[4]{
            return true
        }
        return false
    }
    
    func isFullHouse(nums: [Int])->Bool{
        var numsCopy = nums
        numsCopy.sort()
        if numsCopy[0] == numsCopy[1] && numsCopy[1] == numsCopy[2]{
            if numsCopy[3] == numsCopy[4]{
                return true
            }
        }
        else if numsCopy[4] == numsCopy[3] && numsCopy[3] == numsCopy[2]{
            if numsCopy[1] == numsCopy[0]{
                return true
            }
        }
        return false
    }
    
    func isFlush(suits: [String])->Bool{
        let mainSuit = suits[0]
        for i in suits{
            if i != mainSuit{
                return false
            }
        }
        return true
    }
    
    func isStraight(nums: [Int])->Bool{
        var numsCopy = nums
        numsCopy.sort()
        for i in 0..<numsCopy.count - 1{
            if numsCopy[i+1] - numsCopy[i] != 1{
                return false
            }
        }
        return true
    }
    
    func isThreeOfAKind(nums: [Int])->Bool{
        var numsCopy = nums
        numsCopy.sort()
        if numsCopy[0] == numsCopy[1] && numsCopy[1] == numsCopy[2]{
            return true
        }
        else if numsCopy[1] == numsCopy[2] && numsCopy[2] == numsCopy[3]{
            return true
        }
        else if numsCopy[2] == numsCopy[3] && numsCopy[4] == numsCopy[5]{
            return true
        }
        return false
    }
    
    func isTwoPair(nums: [Int])->Bool{
        var numsCopy = nums
        numsCopy.sort()
        if numsCopy[0] ==  numsCopy[1]{
            if numsCopy[2] == numsCopy[3]{
                return true
            }
            if numsCopy[3] == numsCopy[4]{
                return true
            }
        }
        else if numsCopy[1] == numsCopy[2]{
            if numsCopy[3] == numsCopy[3]{
                return true
            }
        }
        return false
    }
    
    func isPair(nums: [Int])->Bool{
        var numsCopy = nums
        numsCopy.sort()
        for i in 0..<numsCopy.count-1{
            if numsCopy[i] == numsCopy[i+1]{
                return true
            }
        }
        return false
    }
}
