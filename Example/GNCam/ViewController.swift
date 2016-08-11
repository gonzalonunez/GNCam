//
//  ViewController.swift
//  GNCam
//
//  Created by gonzalonunez on 08/08/2016.
//  Copyright (c) 2016 gonzalonunez. All rights reserved.
//

import UIKit

import AVFoundation
import CoreMedia

import GNCam

class ViewController: UIViewController {
  
  @IBOutlet weak private var imageView: UIImageView!
  
  @IBOutlet private var viewTap: UITapGestureRecognizer!
  @IBOutlet private var viewDoubleTap: UITapGestureRecognizer!
  
  let captureManager = CaptureManager.sharedManager
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    viewTap.require(toFail: viewDoubleTap)
    
    captureManager.dataOutputDelegate = self
    captureManager.setUp(sessionPreset: AVCaptureSessionPresetHigh,
                         previewLayerProvider: self,
                         inputs: [.video],
                         outputs: [.stillImage, .videoData])
    { (error) in
      print("Woops, got error: \(error)")
    }
    
    captureManager.startRunning()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    let aspectRatioConstraint = NSLayoutConstraint(item: imageView,
                                         attribute: .width,
                                         relatedBy: .equal,
                                         toItem: imageView,
                                         attribute: .height,
                                         multiplier: view.bounds.width / view.bounds.height,
                                         constant: 0)
    
    NSLayoutConstraint.activate([aspectRatioConstraint])
  }
  
  override var prefersStatusBarHidden: Bool {
    return true
  }
  
  //MARK: IBActions
    
  @IBAction func handleViewTap(_ sender: UITapGestureRecognizer) {
    captureManager.captureStillImage() { (image, error) in
      self.imageView.image = image
    }
  }
  
  @IBAction func handleViewDoubleTap(_ sender: UITapGestureRecognizer) {
    captureManager.toggleCamera() { (error) -> Void in
      print("Woops, got error: \(error)")
    }
  }
  
}

extension ViewController: VideoPreviewLayerProvider {
  
  var previewLayer: AVCaptureVideoPreviewLayer {
    return view.layer as! AVCaptureVideoPreviewLayer
  }
  
}

extension ViewController: VideoDataOutputDelegate {
  
  func captureManagerDidOutput(sampleBuffer: CMSampleBuffer) {
    print("\(NSDate()) Capture manager did output a buffer.")
  }
  
}

