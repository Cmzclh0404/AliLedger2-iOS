import UIKit
import CommonCrypto

struct VisionService {

    private static let apiKeyId = "6eced589da5f46b2807f4653b677466a"
    private static let apiKeySecret = "w4NCTQKnL25tjjfF"
    private static let apiUrl = "https://open.bigmodel.cn/api/paas/v4/chat/completions"
    private static let model = "glm-4v-flash"

    // MARK: - Public API

    static func recognize(
        image: UIImage,
        userCategories: [String] = [],
        completion: @escaping (String) -> Void
    ) {
        let scaled = scaleDown(image)
        guard let base64 = imageToBase64(scaled) else {
            completion("{\"amount\":0,\"merchant\":\"图片处理失败\",\"date\":\"\",\"category\":\"其他\"}")
            return
        }
        sendToAI(base64Image: base64, userCategories: userCategories, completion: completion)
    }

    // MARK: - Image Processing

    private static func scaleDown(_ image: UIImage) -> UIImage {
        let maxDim: CGFloat = 1024
        let currentMax = max(image.size.width, image.size.height)
        guard currentMax > maxDim else { return image }
        let scale = maxDim / currentMax
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resized
    }

    private static func imageToBase64(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        return data.base64EncodedString()
    }

    // MARK: - JWT Token Generation

    private static func generateToken() -> String {
        // Header
        let headerDict: [String: Any] = ["alg": "HS256", "sign_type": "SIGN"]
        let headerData = try! JSONSerialization.data(withJSONObject: headerDict)
        let headerB64 = headerData.base64URLEncodedString()

        // Payload
        let now = Int(Date().timeIntervalSince1970 * 1000)
        let payloadDict: [String: Any] = [
            "api_key": apiKeyId,
            "exp": now + 3600 * 1000,
            "timestamp": now
        ]
        let payloadData = try! JSONSerialization.data(withJSONObject: payloadDict)
        let payloadB64 = payloadData.base64URLEncodedString()

        // Sign
        let content = "\(headerB64).\(payloadB64)"
        let sign = hmacSHA256(content: content, key: apiKeySecret)
        let signB64 = sign.base64URLEncodedString()

        return "\(content).\(signB64)"
    }

