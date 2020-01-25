//
//  ViewController.swift
//  Perspective Photo Animation
//
//  Created by Ivan Vavilov on 21.01.2020.
//  Copyright © 2020 Ivan Vavilov. All rights reserved.
//

import AVFoundation
import UIKit

final class ViewController: UIViewController {

    private enum Constants {
        static let leftSpace: CGFloat = 56
        static let imageAspectRatio: CGFloat = 0.43
    }
    
    @IBOutlet private var previewView: PreviewView!
    
    private var bufferSize: CGSize = .zero
    private lazy var session = AVCaptureSession()
    private lazy var photoCaptureManager = PhotoCaptureManager(session: session)
    private lazy var rectangleRecognizer = RectangleRecognizer(imageSize: bufferSize)
    private lazy var videoDataOutput = AVCaptureVideoDataOutput()
    private lazy var videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private var detectionOverlay: CALayer!
    private var rectanglePoints = [CGPoint]()
    private var isRecognizing: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSession()
        previewView.session = session
        rectangleRecognizer.delegate = self
        setupLayers()
        updateLayerGeometry()
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
        photoCaptureManager.makePhoto { [weak self] in
            self?.recognizeBlank($0)
        }
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
    
    private func setupLayers() {
        detectionOverlay = CALayer()
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0, y: 0, width: bufferSize.width, height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: previewView.layer.bounds.midX, y: previewView.layer.bounds.midY)
        previewView.layer.addSublayer(detectionOverlay)
        previewView.videoPreviewLayer.videoGravity = .resizeAspect
    }
    
    private func updateLayerGeometry() {
        let bounds = previewView.layer.bounds
        var scale: CGFloat

        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width

        scale = min(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)

        let transform = CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale)
        detectionOverlay.setAffineTransform(transform)
        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
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
    
    private func recognizeBlank(_ buffer: CVPixelBuffer) {
        session.stopRunning()
        
        isRecognizing = true
        
        rectangleRecognizer.performRequest(for: buffer, orientation: self.exifOrientationFromDeviceOrientation())
    }
    
    private func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation
        
        switch curDeviceOrientation {
        case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = .left
        case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
            exifOrientation = .upMirrored
        case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
            exifOrientation = .down
        case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
            exifOrientation = .up
        default:
            exifOrientation = .up
        }
        return exifOrientation
    }
    
    private func drawVisionRequestResult(_ points: [CGPoint]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)

        detectionOverlay.sublayers = nil
        let rectLayer = createPolygon(points, for: bufferSize)
        detectionOverlay.addSublayer(rectLayer)
        
        DispatchQueue.main.async {
            self.updateLayerGeometry()
        }

        CATransaction.commit()
    }
    
    private func createPolygon(_ normalizedPoints: [CGPoint], for frame: CGSize) -> CALayer {
        guard !normalizedPoints.isEmpty else {
            return CALayer()
        }
        
        let shape = CAShapeLayer()
        shape.opacity = 0.5
        shape.lineWidth = 10
        shape.lineJoin = CAShapeLayerLineJoin.miter
        shape.fillColor = UIColor.blue.withAlphaComponent(0.25).cgColor
        
        self.rectanglePoints = normalizedPoints.map { $0.scaled(to: frame) }
        
        let path = UIBezierPath()
        path.move(to: rectanglePoints[0])
        rectanglePoints[1...3].forEach { point in
            path.addLine(to: point)
        }
        path.close()
        shape.path = path.cgPath
        
        return shape
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        rectangleRecognizer.performRequest(for: pixelBuffer, orientation: exifOrientationFromDeviceOrientation())
    }
}

// MARK: - RectangleRecognizerDelegate

extension ViewController: RectangleRecognizerDelegate {
    
    func didDetectRectangle(points: [CGPoint], rectifiedImage: UIImage?) {
        drawVisionRequestResult(points)
        
        guard isRecognizing else { return }
        
        if let image = rectifiedImage {
            animatePerspective(image)
        }
        session.startRunning()
        isRecognizing.toggle()
    }
    
    private func animatePerspective(_ image: UIImage) {
        let imageView = UIImageView(image: image)
        previewView.addSubview(imageView)
        previewView.bringSubviewToFront(imageView)
        
        let rect = imageView.frame
        imageView.layer.anchorPoint = .zero
        imageView.frame = rect
        
        let points = rectanglePoints.map { detectionOverlay.convert($0, to: previewView.layer) }
        
        let start = Quadrilateral(points: points)
        let destination = Quadrilateral(frame: imageView.frame)
        imageView.transform3D = destination.transformTo(start)
        
        UIView.animate(
            withDuration: 1,
            animations: {
                let currentSize = imageView.bounds.size
                let targetSize = CGSize(
                    width: self.view.bounds.size.width - 2 * Constants.leftSpace,
                    height: Constants.imageAspectRatio * self.view.bounds.size.height
                )
                let scale = min(targetSize.width / currentSize.width, targetSize.height / currentSize.height)
                let translation = CGPoint(
                    x: Constants.leftSpace / scale,
                    y: ((self.view.bounds.size.height - targetSize.height) / 2 - self.previewView.frame.minY) / scale
                )
                
                imageView.transform3D = CATransform3DTranslate(CATransform3DMakeScale(scale, scale, 1), translation.x, translation.y, 0)
            },
            completion: { _ in
                UIView.animate(
                    withDuration: 0.5,
                    delay: 3,
                    animations: {
                        imageView.alpha = 0
                    },
                    completion: { _ in
                        imageView.removeFromSuperview()
                    })
            }
        )
    }
}
