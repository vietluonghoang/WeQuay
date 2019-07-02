//
//  ViewController.swift
//  NightOwlCam
//
//  Created by VietLH on 6/24/19.
//  Copyright © 2019 VietLH. All rights reserved.
//
// video location "file:///private/var/mobile/Containers/Data/Application/0EB047F7-CB9D-4F28-B36F-7AA3FEDD288A/tmp/output.mov"

import UIKit
import AVFoundation
import AVKit
import Photos

class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate, AVAudioRecorderDelegate, UIScrollViewDelegate {
    
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet var viewCover: UIView!
    @IBOutlet var imgCenterLogo: UIImageView!
    @IBOutlet var swtSplit: UISwitch!
    @IBOutlet var imgIndicator: UIImageView!
    
    @IBOutlet var scvTutorial: UIScrollView!
    @IBOutlet var btnTutorial: UIButton!
    @IBOutlet var viewTutorial: UIView!
    @IBOutlet var btnGotit: UIButton!
    
    let captureSession = AVCaptureSession()
    var backCamera: AVCaptureDevice?
    var frontCamera: AVCaptureDevice?
    var currentDevice: AVCaptureDevice?
    var videoFileOutput:AVCaptureMovieFileOutput?
    var cameraPreviewLayer:AVCaptureVideoPreviewLayer?
    var captureAudioDevice :AVCaptureDevice?
    
    var isReadyToRecord = false
    var isRecording = false
    var wasInterruptedByPuttingToBackground = false
    var toggleCameraGestureRecognizer = UISwipeGestureRecognizer()
    
    var zoomInGestureRecognizer = UISwipeGestureRecognizer()
    var zoomOutGestureRecognizer = UISwipeGestureRecognizer()
    var scaleUpIndicatorGestureRecognizer = UISwipeGestureRecognizer()
    var scaleDownIndicatorGestureRecognizer = UISwipeGestureRecognizer()
    var enableIndicatorScalingGestureRecognizer = UITapGestureRecognizer()
    
    
    var tapGestureRecognizer = UITapGestureRecognizer()
    var doubleTapGestureRecognizer = UITapGestureRecognizer()
    var tapLogoGestureRecognizer = UITapGestureRecognizer()
    var requiredTick = 5
    var requiredTickLimit = 5
    var tick = 5
    var tickLimit = 5
    var aboutToStop = false
    var videoLength = 90
    var videoSaveTimer = Timer()
    var videoFileURL: URL?
    let fileA = "outputA.mov"
    let fileB = "outputB.mov"
    var isEnableSplitVideo = false
    var indicatorScalingRatio = 1.0
    var isIndicatorScalingEnable = false
    
    var settings = [String:String]()
    let indicatorScalingRatioKey = "indicatorScalingRatio"
    let enableSplitVideoKey = "splitVideo"
    
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        RunLoop.current.run(until: Date(timeIntervalSinceNow : 2.0))
        super.viewDidLoad()
        setupCaptureSession()
        setupDevice()
        setupInputOutput()
        setupPreviewLayer()
        startRunningCaptureSession()
        