    private static func hmacSHA256(content: String, key: String) -> Data {
        let contentData = Data(content.utf8)
        let keyData = Data(key.utf8)
        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        contentData.withUnsafeBytes { contentBytes in
            keyData.withUnsafeBytes { keyBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                       keyBytes.baseAddress, keyData.count,
                       contentBytes.baseAddress, contentData.count,
                       &hmac)
            }
        }
        return Data(hmac)
    }

    // MARK: - API Request

    private static func sendToAI(
        base64Image: String,
        userCategories: [String],
        completion: @escaping (String) -> Void
    ) {
        let allCats = userCategories.isEmpty
            ? "餐饮、交通、购物、娱乐、日用、其他"
            : userCategories.joined(separator: "、")

        let systemPrompt = """
        严格只输出一行JSON对象，不要任何其他文字、不要markdown、不要解释。
        格式：{"amount":数字,"merchant":"商户名","date":"YYYY-MM-DD HH:mm","category":"分类"}
        category必须是以下之一：\(allCats)
        判断规则：餐饮=吃喝外卖；交通=打车地铁加油高铁机票；购物=网购百货数码服装；娱乐=电影游戏KTV旅游住宿酒店宾馆；日用=超市便利店水电话费；其他=都不符合
        重点：酒店宾馆住宿相关一律选"住宿"分类（如果有该分类的话）。
        """

        let catHint = userCategories.isEmpty ? "" : "可用分类：\(userCategories.joined(separator: "、"))"
        let userText = "这是消费凭证照片，请识别金额、商户、日期、分类。\(catHint) 分类必须从上述列表中选一个最匹配的。"

        // Build request JSON
        let imageContent: [String: Any] = [
            "type": "image_url",
            "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]
        ]
        let textContent: [String: Any] = [
            "type": "text",
            "text": userText
        ]

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": [imageContent, textContent]]
            ],
            "max_tokens": 1024
        ]

        guard let url = URL(string: apiUrl),
              let bodyData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion("{\"amount\":0,\"merchant\":\"请求构建失败\",\"date\":\"\",\"category\":\"其他\"}")
            return
        }

        let token = generateToken()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        request.timeoutInterval = 30

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ VisionService request failed: \(error.localizedDescription)")
                completion("{\"amount\":0,\"merchant\":\"网络异常\",\"date\":\"\",\"category\":\"其他\"}")
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                completion("{\"amount\":0,\"merchant\":\"识别失败(\(code))\",\"date\":\"\",\"category\":\"其他\"}")
                return
            }

            print("🤖 VisionService raw: \(content.prefix(500))")
            let result = extractJson(from: content, userCategories: userCategories)
            completion(result)
        }.resume()
    }

    // MARK: - JSON Extraction

    private static func extractJson(from text: String, userCategories: [String]) -> String {
        let standardCats = ["餐饮", "交通", "购物", "娱乐", "日用", "其他"]

        func matchCategory(_ raw: String) -> String? {
            if let found = userCategories.first(where: { raw.contains($0) }) { return found }
            if let found = standardCats.first(where: { raw.contains($0) }) { return found }
            return nil
        }

        // Try extracting from markdown code block
        var raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = text.range(of: "```(?:json)?\\s*([\\s\\S]*?)```", options: .regularExpression) {
            raw = String(text[range])
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try parsing as JSON
        if let data = raw.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

            let amount: Double = {
                if let a = obj["amount"] as? Double { return abs(a) }
                if let a = obj["amount"] as? Int { return abs(Double(a)) }
                if let a = obj["金额"] as? String,
                   let val = Double(a.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                    return abs(val)
                }
                return 0
            }()

            let merchant = (obj["merchant"] as? String) ?? (obj["商户"] as? String) ?? ""

            let date: String = {
                if let d = obj["date"] as? String { return d }
                if let d = obj["日期"] as? String {
                    return d.replacingOccurrences(of: "年", with: "-")
                        .replacingOccurrences(of: "月", with: "-")
                        .replacingOccurrences(of: "日", with: " ")
                        .trimmingCharacters(in: .whitespaces)
                }
                return ""
            }()

            let category: String = {
                if let c = obj["category"] as? String {
                    return matchCategory(c) ?? inferCategory(merchant)
                }
                if let c = obj["分类"] as? String {
                    return matchCategory(c) ?? inferCategory(merchant)
                }
                return inferCategory(merchant)
            }()

            let result: [String: Any] = [
                "amount": amount,
                "merchant": merchant,
                "date": date,
                "category": category
            ]
            if let d = try? JSONSerialization.data(withJSONObject: result),
               let s = String(data: d, encoding: .utf8) {
                return s
            }
        }

        // Fallback: regex extraction
        let amount = extractAmount(from: text)
        let merchant = extractField(from: text, keys: ["商户名称", "商户", "店名", "商家"])
        let date = extractField(from: text, keys: ["日期", "时间"])
        let rawCat = extractField(from: text, keys: ["分类"])
        let category = matchCategory(rawCat) ?? inferCategory(merchant)

        let result: [String: Any] = [
            "amount": amount,
            "merchant": merchant,
            "date": date,
            "category": category
        ]
        if let d = try? JSONSerialization.data(withJSONObject: result),
           let s = String(data: d, encoding: .utf8) {
            return s        }
        return "{\"amount\":0,\"merchant\":\"\",\"date\":\"\",\"category\":\"其他\"}"
    }

    private static func extractAmount(from text: String) -> Double {
        let patterns = [
            "(?:金额|实付|合计|总计|total|paid)[：: ]*([\\d.]+)",
            "([\\d.]+)\\s*元"
        ]
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                let match = String(text[range])
                if let val = Double(match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                    return abs(val)
                }
            }
        }
        return 0
    }

    private static func extractField(from text: String, keys: [String]) -> String {
        for key in keys {
            let pattern = "\(NSRegularExpression.escapedPattern(for: key))[\\s*：:]+(.+)"
            if let range = text.range(of: pattern, options: .regularExpression) {
                var value = String(text[range])
                    .replacingOccurrences(of: key, with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: " ：:*"))
                value = value.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces) ?? value
                if !value.isEmpty { return value }
            }
        }
        return ""
    }

    private static func inferCategory(_ merchant: String) -> String {
        let m = merchant.lowercased()
        let rules: [(keywords: [String], category: String)] = [
            (["滴滴","地铁","高铁","加油","停车","公交","机票","出行","打车"], "交通"),
            (["淘宝","京东","拼多多","天猫","百货","商场","购物","数码","服装"], "购物"),
            (["超市","便利店","屈臣氏","水电","话费","充值","沃尔玛","永辉"], "日用"),
            (["茶","餐","饭","面","鸡","锅","烤","奶茶","咖啡","外卖","肯德基","麦当劳","星巴克","瑞幸","喜茶","火锅","烧烤"], "餐饮"),
            (["电影","ktv","游戏","steam","游乐","演出","摄影","美容","美发"], "娱乐"),
            (["酒店","住宿","宾馆","民宿"], "娱乐")
        ]
        for rule in rules {
            if rule.keywords.contains(where: { m.contains($0) }) {
                return rule.category
            }
        }
        return "其他"
    }
}

// MARK: - Data Extension for Base64URL

extension Data {
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
