//
//  ViewController.swift
//  GNCam
//
//  Created by gonzalonunez on 08/08/2016.
//  Copyright (c) 2016 gonzalonunez. All rights reserved.
//

import UIKit

import GNCam
import AVFoundation

class ViewController: UIViewController, CaptureViewControllerDelegate, MetadataOutputDelegate {
  
  @IBOutlet weak private var imageView: UIImageView!
  
  private lazy var captureVC: CaptureViewController = {
    let vc = CaptureViewController(inputs: [.video], outputs: [.stillImage, .metadata([AVMetadataObjectTypeQRCode])])
    vc.captureDelegate = self
    vc.captureManager.metadataOutputDelegate = self
    return vc
  }()
  
  override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    captureVC.captureManager.refreshOrientation()
  }
  
  //MARK: IBActions
  
  @IBAction func handleTakePictureButton(_ sender: UIButton) {
    present(captureVC, animated: true, completion: nil)
  }
  
  //MARK: CaptureViewControllerDelegate
  
  public func captureViewController(_ controller: CaptureViewController, didCaptureStillImage image: UIImage?) {
    controller.dismiss(animated: true)
    
    guard let img = image else {
      print("Woops, we didn't get an image!")
      return
    }
    
    imageView.image = img
  }
  
  //MARK: MetadataOutputDelegate
  
  public func captureManagerDidOutput(metadataObjects: [Any]) {
    if metadataObjects.isEmpty {
      captureVC.reactToBarcode(.hidden)
      return
    }
    
    guard let metadata = metadataObjects[0] as? AVMetadataMachineReadableCodeObject, metadata.type == AVMetadataObjectTypeQRCode,
          let barcode = captureVC.previewLayer.transformedMetadataObject(for: metadata) else
    {
      return
    }
    
    captureVC.reactToBarcode(.showing(barcode.bounds))
    print("Found QR code with string value: metadata.stringValue")
    
  }
  
}
