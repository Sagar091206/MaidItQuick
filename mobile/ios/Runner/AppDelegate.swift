import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentPickerDelegate {
  private let kycDocumentPickerChannel = "maiditquick/kyc_document_picker"
  private let textToSpeechChannel = "maiditquick/text_to_speech"
  private var pendingDocumentPickerResult: FlutterResult?
  private let speechSynthesizer = AVSpeechSynthesizer()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KycDocumentPicker") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: kycDocumentPickerChannel,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "pickDocument":
        self?.openDocumentPicker(result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let speechChannel = FlutterMethodChannel(
      name: textToSpeechChannel,
      binaryMessenger: registrar.messenger()
    )
    speechChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "speak":
        self?.speak(call, result)
      case "stop":
        self?.speechSynthesizer.stopSpeaking(at: .immediate)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func speak(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let text = arguments["text"] as? String,
          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      result(FlutterError(
        code: "INVALID_TEXT",
        message: "There is no consent text to play.",
        details: nil
      ))
      return
    }

    let languageCode = arguments["languageCode"] as? String ?? "en-IN"
    speechSynthesizer.stopSpeaking(at: .immediate)
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = speechVoice(for: languageCode)
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
    speechSynthesizer.speak(utterance)
    result(nil)
  }

  private func speechVoice(for languageCode: String) -> AVSpeechSynthesisVoice? {
    if languageCode.hasPrefix("mr") {
      return AVSpeechSynthesisVoice(language: "hi-IN") ??
        AVSpeechSynthesisVoice(language: languageCode) ??
        AVSpeechSynthesisVoice(language: "en-IN")
    }

    if let exact = AVSpeechSynthesisVoice(language: languageCode) {
      return exact
    }

    if languageCode.hasPrefix("bn") {
      return AVSpeechSynthesisVoice(language: "hi-IN")
    }

    return AVSpeechSynthesisVoice(language: "en-IN")
  }

  private func openDocumentPicker(_ result: @escaping FlutterResult) {
    guard pendingDocumentPickerResult == nil else {
      result(FlutterError(
        code: "PICKER_IN_PROGRESS",
        message: "A document picker is already open.",
        details: nil
      ))
      return
    }

    guard let presenter = topViewController() else {
      result(FlutterError(
        code: "NO_PRESENTER",
        message: "Could not open the document picker.",
        details: nil
      ))
      return
    }

    pendingDocumentPickerResult = result
    let picker = UIDocumentPickerViewController(
      documentTypes: ["com.adobe.pdf", "public.jpeg", "public.png"],
      in: .import
    )
    picker.delegate = self
    picker.allowsMultipleSelection = false
    presenter.present(picker, animated: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingDocumentPickerResult?(nil)
    pendingDocumentPickerResult = nil
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let result = pendingDocumentPickerResult else { return }
    pendingDocumentPickerResult = nil

    guard let url = urls.first else {
      result(nil)
      return
    }

    let accessed = url.startAccessingSecurityScopedResource()
    defer {
      if accessed {
        url.stopAccessingSecurityScopedResource()
      }
    }

    do {
      let values = try url.resourceValues(forKeys: [.nameKey])
      guard let mimeType = mimeType(for: url) else {
        result(FlutterError(
          code: "UNSUPPORTED_FILE",
          message: "Choose a PDF, JPG or PNG document.",
          details: nil
        ))
        return
      }

      let bytes = try Data(contentsOf: url)
      result([
        "name": values.name ?? url.lastPathComponent,
        "mimeType": mimeType,
        "bytes": FlutterStandardTypedData(bytes: bytes)
      ])
    } catch {
      result(FlutterError(
        code: "READ_FAILED",
        message: "Could not read the selected document.",
        details: error.localizedDescription
      ))
    }
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
    let root = scenes
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?
      .rootViewController
    return topViewController(from: root)
  }

  private func topViewController(from root: UIViewController?) -> UIViewController? {
    if let navigation = root as? UINavigationController {
      return topViewController(from: navigation.visibleViewController)
    }
    if let tab = root as? UITabBarController {
      return topViewController(from: tab.selectedViewController)
    }
    if let presented = root?.presentedViewController {
      return topViewController(from: presented)
    }
    return root
  }

  private func mimeType(for url: URL) -> String? {
    switch url.pathExtension.lowercased() {
    case "pdf":
      return "application/pdf"
    case "jpg", "jpeg":
      return "image/jpeg"
    case "png":
      return "image/png"
    default:
      return nil
    }
  }
}
