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
  func captureViewController(_ controller: CaptureViewController, didCaptureStillImage image: UIImage?)
}

public class CaptureViewController: UIViewController, VideoPreviewLayerProvider {
  
  static private let captureButtonRestingRadius: CGFloat = 3
  static private let captureButtonElevatedRadius: CGFloat = 7
  
  public var inputs = [CaptureSessionInput.video] {
    didSet {
      didChangeInputsOrOutputs()
    }
  }
  
  public var outputs = [CaptureSessionOutput.stillImage] {
    didSet {
      didChangeInputsOrOutputs()
    }
  }
  
  public weak var captureDelegate: CaptureViewControllerDelegate?
  
  private lazy var captureButton: UIButton = {
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
  
  private lazy var cameraSwitchButton: UIButton = {
    let btn = UIButton(frame: CGRect.zero)
    
    let type = type(of: self)
    let bundle = Bundle(for: type)
    let switchCamera = UIImage(named: "switchCamera", in: bundle, compatibleWith: nil)
        
    btn.setImage(switchCamera, for: .normal)
    btn.addTarget(self, action: #selector(handleCameraSwitchButton(_:)), for: .touchUpInside)
    
    return btn
  }()
  
  private lazy var viewTap: UITapGestureRecognizer = {
    let tap = UITapGestureRecognizer(target: self, action: #selector(handleViewTap(_:)))
    tap.delaysTouchesEnded = false
    return tap
  }()
  
  
  private lazy var viewDoubleTap: UITapGestureRecognizer = {
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
  
  override public func viewDidLoad() {
    super.viewDidLoad()
    setUp()
  }
    
  override public func loadView() {
    view = CapturePreviewView()
  }
  
  override public var prefersStatusBarHidden: Bool {
    return true
  }
  
  override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    captureManager.refreshOrientation()
  }
  
  //MARK: Set Up
  
  private func setUp() {
    setUpButtons()
    setUpGestures()
    setUpCaptureManager()
  }
  
  private func setUpButtons() {
    setUpCameraSwitchButton()
    setUpCaptureButton()
  }
  
  private func setUpCameraSwitchButton() {
    cameraSwitchButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(cameraSwitchButton)
    
    let top = cameraSwitchButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 16)
    let right = cameraSwitchButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 16)
    let width = cameraSwitchButton.widthAnchor.constraint(equalToConstant: 44)
    let height = cameraSwitchButton.heightAnchor.constraint(equalToConstant: 44)
    
    NSLayoutConstraint.activate([top, right, width, height])
  }
  
  private func setUpCaptureButton() {
    captureButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(captureButton)
    
    let bottom = captureButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
    let centerX = captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
    let width = captureButton.widthAnchor.constraint(equalToConstant: 80)
    let height = captureButton.heightAnchor.constraint(equalToConstant: 80)
    
    NSLayoutConstraint.activate([bottom, centerX, width, height])
  }
  
  private func setUpGestures() {
    view.addGestureRecognizer(viewTap)
    view.addGestureRecognizer(viewDoubleTap)
    
    viewTap.require(toFail: viewDoubleTap)
  }
  
  private func setUpCaptureManager() {
    captureManager.setUp(sessionPreset: AVCaptureSessionPresetHigh,
                         previewLayerProvider: self,
                         inputs: [.video],
                         outputs: [.stillImage])
    { (error) in
      print("Woops, got error: \(error)")
    }
    
    captureManager.startRunning()
  }
  
  //MARK: Actions
  
  @objc private func handleCaptureButtonTouchDown(_: UIButton) {
    captureButton.layer.animateShadowRadius(to: CaptureViewController.captureButtonElevatedRadius)
    captureButton.backgroundColor = captureButton.backgroundColor?.withAlphaComponent(0.7)
  }
  
  @objc private func handleCaptureButtonTouchUpOutside(_: UIButton) {
    captureButton.layer.animateShadowRadius(to: CaptureViewController.captureButtonRestingRadius)
    captureButton.backgroundColor = captureButton.backgroundColor?.withAlphaComponent(1)
  }
  
  @objc private func handleCaptureButtonTouchUpInside(_: UIButton) {
    captureButton.layer.animateShadowRadius(to: CaptureViewController.captureButtonRestingRadius)
    captureButton.backgroundColor = captureButton.backgroundColor?.withAlphaComponent(1)
    
    captureManager.captureStillImage() { (image, error) in
      self.captureDelegate?.captureViewController(self, didCaptureStillImage: image)
    }
  }
  
  @objc private func handleCameraSwitchButton(_: UIButton) {
    toggleCamera()
  }
  
  //MARK: Gestures
  
  @objc private func handleViewTap(_ tap: UITapGestureRecognizer) {
    let loc = tap.location(in: view)
    
    func showIndicatorView() {
      let indicator = FocusIndicatorView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
      indicator.center = loc
      indicator.backgroundColor = .clear
      
      view.addSubview(indicator)
      
      indicator.popUpDown() { _ -> Void in
        indicator.removeFromSuperview()
      }
    }
    
    do {
      try captureManager.focusAndExposure(at: loc)
      showIndicatorView()
    } catch let error {
      print("Woops, got error: \(error)")
    }
  }
  
  @objc private func handleViewDoubleTap(_ tap: UITapGestureRecognizer) {
    toggleCamera()
  }

  //MARK: VideoPreviewLayerProvider
  
  public var previewLayer: AVCaptureVideoPreviewLayer {
    return view.layer as! AVCaptureVideoPreviewLayer
  }
  
  //MARK: Helpers
  
  private func toggleCamera() {
    captureManager.toggleCamera() { (error) -> Void in
      print("Woops, got error: \(error)")
    }
  }
  
  private func didChangeInputsOrOutputs() {
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
