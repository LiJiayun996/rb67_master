//
//  ViewController.swift
//  rb67_master
//
//  Created by Jiayun Li on 2/28/19.
//  Copyright © 2019 Jiayun Li. All rights reserved.
//

import UIKit
import AVFoundation
import CoreImage

class ViewController: UIViewController {
    
    
    //MARK:  -- Camera var
    var captureSession = AVCaptureSession()
    var backCamera: AVCaptureDevice?
    var frontCamera: AVCaptureDevice?
    var currentCamera: AVCaptureDevice?
    
    var photoOutput: AVCapturePhotoOutput?
    var cameraPreviewLayer: AVCaptureVideoPreviewLayer?
    
    @IBOutlet weak var previewView: UIView!
    
    //MARK:  -- image var
    var image: UIImage?

    
    //MARK:  -- fine tuning image exposure
    var isoValueAsShot: Float! {get{return currentCamera?.iso}}
    var shutterValueAsShot: CMTime! {get{return currentCamera?.exposureDuration}}
    
    var exposureIndexNumber: Float! {get{return Float(shutterValueAsShot.value/100000) * Float(isoValueAsShot) }}
    
    //MARK:  -- Post image processing var
    
    var postProcessingImage : UIImage!
    
    var lightLeakOverlayImage : UIImage!
    
    var borderOverlayImage : UIImage!
    
    var filterToProcess : String = "B&W"
    
    //MARK:  -- Camera Operations
    
    @IBAction func colorShutterPressedTouchUpInside(_ sender: Any) {
        
        print("ISO value as shot was \(String(describing: isoValueAsShot))")
        print("Shutter value as shot was \(String(describing: shutterValueAsShot))")
        
        if exposureIndexNumber >= 3000 {
            
            print(exposureIndexNumber)
            print("room lighting")

            cameraExposureAdjust(exposureBias: -1.5 )
            
            filterToProcess = "ColorNight"
            
            
        } else {
            
            print(exposureIndexNumber)
            print("daylight")
            
            cameraExposureAdjust(exposureBias: -1.7 )
            
            filterToProcess = "ColorDay"
        }
        
        let settings = AVCapturePhotoSettings()
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
        
    }
    
    @IBAction func blackWhiteShutterPressedTouchUpInside(_ sender: Any) {
        
        print("ISO value as shot was \(String(describing: isoValueAsShot))")
        print("Shutter value as shot was \(String(describing: shutterValueAsShot))")
        
        filterToProcess = "B&W"
        let settings = AVCapturePhotoSettings()
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
        
    }
    
    @IBAction func flipCameraPressedTouchUpInside(_ sender: Any) {
        switchCamera()
    }
    
    //MARK:  -- UI Controlls
    
    @IBAction func settingButtonPressed(_ sender: Any) {
        
        performSegue(withIdentifier: "showSetting_Segue", sender: nil)
        
    }
    
    @IBAction func galleryButtonPressed(_ sender: Any) {
        
    }
    
    
    @IBAction func TestButtonPressed(_ sender: Any) {
        
        do{
            try self.currentCamera!.lockForConfiguration()
            self.currentCamera!.setExposureTargetBias(-1.7, completionHandler: nil)
        } catch let error { print(error) }
        
    }
    
    
    //MARK:  -- Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCaptureSession()
        setupDevice()
        setupInputOutput()
        setupPreviewLayer()
        captureSession.startRunning()
        
        
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    //MARK: Setup UI
    
    func configColorShutterButton() {
        
        
        
    }
    
    
    //MARK:  -- Camera Methods
    
    func cameraExposureAdjust (exposureBias: Float ){
        
        do{
            try self.currentCamera!.lockForConfiguration()
            self.currentCamera!.setExposureTargetBias(exposureBias, completionHandler: nil)
            
        } catch let error { print(error) }
        
    }

    func setupCaptureSession() {
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
    }
    
