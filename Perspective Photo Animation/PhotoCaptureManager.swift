//
//  PhotoCaptureManager.swift
//
//  Created by Aleksandr Khlebnikov on 02.12.2019.
//

import AVFoundation
import Foundation

final class PhotoCaptureManager: NSObject {
    
    private var session: AVCaptureSession
    private var photoOutput = AVCapturePhotoOutput()
    
    private var bufferHandler: ((CVPixelBuffer) -> Void)?
    
    var flashMode: AVCaptureDevice.FlashMode = .auto
    
    init(session: AVCaptureSession) {
        self.session = session
        super.init()
        
        self.addPhotoOutput()
    }
    
    func makePhoto(completion: @escaping (CVPixelBuffer) -> Void) {
        bufferHandler = completion

        let photoSettings = AVCapturePhotoSettings(format:
        [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        photoSettings.flashMode = flashMode
        
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    private func addPhotoOutput() {
        photoOutput.setPreparedPhotoSettingsArray(
            [AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])],
            completionHandler: nil
        )
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
    }
    
    deinit {
        session.removeOutput(photoOutput)
    }
}

extension PhotoCaptureManager: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print(error)
            return
        }
        
        if let buffer = photo.pixelBuffer {
            bufferHandler?(buffer)
        }
    }
}
