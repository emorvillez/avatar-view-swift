// MIT License
//
// Copyright (c) 2017 Erwan Morvillez
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit
import AVFoundation

protocol AvatarViewDelegate {
    func onAvatarViewResponse(avatarView:AvatarView, image:UIImage?)
}

@IBDesignable class AvatarView: UIView, AVCapturePhotoCaptureDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBInspectable var image: UIImage? {
        didSet {
            if let image = image {
                button.setImage(image, for: .normal)
            }
        }
    }
    
    /** delegate the protocol FrontCamAvatarDelegate */
    var delegate:AvatarViewDelegate?
    
    /** save choosen photo */
    var photo: UIImage?

    @IBOutlet var button: UIButton!
    @IBOutlet var label: UILabel!
    
    private var counter = 0 {
        didSet {
            label.text = String(counter)
        }
    }
    
    private let session = AVCaptureSession()
    private let cameraOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var imageOrientation: UIImageOrientation = .leftMirrored
    private var timer: Timer?
    private var delay: Int = 3
    
    func nibSetup() {
        let view = loadViewFromNib()
        view.frame = bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(view)
        
        button.imageView?.contentMode = UIViewContentMode.scaleAspectFill
        clipsToBounds = true
        
        if let frontCam = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front) {
            session.sessionPreset = AVCaptureSessionPreset352x288
            do {
                let deviceInput = try AVCaptureDeviceInput(device: frontCam)
                if session.canAddInput(deviceInput) {
                    session.addInput(deviceInput)
                    session.addOutput(cameraOutput)
                    
                    if let previewLayer = AVCaptureVideoPreviewLayer(session: session) {
                        self.previewLayer = previewLayer
                        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
                        previewLayer.frame = bounds
                        layer.insertSublayer(previewLayer, at: 0)
                    }
                }
            } catch {
                print("[FrontCamView] - Error: \(error.localizedDescription)")
            }
        }

    }
    
    func loadViewFromNib() -> UIView {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: String(describing: type(of: self)), bundle: bundle)
        let view = nib.instantiate(withOwner: self, options: nil).first as! UIView
        return view
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        nibSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        nibSetup()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = frame.size.width/2
        if let previewLayer = previewLayer {
            previewLayer.frame = self.bounds
            if previewLayer.connection.isVideoOrientationSupported {
                previewLayer.connection.videoOrientation = interfaceOrientationToVideoOrientation(orientation: UIApplication.shared.statusBarOrientation)
            }
        }
    }
    
    func interfaceOrientationToVideoOrientation(orientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation {
        switch (orientation) {
        case .portrait:
            imageOrientation = .leftMirrored
            return AVCaptureVideoOrientation.portrait
        case .portraitUpsideDown:
            imageOrientation = .rightMirrored
            return AVCaptureVideoOrientation.portraitUpsideDown
        case .landscapeLeft:
            imageOrientation = .upMirrored
            return AVCaptureVideoOrientation.landscapeLeft
        case .landscapeRight:
            imageOrientation = .downMirrored
            return AVCaptureVideoOrientation.landscapeRight
        default:
            break
        }
        print("[FrontCamView] - Warning: Didn't recognise interface orientation (%d)", orientation);
        return AVCaptureVideoOrientation.portrait
    }
    
    @IBAction func showActions() {
        openCam()
        let optionMenuController = UIAlertController(title: nil, message: "Create avatar", preferredStyle: .actionSheet)
        
        let pelliculeAction = UIAlertAction(title: "Access to pellicule", style: .default) {
            alertAction in
            let pickerController = UIImagePickerController()
            pickerController.delegate = self;
            pickerController.allowsEditing = true
            pickerController.sourceType = .photoLibrary
            if let controller = self.delegate as? UIViewController {
                controller.present(pickerController, animated: true, completion: nil)
            }
        }
        let takePhotoAction = UIAlertAction(title: "Take a photo", style: .default) {
            alertAction in
            self.takePhoto()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) {
            alertAction in
            self.button.setImage(self.image, for: .normal)
            self.photo = nil
            self.closeCam()
        }
        optionMenuController.addAction(pelliculeAction)
        optionMenuController.addAction(takePhotoAction)
        optionMenuController.addAction(cancelAction)
        if let controller = delegate as? UIViewController {
            controller.present(optionMenuController, animated: true, completion: nil)
        } else {
            print("[FrontCamView] - Error: no controller assign as delegate")
        }
    }
    
    private func openCam() {
        // start front cam capture
        session.startRunning()
        
        label.isHidden = true
        button.isEnabled = false
        button.isHidden = false
        
        UIView.animate(withDuration: 0.35, animations: {
            self.button.alpha = 0
        }) {
            finished in
            self.button.isHidden = true
        }
    }
    
    private func closeCam() {
        if let timer = timer {
            timer.invalidate()
        }
        button.isEnabled = true
        button.alpha = 0
        button.isHidden = false
        label.isHidden = true
        
        UIView.animate(withDuration: 0.35) {
            self.button.alpha = 1
            self.session.stopRunning()
        }
    }
    
    private func takePhoto(delay: Int = 3) {
        self.delay = delay
        counter = delay
        label.isHidden = false
        self.timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(AvatarView.updateCounter), userInfo: nil, repeats: true)
    }
    
    @objc private func updateCounter() {
        counter -= 1
        if counter == 0 {
            if let timer = timer {
                timer.invalidate()
            }
            takePicture()
        }
    }
    
    private func takePicture() {
        let settings = AVCapturePhotoSettings()
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                             kCVPixelBufferWidthKey as String: 160,
                             kCVPixelBufferHeightKey as String: 160 ]
        settings.previewPhotoFormat = previewFormat
        self.cameraOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: AVCapturePhotoCaptureDelegate
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        
        if let error = error {
            print("[FrontCamView] - Error: \(error.localizedDescription)")
        }
        
        if
            let sampleBuffer = photoSampleBuffer,
            let previewBuffer = previewPhotoSampleBuffer,
            let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: previewBuffer),
            let dataProvider = CGDataProvider(data: dataImage as CFData),
            let cgImageRef = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .absoluteColorimetric)
        {
            photo = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: imageOrientation)
            button.setImage(photo, for: .normal)
            closeCam()
            delegate?.onAvatarViewResponse(avatarView: self, image: photo)
        } else {
            print("[FrontCamView] - Error: impossible to get photo")
        }
    }
    
    // MARK: UIImagePickerControllerDelegate
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        closeCam()
        picker.dismiss(animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        closeCam()
        if let image = info[UIImagePickerControllerEditedImage] as? UIImage {
            photo = image.resizeImage(newWidth: 300)
            button.setImage(photo, for: .normal)
            delegate?.onAvatarViewResponse(avatarView: self, image: photo)
        } else if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            photo = image.resizeImage(newWidth: 300)
            button.setImage(photo, for: .normal)
            delegate?.onAvatarViewResponse(avatarView: self, image: photo)
        } else{
            print("[FrontCamView] - Error: impossible to get photo in Pelicule")
        }
        
        picker.dismiss(animated: true)
    }
}

extension UIImage {
    func resizeImage(newWidth: CGFloat) -> UIImage {
        
        let scale = newWidth / self.size.width
        let newHeight = self.size.height * scale
        UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
        self.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    } }

