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
    @IBOutlet var btnRecordingIndicator: UIButton!
    @IBOutlet var lblVersionInfo: UILabel!
    
    @IBOutlet var scvTutorial: UIScrollView!
    @IBOutlet var btnTutorial: UIButton!
    @IBOutlet var viewTutorial: UIView!
    @IBOutlet var btnGotit: UIButton!
    @IBOutlet var lblRecording: UILabel!
    
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
    var darkenRecordingScreenGestureRecognizer = UITapGestureRecognizer()
    var enableDarkenRecordingScreenGestureRecognizer = UITapGestureRecognizer()
    
    
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
    var defaultCoverViewAlphaRatio = 0.8
    var coverViewAlphaRatio = 0.8
    var isCoveringRecordingScreenEnable = false
    
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
        
        darkenRecordingScreenGestureRecognizer.numberOfTapsRequired = 5
        darkenRecordingScreenGestureRecognizer.numberOfTouchesRequired = 3
        darkenRecordingScreenGestureRecognizer.addTarget(self, action: #selector(coverRecordingScreenNow))
        view.addGestureRecognizer(darkenRecordingScreenGestureRecognizer)
        
        tapGestureRecognizer.addTarget(self, action: #selector(tapCount))
        viewCover.addGestureRecognizer(tapGestureRecognizer)
        
        doubleTapGestureRecognizer.numberOfTapsRequired = 3
        doubleTapGestureRecognizer.numberOfTouchesRequired = 2
        doubleTapGestureRecognizer.addTarget(self, action: #selector(triggerStopRecord))
        viewCover.addGestureRecognizer(doubleTapGestureRecognizer)
        
        enableDarkenRecordingScreenGestureRecognizer.numberOfTapsRequired = 5
        enableDarkenRecordingScreenGestureRecognizer.numberOfTouchesRequired = 4
        enableDarkenRecordingScreenGestureRecognizer.addTarget(self, action: #selector(enableIndicatorScaling))
        view.addGestureRecognizer(enableDarkenRecordingScreenGestureRecognizer)
        
        tapLogoGestureRecognizer.addTarget(self, action: #selector(countLogoTap))
        imgCenterLogo.addGestureRecognizer(tapLogoGestureRecognizer)
        
        enableCover(now: false)

        addBlinkingEffectTo(view: self.btnTutorial)
        scvTutorial.delegate = self
        
        readingAppSettings()
        NotificationCenter.default.addObserver(self, selector: #selector(saveDataBeforeQuit), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resumeAppProgress), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        lblVersionInfo.text = getVersion()
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
            
            addBlinkingEffectTo(view: self.btnRecordingIndicator)
            let outputPath = NSTemporaryDirectory() + fileA
            videoFileURL = URL(fileURLWithPath: outputPath)
            videoFileOutput?.startRecording(to: videoFileURL!, recordingDelegate: self)
            videoSaveTimer = Timer.scheduledTimer(timeInterval: TimeInterval(videoLength), target: self, selector: #selector(saveVideo), userInfo: nil, repeats: true)
            enableCover(now: true)
        } else {
            videoSaveTimer.invalidate()
            removeBlinkingEffectFrom(view: self.btnRecordingIndicator)
            recordButton.layer.removeAllAnimations()
            btnRecordingIndicator.layer.removeAllAnimations()
            imgCenterLogo.layer.removeAllAnimations()
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
    
    @objc func finish() {
    }
    
    func enableCover(now: Bool) {
        if now {
            recordButton.isHidden = true
            viewCover.alpha = CGFloat(coverViewAlphaRatio)
            if coverViewAlphaRatio == 1 {
                btnRecordingIndicator.alpha = 0
            }else {
                btnRecordingIndicator.alpha = 1
            }
            UIApplication.shared.isIdleTimerDisabled = true //never sleep device when recording
        } else {
            recordButton.isHidden = false
            viewCover.alpha = 0
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    @objc func triggerStopRecord(){
        if !aboutToStop {
            aboutToStop = true
            Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(rejectTriggerStopRecord), userInfo: nil, repeats: false)
            tick = requiredTick
            tickLimit = requiredTickLimit
            addBlinkingEffectTo(view: self.imgCenterLogo)
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
        imgCenterLogo.transform = CGAffineTransform.identity
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
        hideCenterLogo()
//        Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(hideCenterLogo), userInfo: nil, repeats: false)
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
        if cameraStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { success in
                if success { // if request is granted (success is true)
                    videoCheckpoint = true
                } else { // if request is denied (success is false)
                }
            }
        }else{
            if cameraStatus == .authorized {
                videoCheckpoint = true
            }else {
                if !isAlertShowing {
                    isAlertShowing = true
                    openAppSettings()
                }
            }
        }
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if audioStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { success in
                if success { // if request is granted (success is true)
                    audioCheckpoint = true
                } else { // if request is denied (success is false)
                }
            }
        } else {
            if audioStatus == .authorized {
                audioCheckpoint = true
            }else{
                if !isAlertShowing {
                    isAlertShowing = true
                    openAppSettings()
                }
            }
        }
        
        //check access to Photos
        let photosStatus = PHPhotoLibrary.authorizationStatus()
        if photosStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization({status in
                if status == .authorized{
                    photosCheckpoint = true
                } else {
                }
            })
        } else {
            if (photosStatus == PHAuthorizationStatus.authorized) {
                // Access has been granted.
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
    
    @objc func enableIndicatorScaling() {
        if !isCoveringRecordingScreenEnable {
            isCoveringRecordingScreenEnable = true
            Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(disableIndicatorScaling), userInfo: nil, repeats: false)
        }
    }
    
    @objc func disableIndicatorScaling() {
        if isCoveringRecordingScreenEnable {
            isCoveringRecordingScreenEnable = false
        }
    }
    
    @objc func coverRecordingScreenNow(){
        if isCoveringRecordingScreenEnable {
            if coverViewAlphaRatio == 1.0 {
                coverViewAlphaRatio = defaultCoverViewAlphaRatio
            } else {
                coverViewAlphaRatio = 1.0
            }
        }
    }
    
    func addBlinkingEffectTo(view: UIView) {
        UIView.animate(withDuration: 0.5, delay: 0.0, options: [.repeat, .autoreverse, .allowUserInteraction], animations: { () -> Void in
            view.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }, completion: nil)
    }
    
    func removeBlinkingEffectFrom(view: UIView) {
        UIView.animate(withDuration: 0.5, delay: 1.0, options: [], animations: { () -> Void in
            view.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        }, completion: nil)
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
            coverViewAlphaRatio = Double(settings[indicatorScalingRatioKey]!)!
        }else{
            coverViewAlphaRatio = defaultCoverViewAlphaRatio
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
    
    func getVersion() -> String {
        let bundleCode: AnyObject? = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as AnyObject
        let bundleVersion: AnyObject? = Bundle.main.infoDictionary!["CFBundleVersion"] as AnyObject
        let versionInfo = "v.\(bundleCode as! String)(\(bundleVersion as! String))"
        //        print("=========== \(versionInfo)")
        return versionInfo
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
