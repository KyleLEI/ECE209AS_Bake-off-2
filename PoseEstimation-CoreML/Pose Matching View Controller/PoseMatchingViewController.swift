//
//  PoseMatchingViewController.swift
//  PoseEstimation-CoreML
//
//  Created by Doyoung Gwak on 13/08/2019.
//  Copyright © 2019 tucan9389. All rights reserved.
//

import UIKit
import CoreMedia
import Vision

class PoseMatchingViewController: UIViewController {

    // MARK: - UI Property
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var jointView: DrawingJointView!
    @IBOutlet var capturedJointViews: [DrawingJointView]!
    
    var capturedIndex = 0
    
    // MARK: - AV Property
    var videoCapture: VideoCapture!
    
    // MARK: - ML Properties
    // Core ML model
    typealias EstimationModel = model_cpm
    
    // Preprocess and Inference
    var request: VNCoreMLRequest?
    var visionModel: VNCoreMLModel?
    
    // Postprocess
    var postProcessor: HeatmapPostProcessor = HeatmapPostProcessor()
    var mvfilters: [MovingAverageFilter] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup the drawing views
        setUpCapturedJointView()

        // setup the model
        setUpModel()
        
        // setup camera
        setUpCamera()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.videoCapture.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.videoCapture.stop()
    }
    
    // MARK: - Setup Captured Joint View
    func setUpCapturedJointView() {
        postProcessor.onlyBust = true
        
        for capturedJointView in capturedJointViews {
            capturedJointView.layer.borderWidth = 2
            capturedJointView.layer.borderColor = UIColor.gray.cgColor
        }
    }
    
    // MARK: - Setup Core ML
    func setUpModel() {
        if let visionModel = try? VNCoreMLModel(for: EstimationModel().model) {
            self.visionModel = visionModel
            request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            request?.imageCropAndScaleOption = .centerCrop
        } else {
            fatalError("cannot load the ml model")
        }
    }
    
    // MARK: - SetUp Video
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = 30
        videoCapture.setUp(sessionPreset: .vga640x480, cameraPosition: .front) { success in
            
            if success {
                // add preview view on the layer
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                
                // start video preview when setup is done
                self.videoCapture.start()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizePreviewLayer()
    }
    
    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }
    
    @IBAction func tapCapture(_ sender: Any) {
        let currentIndex = capturedIndex % capturedJointViews.count
        let capturedJointView = capturedJointViews[currentIndex]
        
        capturedJointView.bodyPoints = jointView.bodyPoints
        
        capturedIndex += 1
    }
}

// MARK: - VideoCaptureDelegate
extension PoseMatchingViewController: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        // the captured image from camera is contained on pixelBuffer
        if let pixelBuffer = pixelBuffer {
            predictUsingVision(pixelBuffer: pixelBuffer)
        }
    }
}

extension PoseMatchingViewController {
    // MARK: - Inferencing
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        guard let request = request else { fatalError() }
        // vision framework configures the input size of image following our model's input configuration automatically
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
    }
    
    // MARK: - Postprocessing
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let heatmaps = observations.first?.featureValue.multiArrayValue else { return }
        
        /* =================================================================== */
        /* ========================= post-processing ========================= */
        
        /* ------------------ convert heatmap to point array ----------------- */
        var predictedPoints = postProcessor.convertToPredictedPoints(from: heatmaps, isFlipped: true)
        
        /* --------------------- moving average filter ----------------------- */
        if predictedPoints.count != mvfilters.count {
            mvfilters = predictedPoints.map { _ in MovingAverageFilter(limit: 3) }
        }
        for (predictedPoint, filter) in zip(predictedPoints, mvfilters) {
            filter.add(element: predictedPoint)
        }
        predictedPoints = mvfilters.map { $0.averagedValue() }
        /* =================================================================== */
        
        /* =================================================================== */
        /* ======================= display the results ======================= */
        DispatchQueue.main.sync { [weak self] in
            guard let self = self else { return }
            // draw line
            self.jointView.bodyPoints = predictedPoints
        }
        /* =================================================================== */
    }
}
