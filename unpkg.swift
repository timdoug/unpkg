//
//  unpkg.swift
//  unpkg - Native macOS app for extracting installer packages
//

import SwiftUI
import Cocoa
import UniformTypeIdentifiers
import Foundation
import AppKit

// MARK: - App Entry Point

// Minimal app delegate to ensure app quits when last window is closed
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // Handle files opened by dropping onto app icon or double-clicking
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            let ext = url.pathExtension.lowercased()
            guard ext == "pkg" || ext == "mpkg" else { continue }

            // Post notification to ContentView to add file to queue
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenPackageFile"),
                object: nil,
                userInfo: ["url": url]
            )
        }
    }
}

@main
struct unpkgApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("unpkg") {
            ContentView()
                .frame(minWidth: 600, minHeight: 500)
                .handlesExternalEvents(preferring: Set(["*"]), allowing: Set(["*"]))
        }
        .handlesExternalEvents(matching: Set(["*"]))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenFileMenu"), object: nil)
                }
                .keyboardShortcut("O", modifiers: .command)
            }
        }
    }
}

// MARK: - UI Views

struct ContentView: View {
    @StateObject private var extractor = PackageExtractor.shared
    @State private var isDragTargeted = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Logo and drop area
            VStack(spacing: 20) {
                if let nsImage = NSImage(named: "AppIcon") ?? NSImage(named: "unpkg") {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                } else {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)
                }

                Text("Drop packages here")
                    .font(.headline)
                    .foregroundColor(isDragTargeted ? .accentColor : .secondary)

                Button("Browse Files...") {
                    selectFiles()
                }
                .buttonStyle(.bordered)
            }

            // Progress section
            if extractor.isExtracting {
                VStack(spacing: 10) {
                    ProgressView(value: extractor.progress)
                        .progressViewStyle(.linear)

                    Text(extractor.currentOperation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            // Queue status
            if !extractor.fileQueue.isEmpty {
                Text("Files in queue: \(extractor.fileQueue.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Results section
            if !extractor.extractionResults.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extraction Results:")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(extractor.extractionResults, id: \.self) { result in
                            ResultRow(result: result)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            Spacer()

            // Clear button
            if !extractor.extractionResults.isEmpty {
                Button("Clear Results") {
                    extractor.clearResults()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .padding(.bottom, 10)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isDragTargeted ? Color.accentColor.opacity(0.05) : Color.clear)
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted, perform: handleDrop)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenFileMenu"))) { _ in
            selectFiles()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenPackageFile"))) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                extractor.addFilesToQueue([url])
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var droppedURLs: [URL] = []
        let group = DispatchGroup()
        let lock = NSLock()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                defer { group.leave() }

                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      (url.pathExtension.lowercased() == "pkg" || url.pathExtension.lowercased() == "mpkg") else { return }

                lock.lock()
                droppedURLs.append(url)
                lock.unlock()
            }
        }

        group.notify(queue: .main) {
            extractor.addFilesToQueue(droppedURLs)
        }

        return true
    }

    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "pkg") ?? .package,
            UTType(filenameExtension: "mpkg") ?? .package
        ]
        panel.message = "Select package files to extract"

        if panel.runModal() == .OK {
            extractor.addFilesToQueue(panel.urls)
        }
    }
}

struct ResultRow: View {
    let result: ExtractionResult

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text(result.packageName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Text(result.success
                    ? "Extracted to: \(result.extractionPath ?? "")"
                    : result.error ?? "Unknown error")
                    .font(.system(size: 11))
                    .foregroundColor(result.success ? .secondary : .red)
                    .lineLimit(result.success ? 1 : 2)
            }

            Spacer()

