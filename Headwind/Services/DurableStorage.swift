import Foundation

/// Durable on-device storage for downloaded aeronautical data.
///
/// iOS purges `Caches/` under storage pressure — unacceptable for offline
/// charts and plates a pilot is counting on in the air. Everything the user
/// deliberately downloaded lives in Application Support instead, excluded
/// from iCloud backup (it's all re-downloadable public data).
enum DurableStorage {
    static func directory(_ name: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var dir = base.appendingPathComponent(name, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? dir.setResourceValues(values)
        }
        return dir
    }
}
