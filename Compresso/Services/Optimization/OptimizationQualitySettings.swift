//
//  OptimizationQualitySettings.swift
//  Compresso
//
//  User-configurable quality parameters for optimization tools.
//

import Foundation

nonisolated enum OptimizationQualitySettings {
    private static let imageQualityKey = "optimization.imageQuality"
    private static let videoQualityKey = "optimization.videoQuality"

    static let allowedImageQualityRange = 10...100
    static let allowedVideoQualityRange = 18...51

    /// Image quality setting (10–100). Used by pngquant, jpegoptim, vips, gifski.
    /// Higher values produce better quality and larger files.
    static var imageQuality: Int {
        get {
            let saved = UserDefaults.standard.integer(forKey: imageQualityKey)
            return saved > 0 ? clampImageQuality(saved) : 85
        }
        set {
            UserDefaults.standard.set(clampImageQuality(newValue), forKey: imageQualityKey)
        }
    }

    /// Video quality CRF value (18–51). Used by ffmpeg.
    /// Lower values produce better quality and larger files.
    static var videoQuality: Int {
        get {
            let saved = UserDefaults.standard.integer(forKey: videoQualityKey)
            return saved > 0 ? clampVideoQuality(saved) : 28
        }
        set {
            UserDefaults.standard.set(clampVideoQuality(newValue), forKey: videoQualityKey)
        }
    }

    // MARK: - PNG quality range for pngquant

    /// Returns the `--quality` range string for pngquant (e.g. "65-95").
    static var pngQualityRange: String {
        let q = imageQuality
        let minQ = max(q - 20, 0)
        return "\(minQ)-\(q)"
    }

    // MARK: - Clamping

    static func clampImageQuality(_ value: Int) -> Int {
        min(max(value, allowedImageQualityRange.lowerBound), allowedImageQualityRange.upperBound)
    }

    static func clampVideoQuality(_ value: Int) -> Int {
        min(max(value, allowedVideoQualityRange.lowerBound), allowedVideoQualityRange.upperBound)
    }
}