    func setupDevice() {
        
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
        let devices = deviceDiscoverySession.devices
        
        for device in devices {
            if device.position == AVCaptureDevice.Position.back{
                backCamera = device
            } else if device.position == AVCaptureDevice.Position.front {
                frontCamera = device }
        }
        currentCamera = backCamera
//
//        do{
//            try self.currentCamera!.lockForConfiguration()
//            self.currentCamera!.setExposureTargetBias(-1.7, completionHandler: nil)
//        } catch let error { print(error) }
        
    }
    
    func setupInputOutput() {
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: currentCamera!)
            captureSession.addInput(captureDeviceInput)
            photoOutput = AVCapturePhotoOutput()
            photoOutput?.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
            captureSession.addOutput(photoOutput!)
        } catch {
            print(error)
        }
    }
    
    func setupPreviewLayer(){
        cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        cameraPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        cameraPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        cameraPreviewLayer?.frame = self.view.frame
        
        // vvv resize camera preview to view element vvv
        previewView.layer.addSublayer(cameraPreviewLayer!)
        self.cameraPreviewLayer?.frame = self.previewView.bounds
        //        previous line
        //        self.view.layer.insertSublayer(cameraPreviewLayer!, at: 0)
        
    }
    
    @objc func switchCamera() {
        captureSession.beginConfiguration()
        
        // Change the device based on the current camera
        let newDevice = (currentCamera?.position == AVCaptureDevice.Position.back) ? frontCamera : backCamera
        
        // Remove all inputs from the session
        for input in captureSession.inputs {
            captureSession.removeInput(input as! AVCaptureDeviceInput)
        }
        
        // Change to the new input
        let cameraInput:AVCaptureDeviceInput
        do {
            cameraInput = try AVCaptureDeviceInput(device: newDevice!)
        } catch {
            print(error)
            return
        }
        
        if captureSession.canAddInput(cameraInput) {
            captureSession.addInput(cameraInput)
        }
        currentCamera = newDevice
        captureSession.commitConfiguration()
        
    }
    
    //MARK:  -- Image Tuning while in operation
    
    func exposureAdjust() {
        // Preset exposure gain value, for better high light detail
        do{
            try self.currentCamera!.lockForConfiguration()
            self.currentCamera!.setExposureTargetBias(-1.3, completionHandler: nil)
        } catch let error { print(error) }
    }
    
    
    //MARK:  -- Post Image Production

    func postImageProcessingProcedure() {
        
        postProcessingImage = image
        lightLeakOverlayImage = UIImage(named: "testSquareOverlay")
        borderOverlayImage = UIImage(named: "testBorderOverlayPNG")
        
        // assigning / applying filter to master post processing image
        if filterToProcess == "B&W" {
            
            postProcessingImage = postProcessingImage.scaled(to: CGSize(width: postProcessingImage.size.width, height: postProcessingImage.size.width))
            lightLeakOverlayImage = lightLeakOverlayImage.scaled(to: postProcessingImage.size)
            
            postProcessingImage = applyFilterTo(image: postProcessingImage, filterEffect: Filter(filterName: "CIVignette", fliterEffectValue: 0.5, filterEffectValueName: kCIInputIntensityKey))
            
            postProcessingImage = blendImage(image: postProcessingImage, overlayImage: lightLeakOverlayImage)
            
            postProcessingImage = blendBoarderImage(image: postProcessingImage, overlayImage: borderOverlayImage)
    
            postProcessingImage = applyFilterTo(image: postProcessingImage, filterEffect: Filter(filterName: "CIPhotoEffectNoir", fliterEffectValue: nil, filterEffectValueName: nil))
            
        } else if filterToProcess == "ColorDay"{
            
            postProcessingImage = postProcessingImage.scaled(to: CGSize(width: postProcessingImage.size.width, height: postProcessingImage.size.width))
            lightLeakOverlayImage = lightLeakOverlayImage.scaled(to: postProcessingImage.size)
            
            postProcessingImage = applyFilterTo(image: postProcessingImage, filterEffect: Filter(filterName: "CIPhotoEffectFade", fliterEffectValue: nil, filterEffectValueName: nil))
            
            postProcessingImage = applyFilterTo(image: postProcessingImage, filterEffect: Filter(filterName: "CIVignette", fliterEffectValue: 0.5, filterEffectValueName: kCIInputIntensityKey))
            
            postProcessingImage = applyFilterTo(image: postProcessingImage, filterEffect: Filter(filterName: "CIPhotoEffectChrome", fliterEffectValue: nil, filterEffectValueName: nil))
            
            postProcessingImage = blendImage(image: postProcessingImage, overlayImage: lightLeakOverlayImage)
            
            postProcessingImage = blendBoarderImage(image: postProcessingImage, overlayImage: borderOverlayImage)
            
        } else if filterToProcess == "ColorNight" {
            
            postProcessingImage = postProcessingImage.scaled(to: CGSize(width: postProcessingImage.size.width, height: postProcessingImage.size.width))
            lightLeakOverlayImage = lightLeakOverlayImage.scaled(to: postProcessingImage.size)
            
            postProcessingImage = applyFilterTo(image: postProcessingImage, filterEffect: Filter(filterName: "CIPhotoEffectFade", fliterEffectValue: nil, filterEffectValueName: nil))
            
            postProcessingImage = applyFilterTo(image: postProcessingImage, filterEffect: Filter(filterName: "CIVignette", fliterEffectValue: 0.5, filterEffectValueName: kCIInputIntensityKey))
            
            postProcessingImage = applyFilterTo(image: postProcessingImage, filterEffect: Filter(filterName: "CIPhotoEffectChrome", fliterEffectValue: nil, filterEffectValueName: nil))
            
            postProcessingImage = blendImage(image: postProcessingImage, overlayImage: lightLeakOverlayImage)
            
            postProcessingImage = blendBoarderImage(image: postProcessingImage, overlayImage: borderOverlayImage)
            
        }
        
        UIImageWriteToSavedPhotosAlbum(postProcessingImage, print("postProcessingImage Saved"), nil, nil)
        
        
        // assigning / applying light leak overlay
        
        
        // assigning / applying film boarder overlay
        
        // save processed image
        
    }
    
    
    
    
    
    
    struct Filter {
        let filterName: String
        var filterEffectValue: Any?
        var filterEffectValueName: String?
        
        init(filterName: String, fliterEffectValue: Any?, filterEffectValueName: String? ){
            self.filterName = filterName
            self.filterEffectValue = fliterEffectValue
            self.filterEffectValueName = filterEffectValueName
        }
    }
    
    
    private func applyFilterTo(image: UIImage, filterEffect: Filter) -> UIImage? {
        
        guard let cgImage = image.cgImage, let openGLContext = EAGLContext(api: .openGLES3) else {
            return nil
        }
        
        let context = CIContext(eaglContext: openGLContext)
        
        let ciImage = CIImage(cgImage: cgImage)
        let filter = CIFilter(name: filterEffect.filterName)
        
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        
        if let filterEffectValue = filterEffect.filterEffectValue,
            let filterEffterValueName = filterEffect.filterEffectValueName {
            filter?.setValue(filterEffectValue, forKey: filterEffterValueName)
        }
        
        var filteredImage: UIImage?
        
        if let output = filter?.value(forKey: kCIOutputImageKey) as? CIImage,
            let cgiImageResult = context.createCGImage(output, from: output.extent){
            filteredImage = UIImage(cgImage: cgiImageResult)
        }
        return filteredImage
    }
    
    
    private func blendImage(image: UIImage, overlayImage: UIImage) -> UIImage? {
        
        
        guard let cgImage = image.cgImage, let openGLContext = EAGLContext(api: .openGLES3) else {
            return nil
        }
        
        let context = CIContext(eaglContext: openGLContext)
        
        
        let imageToProcess = CIImage(image: image)
        let overlayImageToProcess = CIImage(image: overlayImage)
        
        let imageBlend = CIFilter(name: "CIScreenBlendMode")
        
        imageBlend?.setValue(overlayImageToProcess, forKey: kCIInputImageKey)
        imageBlend?.setValue(imageToProcess, forKey: kCIInputBackgroundImageKey)
        
        var blendedImage: UIImage?
        
        if let output = imageBlend?.value(forKey: kCIOutputImageKey) as? CIImage,
            let cgiImageResult = context.createCGImage(output, from: output.extent){
            blendedImage = UIImage(cgImage: cgiImageResult)
        }
        
        return blendedImage
    }
    
    
    private func blendBoarderImage(image: UIImage, overlayImage: UIImage) -> UIImage? {
        
        
        guard let cgImage = image.cgImage, let openGLContext = EAGLContext(api: .openGLES3) else {
            return nil
        }
        
        let context = CIContext(eaglContext: openGLContext)
        
        
        let imageToProcess = CIImage(image: image)
        let overlayImageToProcess = CIImage(image: overlayImage)
        
        let imageBlend = CIFilter(name: "CISourceOverCompositing")
        
        imageBlend?.setValue(overlayImageToProcess, forKey: kCIInputImageKey)
        imageBlend?.setValue(imageToProcess, forKey: kCIInputBackgroundImageKey)
        
        var blendedImage: UIImage?
        
        if let output = imageBlend?.value(forKey: kCIOutputImageKey) as? CIImage,
            let cgiImageResult = context.createCGImage(output, from: output.extent){
            blendedImage = UIImage(cgImage: cgiImageResult)
        }
        
        return blendedImage
    }
    
    
    
    
    //MARK:  -- Resize Image / overlay image
        // Adaptive to all camera specs


    
    
    
} // end of viewcontroller class