        toggleCameraGestureRecognizer.direction = .up
        toggleCameraGestureRecognizer.addTarget(self, action: #selector(self.switchCamera))
        view.addGestureRecognizer(toggleCameraGestureRecognizer)
        
        // Zoom In recognizer
        zoomInGestureRecognizer.direction = .right
        zoomInGestureRecognizer.addTarget(self, action: #selector(zoomIn))
        view.addGestureRecognizer(zoomInGestureRecognizer)
        
        // Zoom Out recognizer
        zoomOutGestureRecognizer.direction = .left
        zoomOutGestureRecognizer.addTarget(self, action: #selector(zoomOut))
        view.addGestureRecognizer(zoomOutGestureRecognizer)
        
        scaleUpIndicatorGestureRecognizer.direction = .left
        scaleUpIndicatorGestureRecognizer.addTarget(self, action: #selector(scaleUpIndicator))
        viewCover.addGestureRecognizer(scaleUpIndicatorGestureRecognizer)
        
        scaleDownIndicatorGestureRecognizer.direction = .right
        scaleDownIndicatorGestureRecognizer.addTarget(self, action: #selector(scaleDownIndicator))
        viewCover.addGestureRecognizer(scaleDownIndicatorGestureRecognizer)
        
        tapGestureRecognizer.addTarget(self, action: #selector(tapCount))
        viewCover.addGestureRecognizer(tapGestureRecognizer)
        
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        doubleTapGestureRecognizer.numberOfTouchesRequired = 1
        doubleTapGestureRecognizer.addTarget(self, action: #selector(triggerStopRecord))
        viewCover.addGestureRecognizer(doubleTapGestureRecognizer)
        
        enableIndicatorScalingGestureRecognizer.numberOfTapsRequired = 3
        enableIndicatorScalingGestureRecognizer.numberOfTouchesRequired = 2
        enableIndicatorScalingGestureRecognizer.addTarget(self, action: #selector(enableIndicatorScaling))
        viewCover.addGestureRecognizer(enableIndicatorScalingGestureRecognizer)
        
        tapLogoGestureRecognizer.addTarget(self, action: #selector(countLogoTap))
        imgCenterLogo.addGestureRecognizer(tapLogoGestureRecognizer)
        
        enableCover(now: false)
        
        UIView.animate(withDuration: 0.5, delay: 0.0, options: [.repeat, .autoreverse, .allowUserInteraction], animations: { () -> Void in
            self.btnTutorial.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }, completion: nil)
        scvTutorial.delegate = self
        
        readingAppSettings()
        NotificationCenter.default.addObserver(self, selector: #selector(saveDataBeforeQuit), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resumeAppProgress), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkAuthorizationForAccessingMedia()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scvTutorial.contentOffset.x != 0 {
            scvTutorial.contentOffset.x = 0
        }
    }
    
    func setupCaptureSession() {
        captureSession.sessionPreset = AVCaptureSession.Preset.high
    }
    
    func setupDevice() {
        if #available(iOS 10.0, *) {
            let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera, AVCaptureDevice.DeviceType.builtInMicrophone], mediaType: nil, position: AVCaptureDevice.Position.unspecified)
            
            let devices = deviceDiscoverySession.devices
            
            for device in devices {
                if (device.hasMediaType(AVMediaType.video)) {
                    if device.position == AVCaptureDevice.Position.back {
                        backCamera = device
                    } else if device.position == AVCaptureDevice.Position.front {
                        frontCamera = device
                    }
                }
                if(device.hasMediaType(AVMediaType.audio)){
                    captureAudioDevice = device //initialize audio
                }
            }
            currentDevice = backCamera
        } else {
            // Fallback on earlier versions
        }
    }
    
    func setupInputOutput() {
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: currentDevice!)
            let captureAudioInput = try AVCaptureDeviceInput(device: captureAudioDevice!)
            captureSession.addInput(captureDeviceInput)
            captureSession.addInput(captureAudioInput)
            videoFileOutput = AVCaptureMovieFileOutput()
            captureSession.addOutput(videoFileOutput!)
        } catch {
            print(error)
        }
    }
    
    func setupPreviewLayer() {
        cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        cameraPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        cameraPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        cameraPreviewLayer?.frame = self.view.frame
        self.view.layer.insertSublayer(cameraPreviewLayer!, at: 0)
    }
    
    func startRunningCaptureSession() {
        captureSession.startRunning()
    }
    // MARK: - Action methods
    
    @IBAction func unwindToCamera(segue:UIStoryboardSegue) {
        
    }
    
    @IBAction func capture(sender: UIButton) {
        // We have to call the check again here to solve the problem of having permission grant at the first launch but the checkpoint does not get updated. The reason could be an async method called on viewDidAppear
        checkAuthorizationForAccessingMedia()
        if isReadyToRecord {
            if !self.isRecording {
                self.isRecording = true
            } else {
                self.isRecording = false
            }
            self.changeRecordState()
        }else{
            openAppSettings()
        }
        
    }
    
    @IBAction func btnGotitAct(_ sender: Any) {
        viewTutorial.isHidden = true
    }
    
    @IBAction func btnTutorialAct(_ sender: Any) {
        if viewTutorial.isHidden {
            viewTutorial.isHidden = false
        }else{
            viewTutorial.isHidden = true
        }
    }
    
    @IBAction func swtChangeAct(_ sender: Any) {
        if swtSplit.isOn {
            isEnableSplitVideo = true
            settings[enableSplitVideoKey] = "1"
        }else{
            isEnableSplitVideo = false
            settings[enableSplitVideoKey] = "0"
        }
    }
    
    func changeRecordState() {
        if isRecording {
            
            // Offset the button to center of the screen.
            imgCenterLogo.center.x = viewCover.bounds.width / 2
            imgCenterLogo.center.y = viewCover.bounds.height / 2
            
            UIView.animate(withDuration: 0.5, delay: 0.0, options: [.repeat, .autoreverse, .allowUserInteraction], animations: { () -> Void in
                self.recordButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            }, completion: nil)
            let outputPath = NSTemporaryDirectory() + fileA
            videoFileURL = URL(fileURLWithPath: outputPath)
            videoFileOutput?.startRecording(to: videoFileURL!, recordingDelegate: self)
            videoSaveTimer = Timer.scheduledTimer(timeInterval: TimeInterval(videoLength), target: self, selector: #selector(saveVideo), userInfo: nil, repeats: true)
            enableCover(now: true)
        } else {
            videoSaveTimer.invalidate()
            UIView.animate(withDuration: 0.5, delay: 1.0, options: [], animations: { () -> Void in
                self.recordButton.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            }, completion: nil)
            recordButton.layer.removeAllAnimations()
            imgCenterLogo.layer.removeAllAnimations()
            imgIndicator.layer.removeAllAnimations()
            videoFileOutput?.stopRecording()
            enableCover(now: false)
            writingAppSettings()
        }
    }
    
    // MARK: - AVCaptureFileOutputRecordingDelegate methods
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error != nil {
            if wasInterruptedByPuttingToBackground {
                wasInterruptedByPuttingToBackground = false
                print("recording video")
                UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.relativePath, self, nil, nil)
            }
            print(error!.localizedDescription + "\nvideoFile: \(outputFileURL.lastPathComponent)")
            return
        }
        print("recording video")
        UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.relativePath, self, nil, nil)
        if isRecording{
            switchOutput()
        }
    }
    
    @objc func switchCamera() {
        if !isRecording {
            captureSession.beginConfiguration()
            
            // Change the device based on the current camera
            let newDevice = (currentDevice?.position == AVCaptureDevice.Position.back) ? frontCamera : backCamera
            
            // Remove all inputs from the session
            for input in captureSession.inputs {
                captureSession.removeInput(input as! AVCaptureDeviceInput)
            }
            
            // Change to the new input
            let cameraInput:AVCaptureDeviceInput
            let captureAudioInput: AVCaptureDeviceInput
            do {
                cameraInput = try AVCaptureDeviceInput(device: newDevice!)
                captureAudioInput = try AVCaptureDeviceInput(device: captureAudioDevice!)
            } catch {
                print(error)
                return
            }
            
            if captureSession.canAddInput(cameraInput) {
                captureSession.addInput(cameraInput)
            }
            if captureSession.canAddInput(captureAudioInput) {
                captureSession.addInput(captureAudioInput)
            }
            currentDevice = newDevice
            captureSession.commitConfiguration()
        }
        
    }
    
    @objc func zoomIn() {
        if let zoomFactor = currentDevice?.videoZoomFactor {
            if zoomFactor < 5.0 {
                let newZoomFactor = min(zoomFactor + 1.0, 5.0)
                do {
                    try currentDevice?.lockForConfiguration()
                    currentDevice?.ramp(toVideoZoomFactor: newZoomFactor, withRate: 1.0)
                    currentDevice?.unlockForConfiguration()
                } catch {
                    print(error)
                }
            }
        }
    }
    
    @objc func zoomOut() {
        if let zoomFactor = currentDevice?.videoZoomFactor {
            if zoomFactor > 1.0 {
                let newZoomFactor = max(zoomFactor - 1.0, 1.0)
                do {
                    try currentDevice?.lockForConfiguration()
                    currentDevice?.ramp(toVideoZoomFactor: newZoomFactor, withRate: 1.0)
                    currentDevice?.unlockForConfiguration()
                } catch {
                    print(error)
                }
            }
        }
    }
    
    @objc func scaleUpIndicator(){
        if isIndicatorScalingEnable{
            if indicatorScalingRatio < 1 {
                indicatorScalingRatio *= 2
                if indicatorScalingRatio > 1 {
                    indicatorScalingRatio = 1
                }
            }
            scaleIndicator()
        }
    }
    
    @objc func scaleDownIndicator(){
        if isIndicatorScalingEnable{
            if indicatorScalingRatio > 0.1 {
                indicatorScalingRatio *= 0.5
                if indicatorScalingRatio < 0.1 {
                    indicatorScalingRatio = 0.1
                }
            }
            scaleIndicator()
        }
    }
    
    @objc func finish() {
    }
    
    func enableCover(now: Bool) {
        if now {
            recordButton.isHidden = true
            imgCenterLogo.isHidden = false
            imgIndicator.isHidden = true
            viewCover.alpha = 1
            UIApplication.shared.isIdleTimerDisabled = true
            
            imgCenterLogo.isUserInteractionEnabled = false
            viewCover.isUserInteractionEnabled = false
            UIView.animate(withDuration: 0.5, delay: 0.0, options: [.repeat, .autoreverse, .allowUserInteraction], animations: { () -> Void in
                self.imgCenterLogo.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            }, completion: nil)
            Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(hideCenterLogo), userInfo: nil, repeats: false)
        } else {
            recordButton.isHidden = false
            imgCenterLogo.isHidden = true
            viewCover.alpha = 0
            UIApplication.shared.isIdleTimerDisabled = false
            UIView.animate(withDuration: 0.5, delay: 1.0, options: [], animations: { () -> Void in
                self.imgCenterLogo.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            }, completion: nil)
        }
    }
    
