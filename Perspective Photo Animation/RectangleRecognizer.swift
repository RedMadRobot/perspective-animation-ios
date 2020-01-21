//
//  RectangleRecognizer.swift
//
//  Created by Aleksandr Khlebnikov on 02.12.2019.
//

import CoreImage
import Foundation
import UIKit
import Vision

protocol RectangleRecognizerDelegate: class {
    func didDetectRectangle(points: [CGPoint], rectifiedImage: UIImage?)
}

final class RectangleRecognizer {
    
    private var requests = [VNRequest]()
    private var buffer: CVImageBuffer?
    private var imageSize: CGSize
    weak var delegate: RectangleRecognizerDelegate?
        
    init(imageSize: CGSize) {
        self.imageSize = imageSize
        setupVision()
    }
    
    func performRequest(for buffer: CVImageBuffer, orientation: CGImagePropertyOrientation) {
        self.buffer = buffer
        
        let imageRequestHandler = VNImageRequestHandler(
            cvPixelBuffer: buffer,
            orientation: orientation,
            options: [:]
        )
        
        do {
            try imageRequestHandler.perform(self.requests)
        } catch {
            print(error)
        }
    }
        
    private func setupVision() {
        let request = VNDetectRectanglesRequest { request, _ in
            guard let results = request.results as? [VNRectangleObservation], let result = results.first else {
                self.delegate?.didDetectRectangle(points: [], rectifiedImage: nil)
                return
            }
            let image = self.getImage(result: result)
            self.delegate?.didDetectRectangle(points: result.points, rectifiedImage: image)
        }
        
        request.minimumConfidence = 0.8
        request.minimumSize = 0.65

        requests = [request]
    }
    
    private func getImage(result: VNRectangleObservation) -> UIImage {
        guard let buffer = buffer else { return UIImage() }
        
        let ciImage = rectifyImageBuffer(cvImageBuffer: buffer, detectedRectangle: result)
        return UIImage(ciImage: ciImage)
    }
    
    private func rectifyImageBuffer(
        cvImageBuffer: CVImageBuffer,
        detectedRectangle: VNRectangleObservation) -> CIImage {
        
        let inputImage = CIImage(cvImageBuffer: cvImageBuffer)
        return rectifyCIImage(inputImage, detectedRectangle: detectedRectangle)
    }
    
    private func rectifyCIImage(_ image: CIImage, detectedRectangle: VNRectangleObservation) -> CIImage {
        let boundingBox = detectedRectangle.boundingBox.scaled(to: imageSize)

        guard image.extent.contains(boundingBox) else { return CIImage() }

        let topLeft = detectedRectangle.topLeft.scaled(to: imageSize)
        let topRight = detectedRectangle.topRight.scaled(to: imageSize)
        let bottomLeft = detectedRectangle.bottomLeft.scaled(to: imageSize)
        let bottomRight = detectedRectangle.bottomRight.scaled(to: imageSize)
        let correctedImage: CIImage = image
            .cropped(to: boundingBox)
            .applyingFilter("CIPerspectiveCorrection",
                            parameters: [
                                "inputTopLeft": CIVector(cgPoint: topLeft),
                                "inputTopRight": CIVector(cgPoint: topRight),
                                "inputBottomLeft": CIVector(cgPoint: bottomLeft),
                                "inputBottomRight": CIVector(cgPoint: bottomRight)]
            )
            .oriented(.right)
        
        return correctedImage
    }
}

extension VNRectangleObservation {
    
    /// Clockwise route from topLeft to bottomLeft
    var points: [CGPoint] {
        return [topLeft, topRight, bottomRight, bottomLeft]
    }
}

private extension CGRect {
    func scaled(to size: CGSize) -> CGRect {
        return CGRect(
            x: self.origin.x * size.width,
            y: self.origin.y * size.height,
            width: self.width * size.width,
            height: self.height * size.height
        )
    }
}

private extension CGPoint {
    func scaled(to size: CGSize) -> CGPoint {
        return CGPoint(x: self.x * size.width, y: self.y * size.height)
    }
}
