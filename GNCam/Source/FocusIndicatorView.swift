//
//  FocusIndicatorView.swift
//  Pods
//
//  Created by Gonzalo Nunez on 8/15/16.
//
//

import UIKit

public enum PopDirection {
  case up, down
}

@IBDesignable
public class FocusIndicatorView: UIView {
  
  private var circleView = UIView()
  
  /// The padding in between the circular border and the view's bounds.
  var circlePadding: CGFloat = 2 {
    didSet {
      setNeedsDisplay()
    }
  }
  
  /// The line width used to draw the circular border.
  var lineWidth: CGFloat = 1 {
    didSet {
      setNeedsDisplay()
    }
  }
  
  /// The `backgroundColor` of `circleView`
  var fillColor: UIColor = UIColor.white.withAlphaComponent(0.7) {
    didSet {
      setNeedsDisplay()
    }
  }
  
  /// The `borderColor` of the `layer` of `circleView`
  var strokeColor: UIColor = UIColor.white.withAlphaComponent(0.7) {
    didSet {
      setNeedsDisplay()
    }
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setUpCircle()
  }
  
  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setUpCircle()
  }
  
  public override func draw(_ rect: CGRect) {
    super.draw(rect)
    guard let ctx = UIGraphicsGetCurrentContext() else { return }
    
    ctx.setLineWidth(lineWidth)
    ctx.setStrokeColor(strokeColor.cgColor)
    
    let center = CGPoint(x: rect.midX, y: rect.midY)
    ctx.addCircle(center: center, radius: radius(in: rect))
    
    ctx.strokePath()
  }
  
  private func setUpCircle() {
    circleView.backgroundColor = fillColor
    circleView.layer.cornerRadius = (bounds.width * 0.9)/2
    
    let centerX = circleView.centerXAnchor.constraint(equalTo: centerXAnchor)
    let centerY = circleView.centerYAnchor.constraint(equalTo: centerYAnchor)
    let height = circleView.heightAnchor.constraint(equalToConstant: bounds.height * 0.9)
    let width = circleView.widthAnchor.constraint(equalToConstant: bounds.width * 0.9)
    
    circleView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(circleView)
    
    NSLayoutConstraint.activate([centerX, centerY, height, width])
    
    pop(.down, animated: false)
  }
  
  public func pop(_ dir: PopDirection, animated: Bool = true, completion: ((Bool) -> Void)? = nil) {
    switch dir {
    case .up:
      
      func popUp() {
        alpha = 1
        circleView.transform = CGAffineTransform(scaleX: 1, y: 1)
      }
      
      if (!animated) {
        popUp()
        return
      }
      
      UIView.animate(withDuration: 0.3,
                     delay: 0,
                     usingSpringWithDamping: 0.6,
                     initialSpringVelocity: 0,
                     options: [.curveEaseOut],
                     animations: {
                      popUp()
        },
                     completion: completion)
    case .down:
      
      func popDown() {
        alpha = 0
        circleView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
      }
      
      if (!animated) {
        popDown()
        return
      }
      
      UIView.animate(withDuration: 0.3,
                     animations: {
                      popDown()
        },
                     completion: completion)
      
    }
  }
  
  public func popUpDown(completion: ((Bool) -> Void)? = nil) {
    pop(.up) { _ -> Void in
      self.pop(.down, completion: completion)
    }
  }
  
  /// The calculated radius for `rect`. Takes into account `circlePadding`.
  private func radius(in rect: CGRect) -> CGFloat {
    return rect.width/2 - circlePadding
  }

  
}

private extension CGContext {
  
  func addCircle(center: CGPoint, radius: CGFloat) {
    return addArc(center: center, radius: radius, startAngle: CGFloat(0), endAngle: CGFloat(2*M_PI), clockwise: false)
  }
  
}

private extension CGMutablePath {
  
  func addCircle(center: CGPoint, radius: CGFloat) {
    return addArc(center: center, radius: radius,startAngle: CGFloat(0), endAngle: CGFloat(2*M_PI), clockwise: false)
  }
  
}
