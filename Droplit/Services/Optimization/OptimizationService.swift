import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct OptimizationResult {
    let outputURL: URL
    let originalBytes: Int64
    let optimizedBytes: Int64
    let pixelSize: CGSize?
}

struct OptimizationTool: Identifiable {
    let id: String
    let name: String
    let command: String
    let brewPackage: String
    let role: String
    let systemImage: String
    let projectURL: URL

    var isAvailable: Bool {
        OptimizationToolResolver.executable(named: command) != nil
    }

    static let catalog: [OptimizationTool] = [
        OptimizationTool(id: "pngquant", name: "pngquant", command: "pngquant", brewPackage: "pngquant", role: "PNG", systemImage: "photo", projectURL: URL(string: "https://github.com/kornelski/pngquant")!),
        OptimizationTool(id: "jpegoptim", name: "jpegoptim", command: "jpegoptim", brewPackage: "jpegoptim", role: "JPEG", systemImage: "camera", projectURL: URL(string: "https://github.com/tjko/jpegoptim")!),
        OptimizationTool(id: "gifsicle", name: "gifsicle", command: "gifsicle", brewPackage: "gifsicle", role: "GIF", systemImage: "sparkles", projectURL: URL(string: "https://github.com/kohler/gifsicle")!),
        OptimizationTool(id: "ffmpeg", name: "ffmpeg", command: "ffmpeg", brewPackage: "ffmpeg", role: "Video", systemImage: "video", projectURL: URL(string: "https://ffmpeg.org")!),
        OptimizationTool(id: "vips", name: "libvips", command: "vips", brewPackage: "vips", role: "Resize", systemImage: "arrow.down.right.and.arrow.up.left", projectURL: URL(string: "https://github.com/libvips/libvips")!),
        OptimizationTool(id: "gifski", name: "gifski", command: "gifski", brewPackage: "gifski", role: "Video to GIF", systemImage: "film.stack", projectURL: URL(string: "https://github.com/ImageOptim/gifski")!),
        OptimizationTool(id: "gs", name: "ghostscript", command: "gs", brewPackage: "ghostscript", role: "PDF", systemImage: "doc.richtext", projectURL: URL(string: "https://ghostscript.com")!)
    ]
}

enum OptimizationError: LocalizedError {
    case unsupportedType
    case missingTool(String)
    case commandFailed(String)
    case outputMissing

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "Unsupported file"
        case .missingTool(let tool):
            return "\(tool) not found"
        case .commandFailed(let message):
            return message.isEmpty ? "Optimizer failed" : message
        case .outputMissing:
            return "Output missing"
        }
    }
}