extension ViewController: AVCapturePhotoCaptureDelegate{
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation(){
            print(imageData)
            image = UIImage(data: imageData)
//            performSegue(withIdentifier: "showPhoto_Segue", sender: nil)
            postProcessingImage = image
            cameraExposureAdjust(exposureBias: 0.0)
            postImageProcessingProcedure()
            
        }
    }
}

extension UIImage {
    
    /// Represents a scaling mode
    enum ScalingMode {
        case aspectFill
        case aspectFit
        
        /// Calculates the aspect ratio between two sizes
        ///
        /// - parameters:
        ///     - size:      the first size used to calculate the ratio
        ///     - otherSize: the second size used to calculate the ratio
        ///
        /// - return: the aspect ratio between the two sizes
        func aspectRatio(between size: CGSize, and otherSize: CGSize) -> CGFloat {
            let aspectWidth  = size.width/otherSize.width
            let aspectHeight = size.height/otherSize.height
            
            switch self {
            case .aspectFill:
                return max(aspectWidth, aspectHeight)
            case .aspectFit:
                return min(aspectWidth, aspectHeight)
            }
        }
    }
    
    /// Scales an image to fit within a bounds with a size governed by the passed size. Also keeps the aspect ratio.
    ///
    /// - parameter:
    ///     - newSize:     the size of the bounds the image must fit within.
    ///     - scalingMode: the desired scaling mode
    ///
    /// - returns: a new scaled image.
    func scaled(to newSize: CGSize, scalingMode: UIImage.ScalingMode = .aspectFill) -> UIImage {
        
        let aspectRatio = scalingMode.aspectRatio(between: newSize, and: size)
        
        /* Build the rectangle representing the area to be drawn */
        var scaledImageRect = CGRect.zero
        
        scaledImageRect.size.width  = size.width * aspectRatio
        scaledImageRect.size.height = size.height * aspectRatio
        scaledImageRect.origin.x    = (newSize.width - size.width * aspectRatio) / 2.0
        scaledImageRect.origin.y    = (newSize.height - size.height * aspectRatio) / 2.0
        
        /* Draw and retrieve the scaled image */
        UIGraphicsBeginImageContext(newSize)
        
        draw(in: scaledImageRect)
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return scaledImage!
    }
}
