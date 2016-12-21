import UIKit

import AVFoundation
import CoreMedia

public protocol VideoPreviewLayerProvider: class {
  /**
   The `AVCaptureVideoPreviewLayer` that will be hooked up to the `captureSession`.
   */
  var previewLayer: AVCaptureVideoPreviewLayer { get }
}

public extension VideoPreviewLayerProvider {
  var captureManager: CaptureManager {
    return CaptureManager.sharedManager
  }
}

public protocol VideoDataOutputDelegate: class {
  /**
   Called when the `CaptureManager` outputs a `CMSampleBuffer`.
   - Important: This is **NOT** called on the main thread, but instead on `CaptureManager.kFramesQueue`.
   */
  func captureManagerDidOutput(_ sampleBuffer: CMSampleBuffer)
}

public protocol MetadataOutputDelegate: class {
  /**
   Called when the `CaptureManager` outputs a metadata objects.
   */
  func captureManagerDidOutput(metadataObjects: [Any])
}

/// Input types for the `AVCaptureSession` of a `CaptureManager`
public enum CaptureSessionInput {
  case video
  case audio
  
  var mediaType: String {
    switch self {
    case .video:
      return AVMediaTypeVideo
    case .audio:
      return AVMediaTypeAudio
    }
  }
}

/// Output types for the `AVCaptureSession` of a `CaptureManager`
public enum CaptureSessionOutput {
  case stillImage
  case videoData
  case movieFile
  case metadata([String])
}

/// Error types for `CaptureManager`
public enum CaptureManagerError: Error {
  case invalidSessionPreset
  case invalidMediaType
  case invalidCaptureInput
  case invalidCaptureOutput
  case sessionNotSetUp
  case missingOutputConnection
  case missingVideoDevice
  case missingMovieOutput
  case missingPreviewLayerProvider
  case cameraToggleFailed
  case focusNotSupported
  case exposureNotSupported
  case flashNotAvailable
  case flashModeNotSupported
  case torchNotAvailable
  case torchModeNotSupported
}

/// Error types for `CaptureManager` related to `AVCaptureStillImageOutput`
public enum StillImageError: Error {
  case noData
  case noImage
}

open class CaptureManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate {
  
  public static let sharedManager = CaptureManager()
  
  public typealias ErrorCompletionHandler = (Error) -> Void
  public typealias ImageCompletionHandler = (UIImage) -> Void
  public typealias ImageErrorCompletionHandler = (UIImage?, Error?) -> Void
  
  fileprivate static let kFramesQueue = "com.ZenunSoftware.GNCam.FramesQueue"
  fileprivate static let kSessionQueue = "com.ZenunSoftware.GNCam.SessionQueue"
  
  public let framesQueue: DispatchQueue
  public let sessionQueue: DispatchQueue
  
  fileprivate let captureSession: AVCaptureSession
  public fileprivate(set) var didSetUp = false
  
  public var isRunning: Bool {
    return captureSession.isRunning
  }
  
  public var captureSessionPreset: String? {
    return captureSession.sessionPreset
  }
  
  fileprivate var audioDevice: AVCaptureDevice?
  fileprivate var videoDevice: AVCaptureDevice?
  public fileprivate(set) var videoDevicePosition = AVCaptureDevicePosition.back
  
  fileprivate var videoInput: AVCaptureDeviceInput?
  fileprivate var audioInput: AVCaptureDeviceInput?
  
  fileprivate var stillImageOutput: AVCaptureStillImageOutput?
  fileprivate var videoDataOutput: AVCaptureVideoDataOutput?
  fileprivate var movieFileOutput: AVCaptureMovieFileOutput?
  fileprivate var metadataOutput: AVCaptureMetadataOutput?
  
  public weak var dataOutputDelegate: VideoDataOutputDelegate? {
    didSet {
      videoDataOutput?.setSampleBufferDelegate(self, queue: framesQueue)
    }
  }
  
  
  public weak var metadataOutputDelegate: MetadataOutputDelegate? {
    didSet {
      metadataOutput?.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
    }
  }
  
