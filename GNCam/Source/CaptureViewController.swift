//
//  CaptureViewController.swift
//  Pods
//
//  Created by Gonzalo Nunez on 8/21/16.
//
//

import AVFoundation
import CoreMedia

import UIKit

public protocol CaptureViewControllerDelegate: class {
  /**
   Called when the `controller` captures an image.
   */
  func captureViewController(_ controller: CaptureViewController, didCaptureStillImage image: UIImage?)
}

public enum BarcodeMode {
  case showing(CGRect)
  case hidden
}

open class CaptureViewController: UIViewController, VideoPreviewLayerProvider {
  
  static fileprivate let captureButtonRestingRadius: CGFloat = 3
  static fileprivate let captureButtonElevatedRadius: CGFloat = 7
  
  /**
   The inputs used to set up the `AVCaptureSession`.
  */
  open var inputs = [CaptureSessionInput.video] {
    didSet {
      didChangeInputsOrOutputs()
    }
  }
  
  /**
   The outputs used to set up the `AVCaptureSession`.
  */
  open var outputs = [CaptureSessionOutput.stillImage] {
    didSet {
      didChangeInputsOrOutputs()
    }
  }
  
  /**
   Determines whether or not to display the `closeButton` on the top left of `view`.
  */
  public var dismissable = true {
    didSet {
      closeButton.isHidden = !dismissable
    }
  }
  
  /**
   The `CaptureViewControllerDelegate` that will be informed of image capture events.
  */
  public weak var captureDelegate: CaptureViewControllerDelegate?
  