    @objc func triggerStopRecord(){
        if !aboutToStop {
            aboutToStop = true
            Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(rejectTriggerStopRecord), userInfo: nil, repeats: false)
            tick = requiredTick
            tickLimit = requiredTickLimit
            UIView.animate(withDuration: 0.5, delay: 0.0, options: [.repeat, .autoreverse, .allowUserInteraction], animations: { () -> Void in
                self.imgCenterLogo.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            }, completion: nil)
            imgCenterLogo.isHidden = false
            imgCenterLogo.isUserInteractionEnabled = true
        }
    }
    
    func showCenterLogoRandomly() {
        let buttonWidth = imgCenterLogo.frame.width
        let buttonHeight = imgCenterLogo.frame.height
        
        // Find the width and height of the enclosing view
        let viewWidth = viewCover.bounds.width
        let viewHeight = viewCover.bounds.height
        
        // Compute width and height of the area to contain the button's center
        let xwidth = viewWidth - buttonWidth
        let yheight = viewHeight - buttonHeight
        
        // Generate a random x and y offset
        let xoffset = CGFloat(arc4random_uniform(UInt32(xwidth)))
        let yoffset = CGFloat(arc4random_uniform(UInt32(yheight)))
        
        // Offset the button's center by the random offsets.
        imgCenterLogo.center.x = xoffset + buttonWidth / 2
        imgCenterLogo.center.y = yoffset + buttonHeight / 2
    }
    
    @objc func hideCenterLogo() {
        imgCenterLogo.isHidden = true
        imgCenterLogo.isUserInteractionEnabled = false
        viewCover.isUserInteractionEnabled = true
        scaleIndicator()
        imgIndicator.isHidden = false
        imgCenterLogo.transform = CGAffineTransform.identity
        rotateView(targetView: imgIndicator, duration: 0.5)
    }
    
    @objc func countLogoTap(){
        if aboutToStop {
            tick -= 1
            validateTriggerStop()
        }
        
    }
    @objc func tapCount(){
        if aboutToStop {
            tickLimit -= 1
            validateTriggerStop()
        }
        
    }
    
    @objc func rejectTriggerStopRecord(){
        tick = requiredTick
        tickLimit = requiredTickLimit
        aboutToStop = false
        imgCenterLogo.isHidden = true
        imgCenterLogo.isUserInteractionEnabled = false
        viewCover.isUserInteractionEnabled = false
        Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(hideCenterLogo), userInfo: nil, repeats: false)
    }
    
    func validateTriggerStop() {
        if tick == 0 {
            isRecording = false
            changeRecordState()
            enableCover(now: false)
        } else if tickLimit > 0 && tick > 0 {
            showCenterLogoRandomly()
        } else {
            rejectTriggerStopRecord()
        }
    }
    
    @objc func saveVideo() {
        if isEnableSplitVideo && isRecording {
            videoFileOutput?.stopRecording()
        }else{
            videoSaveTimer.invalidate()
        }
    }
    
    func switchOutput() {
        if isEnableSplitVideo{
            let theFileName = videoFileURL!.lastPathComponent
            if theFileName ==  fileA{
                videoFileURL = URL(fileURLWithPath: NSTemporaryDirectory() + fileB)
            } else {
                videoFileURL = URL(fileURLWithPath: NSTemporaryDirectory() + fileA)
            }
            videoFileOutput?.startRecording(to: videoFileURL!, recordingDelegate: self)
        }
    }
    
    func checkAuthorizationForAccessingMedia() {
        // handler in .requestAccess is needed to process user's answer to our request
        var videoCheckpoint = false
        var audioCheckpoint = false
        var photosCheckpoint = false
        var isAlertShowing = false
        
        
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("======== Checking camera")
        if cameraStatus == .notDetermined {
            print("+++++======== Not decide yet")
            AVCaptureDevice.requestAccess(for: .video) { success in
                if success { // if request is granted (success is true)
                    print("+++++======== Accept")
                    videoCheckpoint = true
                } else { // if request is denied (success is false)
                    print("+++++======== Deny")
                }
            }
        }else{
            print("+++++======== Already decided")
            if cameraStatus == .authorized {
                print("+++++======== Accept")
                videoCheckpoint = true
            }else {
                if !isAlertShowing {
                    isAlertShowing = true
                    openAppSettings()
                }
            }
        }
        print("======== Checking audio")
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if audioStatus == .notDetermined {
            print("+++++======== Not decide yet")
            AVCaptureDevice.requestAccess(for: .audio) { success in
                if success { // if request is granted (success is true)
                    print("+++++======== Accept")
                    audioCheckpoint = true
                } else { // if request is denied (success is false)
                    print("+++++======== Deny")
                }
            }
        } else {
            print("+++++======== Already decided")
            if audioStatus == .authorized {
                print("+++++======== Accept")
                audioCheckpoint = true
            }else{
                if !isAlertShowing {
                    isAlertShowing = true
                    openAppSettings()
                }
            }
        }
        
        //check access to Photos
        print("======== Checking photos")
        let photosStatus = PHPhotoLibrary.authorizationStatus()
        if photosStatus == .notDetermined {
            print("+++++======== Not decide yet")
            PHPhotoLibrary.requestAuthorization({status in
                if status == .authorized{
                    print("+++++======== Accept")
                    photosCheckpoint = true
                } else {
                    print("+++++======== Deny")
                }
            })
        } else {
            print("+++++======== Already decided")
            if (photosStatus == PHAuthorizationStatus.authorized) {
                // Access has been granted.
                print("+++++======== Accept")
                photosCheckpoint = true
            } else if (photosStatus == PHAuthorizationStatus.denied) {
                // Access has been denied.
                if !isAlertShowing {
                    isAlertShowing = true
                    openAppSettings()
                }
            }
        }
        
        validateRecordReadyState(audioCheckpoint: audioCheckpoint, photosCheckpoint: photosCheckpoint, videoCheckpoint: videoCheckpoint)
    }
    
    func validateRecordReadyState(audioCheckpoint: Bool, photosCheckpoint: Bool, videoCheckpoint:Bool) {
        if(audioCheckpoint && photosCheckpoint && videoCheckpoint){
            isReadyToRecord = true
        }
        print("=============== isReadyToRecord? \(isReadyToRecord)")
    }
    
    func openAppSettings() {
        let alert = UIAlertController(title: "Alert", message: "Please authorize access to Camera, Microphone and Photos before recording video.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Go to Settings", style: .default, handler: { action in
            let settingsUrl = URL(string:UIApplication.openSettingsURLString)
            if let url = settingsUrl {
                if UIApplication.shared.canOpenURL(url) {
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    } else {
                        UIApplication.shared.openURL(url)
                    }
                }
            }
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    func scaleIndicator() {
        settings[indicatorScalingRatioKey] = String(indicatorScalingRatio)
        imgIndicator.transform = CGAffineTransform(scaleX: CGFloat(indicatorScalingRatio), y: CGFloat(indicatorScalingRatio))
    }
    
    private func rotateView(targetView: UIView, duration: Double = 1.0) {
        UIView.animate(withDuration: duration, delay: 0.0, options: .curveLinear, animations: {
            targetView.transform = targetView.transform.rotated(by: CGFloat.pi)
        }) { finished in
            self.rotateView(targetView: targetView, duration: duration)
        }
    }
    
    @objc func enableIndicatorScaling() {
        if !isIndicatorScalingEnable {
            isIndicatorScalingEnable = true
            Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(disableIndicatorScaling), userInfo: nil, repeats: false)
        }
    }
    
    @objc func disableIndicatorScaling() {
        if isIndicatorScalingEnable {
            isIndicatorScalingEnable = false
        }
    }
    
    func readingAppSettings() {
        let fileName = "settings.txt"
        let filePath = NSTemporaryDirectory() + fileName
        let fileURL = URL(fileURLWithPath: filePath)
        var settingContent = ""
        let fileMan = FileManager.default
        if fileMan.fileExists(atPath: filePath ) {
            do{
                settingContent = try String(contentsOf: fileURL)
            }catch{
                print(error)
            }
        }
        for setting in settingContent.split(separator: "\n") {
            let key = String(setting.split(separator: ":")[0])
            let value = String(setting.split(separator: ":")[1])
            settings[key] = value
        }
        
        if settings[indicatorScalingRatioKey] != nil {
            indicatorScalingRatio = Double(settings[indicatorScalingRatioKey]!)!
        }else{
            indicatorScalingRatio = 1.0
        }
        if settings[enableSplitVideoKey] != nil {
            if settings[enableSplitVideoKey] == "1"{
                isEnableSplitVideo = true
            }else{
                isEnableSplitVideo = false
            }
        }else{
            isEnableSplitVideo = false
        }
    }
    
    func writingAppSettings() {
        let fileName = "settings.txt"
        let filePath = NSTemporaryDirectory() + fileName
        let fileURL = URL(fileURLWithPath: filePath)
        var settingContent = ""
        
        for key in settings.keys {
            let setting = key + ":" + settings[key]! + "\n"
            settingContent += setting
        }
        do{
            try settingContent.write(to: fileURL, atomically: false, encoding: String.Encoding.utf8)
        }catch{
            print(error)
        }
    }
    
    //set of actions that need to take before puting the app to background
    @objc func saveDataBeforeQuit(){
        if isRecording{
            UISaveVideoAtPathToSavedPhotosAlbum(videoFileURL!.relativePath, self, nil, nil)
            wasInterruptedByPuttingToBackground = true
            print("urgent saving")
        }
        writingAppSettings()
        isRecording = false
        changeRecordState()
        enableCover(now: false)
    }
    
    //set of behaviours that need to perform when resuming from background
    @objc func resumeAppProgress(){
        checkAuthorizationForAccessingMedia()
    }
}