nonisolated enum OptimizationService {
    static func optimize(sourceURL: URL, kind: QuickAccessFileKind) async throws -> OptimizationResult {
        let task = Task.detached(priority: .userInitiated) {
            try optimizeSynchronously(sourceURL: sourceURL, kind: kind)
        }
        return try await withTaskCancellationHandler(operation: {
            try await task.value
        }, onCancel: {
            task.cancel()
        })
    }

    static func convert(sourceURL: URL, target: QuickAccessConversionTarget, mode: ConversionOutputMode) async throws -> OptimizationResult {
        let task = Task.detached(priority: .userInitiated) {
            try convertSynchronously(sourceURL: sourceURL, target: target, mode: mode)
        }
        return try await withTaskCancellationHandler(operation: {
            try await task.value
        }, onCancel: {
            task.cancel()
        })
    }

    private static func optimizeSynchronously(sourceURL: URL, kind: QuickAccessFileKind) throws -> OptimizationResult {
        guard kind.isSupported else { throw OptimizationError.unsupportedType }

        let originalBytes = fileSize(at: sourceURL)
        let outputURL = try makeOutputURL(for: sourceURL, kind: kind)

        switch kind {
        case .png:
            try runPNGQuant(sourceURL: sourceURL, outputURL: outputURL)
        case .jpeg:
            try runJPEGOptim(sourceURL: sourceURL, outputURL: outputURL)
        case .gif:
            try runGifsicle(sourceURL: sourceURL, outputURL: outputURL)
        case .video:
            try runFFmpeg(sourceURL: sourceURL, outputURL: outputURL)
        case .pdf:
            try runGhostscript(sourceURL: sourceURL, outputURL: outputURL)
        case .image:
            try runVips(sourceURL: sourceURL, outputURL: outputURL)
        case .unknown:
            throw OptimizationError.unsupportedType
        }

        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw OptimizationError.outputMissing
        }

        return OptimizationResult(
            outputURL: outputURL,
            originalBytes: originalBytes,
            optimizedBytes: fileSize(at: outputURL),
            pixelSize: NSImage(contentsOf: outputURL)?.pixelSizeForOptimization
        )
    }

    private static func convertSynchronously(sourceURL: URL, target: QuickAccessConversionTarget, mode: ConversionOutputMode) throws -> OptimizationResult {
        let sourceKind = QuickAccessFileKind.detect(from: sourceURL)
        guard QuickAccessConversionTarget.targets(for: sourceKind).contains(target) else {
            throw OptimizationError.unsupportedType
        }

        let originalBytes = fileSize(at: sourceURL)
        let outputURL = try makeOutputURL(
            for: sourceURL,
            target: target,
            mode: mode
        )

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        if target.isImageTarget {
            try runImageConversion(sourceURL: sourceURL, outputURL: outputURL, target: target)
        } else {
            try runVideoConversion(sourceURL: sourceURL, outputURL: outputURL, target: target)
        }

        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw OptimizationError.outputMissing
        }

        return OptimizationResult(
            outputURL: outputURL,
            originalBytes: originalBytes,
            optimizedBytes: fileSize(at: outputURL),
            pixelSize: NSImage(contentsOf: outputURL)?.pixelSizeForOptimization
        )
    }

    private static func runPNGQuant(sourceURL: URL, outputURL: URL) throws {
        let executable = try requiredExecutable("pngquant")
        do {
            try run(
                executable,
                arguments: [
                    "--force",
                    "--skip-if-larger",
                    "--quality", "65-95",
                    "--output", outputURL.path,
                    sourceURL.path
                ]
            )
        } catch {
            if !FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.copyItem(at: sourceURL, to: outputURL)
            }
            return
        }
        if !FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.copyItem(at: sourceURL, to: outputURL)
        }
    }

    private static func runJPEGOptim(sourceURL: URL, outputURL: URL) throws {
        let executable = try requiredExecutable("jpegoptim")
        try FileManager.default.copyItem(at: sourceURL, to: outputURL)
        try run(
            executable,
            arguments: [
                "--strip-all",
                "--max=85",
                outputURL.path
            ]
        )
    }

    private static func runGifsicle(sourceURL: URL, outputURL: URL) throws {
        let executable = try requiredExecutable("gifsicle")
        try run(
            executable,
            arguments: [
                "-O3",
                sourceURL.path,
                "-o",
                outputURL.path
            ]
        )
    }

    private static func runFFmpeg(sourceURL: URL, outputURL: URL) throws {
        let executable = try requiredExecutable("ffmpeg")
        try run(
            executable,
            arguments: [
                "-y",
                "-i", sourceURL.path,
                "-map_metadata", "-1",
                "-c:v", "libx264",
                "-preset", "medium",
                "-crf", "28",
                "-c:a", "aac",
                "-b:a", "128k",
                outputURL.path
            ]
        )
    }

    private static func runGhostscript(sourceURL: URL, outputURL: URL) throws {
        let executable = try requiredExecutable("gs")
        try run(
            executable,
            arguments: [
                "-sDEVICE=pdfwrite",
                "-dCompatibilityLevel=1.4",
                "-dPDFSETTINGS=/ebook",
                "-dNOPAUSE",
                "-dQUIET",
                "-dBATCH",
                "-sOutputFile=\(outputURL.path)",
                sourceURL.path
            ]
        )
    }

    private static func runVips(sourceURL: URL, outputURL: URL) throws {
        let executable = try requiredExecutable("vips")
        try run(
            executable,
            arguments: [
                "thumbnail",
                sourceURL.path,
                outputURL.path,
                "2560",
                "--size", "down"
            ]
        )
    }

    private static func runImageConversion(
        sourceURL: URL,
        outputURL: URL,
        target: QuickAccessConversionTarget
    ) throws {
        if target == .webp {
            try runVipsFormatConversion(sourceURL: sourceURL, outputURL: outputURL, target: target)
            return
        }

        guard let typeIdentifier = UTType(filenameExtension: target.fileExtension)?.identifier,
              let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, typeIdentifier as CFString, 1, nil) else {
            throw OptimizationError.commandFailed("\(target.displayName) conversion unavailable")
        }

        let options = imageConversionOptions(for: target)
        CGImageDestinationAddImageFromSource(destination, source, 0, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw OptimizationError.commandFailed("\(target.displayName) conversion failed")
        }
    }

    private static func runVipsFormatConversion(
        sourceURL: URL,
        outputURL: URL,
        target: QuickAccessConversionTarget
    ) throws {
        let executable = try requiredExecutable("vips")
        let outputPath: String

        switch target {
        case .webp:
            outputPath = "\(outputURL.path)[Q=92]"
        case .png, .jpeg, .heic, .gif, .mov, .mp4:
            outputPath = outputURL.path
        }

        try run(
            executable,
            arguments: [
                "copy",
                sourceURL.path,
                outputPath
            ]
        )
    }

    private static func runVideoConversion(
        sourceURL: URL,
        outputURL: URL,
        target: QuickAccessConversionTarget
    ) throws {
        switch target {
        case .gif:
            if QuickAccessFileKind.detect(from: sourceURL) == .gif {
                try runGifsicle(sourceURL: sourceURL, outputURL: outputURL)
            } else {
                try runVideoToGIFConversion(sourceURL: sourceURL, outputURL: outputURL)
            }
        case .mov, .mp4:
            try runFFmpegContainerConversion(sourceURL: sourceURL, outputURL: outputURL, target: target)
        case .png, .jpeg, .webp, .heic:
            throw OptimizationError.unsupportedType
        }
    }

    private static func runVideoToGIFConversion(sourceURL: URL, outputURL: URL) throws {
        if let executable = OptimizationToolResolver.executable(named: "gifski") {
            do {
                try run(
                    executable,
                    arguments: [
                        "--fps", "15",
                        "--width", "720",
                        "--quality", "82",
                        "--output", outputURL.path,
                        sourceURL.path
                    ]
                )
                return
            } catch {
                try? FileManager.default.removeItem(at: outputURL)
            }
        }

        try runFFmpegGIFConversion(sourceURL: sourceURL, outputURL: outputURL)
    }

    private static func runFFmpegGIFConversion(sourceURL: URL, outputURL: URL) throws {
        let executable = try requiredExecutable("ffmpeg")
        try run(
            executable,
            arguments: [
                "-y",
                "-i", sourceURL.path,
                "-filter_complex",
                "[0:v]fps=15,scale=720:-1:flags=lanczos:force_original_aspect_ratio=decrease,split[v0][v1];[v0]palettegen[p];[v1][p]paletteuse=dither=sierra2_4a[gif]",
                "-map", "[gif]",
                "-loop", "0",
                outputURL.path
            ]
        )
    }

    private static func runFFmpegContainerConversion(
        sourceURL: URL,
        outputURL: URL,
        target: QuickAccessConversionTarget
    ) throws {
        let executable = try requiredExecutable("ffmpeg")
        do {
            try run(
                executable,
                arguments: ffmpegRemuxArguments(sourceURL: sourceURL, outputURL: outputURL, target: target)
            )
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            try run(
                executable,
                arguments: ffmpegTranscodeArguments(sourceURL: sourceURL, outputURL: outputURL, target: target)
            )
        }
    }

    private static func makeOutputURL(for sourceURL: URL, kind: QuickAccessFileKind) throws -> URL {
        let pathExtension: String

        switch kind {
        case .video:
            pathExtension = "mp4"
        case .image:
            pathExtension = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        default:
            pathExtension = sourceURL.pathExtension
        }

        return try makeOutputURL(
            for: sourceURL,
            nameComponent: "optimized",
            pathExtension: pathExtension
        )
    }

    private static func makeOutputURL(
        for sourceURL: URL,
        nameComponent: String,
        pathExtension: String
    ) throws -> URL {
        let directory = try outputDirectory()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let suffix = UUID().uuidString.prefix(8)

        return directory
            .appendingPathComponent("\(baseName)-\(nameComponent)-\(suffix)")
            .appendingPathExtension(pathExtension)
    }

    private static func makeOutputURL(
        for sourceURL: URL,
        target: QuickAccessConversionTarget,
        mode: ConversionOutputMode
    ) throws -> URL {
        let directory = try outputDirectory()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent

        switch mode {
        case .replace:
            return directory
                .appendingPathComponent(baseName)
                .appendingPathExtension(target.fileExtension)
        case .duplicate:
            let suffix = UUID().uuidString.prefix(8)
            return directory
                .appendingPathComponent("\(baseName)-converted-\(target.fileExtension)-\(suffix)")
                .appendingPathExtension(target.fileExtension)
        }
    }

    private static func imageConversionOptions(for target: QuickAccessConversionTarget) -> [CFString: Any] {
        switch target {
        case .jpeg, .webp, .heic:
            return [kCGImageDestinationLossyCompressionQuality: 0.92]
        case .png, .gif, .mov, .mp4:
            return [:]
        }
    }

    private static func ffmpegRemuxArguments(
        sourceURL: URL,
        outputURL: URL,
        target: QuickAccessConversionTarget
    ) -> [String] {
        var arguments = [
            "-y",
            "-i", sourceURL.path,
            "-map", "0",
            "-map_metadata", "-1",
            "-c", "copy"
        ]
        if target == .mp4 {
            arguments += ["-movflags", "+faststart"]
        }
        arguments.append(outputURL.path)
        return arguments
    }

    private static func ffmpegTranscodeArguments(
        sourceURL: URL,
        outputURL: URL,
        target: QuickAccessConversionTarget
    ) -> [String] {
        var arguments = [
            "-y",
            "-i", sourceURL.path,
            "-map_metadata", "-1",
            "-c:v", "libx264",
            "-preset", "medium",
            "-crf", "20",
            "-pix_fmt", "yuv420p",
            "-c:a", "aac",
            "-b:a", "160k"
        ]
        if target == .mp4 {
            arguments += ["-movflags", "+faststart"]
        }
        arguments.append(outputURL.path)
        return arguments
    }

    private static func outputDirectory() throws -> URL {
        let destination = OptimizationOutputSettings.outputDestination
        switch destination.kind {
        case .userLocation:
            try FileManager.default.createDirectory(at: destination.directory, withIntermediateDirectories: true)
            return destination.directory
        case .temporary:
            return try OptimizationTemporaryFileStore.makeJobOutputDirectory()
        }
    }

    private static func requiredExecutable(_ name: String) throws -> URL {
        guard let url = OptimizationToolResolver.executable(named: name) else {
            throw OptimizationError.missingTool(name)
        }
        return url
    }

    private static func run(_ executableURL: URL, arguments: [String]) throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Droplit-Optimizer-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let logHandle = try FileHandle(forWritingTo: logURL)
        let outputHandle = FileHandle(forWritingAtPath: "/dev/null")
        defer {
            try? logHandle.close()
            try? outputHandle?.close()
            try? FileManager.default.removeItem(at: logURL)
        }

        process.standardError = logHandle
        if let outputHandle {
            process.standardOutput = outputHandle
        }

        try process.run()
        while process.isRunning {
            if Task.isCancelled {
                process.terminate()
                process.waitUntilExit()
                throw CancellationError()
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        guard process.terminationStatus == 0 else {
            try? logHandle.synchronize()
            let message = (try? String(contentsOf: logURL, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw OptimizationError.commandFailed(message)
        }
    }

    private static func fileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }
}

nonisolated enum OptimizationToolResolver {
    static let searchPaths = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/opt/homebrew/sbin",
        "/usr/local/sbin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin"
    ]

    static var pathEnvironmentValue: String {
        searchPaths.joined(separator: ":")
    }

    static func executable(named name: String) -> URL? {
        for directory in searchPaths {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }
}

struct HomebrewBootstrapResult {
    let requestedPackages: [String]
    let stillMissingTools: [OptimizationTool]

    var installedEverything: Bool {
        stillMissingTools.isEmpty
    }
}

struct HomebrewBootstrapProgress {
    enum Phase: Equatable {
        case preparing
        case installing
        case verifying
        case finished
    }

    let completedPackageCount: Int
    let totalPackageCount: Int
    let currentPackage: String?
    let phase: Phase

    var fractionCompleted: Double {
        guard totalPackageCount > 0 else { return 1 }
        let completed = Double(completedPackageCount)
        let total = Double(totalPackageCount)

        switch phase {
        case .preparing:
            return 0
        case .installing:
            return min(max((completed + 0.35) / total, 0.05), 0.95)
        case .verifying, .finished:
            return 1
        }
    }
}

typealias HomebrewBootstrapProgressHandler = (HomebrewBootstrapProgress) -> Void

enum HomebrewBootstrapError: LocalizedError {
    case homebrewMissing
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .homebrewMissing:
            return "Homebrew not found"
        case .installFailed(let message):
            return message.isEmpty ? "Homebrew install failed" : message
        }
    }
}

