import Flutter
import UIKit
import AVFoundation
import MobileCoreServices
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentPickerDelegate {
  private let documentChannelName = "maiditquick/kyc_document_picker"
  private let speechChannelName = "maiditquick/text_to_speech"
  private var pendingDocumentResult: FlutterResult?
  private let speechSynthesizer = AVSpeechSynthesizer()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()

    let documentChannel = FlutterMethodChannel(name: documentChannelName, binaryMessenger: messenger)
    documentChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "pickDocument":
        self?.pickDocument(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let speechChannel = FlutterMethodChannel(name: speechChannelName, binaryMessenger: messenger)
    speechChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "speak":
        let args = call.arguments as? [String: Any]
        let text = (args?["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let languageCode = (args?["languageCode"] as? String) ?? "en-IN"
        self?.speak(text: text, languageCode: languageCode)
        result(nil)
      case "stop":
        self?.speechSynthesizer.stopSpeaking(at: .immediate)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Document picker

  private func pickDocument(result: @escaping FlutterResult) {
    guard pendingDocumentResult == nil else {
      result(FlutterError(code: "PICKER_IN_PROGRESS", message: "A document picker is already open.", details: nil))
      return
    }
    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      picker = UIDocumentPickerViewController(
        forOpeningContentTypes: [.pdf, .jpeg, .png]
      )
    } else {
      picker = UIDocumentPickerViewController(
        documentTypes: [kUTTypePDF as String, kUTTypeJPEG as String, kUTTypePNG as String],
        in: .import
      )
    }
    picker.delegate = self
    pendingDocumentResult = result
    topViewController()?.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pendingDocumentResult else { return }
    pendingDocumentResult = nil
    guard let url = urls.first else {
      result(nil)
      return
    }
    do {
      let data = try Data(contentsOf: url, options: [.mappedIfSafe])
      let response: [String: Any] = [
        "name": url.lastPathComponent,
        "mimeType": mimeTypeFor(url) ?? "application/octet-stream",
        "bytes": FlutterStandardTypedData(bytes: data),
      ]
      result(response)
    } catch {
      result(FlutterError(code: "READ_FAILED", message: "Could not read the selected document.", details: nil))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingDocumentResult?(nil)
    pendingDocumentResult = nil
  }

  private func mimeTypeFor(_ url: URL) -> String? {
    let ext = url.pathExtension.lowercased()
    if #available(iOS 14.0, *) {
      guard let type = UTType(filenameExtension: ext) else { return nil }
      if type.conforms(to: .pdf) { return "application/pdf" }
      if type.conforms(to: .jpeg) { return "image/jpeg" }
      if type.conforms(to: .png) { return "image/png" }
      return nil
    }
    switch ext {
    case "pdf": return "application/pdf"
    case "jpg", "jpeg": return "image/jpeg"
    case "png": return "image/png"
    default: return nil
    }
  }

  // MARK: - Text to speech

  private func speak(text: String, languageCode: String) {
    guard !text.isEmpty else { return }
    speechSynthesizer.stopSpeaking(at: .immediate)
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: localeFor(languageCode))
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
    speechSynthesizer.speak(utterance)
  }

  private func localeFor(_ languageCode: String) -> String {
    let code = languageCode.lowercased()
    if code.hasPrefix("mr") || code.hasPrefix("bn") {
      // Fall back to Hindi when Marathi/Bengali voices are unavailable.
      return "hi-IN"
    }
    if code.hasPrefix("hi") {
      return "hi-IN"
    }
    return "en-IN"
  }

  private func topViewController() -> UIViewController? {
    guard var top = window?.rootViewController else { return nil }
    while let presented = top.presentedViewController {
      top = presented
    }
    return top
  }
}
