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
  
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet var viewTap: UITapGestureRecognizer!
  @IBOutlet var viewDoubleTap: UITapGestureRecognizer!
  
  let captureManager = CaptureManager.sharedManager
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    viewTap.require(toFail: viewDoubleTap)
    
    imageView.contentMode = .scaleAspectFit
    imageView.layer.shadowColor = UIColor.black.withAlphaComponent(0.7).cgColor
    imageView.layer.shadowOffset = CGSize(width: -4, height: -4)
    
    try? captureManager.setUp(sessionPreset: AVCaptureSessionPresetHigh,
                              previewLayerProvider: self,
                              inputs: [.video],
                              outputs: [.stillImage, .videoData]) { (error) in
                                print("Woops, got error: \(error)")
    }
    
    captureManager.dataOutputDelegate = self
    captureManager.startRunning()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @IBAction func handleViewTap(_ sender: UITapGestureRecognizer) {
    captureManager.captureStillImage() { (image, error) in
      self.imageView.image = image
    }
  }
  
  @IBAction func handleViewDoubleTap(_ sender: UITapGestureRecognizer) {
    try? captureManager.toggleCamera()
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

