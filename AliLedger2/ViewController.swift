import UIKit
import WebKit

class ViewController: UIViewController, WKUIDelegate, WKScriptMessageHandler,
                      UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    private var webView: WKWebView!
    private var pendingFileCallback: (([URL]?) -> Void)?
    private let imagePicker = UIImagePickerController()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        loadHTML()
    }

    override var prefersStatusBarHidden: Bool { false }

    // MARK: - WebView Setup

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        // 注入 JS bridge，供前端调用 native 方法
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "nativeBridge")
        config.userContentController = userContentController

        config.allowsInlineMediaPlayback = true

        webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.bounces = false

        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // 适配 safe area — 设置 contentInset 为 0
        webView.scrollView.contentInsetAdjustmentBehavior = .never
    }

    private func loadHTML() {
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html") else {
            print("❌ index.html not found in bundle")
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    // MARK: - WKUIDelegate — 文件选择（相册/相机）

    @available(iOS 18.4, *)
    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        pendingFileCallback = completionHandler

        let alert = UIAlertController(title: "选择图片", message: nil, preferredStyle: .actionSheet)

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: "拍照", style: .default) { _ in
                self.openCamera()
            })
        }

        alert.addAction(UIAlertAction(title: "从相册选择", style: .default) { _ in
            self.openPhotoLibrary()
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
            completionHandler(nil)
            self.pendingFileCallback = nil
        })

        // iPad popover support
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        present(alert, animated: true)
    }

    // MARK: - Camera / Photo Library

    private func openCamera() {
        imagePicker.sourceType = .camera
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.cameraCaptureMode = .photo
        present(imagePicker, animated: true)
    }

    private func openPhotoLibrary() {
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        present(imagePicker, animated: true)
    }

    // MARK: - UIImagePickerControllerDelegate

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage else {
            pendingFileCallback?(nil)
            pendingFileCallback = nil
            return
        }

        // 保存到临时文件，供 WebView 使用
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("aliledger_\(UUID().uuidString).jpg")
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: tempURL)
        }

        // 返回文件 URL 给 WebView 的 input[type=file]
        pendingFileCallback?([tempURL])
        pendingFileCallback = nil

        // 同时调用 AI 识别
        recognizeImage(image)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        pendingFileCallback?(nil)
        pendingFileCallback = nil
    }

    // MARK: - AI Vision Recognition

    private func recognizeImage(_ image: UIImage) {
        // 获取用户分类列表
        webView.evaluateJavaScript(
            "(window.state && state.categories || []).map(function(c){return c.name})"
        ) { result, error in
            var userCategories: [String] = []
            if let arr = result as? [String] {
                userCategories = arr
            }

            VisionService.recognize(image: image, userCategories: userCategories) { jsonStr in
                DispatchQueue.main.async {
                    self.sendOcrResult(jsonStr)
                }
            }
        }
    }

    private func sendOcrResult(_ jsonString: String) {
        // 转义 JSON 字符串，安全注入 JS
        guard let escaped = jsonString.data(using: .utf8),
              let quoted = try? JSONEncoder().encode(String(data: escaped, encoding: .utf8) ?? ""),
              let quotedStr = String(data: quoted, encoding: .utf8) else {
            return
        }

        let js = "window.onNativeOcrResult && window.onNativeOcrResult(\(quotedStr));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - WKScriptMessageHandler (备用 JS bridge)

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // 预留给前端主动调用 native 功能
        print("📱 JS Bridge message: \(message.body)")
    }
}
