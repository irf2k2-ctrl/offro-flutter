import UserNotifications
import FirebaseMessaging

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
//   1. Reports delivery to Firebase Messaging (analytics)
//   2. Extracts the image URL from the payload
//   3. Validates it's HTTPS with a valid image extension
//   4. Downloads and attaches the image
//   5. Calls the content handler with the enriched content
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

        // 1. Report delivery to Firebase Messaging
        Messaging.messaging().appDidReceiveMessage(request.content)

        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        // 2. Extract image URL from multiple possible keys
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

        // 3. Validate URL: must be HTTPS with valid image extension
        guard let urlString = imageURLString,
              urlString.lowercased().hasPrefix("https://") else {
            // No valid image URL — deliver notification as-is
            contentHandler(bestAttemptContent)
            return
        }

        // Check for valid image extension
        let lowerURL = urlString.lowercased()
        let validExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic", ".bmp"]
        let hasValidExtension = validExtensions.contains { lowerURL.contains($0) }
        if !hasValidExtension {
            // URL might be a CDN URL without extension (e.g., Cloudinary with transforms)
            // Allow it through — the download will fail gracefully if it's not an image
            NSLog("[NOTIF-EXT] Image URL has no standard extension, attempting download anyway: %@", urlString)
        }

        // 4. Download and attach image
        guard let imageURL = URL(string: urlString) else {
            contentHandler(bestAttemptContent)
            return
        }

        NSLog("[NOTIF-EXT] Downloading image: %@", urlString)

        let task = URLSession.shared.downloadTask(with: imageURL) { [weak self]
            tempURL, response, error in
            guard let self = self else {
                contentHandler(bestAttemptContent)
                return
            }

            guard let tempURL = tempURL, error == nil else {
                NSLog("[NOTIF-EXT] Image download failed: %@", error?.localizedDescription ?? "unknown")
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
                NSLog("[NOTIF-EXT] Failed to move downloaded file: %@", error.localizedDescription)
                contentHandler(bestAttemptContent)
                return
            }

            // 5. Create notification attachment
            do {
                let attachment = try UNNotificationAttachment(
                    identifier: "offro-image",
                    url: fileURL,
                    options: [
                        UNNotificationAttachmentOptionsThumbnailHiddenKey: false,
                        UNNotificationAttachmentOptionsThumbnailClippingRectKey: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 0.5)
                    ]
                )
                bestAttemptContent.attachments = [attachment]
                NSLog("[NOTIF-EXT] ✅ Image attached successfully")
            } catch {
                NSLog("[NOTIF-EXT] Failed to create attachment: %@", error.localizedDescription)
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
            if contentType.contains("jpeg") || contentType.contains("jpg") { return "jpg" }
            if contentType.contains("png") { return "png" }
            if contentType.contains("gif") { return "gif" }
            if contentType.contains("webp") { return "webp" }
        }
        // Default
        return "jpg"
    }

    override func serviceExtensionTimeWillExpire() {
        // Called when the system gives us ~30 seconds total.
        // If the download hasn't finished, deliver what we have.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            NSLog("[NOTIF-EXT] Time expiring — delivering best attempt content")
            contentHandler(bestAttemptContent)
        }
    }
}