  fileprivate lazy var closeButton: UIButton = {
    let btn = UIButton(frame: CGRect.zero)
    
    let bundle = Bundle(for: CaptureViewController.self)
    let close = UIImage(named: "close", in: bundle, compatibleWith: nil)
    
    btn.setImage(close, for: .normal)
    btn.addTarget(self, action: #selector(handleCloseButton(_:)), for: .touchUpInside)
    
    return btn
  }()
  
  fileprivate lazy var cameraSwitchButton: UIButton = {
    let btn = UIButton(frame: CGRect.zero)
    
    let bundle = Bundle(for: CaptureViewController.self)
    let switchCamera = UIImage(named: "switchCamera", in: bundle, compatibleWith: nil)
        
    btn.setImage(switchCamera, for: .normal)
    btn.addTarget(self, action: #selector(handleCameraSwitchButton(_:)), for: .touchUpInside)
    
    return btn
  }()
  
  fileprivate lazy var flashButton: UIButton = {
    let btn = UIButton(frame: CGRect.zero)
    
    let bundle = Bundle(for: CaptureViewController.self)
    let flashOff = UIImage(named: "flashOff", in: bundle, compatibleWith: nil)
    
    btn.setImage(flashOff, for: .normal)
    btn.addTarget(self, action: #selector(handleFlashButton(_:)), for: .touchUpInside)
    
    return btn
  }()
  
  fileprivate lazy var captureButton: UIButton = {
    let btn = UIButton(frame: CGRect.zero)
    btn.backgroundColor = .white
    
    btn.layer.cornerRadius = 40
    btn.layer.shadowColor = UIColor.black.cgColor
    btn.layer.shadowOpacity = 0.5
    btn.layer.shadowOffset = CGSize(width: 0, height: 2)
    btn.layer.shadowRadius = CaptureViewController.captureButtonRestingRadius
    
    btn.addTarget(self, action: #selector(handleCaptureButtonTouchDown(_:)), for: .touchDown)
    btn.addTarget(self, action: #selector(handleCaptureButtonTouchUpOutside(_:)), for: .touchUpOutside)
    btn.addTarget(self, action: #selector(handleCaptureButtonTouchUpInside(_:)), for: .touchUpInside)
    
    return btn
  }()
  
  fileprivate lazy var detectorView: UIView = {
    let view = UIView()
    view.backgroundColor = .clear
    view.layer.borderWidth = 2
    return view
  }()
  
  public var detectorViewBorderColor: UIColor = .green {
    didSet {
      detectorView.layer.borderColor = detectorViewBorderColor.cgColor
    }
  }
  
  fileprivate var detectorViewCenterX: NSLayoutConstraint!
  fileprivate var detectorViewCenterY: NSLayoutConstraint!
  fileprivate var detectorViewWidth: NSLayoutConstraint!
  fileprivate var detectorViewHeight: NSLayoutConstraint!

  fileprivate lazy var viewTap: UITapGestureRecognizer = {
    let tap = UITapGestureRecognizer(target: self, action: #selector(handleViewTap(_:)))
    tap.delaysTouchesEnded = false
    return tap
  }()
  
  
  fileprivate lazy var viewDoubleTap: UITapGestureRecognizer = {
    let tap = UITapGestureRecognizer(target: self, action: #selector(handleViewDoubleTap(_:)))
    tap.delaysTouchesEnded = false
    tap.numberOfTapsRequired = 2
    return tap
  }()
  
  public convenience init(inputs: [CaptureSessionInput], outputs:[CaptureSessionOutput]) {
    self.init(nibName: nil, bundle: nil)
    self.inputs = inputs
    self.outputs = outputs
  }
  
  override open func viewDidLoad() {
    super.viewDidLoad()
    setUp()
  }
    
  override open func loadView() {
    view = CapturePreviewView()
  }
  
  override open var prefersStatusBarHidden: Bool {
    return true
  }
  
  override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    captureManager.refreshOrientation()
  }
  
  //MARK: Set Up
  
  fileprivate func setUp() {
    setUpViews()
    setUpGestures()
    setUpCaptureManager()
  }
  
  fileprivate func setUpViews() {
    setUpCloseButton()
    setUpCameraSwitchButton()
    setUpCaptureButton()
    setUpFlashButton()
    setUpDetectorView()
  }
  
  fileprivate func setUpCloseButton() {
    closeButton.isHidden = !dismissable
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(closeButton)
    
    let top = closeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 16)
    let left = closeButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 16)
    let width = closeButton.widthAnchor.constraint(equalToConstant: 44)
    let height = closeButton.heightAnchor.constraint(equalToConstant: 44)
    
    NSLayoutConstraint.activate([top, left, width, height])
  }
  
  fileprivate func setUpCameraSwitchButton() {
    cameraSwitchButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(cameraSwitchButton)
    
    let top = cameraSwitchButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 16)
    let right = cameraSwitchButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -16)
    let width = cameraSwitchButton.widthAnchor.constraint(equalToConstant: 44)
    let height = cameraSwitchButton.heightAnchor.constraint(equalToConstant: 44)
    
    NSLayoutConstraint.activate([top, right, width, height])
  }
  
  fileprivate func setUpFlashButton() {
    flashButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(flashButton)
    
    let top = flashButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 16)
    let centerX = flashButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
    let width = flashButton.widthAnchor.constraint(equalToConstant: 44)
    let height = flashButton.heightAnchor.constraint(equalToConstant: 44)
    
    NSLayoutConstraint.activate([top, centerX, width, height])
  }
  
  fileprivate func setUpCaptureButton() {
    captureButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(captureButton)
    
    let bottom = captureButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
    let centerX = captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
    let width = captureButton.widthAnchor.constraint(equalToConstant: 80)
    let height = captureButton.heightAnchor.constraint(equalToConstant: 80)
    
    NSLayoutConstraint.activate([bottom, centerX, width, height])
  }
  
  fileprivate func setUpDetectorView() {
    detectorView.translatesAutoresizingMaskIntoConstraints = false
    detectorView.alpha = 0
    detectorView.layer.borderColor = detectorViewBorderColor.cgColor
    view.addSubview(detectorView)
    
    detectorViewCenterX = detectorView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
    detectorViewCenterY = detectorView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
    detectorViewWidth = detectorView.widthAnchor.constraint(equalToConstant: 44)
    detectorViewHeight = detectorView.heightAnchor.constraint(equalToConstant: 44)
    
    NSLayoutConstraint.activate([detectorViewCenterX, detectorViewCenterY, detectorViewWidth, detectorViewHeight])
  }
  
  fileprivate func setUpGestures() {
    view.addGestureRecognizer(viewTap)
    view.addGestureRecognizer(viewDoubleTap)
    
    viewTap.require(toFail: viewDoubleTap)
  }
  
  fileprivate func setUpCaptureManager() {
    captureManager.setUp(sessionPreset: AVCaptureSessionPresetHigh,
                         previewLayerProvider: self,
                         inputs: inputs,
                         outputs: outputs)
    { (error) in
      print("Woops, got error: \(error)")
    }
    
    captureManager.startRunning()
  }
  
  //MARK: Actions
  
  @objc fileprivate func handleCloseButton(_: UIButton) {
    dismiss(animated: true, completion: nil)
  }
  
  @objc fileprivate func handleCameraSwitchButton(_: UIButton) {
    let wantsFront = (captureManager.videoDevicePosition == .back)
    flashButton.isHidden = wantsFront
    toggleCamera()
  }
  
  @objc fileprivate func handleFlashButton(_: UIButton) {
    let wantsFlash = (captureManager.flashMode == .off)
    do {
      try captureManager.toggleFlash()
      let imageName = wantsFlash ? "flashOn" : "flashOff"
      let bundle = Bundle(for: CaptureViewController.self)
      let image = UIImage(named: imageName, in: bundle, compatibleWith: nil)
      flashButton.setImage(image, for: .normal)
    } catch {
      print("Woops, got an error: \(error)")
    }
  }
  
  @objc fileprivate func handleCaptureButtonTouchDown(_: UIButton) {
    captureButton.layer.animateShadowRadius(to: CaptureViewController.captureButtonElevatedRadius)
    captureButton.backgroundColor = captureButton.backgroundColor?.withAlphaComponent(0.7)
  }
  
  @objc fileprivate func handleCaptureButtonTouchUpOutside(_: UIButton) {
    captureButton.layer.animateShadowRadius(to: CaptureViewController.captureButtonRestingRadius)
    captureButton.backgroundColor = captureButton.backgroundColor?.withAlphaComponent(1)
  }
  
  @objc fileprivate func handleCaptureButtonTouchUpInside(_: UIButton) {
    captureButton.layer.animateShadowRadius(to: CaptureViewController.captureButtonRestingRadius)
    captureButton.backgroundColor = captureButton.backgroundColor?.withAlphaComponent(1)
    
    captureManager.captureStillImage() { (image, error) in
      self.captureDelegate?.captureViewController(self, didCaptureStillImage: image)
    }
  }
  
  public func reactToBarcode(_ mode: BarcodeMode) {
    switch mode {
    case .showing(let bounds):
      detectorViewCenterX.constant = bounds.midX - view.center.x
      detectorViewCenterY.constant = bounds.midY - view.center.y
      detectorViewWidth.constant   = bounds.width
      detectorViewHeight.constant  = bounds.height
      
      view.layoutIfNeeded()
      
      UIView.animate(withDuration: 0.2) {
        self.detectorView.alpha = 1
      }
    case .hidden:
      UIView.animate(withDuration: 0.2) {
        self.detectorView.alpha = 0
      }
    }
  }
  
  //MARK: Gestures
  
  @objc fileprivate func handleViewTap(_ tap: UITapGestureRecognizer) {
    let loc = tap.location(in: view)
    do {
      try captureManager.focusAndExposure(at: loc)
      showIndicatorView(at: loc)
    } catch {
      print("Woops, got error: \(error)")
    }
  }
  
  /**
   Makes a `FocusIndicatorView` pop up and down at `loc`.
  */
  open func showIndicatorView(at loc: CGPoint) {
    let indicator = FocusIndicatorView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
    indicator.center = loc
    indicator.backgroundColor = .clear
    
    view.addSubview(indicator)
    
    indicator.popUpDown() { _ -> Void in
      indicator.removeFromSuperview()
    }
  }
  
  @objc fileprivate func handleViewDoubleTap(_ tap: UITapGestureRecognizer) {
    toggleCamera()
  }

  //MARK: VideoPreviewLayerProvider
  
  /**
   The `AVCaptureVideoPreviewLayer` that will be used with the `AVCaptureSession`.
  */
  open var previewLayer: AVCaptureVideoPreviewLayer {
    return view.layer as! AVCaptureVideoPreviewLayer
  }
  
  //MARK: Helpers
  
  fileprivate func toggleCamera() {
    captureManager.toggleCamera() { (error) -> Void in
      print("Woops, got error: \(error)")
    }
  }
  
  fileprivate func didChangeInputsOrOutputs() {
    let wasRunning = captureManager.isRunning
    captureManager.stopRunning()
    setUpCaptureManager()
    if (wasRunning) { captureManager.startRunning() }
  }
  
}

private extension CALayer {
  
  func animateShadowRadius(to radius: CGFloat) {
    let key = "com.ZenunSoftware.GNCam.animateShadowRadius"
    
    removeAnimation(forKey: key)
    
    let anim = CABasicAnimation(keyPath: #keyPath(shadowRadius))
    anim.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
    anim.toValue = radius
    anim.duration = 0.2
    
    add(anim, forKey: key)
    shadowRadius = radius
  }
  
}
