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
import Vision
import CoreMotion

struct GlobalVariable {
    static var userImageStorageURLGlobal = [URL]()
    static var userImageThumbnailStorageURLsGlobal = [URL]()
}

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    //MARK:  -- Camera var
    let dataOutput = AVCaptureVideoDataOutput()
    var captureSession = AVCaptureSession()
    var backCamera: AVCaptureDevice?
    var frontCamera: AVCaptureDevice?
    var currentCamera: AVCaptureDevice?
    var photoOutput: AVCapturePhotoOutput?
    var cameraPreviewLayer: AVCaptureVideoPreviewLayer?
    @IBOutlet weak var previewView: UIView!
    
//    let motionManager = CMMotionManager()
    
    //MARK:  -- image var
    var image: UIImage?
    var cameraPositionIsBack = true
    
    //MARK:  -- fine tuning image exposure
    var faceDetected : Bool = false
    var isoValueAsShot: Float! {get{return currentCamera?.iso}}
    var shutterValueAsShot: CMTime! {get{return currentCamera?.exposureDuration}}
    var exposureIndexNumber: Float! {get{return Float(shutterValueAsShot.value/100000) * Float(isoValueAsShot) }}
    var cameraWBRedBlueIndex : Float {get{return currentCamera!.deviceWhiteBalanceGains.redGain - currentCamera!.deviceWhiteBalanceGains.blueGain}}
    
    //MARK:  -- Post image processing
    let ciContext = CIContext()
    var cameraPixelSpec : CGSize! {get{return image?.size}}
    var postProcessingImage : UIImage!
    var lightLeakOverlayImage : UIImage!
    var dirtOverlay : UIImage!
    var borderOverlayImage : UIImage!
    var filterToProcess : String = "B&W"
    
    //MARK: Saving Image
    public var userImageStorageURLs = [URL]()
    public var userImageThumbnailStorageURLs = [URL]()
    
    //MARK:  -- Camera Operations
    @IBOutlet weak var colorShutterButton: UIButton!
    @IBAction func colorShutterPressedTouchUpInside(_ sender: Any) {
        colorShutterButton.isEnabled = false
        cameraExposureAdjust(exposureBias: returnExposureIndex())
        let settings = AVCapturePhotoSettings()
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
    }
    @IBAction func blackWhiteShutterPressedTouchUpInside(_ sender: Any) {
        cameraExposureAdjust(exposureBias: returnExposureIndex())
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
    
    //MARK:  -- Go to and transfer data to GalleryVC
    @IBAction func galleryButtonPressed(_ sender: Any) {
        performSegue(withIdentifier: "showUserImageGallery_Segue", sender: nil)
        GlobalVariable.userImageStorageURLGlobal = userImageStorageURLs
    }
    @IBOutlet weak var testIndexShow: UILabel!
    @IBOutlet weak var testExpo: UILabel!
    @IBAction func TestButtonPressed(_ sender: Any) {
        

        
        print(returnExposureIndex())
        testExpo.text = String(exposureIndexNumber)
    }
    
    //MARK:  -- Methods
    override func viewDidAppear(_ animated: Bool) {
        startDetecting()
        captureSession.startRunning()
    }
    override func viewDidDisappear(_ animated: Bool) {
        stopDetecting()
        captureSession.stopRunning()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        setupDevice()
        setupInputOutput()
        setupPreviewLayer()
        captureSession.startRunning()
        
        // database storages set to global variebles here vvvvv
//        let dataOutput = AVCaptureVideoDataOutput()
//        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
//        captureSession.addOutput(dataOutput)
        
    }
    
//    func startDetectingDeviceAngle(){
//        if self.motionManager.isDeviceMotionAvailable {
//            self.motionManager.deviceMotionUpdateInterval = 0.1
//            self.motionManager.startDeviceMotionUpdates(to: OperationQueue()) { [weak self] (motion, error) -> Void in
//                if let attitude = motion?.attitude {
//
////                    print("yaw ->",attitude.yaw * 180 / Double.pi ," pitch ->", attitude.pitch * 180 / Double.pi, " roll ->", attitude.roll * 180 / Double.pi)
//                    print("yaw ->",attitude.yaw ," pitch ->", attitude.pitch , " roll ->", attitude.roll)
//                    DispatchQueue.main.async{
//                        // Update UI
//                    }
//                }
//            }
//            print("Device motion started")
//        }
//        else {
//            print("Device motion unavailable")
//        }
//    }
    
    func startDetecting(){
        self.dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        self.captureSession.addOutput(dataOutput)
        print("Start detecting")
    }
    
    func stopDetecting(){
        self.captureSession.removeOutput(dataOutput)
        print("face detect end")
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        var faceIsInImage : Bool = false
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectFaceRectanglesRequest { (req, err) in
            if let err = err{
                print("Failed to detect", err)
                return
            }
            req.results?.forEach({ (res) in
                faceIsInImage = true
                return
            })
        }
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
        self.faceDetected = faceIsInImage
    }
    
    
    //MARK: Setup UI
    
    
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
            if newDevice?.position == AVCaptureDevice.Position.front {
                cameraPositionIsBack = false
            } else {
                cameraPositionIsBack = true
            }
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
    
    func returnExposureIndex() -> Float {
        
        if self.faceDetected == true {
            
            // Mark: need to add six new filter
            // portraitDay - Blue Red Neutral
            // portraitNight - Blue Red Neutral
            
            
            if self.exposureIndexNumber < 500 {
                self.filterToProcess = "ColorDay"
                return -1.0
            } else if self.exposureIndexNumber < 1000 {
                self.filterToProcess = "ColorDay"
                return -0.8
            } else if self.exposureIndexNumber < 2000 {
                self.filterToProcess = "ColorDay"
                return -0.6
            } else if self.exposureIndexNumber < 3000 {
                self.filterToProcess = "ColorDay"
                return -0.4
            } else if self.exposureIndexNumber < 6000 {
                self.filterToProcess = "ColorDay"
                return -0.2
            } else if self.exposureIndexNumber < 12000 {
                self.filterToProcess = "ColorDay"
                return -0.1
            } else {
                self.filterToProcess = "ColorDay"
                return 0.0
            }
            
        } else {
            
            if self.exposureIndexNumber < 8000 {
                self.filterToProcess = "ColorDay"
                return -1.5
            } else {
                self.filterToProcess = "ColorDay"
                return -1.5
            }
        }
        
    }
    
    func determineLightLeakOverlay () -> UIImage! {
        if cameraWBRedBlueIndex <= -0.1 {
            // img environment red
            return UIImage(named: "LightLeakIMG\(Int.random(in: 1...25))")
        } else if cameraWBRedBlueIndex >= 0.5 {
            // img environment blue
            return UIImage(named: "LightLeakIMG\(Int.random(in: 1...25))")
        } else {
            // img environment netural
            return UIImage(named: "LightLeakIMG\(Int.random(in: 1...25))")
        }
    }

    
//MARK:  -- Post Image Production
    func postImageProcessingProcedure() {
        
       self.filterToProcess = "ColorDay"
        
        UIImageWriteToSavedPhotosAlbum(image!, nil, nil, nil)
        
        postProcessingImage = image
        
        if cameraPositionIsBack == false {
            postProcessingImage = postProcessingImage.resized(toWidth: 3024)         //BUG FIX for front cam white border
        }
        
        lightLeakOverlayImage = determineLightLeakOverlay()
        
        lightLeakOverlayImage = UIImage(cgImage: lightLeakOverlayImage.cgImage!, scale: lightLeakOverlayImage.scale, orientation: UIImage.Orientation(rawValue: Int.random(in: 0...7))! )
        
        dirtOverlay = UIImage(named: "Dirt\(Int.random(in: 1...9))")
        
        borderOverlayImage = UIImage(named: "InsBorder")
        
        if filterToProcess == "B&W" {
            
            postProcessingImage = cropImage(image: postProcessingImage, FactorToOne: 2)
//
//            postProcessingImage = postProcessingImage.scaled(to: CGSize(width: postProcessingImage.size.width, height: postProcessingImage.size.width))
            
            
            lightLeakOverlayImage = lightLeakOverlayImage.scaled(to: postProcessingImage.size)
            
            postProcessingImage = applyFilterTo(image: postProcessingImage, filterEffect: Filter(filterName: "CIVignette", fliterEffectValue: 0.5, filterEffectValueName: kCIInputIntensityKey))
            
            postProcessingImage = blendImage(image: postProcessingImage, overlayImage: lightLeakOverlayImage)
            
            postProcessingImage = blendBoarderImage(image: postProcessingImage, overlayImage: borderOverlayImage)
    
            postProcessingImage = applyFilterTo(image: postProcessingImage, filterEffect: Filter(filterName: "CIPhotoEffectNoir", fliterEffectValue: nil, filterEffectValueName: nil))
            
        } else if filterToProcess == "ColorDay"{
            
            postProcessingImage = postProcessingImage.scaled(to: CGSize(width: postProcessingImage.size.width, height: postProcessingImage.size.width))
            
            lightLeakOverlayImage = lightLeakOverlayImage.scaled(to: postProcessingImage.size)
            
            borderOverlayImage = borderOverlayImage.scaled(to: postProcessingImage.size)
            
            postProcessingImage = applyFilterTo(image: postProcessingImage, filterEffect: Filter(filterName: "CIVignette", fliterEffectValue: 0.5, filterEffectValueName: kCIInputIntensityKey))
            
            postProcessingImage = applyFilterTo(image: postProcessingImage, filterEffect: Filter(filterName: "CIPhotoEffectChrome", fliterEffectValue: nil, filterEffectValueName: nil))
            
            postProcessingImage = applyFilterTo(image: postProcessingImage, filterEffect: Filter(filterName: "CIPhotoEffectFade", fliterEffectValue: nil, filterEffectValueName: nil))
            
            print(postProcessingImage.size , "size before")
            
            postProcessingImage = applyFilterTo(image: postProcessingImage, filterEffect: Filter(filterName: "CIBloom", fliterEffectValue: 5.0, filterEffectValueName: kCIInputRadiusKey))
            
            print(postProcessingImage.size , "size after")
            
            postProcessingImage = postProcessingImage.scaled(to: CGSize(width: postProcessingImage.size.width - 72.0 , height: postProcessingImage.size.height - 72.0))
            
            print(postProcessingImage.size , "size trim")
            
            postProcessingImage = blendImage(image: postProcessingImage, overlayImage: lightLeakOverlayImage)
            
            postProcessingImage = blendBoarderImage(image: postProcessingImage, overlayImage: borderOverlayImage)
            
            
        } else if filterToProcess == "ColorNight" {
            
            print("colorNight")
            
            postProcessingImage = postProcessingImage.scaled(to: CGSize(width: postProcessingImage.size.width, height: postProcessingImage.size.width))
            
            lightLeakOverlayImage = lightLeakOverlayImage.scaled(to: postProcessingImage.size)
            
            postProcessingImage = applyFilterTo(image: postProcessingImage, filterEffect: Filter(filterName: "CIMedianFilter", fliterEffectValue: nil, filterEffectValueName: nil))
            
            postProcessingImage = applyFilterTo(image: postProcessingImage, filterEffect: Filter(filterName: "CIVignette", fliterEffectValue: 0.5, filterEffectValueName: kCIInputIntensityKey))
            
            postProcessingImage = applyFilterTo(image: postProcessingImage, filterEffect: Filter(filterName: "CIPhotoEffectChrome", fliterEffectValue: nil, filterEffectValueName: nil))
            
            postProcessingImage = applyFilterTo(image: postProcessingImage, filterEffect: Filter(filterName: "CIPhotoEffectFade", fliterEffectValue: nil, filterEffectValueName: nil))
            
            postProcessingImage = blendImage(image: postProcessingImage, overlayImage: lightLeakOverlayImage)
            
            postProcessingImage = blendBoarderImage(image: postProcessingImage, overlayImage: borderOverlayImage)
            
        }
        
        postProcessingImage = blendImage(image: postProcessingImage, overlayImage: dirtOverlay)
        
        // assigning / applying light leak overlay

        
        // assigning / applying film boarder overlay
        
        
        UIImageWriteToSavedPhotosAlbum(postProcessingImage, print("postProcessingImage Saved to ios gallery"), nil, nil)
        // save processed image
        saveImage(imageName: renameUserImage(), image: postProcessingImage, isThumbnail: false)
        
        var galleryThumbNailImage = UIImage()
        galleryThumbNailImage = postProcessingImage.resized(toWidth: 500)!
        saveImage(imageName: "\(renameUserImage())_Thumb", image: galleryThumbNailImage, isThumbnail: true)
        
        
        // store url datas to a data base !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        
        
        // assigning / applying light leak overlay
        
        
        // assigning / applying film boarder overlay
        
        // save processed image
        
    }
    
    //Test Code for folor polynomial
    func filterObject(imageToProcess: UIImage, isDay: Bool, environmentColor: String) -> UIImage {
        
        //if is day == false add more blue
        
        var image = imageToProcess
        image = applyFilterTo(image: image, filterEffect: Filter(filterName: "CIVignette", fliterEffectValue: 0.5, filterEffectValueName: kCIInputIntensityKey))!
        
        image = applyFilterTo(image: image, filterEffect: Filter(filterName: "CIPhotoEffectChrome", fliterEffectValue: nil, filterEffectValueName: nil))!
        
        image = applyFilterTo(image: image, filterEffect: Filter(filterName: "CIPhotoEffectFade", fliterEffectValue: nil, filterEffectValueName: nil))!
        
        return image
    }
    
    

    // MARK: image processing stuffs
    func cropImage(image:UIImage , FactorToOne: CGFloat) -> UIImage{
        var imageToProcess = image
        imageToProcess = image.scaled(to: CGSize(width:image.size.width, height:(image.size.width) * FactorToOne))
        return imageToProcess
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
        let ciImage = CIImage(image: image)
        let filter = CIFilter(name: filterEffect.filterName)
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        if let filterEffectValue = filterEffect.filterEffectValue,
            let filterEffterValueName = filterEffect.filterEffectValueName {
            filter?.setValue(filterEffectValue, forKey: filterEffterValueName)
        }
        var filteredImage: UIImage?
        if let output = filter?.value(forKey: kCIOutputImageKey) as? CIImage,
            let cgiImageResult = self.ciContext.createCGImage(output, from: output.extent){
            filteredImage = UIImage(cgImage: cgiImageResult)
        }
        return filteredImage
    }
    
    
    private func blendImage(image: UIImage, overlayImage: UIImage) -> UIImage? {
        
        let imageToProcess = CIImage(image: image)
        let overlayImageToProcess = CIImage(image: overlayImage)
        let imageBlend = CIFilter(name: "CIScreenBlendMode")
        imageBlend?.setValue(overlayImageToProcess, forKey: kCIInputImageKey)
        imageBlend?.setValue(imageToProcess, forKey: kCIInputBackgroundImageKey)
        var blendedImage: UIImage?
        if let output = imageBlend?.value(forKey: kCIOutputImageKey) as? CIImage,
            let cgiImageResult = self.ciContext.createCGImage(output, from: output.extent){
            blendedImage = UIImage(cgImage: cgiImageResult)
        }

        return blendedImage
    }
    
    
    private func blendBoarderImage(image: UIImage, overlayImage: UIImage) -> UIImage? {
        
        let imageToProcess = CIImage(image: image)
        let overlayImageToProcess = CIImage(image: overlayImage)
        let imageBlend = CIFilter(name: "CISourceOverCompositing")
        imageBlend?.setValue(overlayImageToProcess, forKey: kCIInputImageKey)
        imageBlend?.setValue(imageToProcess, forKey: kCIInputBackgroundImageKey)
        var blendedImage: UIImage?
        if let output = imageBlend?.value(forKey: kCIOutputImageKey) as? CIImage,
            let cgiImageResult = self.ciContext.createCGImage(output, from: output.extent){
            blendedImage = UIImage(cgImage: cgiImageResult)
        }
        return blendedImage
    }
    
    

    
    
    //MARK:  -- Resize Image / overlay image
        // Adaptive to all camera specs
    
    //MARK:  -- Rename images to uniform style
    private func renameUserImage() -> String {
        
        let currentDateTime = Date()
        let userCalendar = Calendar.current
        let requestedComponents: Set<Calendar.Component> = [
            .year,
            .month,
            .day,
            .hour,
            .minute,
            .second
        ]
        let dateTimeComponents = userCalendar.dateComponents(requestedComponents, from: currentDateTime)
        let timestampName = String("\(dateTimeComponents.year!)-\(dateTimeComponents.month!)-\(dateTimeComponents.day!)-\(dateTimeComponents.hour!):\(dateTimeComponents.minute!):\(dateTimeComponents.second!)")
        let caTimeRound = Int( (round( CACurrentMediaTime() / 0.0001 ) * 0.0001) * 1000 )
        let last4 = String(caTimeRound).suffix(4)
        let fileName = "\(timestampName)-\(last4)"
        print(fileName)
        return fileName
    }

    
    //MARK:  -- Saving Image Method
    func saveImage(imageName: String, image: UIImage, isThumbnail: Bool) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileName = imageName
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        guard let data = image.jpegData(compressionQuality: 1) else { return }
        //Checks if file exists, removes it if so.
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(atPath: fileURL.path)
                print("Removed old image")
            } catch let removeError {
                print("couldn't remove file at path", removeError)
            }
        }
        
        do {
            try data.write(to: fileURL)
            
            if isThumbnail == true{
            self.userImageThumbnailStorageURLs.append(fileURL)
            GlobalVariable.userImageThumbnailStorageURLsGlobal.append(fileURL)
            } else {
            self.userImageStorageURLs.append(fileURL)
            GlobalVariable.userImageStorageURLGlobal.append(fileURL)
            }
            
            print("file url is \(fileURL)")
        } catch let error {
            print("error saving file with error", error)
        }
        
    }
    //MARK: Not Sure I Need This One
    func loadImageFromDiskWith(fileName: String) -> UIImage? {
        let documentDirectory = FileManager.SearchPathDirectory.documentDirectory
        let userDomainMask = FileManager.SearchPathDomainMask.userDomainMask
        let paths = NSSearchPathForDirectoriesInDomains(documentDirectory, userDomainMask, true)
        if let dirPath = paths.first {
            let imageUrl = URL(fileURLWithPath: dirPath).appendingPathComponent(fileName)
            let image = UIImage(contentsOfFile: imageUrl.path)
            return image
        }
        return nil
    }
    

    
} // end of viewcontroller class


extension ViewController: AVCapturePhotoCaptureDelegate{
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        colorShutterButton.isEnabled = true
        if let imageData = photo.fileDataRepresentation(){
            image = UIImage(data: imageData)
            postProcessingImage = image
            cameraExposureAdjust(exposureBias: 0.0)
            faceDetected = false
            postImageProcessingProcedure()
        }
    }
}

//MARK: -- for Corping Images

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

extension UIImage {
    func resized(withPercentage percentage: CGFloat) -> UIImage? {
        let canvasSize = CGSize(width: size.width * percentage, height: size.height * percentage)
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    func resized(toWidth width: CGFloat) -> UIImage? {
        let canvasSize = CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    func resized(toWidthAndHeight width: CGFloat, height: CGFloat) -> UIImage? {
        let canvasSize = CGSize(width: width, height: height)
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    func rotate(radians: Float) -> UIImage? {
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!
        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
}











