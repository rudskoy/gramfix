//
//  HubApi+default.swift
//  Clipsa
//
//  Default HubApi configuration for MLX model downloading
//

import Foundation
@preconcurrency import Hub

/// Extension providing a default HubApi instance for downloading model files
extension HubApi {
    /// Default HubApi instance configured to download models to Application Support
    /// under 'Clipsa/Models' subdirectory.
    #if os(macOS)
        static let `default` = HubApi(
            downloadBase: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Clipsa/Models", isDirectory: true)
        )
    #else
        static let `default` = HubApi(
            downloadBase: URL.cachesDirectory.appending(path: "huggingface")
        )
    #endif
}
