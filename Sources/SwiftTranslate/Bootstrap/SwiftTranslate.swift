//
//  Copyright © 2024 Hidden Spectrum, LLC.
//

import ArgumentParser
import Foundation
import OpenAI
import SwiftStringCatalog


@main
struct SwiftTranslate: AsyncParsableCommand {
    
    // MARK: Command Line Options
    
    @Option(
        name: [.customLong("service"), .customShort("s")],
        help: "Service to use. Either `openai` (default) or `google`"
    )
    private var service: TranslationServiceArgument = .openAI

    @Option(
        name: [.customLong("api-key"), .customShort("k")],
        help: "OpenAI or Google Cloud Translate (v2) API key"
    )
    private var apiToken: String = ""

    @Option(
        name: [.customLong("model"), .customShort("m")],
        help: "OpenAI model to use. Either `gpt-3.5-turbo` (default) or `gpt-4o`. Ignored when using Google Translate"
    )
    private var model: OpenAIModel = .gpt3_5Turbo
    
    @OptionGroup(
        title: "Translate text"
    )
    private var textOptions: TextTranslationOptions
    
    @OptionGroup(
        title: "Translate string catalogs"
    )
    private var catalogOptions: CatalogTranslationOptions
    
    @Option(
        name: [.customLong("lang"), .short],
        parsing: .upToNextOption,
        help: "Target language(s) or `all` for all common languages. Omitting this option will use existing languages in the String Catalog(s)\n",
        completion: .list(Language.allCommon.map(\.rawValue))
    )
    private var languages: [Language] = [Language("__in_catalog")]
    
    @Flag(
        name: [.customLong("skip-confirmation"), .customShort("y")],
        help: "Skips confirmation for translating large string files"
    )
    var skipConfirmation: Bool = false
    
    @Option(
        name: [.customLong("retries"), .short],
        help: "Retries for OpenAI API requests in case of errors. Ignored when using Google Translate"
    )
    private var requestRetry: Int = 1

    @Option(
        name: [.customLong("timeout")],
        help: "Timeout interval for API requests"
    )
    private var timeoutInterval: Int = 60

    @Flag(
        name: [.long, .short],
        help: "Enables verbose log output"
    )
    private var verbose: Bool = false

    @Option(
        name: [.customLong("state")],
        help: "State that translated strings are set to. Either Service to use. Either `needsReview` (default) or `translated`"
    )
    private var state: SuccessfulTranslationState = .needsReview

    @Flag(
        name: [.customLong("store-key")],
        help: "Indicates that the API key should be stored for future use. Will stop after storage and will not process translations."
    )
    private var storeKey: Bool = false

    @Flag(
        name: [.customLong("delete-key")],
        help: "Indicates that the API key should be deleted. Will stop after deletion and will not process translations."
    )
    private var deleteKey: Bool = false

    // MARK: Private
    
    private static let languageList = [Language("all-common")] + Language.allCommon

    // MARK: Lifecycle
    
    func run() async throws {
        guard let translationState = TranslationState(rawValue: state.rawValue) else {
            throw ValidationError("Invalid translation state provided: \(state.rawValue)")
        }

        // Delete the API key, if requested
        if deleteKey {
            SecureStorage().deleteValue(for: service.rawValue)
            return
        }

        // Store the API key, if requested
        if storeKey {
            guard !apiToken.isEmpty else {
                throw ValidationError("Unable to store API Key. API Key is missing.")
            }
            SecureStorage().storeValue(apiToken, for: service.rawValue)
            return
        }

        // Validate API key. If not specified, check if we have one stored for this service.
        var apiToken = apiToken
        if apiToken.isEmpty {
            if let storedToken = SecureStorage().retrieveValue(type: String.self, for: service.rawValue) {
                apiToken = storedToken
            }
        }
        guard !apiToken.isEmpty else {
            throw ValidationError("API Key is missing")
        }

        var translator: TranslationService
        
        switch service {
        case .google:
            translator = GoogleTranslator(apiKey: apiToken, timeoutInterval: timeoutInterval)
        case .openAI:
            translator = OpenAITranslator(with: apiToken, model: model, timeoutInterval: timeoutInterval, retries: requestRetry)
        }
        
        var targetLanguages: Set<Language>?
        if languages.first?.rawValue == "__in_catalog" {
            targetLanguages = nil
        } else if languages.first?.rawValue == "all" {
            targetLanguages = Set(Language.allCommon)
        } else {
            let invalidLanguages = languages.filter({ !Language.allCommon.contains($0) }).map(\.rawValue)
            guard invalidLanguages.isEmpty else {
                throw ValidationError("Invalid language(s) provided: \(invalidLanguages.joined(separator: ", "))")
            }
            targetLanguages = Set(languages)
        }
        
        var mode: TranslationCoordinator.Mode
        if let text = textOptions.text {
            guard let targetLanguages else {
                throw ValidationError("Target language(s) is required for text translation")
            }
            mode = .text(text, targetLanguages)
        } else if let fileOrDirectory = catalogOptions.fileOrDirectory.first {
            if let unwrappedTargetLanguages = targetLanguages, !unwrappedTargetLanguages.contains(.english) {
                targetLanguages?.insert(.english)
            }
            mode = .fileOrDirectory(
                URL(fileURLWithPath: fileOrDirectory),
                targetLanguages,
                overwrite: catalogOptions.overwriteExisting
            )
        } else {
            throw ValidationError("No text or string catalog file to translate provided")
        }

        let coordinator = TranslationCoordinator(
            mode: mode,
            translator: translator,
            skipConfirmation: skipConfirmation,
            state: translationState,
            verbose: verbose
        )
        try await coordinator.translate()
    }
}


fileprivate struct TextTranslationOptions: ParsableArguments {
    
    @Option(
        name: [.long, .short],
        help: "Text to translate"
    )
    var text: String?
}

fileprivate struct CatalogTranslationOptions: ParsableArguments {
    
    @Flag(
        name: [.customLong("overwrite")],
        help: "Overwrite string catalog files instead of creating a new file"
    )
    var overwriteExisting: Bool = false
    
    @Argument(
        parsing: .remaining,
        help: "File or directory containing string catalogs to translate"
    )
    var fileOrDirectory: [String] = []
}

public enum SuccessfulTranslationState: String, Codable, Equatable, ExpressibleByArgument {
    case needsReview = "needs_review"
    case translated
}
