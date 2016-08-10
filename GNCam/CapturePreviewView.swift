//
//  CapturePreviewView.swift
//  Giffy
//
//  Created by Gonzalo Nunez on 8/20/15.
//  Copyright (c) 2015 Gonzalo Nunez. All rights reserved.
//

import UIKit
import AVFoundation

class CapturePreviewView: UIView {
  
  override class var layerClass: AnyClass {
    return AVCaptureVideoPreviewLayer.self
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setUp()
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setUp()
  }
  
  private func setUp() {
    backgroundColor = .black
  }
  
}
