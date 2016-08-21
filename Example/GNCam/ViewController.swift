//
//  ViewController.swift
//  GNCam
//
//  Created by gonzalonunez on 08/08/2016.
//  Copyright (c) 2016 gonzalonunez. All rights reserved.
//

import GNCam
import UIKit

class ViewController: UIViewController, CaptureViewControllerDelegate {
  
  @IBOutlet weak var imageView: UIImageView!
  
  @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
  @IBOutlet weak var imageViewWidthConstraint: NSLayoutConstraint!
  
  private lazy var captureVC: CaptureViewController = {
    let vc = CaptureViewController(inputs: [.video], outputs: [.stillImage])
    vc.captureDelegate = self
    return vc
  }()
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    refreshImageViewDimensions()
  }
  
  override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    refreshImageViewDimensions()
    captureVC.captureManager.refreshOrientation()
  }
  
  private func refreshImageViewDimensions() {
    let maxDim = max(view.bounds.height, view.bounds.width)
    let minDim = min(view.bounds.height, view.bounds.width)
    
    imageViewHeightConstraint.constant = (captureVC.captureManager.desiredVideoOrientation == .portrait ? maxDim : minDim) * 0.4
    imageViewWidthConstraint.constant = (captureVC.captureManager.desiredVideoOrientation == .portrait ? minDim : maxDim) * 0.4
    view.layoutIfNeeded()
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
  
}