            if result.success, let path = result.extractionPath {
                Button {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                } label: {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Show in Finder")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

// MARK: - Package Extraction Logic

struct ExtractionResult: Hashable {
    let packageName: String
    let success: Bool
    let extractionPath: String?
    let error: String?
}

@MainActor
class PackageExtractor: ObservableObject {
    static let shared = PackageExtractor()

    @Published var isExtracting = false
    @Published var progress: Double = 0.0
    @Published var currentOperation = ""
    @Published var extractionResults: [ExtractionResult] = []
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var fileQueue: [URL] = []

    private var isProcessingQueue = false
    private let fileManager = FileManager.default

    private init() {}

    // MARK: - Public Methods

    func extractPackage(at url: URL) async {
        isExtracting = true
        progress = 0.0
        currentOperation = "Preparing to extract \(url.lastPathComponent)..."

        do {
            let result = try await performExtraction(url: url)
            extractionResults.append(result)
        } catch {
            let result = ExtractionResult(
                packageName: url.lastPathComponent,
                success: false,
                extractionPath: nil,
                error: error.localizedDescription
            )
            extractionResults.append(result)
            errorMessage = error.localizedDescription
            showError = true
        }

        isExtracting = false
        progress = 1.0
        currentOperation = ""
    }

    func clearResults() {
        extractionResults.removeAll()
        errorMessage = ""
        showError = false
    }

    func addFilesToQueue(_ urls: [URL]) {
        for url in urls where !fileQueue.contains(url) {
            fileQueue.append(url)
        }

        if !isProcessingQueue {
            processQueue()
        }
    }

    private func processQueue() {
        guard !isProcessingQueue && !fileQueue.isEmpty else { return }

        isProcessingQueue = true

        Task {
            while !fileQueue.isEmpty {
                let url = fileQueue.removeFirst()
                await extractPackage(at: url)
            }
            isProcessingQueue = false
        }
    }

    // MARK: - Private Methods

    private func performExtraction(url: URL) async throws -> ExtractionResult {
        // Check if file is readable
        guard fileManager.isReadableFile(atPath: url.path) else {
            throw ExtractionError.fileNotReadable(url.lastPathComponent)
        }

        // Determine extraction directory
        let extractDir = try getExtractionDirectory(for: url)
        currentOperation = "Extracting to \(extractDir.lastPathComponent)..."

        // Check if it's a metapackage
        if url.pathExtension.lowercased() == "mpkg" {
            try await extractMetapackage(url: url, to: extractDir)
        } else {
            // Determine package type and extract
            let isNewStyle = try isNewStylePackage(url: url)
            if isNewStyle {
                try await extractNewStylePackage(url: url, to: extractDir)
            } else {
                try await extractOldStylePackage(url: url, to: extractDir)
            }
        }

        return ExtractionResult(
            packageName: url.lastPathComponent,
            success: true,
            extractionPath: extractDir.path,
            error: nil
        )
    }

    private func getExtractionDirectory(for packageURL: URL) throws -> URL {
        let packageName = packageURL.deletingPathExtension().lastPathComponent
        var baseDir = packageURL.deletingLastPathComponent()

        // Check if source directory is writable, if not use Desktop
        if !fileManager.isWritableFile(atPath: baseDir.path) {
            baseDir = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first!
        }

        var extractDir = baseDir.appendingPathComponent(packageName)
        var suffix = 1

        // Handle naming collisions
        while fileManager.fileExists(atPath: extractDir.path) && suffix < 1000 {
            extractDir = baseDir.appendingPathComponent("\(packageName)-\(suffix)")
            suffix += 1
        }

        if suffix >= 1000 {
            throw ExtractionError.tooManyCollisions(packageName)
        }

        try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true, attributes: nil)
        return extractDir
    }

    private func isNewStylePackage(url: URL) throws -> Bool {
        // Check for xar archive format by reading first 4 bytes
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { fileHandle.closeFile() }

        let data = fileHandle.readData(ofLength: 4)
        guard data.count == 4 else { return false }

        // Check for "xar!" magic bytes
        let magic = String(data: data, encoding: .utf8)
        return magic == "xar!"
    }

    private func extractNewStylePackage(url: URL, to extractDir: URL) async throws {
        progress = 0.2
        currentOperation = "Extracting package metadata..."

        // Create temp directory for xar extraction
        let tempDir = try createTempDirectory()
        defer { try? fileManager.removeItem(at: tempDir) }

        // Extract with xar
        try await runCommand(
            "/usr/bin/xar",
            arguments: ["-xf", url.path],
            workingDirectory: tempDir
        )

        progress = 0.4
        currentOperation = "Processing package contents..."

        // Find and extract all Payload files
        let payloadFiles = try findPayloadFiles(in: tempDir)
        let totalPayloads = Double(payloadFiles.count)

        for (index, payloadFile) in payloadFiles.enumerated() {
            progress = 0.4 + (0.5 * Double(index) / totalPayloads)
            currentOperation = "Extracting \(payloadFile.lastPathComponent)..."

            let isGzipped = payloadFile.lastPathComponent.hasSuffix(".gz") ||
                           payloadFile.lastPathComponent.hasSuffix(".gzip")

            if isGzipped {
                // Use gzcat | cpio pipeline
                try await runPipedCommand(
                    command1: "/usr/bin/gzcat",
                    args1: [payloadFile.path],
                    command2: "/usr/bin/cpio",
                    args2: ["-idm"],
                    workingDirectory: extractDir
                )
            } else {
                // Direct cpio extraction
                try await runCommand(
                    "/usr/bin/cpio",
                    arguments: ["-idm"],
                    workingDirectory: extractDir,
                    inputFile: payloadFile
                )
            }
        }

        progress = 0.9
    }

    private func extractOldStylePackage(url: URL, to extractDir: URL) async throws {
        progress = 0.3
        currentOperation = "Extracting old-style package..."

        // Find pax files
        let paxFiles = try findPaxFiles(in: url)

        let totalPax = Double(paxFiles.count)
        for (index, paxFile) in paxFiles.enumerated() {
            progress = 0.3 + (0.6 * Double(index) / totalPax)
            currentOperation = "Extracting \(paxFile.lastPathComponent)..."

            let isGzipped = paxFile.pathExtension == "gz"

            if isGzipped {
                // Use gzcat | pax pipeline
                try await runPipedCommand(
                    command1: "/usr/bin/gzcat",
                    args1: [paxFile.path],
                    command2: "/bin/pax",
                    args2: ["-r"],
                    workingDirectory: extractDir
                )
            } else {
                // Direct pax extraction
                try await runCommand(
                    "/bin/pax",
                    arguments: ["-r", "-f", paxFile.path],
                    workingDirectory: extractDir
                )
            }
        }

        progress = 0.9
    }

    private func extractMetapackage(url: URL, to extractDir: URL) async throws {
        progress = 0.1
        currentOperation = "Processing metapackage..."

        // Find all .pkg files in the metapackage
        let packages = try findPackagesInMetapackage(url: url)
        let totalPackages = Double(packages.count)

        for (index, package) in packages.enumerated() {
            progress = Double(index) / totalPackages
            currentOperation = "Extracting \(package.lastPathComponent)..."

            let packageDir = extractDir.appendingPathComponent(package.deletingPathExtension().lastPathComponent)
            try fileManager.createDirectory(at: packageDir, withIntermediateDirectories: true, attributes: nil)

            let isNewStyle = try isNewStylePackage(url: package)
            if isNewStyle {
                try await extractNewStylePackage(url: package, to: packageDir)
            } else {
                try await extractOldStylePackage(url: package, to: packageDir)
            }
        }

        progress = 0.9
    }

    // MARK: - Helper Methods

    private func createTempDirectory() throws -> URL {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        return tempDir
    }

    private func findPayloadFiles(in directory: URL) throws -> [URL] {
        var payloadFiles: [URL] = []
        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil)

        while let fileURL = enumerator?.nextObject() as? URL {
            let fileName = fileURL.lastPathComponent
            if fileName.hasPrefix("Payload") || fileName == "Payload.cpio" ||
               fileName == "Payload.cpio.gz" || fileName == "Payload.cpio.gzip" {
                payloadFiles.append(fileURL)
            }
        }

        return payloadFiles.sorted { $0.path < $1.path }
    }

    private func findPaxFiles(in packageURL: URL) throws -> [URL] {
        var paxFiles: [URL] = []

        // Check Contents directory
        let contentsURL = packageURL.appendingPathComponent("Contents")
        guard fileManager.fileExists(atPath: contentsURL.path) else {
            throw ExtractionError.invalidPackageFormat("No Contents directory found")
        }

        let enumerator = fileManager.enumerator(at: contentsURL, includingPropertiesForKeys: nil)

        while let fileURL = enumerator?.nextObject() as? URL {
            let fileName = fileURL.lastPathComponent
            if fileName.hasSuffix(".pax") || fileName.hasSuffix(".pax.gz") {
                paxFiles.append(fileURL)
            }
        }

        if paxFiles.isEmpty {
            throw ExtractionError.invalidPackageFormat("No pax files found in package")
        }

        return paxFiles.sorted { $0.path < $1.path }
    }

    private func findPackagesInMetapackage(url: URL) throws -> [URL] {
        var packages: [URL] = []
        let contentsURL = url.appendingPathComponent("Contents/Packages")

        guard fileManager.fileExists(atPath: contentsURL.path) else {
            throw ExtractionError.invalidPackageFormat("No Packages directory in metapackage")
        }

        let contents = try fileManager.contentsOfDirectory(at: contentsURL, includingPropertiesForKeys: nil)
        for item in contents {
            if item.pathExtension == "pkg" {
                packages.append(item)
            }
        }

        if packages.isEmpty {
            throw ExtractionError.invalidPackageFormat("No packages found in metapackage")
        }

        return packages.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func runCommand(_ command: String, arguments: [String], workingDirectory: URL? = nil, inputFile: URL? = nil) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        if let inputFile = inputFile {
            process.standardInput = try FileHandle(forReadingFrom: inputFile)
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ExtractionError.commandFailed(command, errorString)
        }
    }

    private func runPipedCommand(command1: String, args1: [String], command2: String, args2: [String], workingDirectory: URL) async throws {
        // Create processes
        let process1 = Process()
        process1.executableURL = URL(fileURLWithPath: command1)
        process1.arguments = args1

        let process2 = Process()
        process2.executableURL = URL(fileURLWithPath: command2)
        process2.arguments = args2
        process2.currentDirectoryURL = workingDirectory

        // Create pipe to connect them
        let pipe = Pipe()
        process1.standardOutput = pipe
        process2.standardInput = pipe

        // Error pipes
        let errorPipe1 = Pipe()
        let errorPipe2 = Pipe()
        process1.standardError = errorPipe1
        process2.standardError = errorPipe2

        // Start both processes
        try process1.run()
        try process2.run()

        // Wait for completion
        process1.waitUntilExit()
        process2.waitUntilExit()

        // Check for errors
        if process1.terminationStatus != 0 {
            let errorData = errorPipe1.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ExtractionError.commandFailed(command1, errorString)
        }

        if process2.terminationStatus != 0 {
            let errorData = errorPipe2.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ExtractionError.commandFailed(command2, errorString)
        }
    }
}

// MARK: - Error Types

enum ExtractionError: LocalizedError {
    case fileNotReadable(String)
    case invalidPackageFormat(String)
    case tooManyCollisions(String)
    case commandFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .fileNotReadable(let file):
            return "Cannot read file: \(file)"
        case .invalidPackageFormat(let message):
            return "Invalid package format: \(message)"
        case .tooManyCollisions(let name):
            return "Too many naming collisions for: \(name)"
        case .commandFailed(let command, let error):
            return "Command failed: \(command)\nError: \(error)"
        }
    }
}