  fileprivate(set) weak var previewLayerProvider: VideoPreviewLayerProvider?
  
  /// The `AVCaptureVideoOrientation` that corresponds to the current device's orientation.
  public var desiredVideoOrientation: AVCaptureVideoOrientation {
    switch UIDevice.current.orientation {
    case .portrait, .portraitUpsideDown, .faceUp, .faceDown, .unknown:
      return .portrait
    case .landscapeLeft:
      return .landscapeRight
    case .landscapeRight:
      return .landscapeLeft
    }
  }
  
  /// The `AVCaptureFlashMode` of `videoDevice`
  public var flashMode: AVCaptureFlashMode {
    return videoDevice?.flashMode ?? .off
  }
  
  /// The `AVCaptureTorchMode` of `videoDevice`
  public var torchMode: AVCaptureTorchMode {
    return videoDevice?.torchMode ?? .off
  }
  
  /** Returns the `AVAuthorizationStatus` for the `mediaType` of `input`.
   
   - parameter input: The `CaptureSessionInput` to inspect the status of.
  */
  public func authorizationStatus(forInput input: CaptureSessionInput) -> AVAuthorizationStatus {
    let mediaType = input.mediaType
    return AVCaptureDevice.authorizationStatus(forMediaType: mediaType)
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
   
   - Throws: `CaptureManagerError.invalidSessionPreset` if `sessionPreset` is not valid.
   */
  public func setUp(sessionPreset: String,
                  previewLayerProvider: VideoPreviewLayerProvider?,
                  inputs: [CaptureSessionInput],
                  outputs: [CaptureSessionOutput],
                  errorHandler: @escaping ErrorCompletionHandler)
  {
    func setUpCaptureSession() throws {
      captureSession.beginConfiguration()
      
      try self.setSessionPreset(sessionPreset)
      self.videoDevice = try self.desiredDevice(withMediaType: AVMediaTypeVideo)
      
      self.removeAllInputs()
      try self.addInputs(inputs)
      
      self.removeAllOutputs()
      try self.addOutputs(outputs)
      
      didSetUp = true
      
      captureSession.commitConfiguration()
    }
    
    if let layerProvider = previewLayerProvider {
      layerProvider.previewLayer.session = self.captureSession
      layerProvider.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
      self.previewLayerProvider = layerProvider
    }
    
    sessionQueue.async {
      do {
        try setUpCaptureSession()
      } catch let error {
        DispatchQueue.main.async {
          errorHandler(error)
        }
      }
    }
  }
  
  //MARK: I/O
  
  /// Add the corresponding `AVCaptureInput` for each `CaptureSessionInput` in `inputs`.
  fileprivate func addInputs(_ inputs: [CaptureSessionInput]) throws {
    for input in inputs {
      try addInput(input)
    }
  }
  
  /// Add the corresponding `AVCaptureInput` for `input`.
  fileprivate func addInput(_ input: CaptureSessionInput) throws {
    switch input {
    case .video:
      try addVideoInput()
    case .audio:
      try addAudioInput()
      break
    }
  }
  
  /// Remove the corresponding `AVCaptureInput` for `input`.
  fileprivate func removeInput(_ input: CaptureSessionInput) {
    switch input {
    case .video:
      if let videoInput = videoInput {
        captureSession.removeInput(videoInput)
      }
    case .audio:
      if let audioInput = audioInput {
        captureSession.removeInput(audioInput)
      }
      break
    }
  }
  
  /// Remove all inputs from `captureSession`
  fileprivate func removeAllInputs() {
    if let inputs = captureSession.inputs as? [AVCaptureInput] {
      for input in inputs {
        captureSession.removeInput(input)
      }
    }
  }
  
  /// Add the corresponding `AVCaptureOutput` for each `CaptureSessionInput` in `outputs`.
  fileprivate func addOutputs(_ outputs: [CaptureSessionOutput]) throws {
    for output in outputs {
      try addOutput(output)
    }
  }
  
  /// Add the corresponding `AVCaptureOutput` for `outputs`.
  fileprivate func addOutput(_ output: CaptureSessionOutput) throws {
    switch output {
    case .stillImage:
      try addStillImageOutput()
    case .videoData:
      try addVideoDataOutput()
    case .movieFile:
      try addMovieFileOutput()
    case .metadata(let types):
      try addMetadataOutput(with: types)
    }
  }
  
  /// Remove the corresponding `AVCaptureSessionOutput` for `output`.
  fileprivate func removeOutput(_ output: CaptureSessionOutput) {
    switch output {
    case .stillImage:
      if let stillImageOutput = stillImageOutput {
        captureSession.removeOutput(stillImageOutput)
      }
    case .videoData:
      if let videoDataOutput = videoDataOutput {
        captureSession.removeOutput(videoDataOutput)
      }
    case .movieFile:
      if let movieFileOutput = movieFileOutput {
        captureSession.removeOutput(movieFileOutput)
      }
    case .metadata(let types):
      if let metadataOutput = metadataOutput {
        captureSession.removeOutput(metadataOutput)
      }
    }
  }
  
  /// Remove all outputs from `captureSession`
  fileprivate func removeAllOutputs() {
    if let outputs = captureSession.outputs as? [AVCaptureOutput] {
      for outputs in outputs {
        captureSession.removeOutput(outputs)
      }
    }
  }
  
  //MARK: Actions
  
  /// Start running the `AVCaptureSession`.
  public func startRunning(_ errorHandler: ErrorCompletionHandler? = nil) {
    sessionQueue.async {
      if (!self.didSetUp) {
        errorHandler?(CaptureManagerError.sessionNotSetUp)
        return
      }
      if (self.captureSession.isRunning) { return }
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
  public func captureStillImage(_ completion: @escaping ImageErrorCompletionHandler) {
    
    sessionQueue.async {
      
      guard let imageOutput = self.stillImageOutput,
        let connection = imageOutput.connection(withMediaType: AVMediaTypeVideo) else
      {
        DispatchQueue.main.async {
          completion(nil, CaptureManagerError.missingOutputConnection)
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
            completion(nil, StillImageError.noData)
          }
          return
        }
        
        guard let image = UIImage(data: data) else {
          DispatchQueue.main.async {
            completion(nil, StillImageError.noImage)
          }
          return
        }
        
        var flipped: UIImage?
        let wantsFlipped = (self.videoDevicePosition == .front && self.mirrorsFrontCamera)
        
        if (wantsFlipped) {
          if let cgImage = image.cgImage {
            flipped = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
          }
        }
        
        DispatchQueue.main.async {
          completion(flipped ?? image, nil)
        }
        
      }
      
    }
    
  }
  
  /**
   Start recording a video.
   - parameter toOutputFileURL: The URL where the video is recorded to.
   - parameter recordingDelegate: The `AVCaptureFileOutputRecordingDelegate` for `movieFileOutput`.
   - Throws: `CaptureManagerError.missingMovieOutput` if `movieFileOutput` is nil.
   */
  public func startRecordingMovie(toOutputFileURL url: URL, recordingDelegate: AVCaptureFileOutputRecordingDelegate) throws {
    guard let movieFileOutput = movieFileOutput else {
      throw CaptureManagerError.missingMovieOutput
    }
    movieFileOutput.startRecording(toOutputFileURL: url, recordingDelegate: recordingDelegate)
  }
  
  /**
   Stop recording a video.
   - Throws: `CaptureManagerError.missingMovieOutput` if `movieFileOutput` is nil.
   */
  public func stopRecordingMovie() throws {
    guard let movieFileOutput = movieFileOutput else {
      throw CaptureManagerError.missingMovieOutput
    }
    movieFileOutput.stopRecording()
  }
  
  /**
   Toggles the position of the camera if possible.
   - parameter errorHandler: A closure of type `Error -> Void` that is called on the **main thread** if no opposite device or input was found.
   */
  public func toggleCamera(_ errorHandler: @escaping ErrorCompletionHandler) {
    let position = videoDevicePosition.flipped()
    
    guard let device = try? desiredDevice(withMediaType: AVMediaTypeVideo, position: position) else {
      DispatchQueue.main.async {
        errorHandler(CaptureManagerError.cameraToggleFailed)
      }
      return
    }
    
    if (device == videoDevice) {
      DispatchQueue.main.async {
        errorHandler(CaptureManagerError.cameraToggleFailed)
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
      } catch let error {
        DispatchQueue.main.async {
          errorHandler(error)
        }
      }
    }
    
  }
  
  /**
   Sets the `AVCaptureFlashMode` for `videoDevice`.
   - parameter mode: The `AVCaptureFlashMode` to set.
   - parameter errorHandler: A closure of type `Error -> Void` that is called on the **main thread** if an error occurs while setting the `AVCaptureFlashMode`.
   */
  public func setFlash(_ mode: AVCaptureFlashMode, errorHandler: ErrorCompletionHandler? = nil) throws {
    guard let videoDevice = videoDevice else {
      throw CaptureManagerError.missingVideoDevice
    }
    
    sessionQueue.async {
      do {
        try videoDevice.lockForConfiguration()
        if (!videoDevice.hasFlash || !videoDevice.isFlashAvailable) { throw CaptureManagerError.flashNotAvailable }
        if (!videoDevice.isFlashModeSupported(mode)) { throw CaptureManagerError.flashModeNotSupported }
        videoDevice.flashMode = mode
        videoDevice.unlockForConfiguration()
      }
      catch let error {
        DispatchQueue.main.async {
          errorHandler?(error)
        }
      }
    }
    
  }
  
  /**
   Toggles the `AVCaptureFlashMode` for `videoDevice`.
   - Important: If the current `AVCaptureFlashMode` is set to `.auto`, this will set it to `.on`.
  */
  public func toggleFlash(errorHandler: ErrorCompletionHandler? = nil) throws {
    return try setFlash(flashMode.flipped(), errorHandler: errorHandler)
  }
  
  /**
   Sets the `AVCaptureTorchMode` for `videoDevice`.
   - parameter mode: The `AVCaptureTorchMode` to set.
   - parameter errorHandler: A closure of type `Error -> Void` that is called on the **main thread** if an error occurs while setting the `AVCaptureTorchMode`.
   */
  public func setTorch(_ mode: AVCaptureTorchMode, errorHandler: ErrorCompletionHandler? = nil) throws {
    guard let videoDevice = videoDevice else {
      throw CaptureManagerError.missingVideoDevice
    }
    
    sessionQueue.async {
      do {
        try videoDevice.lockForConfiguration()
        if (!videoDevice.hasTorch || !videoDevice.isTorchAvailable) { throw CaptureManagerError.torchNotAvailable }
        if (!videoDevice.isTorchModeSupported(mode)) { throw CaptureManagerError.torchModeNotSupported }
        videoDevice.torchMode = mode
        videoDevice.unlockForConfiguration()
      }
      catch let error {
        DispatchQueue.main.async {
          errorHandler?(error)
        }
      }
    }
    
  }
  
  /**
   Toggles the `AVCaptureTorchMode` for `videoDevice`.
   - Important: If the current `AVCaptureTorchMode` is set to `.auto`, this will set it to `.on`.
   */
  public func toggleTorch(errorHandler: ErrorCompletionHandler? = nil) throws {
    return try setTorch(torchMode.flipped(), errorHandler: errorHandler)
  }
  
  /**
   Focuses the camera at `pointInView`.
   - parameter pointInView: The point inside of the `AVCaptureVideoPreviewLayer`.
   - parameter errorHandler: A closure of type `Error -> Void` that is called on the **main thread** if no device or previewLayerProvider was found or if we failed to lock the device for configuration.
   - Important: Do not normalize! This method handles the normalization for you. Simply pass in the point relative to the preview layer's coordinate system.
   */
  public func focusAndExposure(at pointInView: CGPoint, errorHandler: ErrorCompletionHandler? = nil) throws {
    guard let device = self.videoDevice else {
      throw CaptureManagerError.missingVideoDevice
    }
    
    guard let previewLayerProvider = previewLayerProvider else {
      throw CaptureManagerError.missingPreviewLayerProvider
    }
    
    let point = previewLayerProvider.previewLayer.pointForCaptureDevicePoint(ofInterest: pointInView)
    
    let isFocusSupported = device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus)
    let isExposureSupported = device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose)
    
    sessionQueue.async {
      do {
        try device.lockForConfiguration()
        if (isFocusSupported) {
          device.focusPointOfInterest = point
          device.focusMode = .autoFocus
        }
        if (isExposureSupported) {
          device.exposurePointOfInterest = point
          device.exposureMode = .autoExpose
        }
        device.unlockForConfiguration()
      } catch let error {
        DispatchQueue.main.async {
          errorHandler?(error)
        }
      }
      
    }
  }
  
