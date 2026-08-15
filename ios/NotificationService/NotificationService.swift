import UserNotifications

// ─────────────────────────────────────────────────────────────────
// OffrO Notification Service Extension
// ─────────────────────────────────────────────────────────────────
// Intercepts push notifications with mutable-content:1 and downloads
// the image attachment so iOS can display a rich notification with
// a large image on the lock screen and notification center.
//
// The backend sends:
//   apns.payload.aps.mutable-content = 1
//   apns.fcm_options.image = "https://..."
//   data.image_url = "https://..."
//
// This extension:
//   1. Extracts the image URL from the payload
//   2. Validates it's HTTPS
//   3. Downloads and attaches the image
//   4. Calls the content handler with the enriched content
// ─────────────────────────────────────────────────────────────────

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        // Extract image URL from multiple possible keys
        let userInfo = bestAttemptContent.userInfo
        var imageURLString: String?

        // FCM v1 format: fcm_options.image (nested dictionary)
        if let fcmOptions = userInfo["fcm_options"] as? [String: Any] {
            imageURLString = fcmOptions["image"] as? String
        }

        // FCM v1 format: fcm_options as a string (some FCM versions)
        if imageURLString == nil {
            imageURLString = userInfo["fcm_options"] as? String
        }

        // Custom data field from backend
        if imageURLString == nil {
            imageURLString = userInfo["image_url"] as? String
        }

        // Fallback: image key
        if imageURLString == nil {
            imageURLString = userInfo["image"] as? String
        }

        // Legacy GCM format
        if imageURLString == nil {
            if let gcmNotif = userInfo["gcm.notification"] as? [String: Any] {
                imageURLString = gcmNotif["image"] as? String
            }
        }

        // Validate URL: must be HTTPS
        guard let urlString = imageURLString,
              urlString.lowercased().hasPrefix("https://") else {
            contentHandler(bestAttemptContent)
            return
        }

        // Check for valid image extension
        let lowerURL = urlString.lowercased()
        let validExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic", ".bmp"]
        let hasValidExtension = validExtensions.contains { lowerURL.contains($0) }

        if !hasValidExtension {
            // URL might be a CDN URL without extension.
            // Allow it through — the download will fail gracefully if needed.
        }

        guard let imageURL = URL(string: urlString) else {
            contentHandler(bestAttemptContent)
            return
        }

        let task = URLSession.shared.downloadTask(with: imageURL) { [weak self] tempURL, response, error in
            guard let self = self else {
                contentHandler(bestAttemptContent)
                return
            }

            guard let tempURL = tempURL, error == nil else {
                contentHandler(bestAttemptContent)
                return
            }

            // Move temp file to a known location with proper extension
            let fileManager = FileManager.default
            let tempDir = fileManager.temporaryDirectory
            let fileExtension = self.extractExtension(from: urlString, response: response)
            let fileName = "notif_image_\(UUID().uuidString).\(fileExtension)"
            let fileURL = tempDir.appendingPathComponent(fileName)

            do {
                if fileManager.fileExists(atPath: fileURL.path) {
                    try fileManager.removeItem(at: fileURL)
                }
                try fileManager.moveItem(at: tempURL, to: fileURL)
            } catch {
                contentHandler(bestAttemptContent)
                return
            }

            // Create notification attachment
            do {
                let attachment = try UNNotificationAttachment(
                    identifier: "offro-image",
                    url: fileURL,
                    options: nil
                )

                bestAttemptContent.attachments = [attachment]
            } catch {
                // If attachment creation fails, deliver the normal notification.
            }

            contentHandler(bestAttemptContent)
        }

        task.resume()
    }

    /// Extract file extension from URL or response content-type
    private func extractExtension(from urlString: String, response: URLResponse?) -> String {
        // Try URL path extension first
        if let url = URL(string: urlString) {
            let pathExt = url.pathExtension.lowercased()
            if !pathExt.isEmpty {
                return pathExt
            }
        }

        // Fallback: content-type from response
        if let response = response as? HTTPURLResponse {
            let contentType = (response.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()

            if contentType.contains("jpeg") || contentType.contains("jpg") {
                return "jpg"
            }
            if contentType.contains("png") {
                return "png"
            }
            if contentType.contains("gif") {
                return "gif"
            }
            if contentType.contains("webp") {
                return "webp"
            }
        }

        return "jpg"
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler,
           let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
