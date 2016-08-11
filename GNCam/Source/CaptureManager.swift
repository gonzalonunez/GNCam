import UIKit

import AVFoundation
import CoreMedia

public protocol VideoPreviewLayerProvider: class {
  var previewLayer: AVCaptureVideoPreviewLayer { get }
}

public protocol VideoDataOutputDelegate: class {
  func captureManagerDidOutput(sampleBuffer: CMSampleBuffer)
}

/// Input types for the `AVCaptureSession` of a `CaptureManager`
public enum CaptureSessionInput {
  case video
  case audio
}

/// Output types for the `AVCaptureSession` of a `CaptureManager`
public enum CaptureSessionOutput {
  case stillImage
  case videoData
}

/// Error types for `CaptureManager`
public enum CaptureManagerError: Error {
  case InvalidSessionPreset
  case InvalidMediaType
  case InvalidCaptureInput
  case InvalidCaptureOutput
  case SessionNotSetUp
  case MissingOutputConnection
  case CameraToggleFailed
}

/// Error types for `CaptureManager` related to `AVCaptureStillImageOutput`
public enum StillImageError: Error {
  case NoData
  case NoImage
}

public class CaptureManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
  
  public static let sharedManager = CaptureManager()
  
  public typealias ErrorCompletionHandler = (Error) -> Void
  public typealias ImageCompletionHandler = (UIImage) -> Void
  public typealias ImageErrorCompletionHandler = (UIImage?, Error?) -> Void
  
  private static let kFramesQueue = "com.ZenunSoftware.GNCam.FramesQueue"
  private static let kSessionQueue = "com.ZenunSoftware.GNCam.SessionQueue"
  
  private let framesQueue: DispatchQueue
  private let sessionQueue: DispatchQueue
  
  private let captureSession: AVCaptureSession
  private(set) var didSetUp = false
  
  public var captureSessionPreset: String? {
    return captureSession.sessionPreset
  }
  
  private var audioDevice: AVCaptureDevice?
  private var videoDevice: AVCaptureDevice?
  private(set) var videoDevicePosition = AVCaptureDevicePosition.back
  
  private var videoInput: AVCaptureDeviceInput?
  private var audioInput: AVCaptureDeviceInput?
  
  private var stillImageOutput: AVCaptureStillImageOutput?
  private var videoDataOutput: AVCaptureVideoDataOutput?
  
  weak public var dataOutputDelegate: VideoDataOutputDelegate?
  weak private(set) var previewLayerProvider: VideoPreviewLayerProvider?
  
  var desiredVideoOrientation: AVCaptureVideoOrientation {
    switch UIDevice.current.orientation {
    case .portrait, .portraitUpsideDown, .faceUp, .faceDown, .unknown:
      return .portrait
    case .landscapeLeft:
      return .landscapeRight
    case .landscapeRight:
      return .landscapeLeft
    }
  }
  
  /// Determines whether or not images taken with front camera are mirrored. Default is `true`.
  public var mirrorsFrontCamera = true
  
  //MARK: Init
  
  override init() {
    framesQueue = DispatchQueue(label: CaptureManager.kFramesQueue)
    sessionQueue = DispatchQueue(label: CaptureManager.kSessionQueue)
    captureSession = AVCaptureSession()
    super.init()
  }
  
  //MARK: Set Up
  
  /**
   Set up the AVCaptureSession.
   
   - Important: Recreates inputs/outputs based on `sessionPreset`.
   
   - parameter sessionPreset: The `sessionPreset` for the `AVCaptureSession`.
   - parameter inputs: A mask of options of type `CaptureSessionInputs` indicating what inputs to add to the `AVCaptureSession`.
   - parameter outputs: A mask of options of type `CaptureSessionOutputs` indicating what outputs to add to the `AVCaptureSession`.
   - parameter errorHandler: A closure of type `(Error) -> Void`. Called on the **main thread** if anything performed inside of `sessionQueue` thread throws an error.
   
   - Throws: `CaptureManagerError.InvalidSessionPreset` if `sessionPreset` is not valid.
   */
  public func setUp(sessionPreset: String,
                    previewLayerProvider: VideoPreviewLayerProvider,
                    inputs: [CaptureSessionInput],
                    outputs: [CaptureSessionOutput],
                    errorHandler:ErrorCompletionHandler)
  {
    func setUpCaptureSession() throws {
      try self.setSessionPreset(sessionPreset)
      self.videoDevice = try self.desiredDevice(withMediaType: AVMediaTypeVideo)
      
      self.removeAllInputs()
      try self.addInputs(inputs)
      
      DispatchQueue.main.async {
        self.previewLayerProvider = previewLayerProvider
        previewLayerProvider.previewLayer.session = self.captureSession
      }
      
      self.removeAllOutputs()
      try self.addOutputs(outputs)
      
      didSetUp = true
    }
    
    sessionQueue.async {
      do {
        try setUpCaptureSession()
      } catch let error as Error {
        DispatchQueue.main.async {
          errorHandler(error)
        }
      }
    }
  }
  
  //MARK: I/O
  
  /// Add the corresponding `AVCaptureInput` for each `CaptureSessionInput` in `inputs`.
  private func addInputs(_ inputs: [CaptureSessionInput]) throws {
    for input in inputs {
      try addInput(input)
    }
  }
  
  /// Add the corresponding `AVCaptureInput` for `input`.
  private func addInput(_ input: CaptureSessionInput) throws {
    switch input {
    case .video:
      try addVideoInput()
    case .audio:
      //TODO: Add audio input.
      break
    }
  }
  
  /// Remove the corresponding `AVCaptureInput` for `input`.
  private func removeInput(_ input: CaptureSessionInput) {
    switch input {
    case .video:
      captureSession.removeInput(videoInput)
    case .audio:
      //TODO: Remove audio input.
      break
    }
  }
  
  /// Remove all inputs from `captureSession`
  private func removeAllInputs() {
    if let inputs = captureSession.inputs as? [AVCaptureInput] {
      for input in inputs {
        captureSession.removeInput(input)
      }
    }
  }
  
  /// Add the corresponding `AVCaptureOutput` for each `CaptureSessionInput` in `outputs`.
  private func addOutputs(_ outputs: [CaptureSessionOutput]) throws {
    for output in outputs {
      try addOutput(output)
    }
  }
  
  /// Add the corresponding `AVCaptureOutput` for `outputs`.
  private func addOutput(_ output: CaptureSessionOutput) throws {
    switch output {
    case .stillImage:
      try addStillImageOutput()
    case .videoData:
      try addVideoDataOutput()
    }
  }
  
  /// Remove the corresponding `AVCaptureSessionOutput` for `output`.
  public func removeOutput(_ output: CaptureSessionOutput) {
    switch output {
    case .stillImage:
      captureSession.removeOutput(stillImageOutput)
    case .videoData:
      captureSession.removeOutput(videoDataOutput)
    }
  }
  
  /// Remove all outputs from `captureSession`
  private func removeAllOutputs() {
    if let outputs = captureSession.outputs as? [AVCaptureOutput] {
      for outputs in outputs {
        captureSession.removeOutput(outputs)
      }
    }
  }
  
  //MARK: Actions
  
  /// Start running the `AVCaptureSession`.
  public func startRunning(errorHandler: ErrorCompletionHandler? = nil) {
    sessionQueue.async {
      if (self.captureSession.isRunning) { return }
      if (!self.didSetUp) {
        errorHandler?(CaptureManagerError.SessionNotSetUp)
        return
      }
      self.captureSession.startRunning()
    }
  }
  
  /// Stop running the `AVCaptureSession`.
  public func stopRunning() {
    sessionQueue.async {
      if (!self.captureSession.isRunning) { return }
      self.captureSession.startRunning()
    }
  }
  
  /**
   Capture a still image.
   - parameter completion: A closure of type `(UIImage?, Error?) -> Void` that is called on the **main thread** upon successful capture of the image or the occurence of an error.
   */
  public func captureStillImage(completion: ImageErrorCompletionHandler) {
    
    sessionQueue.async {
      
      guard let imageOutput = self.stillImageOutput,
        let connection = imageOutput.connection(withMediaType: AVMediaTypeVideo) else
      {
        DispatchQueue.main.async {
          completion(nil, CaptureManagerError.MissingOutputConnection)
        }
        return
      }
      
      connection.videoOrientation = self.desiredVideoOrientation
      
      imageOutput.captureStillImageAsynchronously(from: connection) { (sampleBuffer, error) -> Void in
        if (sampleBuffer == nil || error != nil) {
          DispatchQueue.main.async {
            completion(nil, error)
          }
          return
        }
        
        guard let data = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer) else {
          DispatchQueue.main.async {
            completion(nil, StillImageError.NoData)
          }
          return
        }
        
        guard let image = UIImage(data: data) else {
          DispatchQueue.main.async {
            completion(nil, StillImageError.NoImage)
          }
          return
        }
        
        var possiblyFlipped = image
        
        if (self.videoDevicePosition == .front && self.mirrorsFrontCamera) {
          if let cgImage = image.cgImage {
            possiblyFlipped = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
          }
        }
        
        completion(possiblyFlipped, nil)
      }
      
    }
    
  }
  
  /**
   Toggles the position of the camera if possible.
   - parameter errorHandler: A closure of type `Error -> Void` that is called on the **main thread** if no opposite device or input was found.
   */
  public func toggleCamera(errorHandler: ErrorCompletionHandler) {
    let position = videoDevicePosition.flipped()
    let device = try? desiredDevice(withMediaType: AVMediaTypeVideo, position: position)
    
    if (device == nil || device == videoDevice) {
      DispatchQueue.main.async {
        errorHandler(CaptureManagerError.CameraToggleFailed)
      }
      return
    }
    
    sessionQueue.async {
      do {
        self.videoDevicePosition = position
        self.captureSession.beginConfiguration()
        self.removeInput(.video)
        self.videoDevice = device
        try self.addInput(.video)
        self.captureSession.commitConfiguration()
      } catch let error as Error {
        DispatchQueue.main.async {
        errorHandler(error)
        }
      }
    }
    
  }
  
  //MARK: AVCaptureVideoDataOutputSampleBufferDelegate
  
  public func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
    DispatchQueue.main.async {
      self.dataOutputDelegate?.captureManagerDidOutput(sampleBuffer: sampleBuffer)
    }
  }
  
  //MARK: Helpers
  
  /**
   Create `videoInput` and add it to `captureSession`.
   - Throws: `CaptureManagerError.InvalidCaptureInput` if the input cannot be added to `captureSession`.
   */
  private func addVideoInput() throws {
    videoInput = try AVCaptureDeviceInput(device: videoDevice)
    
    if (!captureSession.canAddInput(videoInput)) {
      throw CaptureManagerError.InvalidCaptureInput
    }
    
    captureSession.addInput(videoInput)
  }
  
  /**
   Create `stillImageoutput` and add it to `captureSession`.
   - Throws: `CaptureManagerError.InvalidCaptureOutput` if the output cannot be added to `captureSession`.
   */
  private func addStillImageOutput() throws {
    stillImageOutput = AVCaptureStillImageOutput()
    stillImageOutput?.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
    
    if (!captureSession.canAddOutput(stillImageOutput)) {
      throw CaptureManagerError.InvalidCaptureOutput
    }
    
    captureSession.addOutput(stillImageOutput)
  }
  
  /**
   Create `videoDataOutput` and add it to `captureSession`.
   - Throws: `CaptureManagerError.InvalidCaptureOutput` if the output cannot be added to `captureSession`.
   */
  private func addVideoDataOutput() throws {
    videoDataOutput = AVCaptureVideoDataOutput()
    videoDataOutput?.videoSettings = [kCVPixelBufferPixelFormatTypeKey: UInt(kCVPixelFormatType_32BGRA)]
    videoDataOutput?.setSampleBufferDelegate(self, queue: framesQueue)
    
    if (!captureSession.canAddOutput(videoDataOutput)) {
      throw CaptureManagerError.InvalidCaptureOutput
    }
    
    captureSession.addOutput(videoDataOutput)
  }
  
  /**
   Set the sessionPreset for the AVCaptureSession.
   - Throws: `CaptureManager.InvalidSessionPresent` if `sessionPreset` is not valid.
   */
  private func setSessionPreset(_ preset: String) throws {
    if !captureSession.canSetSessionPreset(preset) {
      throw CaptureManagerError.InvalidSessionPreset
    }
    
    captureSession.sessionPreset = preset
  }
  
  /**
   Find the first `AVCaptureDevice` of type `type`. Return default device of type `type` if nil.
   
   - parameter type: The media type, such as AVMediaTypeVideo, AVMediaTypeAudio, or AVMediaTypeMixed.
   - Throws: `CaptureManagerError.InvalidMediaType` if `type` is not a valid media type.
   - Returns: `AVCaptureDevice?`
   */
  private func desiredDevice(withMediaType type: String, position: AVCaptureDevicePosition? = nil) throws -> AVCaptureDevice {
    guard let devices = AVCaptureDevice.devices(withMediaType: type) as? [AVCaptureDevice] else {
      throw CaptureManagerError.InvalidMediaType
    }
    
    return devices.filter{$0.position == position ?? videoDevicePosition}.first ?? AVCaptureDevice.defaultDevice(withMediaType: type)
  }
  
}

extension AVCaptureDevicePosition {
  
  mutating func flip() {
    if (self == .back) {
      self = .front
    } else {
      self = .back
    }
  }
  
  func flipped() -> AVCaptureDevicePosition {
    var copy = self
    copy.flip()
    return copy
  }
  
}