  //MARK: AVCaptureVideoDataOutputSampleBufferDelegate
  
  public func captureOutput(_ captureOutput: AVCaptureOutput!,
                            didOutputSampleBuffer sampleBuffer: CMSampleBuffer!,
                            from connection: AVCaptureConnection!)
  {
    dataOutputDelegate?.captureManagerDidOutput(sampleBuffer)
  }
  
  //MARK: AVCaptureMetadataOutputObjectsDelegate
  
  public func captureOutput(_ captureOutput: AVCaptureOutput!,
                            didOutputMetadataObjects metadataObjects: [Any]!,
                            from connection: AVCaptureConnection!)
  {
    metadataOutputDelegate?.captureManagerDidOutput(metadataObjects: metadataObjects)
  }

  //MARK: Helpers
  
  /// Asynchronously refreshes the videoOrientation of the `AVCaptureVideoPreviewLayer`.
  public func refreshOrientation() {
    sessionQueue.async {
      self.previewLayerProvider?.previewLayer.connection.videoOrientation = self.desiredVideoOrientation
    }
  }
  
  /**
   Create `videoInput` and add it to `captureSession`.
   - Throws: `CaptureManagerError.invalidCaptureInput` if the input cannot be added to `captureSession`.
   */
  fileprivate func addVideoInput() throws {
    videoInput = try AVCaptureDeviceInput(device: videoDevice)
    try addCaptureInput(videoInput!)
  }
  
