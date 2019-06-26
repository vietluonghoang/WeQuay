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

class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate, AVAudioRecorderDelegate, UIScrollViewDelegate {
    
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet var viewCover: UIView!
    @IBOutlet var imgCenterLogo: UIImageView!
    @IBOutlet var swtSplit: UISwitch!
    
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
    
    var isRecording = false
    var toggleCameraGestureRecognizer = UISwipeGestureRecognizer()
    
    var zoomInGestureRecognizer = UISwipeGestureRecognizer()
    var zoomOutGestureRecognizer = UISwipeGestureRecognizer()
    
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
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        RunLoop.current.run(until: Date(timeIntervalSinceNow : 2.0))
        super.viewDidLoad()
        setupCaptureSession()
        setupDevice()
//        setupInputOutput()
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
        
        tapGestureRecognizer.addTarget(self, action: #selector(tapCount))
        viewCover.addGestureRecognizer(tapGestureRecognizer)
        
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        doubleTapGestureRecognizer.numberOfTouchesRequired = 1
        doubleTapGestureRecognizer.addTarget(self, action: #selector(triggerStopRecord))
        viewCover.addGestureRecognizer(doubleTapGestureRecognizer)
        
        tapLogoGestureRecognizer.addTarget(self, action: #selector(countLogoTap))
        imgCenterLogo.addGestureRecognizer(tapLogoGestureRecognizer)
        
        enableCover(now: false)
        
        UIView.animate(withDuration: 0.5, delay: 0.0, options: [.repeat, .autoreverse, .allowUserInteraction], animations: { () -> Void in
            self.btnTutorial.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }, completion: nil)
        scvTutorial.delegate = self
        //        var files = [String]()
        //        do{
        //            files = try FileManager.default.contentsOfDirectory(atPath: NSTemporaryDirectory())
        //        } catch {
        //            print(error)
        //            return
        //        }
        
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
                    print("Capture device audio init")
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
        if !isRecording {
            isRecording = true
        } else {
            isRecording = false
        }
        changeRecordState()
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
        }else{
            isEnableSplitVideo = false
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
            videoFileOutput?.stopRecording()
            enableCover(now: false)
        }
    }
    
    // MARK: - AVCaptureFileOutputRecordingDelegate methods
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error != nil {
            print(error!)
            return
        }
        //        performSegue(withIdentifier: "playVideo", sender: outputFileURL)
        let videoFileURL = outputFileURL
        UISaveVideoAtPathToSavedPhotosAlbum(videoFileURL.relativePath, self, nil, nil)
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
            imgCenterLogo.isHidden = false
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
            imgCenterLogo.layer.removeAllAnimations()
        }
    }
    
    @objc func triggerStopRecord(){
        if !aboutToStop {
            aboutToStop = true
            Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(rejectTriggerStopRecord), userInfo: nil, repeats: false)
            tick = requiredTick
            tickLimit = requiredTickLimit
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "playVideo" {
            let videoPlayerViewController = segue.destination as! AVPlayerViewController
            let videoFileURL = sender as! URL
            videoPlayerViewController.player = AVPlayer(url: videoFileURL)
            UISaveVideoAtPathToSavedPhotosAlbum(videoFileURL.relativePath, self, nil, nil)
        }
    }
}
