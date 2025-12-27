//
//  HubApi+default.swift
//  Gramfix
//
//  Default HubApi configuration for MLX model downloading
//

import Foundation
@preconcurrency import Hub

/// Extension providing a default HubApi instance for downloading model files
extension HubApi {
    /// Default HubApi instance configured to download models to Application Support
    /// under 'Gramfix/Models' subdirectory.
    #if os(macOS)
        static let `default` = HubApi(
            downloadBase: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Gramfix/Models", isDirectory: true)
        )
    #else
        static let `default` = HubApi(
            downloadBase: URL.cachesDirectory.appending(path: "huggingface")
        )
    #endif
}