  /**
   Create `audioInput` and add it to `captureSession`.
   - Throws: `CaptureManagerError.invalidCaptureInput` if the input cannot be added to `captureSession`.
  */
  fileprivate func addAudioInput() throws {
    let audioDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
    audioInput = try AVCaptureDeviceInput(device: audioDevice)
    try addCaptureInput(audioInput!)
  }
  
  /**
   Add `input` to `captureSession`.
   - Throws: `CaptureManagerError.invalidCaptureInput` if the input cannot be added to `captureSession`.
   */
  fileprivate func addCaptureInput(_ input: AVCaptureInput) throws {
    if (!captureSession.canAddInput(input)) {
      throw CaptureManagerError.invalidCaptureInput
    }
    captureSession.addInput(input)
  }
  
  /**
   Create `stillImageoutput` and add it to `captureSession`.
   - Throws: `CaptureManagerError.invalidCaptureOutput` if the output cannot be added to `captureSession`.
   */
  fileprivate func addStillImageOutput() throws {
    stillImageOutput = AVCaptureStillImageOutput()
    stillImageOutput?.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
    try addCaptureOutput(stillImageOutput!)
  }
  
  /**
   Create `videoDataOutput` and add it to `captureSession`.
   - Throws: `CaptureManagerError.invalidCaptureOutput` if the output cannot be added to `captureSession`.
   */
  fileprivate func addVideoDataOutput() throws {
    videoDataOutput = AVCaptureVideoDataOutput()
    videoDataOutput?.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey): UInt(kCVPixelFormatType_32BGRA)]
    videoDataOutput?.setSampleBufferDelegate(self, queue: framesQueue)
    try addCaptureOutput(videoDataOutput!)
  }
  
  /**
   Create `movieFileOutput` and add it to `captureSession`.
   - Throws: `CaptureManagerError.invalidCaptureOutput` if the output cannot be added to `captureSession`.
   */
  fileprivate func addMovieFileOutput() throws {
    movieFileOutput = AVCaptureMovieFileOutput()
    try addCaptureOutput(movieFileOutput!)
  }
  
  /**
   Create `metadataOutput` and add it to `captureSession`.
   - Throws: `CaptureManagerError.invalidCaptureOutput` if the output cannot be added to `captureSession`.
   */
  fileprivate func addMetadataOutput(with types: [String]) throws {
    metadataOutput = AVCaptureMetadataOutput()
    metadataOutput?.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
    try addCaptureOutput(metadataOutput!)
    metadataOutput?.metadataObjectTypes = types
  }
  
  /**
   Add `output` to `captureSession`.
   - Throws: `CaptureManagerError.invalidCaptureOutput` if the output cannot be added to `captureSession`.
   */
  fileprivate func addCaptureOutput(_ output: AVCaptureOutput) throws {
    if (!captureSession.canAddOutput(output)) {
      throw CaptureManagerError.invalidCaptureOutput
    }
    captureSession.addOutput(output)
  }
  
  /**
   Set the sessionPreset for the AVCaptureSession.
   - Throws: `CaptureManager.invalidSessionPresent` if `sessionPreset` is not valid.
   */
  fileprivate func setSessionPreset(_ preset: String) throws {
    if !captureSession.canSetSessionPreset(preset) {
      throw CaptureManagerError.invalidSessionPreset
    }
    
    captureSession.sessionPreset = preset
  }
  
  /**
   Find the first `AVCaptureDevice` of type `type`. Return default device of type `type` if nil.
   
   - parameter type: The media type, such as AVMediaTypeVideo, AVMediaTypeAudio, or AVMediaTypeMuxed.
   - parameter position: The `AVCaptureDevicePosition`. If nil, `videoDevicePosition` is used.
   - Throws: `CaptureManagerError.invalidMediaType` if `type` is not a valid media type.
   - Returns: `AVCaptureDevice?`
   */
  fileprivate func desiredDevice(withMediaType type: String, position: AVCaptureDevicePosition? = nil) throws -> AVCaptureDevice? {
    guard let devices = AVCaptureDevice.devices(withMediaType: type) as? [AVCaptureDevice] else {
      throw CaptureManagerError.invalidMediaType
    }
    
    return devices.filter{$0.position == position ?? videoDevicePosition}.first ?? AVCaptureDevice.defaultDevice(withMediaType: type)
  }
  
}

protocol Flippable {
  mutating func flip()
  func flipped() -> Self
}

extension AVCaptureDevicePosition: Flippable {
  
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

extension AVCaptureFlashMode: Flippable {
  
  mutating func flip() {
    if (self == .on) {
      self = .off
    } else {
      self = .on
    }
  }
  
  internal func flipped() -> AVCaptureFlashMode {
    var copy = self
    copy.flip()
    return copy
  }
  
}

extension AVCaptureTorchMode: Flippable {
  
  mutating func flip() {
    if (self == .on) {
      self = .off
    } else {
      self = .on
    }
  }
  
  internal func flipped() -> AVCaptureTorchMode {
    var copy = self
    copy.flip()
    return copy
  }
  
}
