//
//  ViewController.swift
//  Perspective Photo Animation
//
//  Created by Ivan Vavilov on 21.01.2020.
//  Copyright © 2020 Ivan Vavilov. All rights reserved.
//

import AVFoundation
import UIKit

final class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet private var previewView: PreviewView!
    
    private var bufferSize: CGSize = .zero
    private lazy var session = AVCaptureSession()
    private lazy var photoCaptureManager = PhotoCaptureManager(session: session)
    private lazy var rectangleRecognizer = RectangleRecognizer(imageSize: bufferSize)
    private lazy var videoDataOutput = AVCaptureVideoDataOutput()
    private lazy var videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private var detectionOverlay: CALayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSession()
        previewView.session = session
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        session.startRunning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }
    
    @IBAction private func shot() {
        print("shot")
    }
    
    private func setupSession() {
        guard let deviceInput = selectVideoDeviceAsInput() else {
            print("Could not set input video device")
            return
        }
                
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Add a video input
        guard session.canAddInput(deviceInput) else {
            print("Could not add video device input to the session")
            session.commitConfiguration()
            return
        }
        
        session.addInput(deviceInput)
        
        addVideoOutput()
        
        let captureConnection = videoDataOutput.connection(with: .video)
        
        // Always process the frames
        captureConnection?.isEnabled = true
        do {
            try deviceInput.device.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((deviceInput.device.activeFormat.formatDescription))
            bufferSize.width = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            deviceInput.device.unlockForConfiguration()
        } catch {
            print(error)
        }
        
        session.commitConfiguration()
    }
    
    private func addVideoOutput() {
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            // Add a video data output
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            session.commitConfiguration()
        }
    }
    
    private func selectVideoDeviceAsInput() -> AVCaptureDeviceInput? {
        guard let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first else {
            return nil
        }
        do {
            try videoDevice.lockForConfiguration()
            videoDevice.focusMode = .continuousAutoFocus
            videoDevice.autoFocusRangeRestriction = .near
            videoDevice.unlockForConfiguration()
            return try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print(error)
            return nil
        }
    }
    
}