enum HomebrewBootstrapService {
    static var homebrewURL: URL? {
        OptimizationToolResolver.executable(named: "brew")
    }

    static var isHomebrewAvailable: Bool {
        homebrewURL != nil
    }

    static func missingTools() -> [OptimizationTool] {
        OptimizationTool.catalog.filter { !$0.isAvailable }
    }

    static func installMissingTools(
        progress: HomebrewBootstrapProgressHandler? = nil
    ) async throws -> HomebrewBootstrapResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try installMissingToolsSynchronously(progress: progress)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func installMissingToolsSynchronously(
        progress: HomebrewBootstrapProgressHandler?
    ) throws -> HomebrewBootstrapResult {
        let missingTools = missingTools()
        guard !missingTools.isEmpty else {
            progress?(
                HomebrewBootstrapProgress(
                    completedPackageCount: 0,
                    totalPackageCount: 0,
                    currentPackage: nil,
                    phase: .finished
                )
            )
            return HomebrewBootstrapResult(requestedPackages: [], stillMissingTools: [])
        }

        guard let homebrewURL else {
            throw HomebrewBootstrapError.homebrewMissing
        }

        let packages = Array(Set(missingTools.map(\.brewPackage))).sorted()
        progress?(
            HomebrewBootstrapProgress(
                completedPackageCount: 0,
                totalPackageCount: packages.count,
                currentPackage: nil,
                phase: .preparing
            )
        )

        for (index, package) in packages.enumerated() {
            progress?(
                HomebrewBootstrapProgress(
                    completedPackageCount: index,
                    totalPackageCount: packages.count,
                    currentPackage: package,
                    phase: .installing
                )
            )
            try runHomebrew(homebrewURL, arguments: ["install", package])
        }

        progress?(
            HomebrewBootstrapProgress(
                completedPackageCount: packages.count,
                totalPackageCount: packages.count,
                currentPackage: nil,
                phase: .verifying
            )
        )

        let stillMissingTools = self.missingTools()
        progress?(
            HomebrewBootstrapProgress(
                completedPackageCount: packages.count,
                totalPackageCount: packages.count,
                currentPackage: nil,
                phase: .finished
            )
        )

        return HomebrewBootstrapResult(
            requestedPackages: packages,
            stillMissingTools: stillMissingTools
        )
    }

    private static func runHomebrew(_ executableURL: URL, arguments: [String]) throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = OptimizationToolResolver.pathEnvironmentValue
        environment["HOMEBREW_NO_ENV_HINTS"] = "1"
        environment["NONINTERACTIVE"] = "1"
        process.environment = environment

        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Droplit-Homebrew-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let logHandle = try FileHandle(forWritingTo: logURL)
        defer {
            try? logHandle.close()
            try? FileManager.default.removeItem(at: logURL)
        }

        process.standardOutput = logHandle
        process.standardError = logHandle

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            try? logHandle.synchronize()
            let message = (try? String(contentsOf: logURL, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                ?? ""
            throw HomebrewBootstrapError.installFailed(message)
        }
    }
}

private nonisolated extension NSImage {
    var pixelSizeForOptimization: CGSize? {
        guard let representation = representations.max(by: { $0.pixelsWide < $1.pixelsWide }) else {
            return nil
        }
        return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
    }
}
