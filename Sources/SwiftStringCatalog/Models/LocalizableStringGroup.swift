//
//  Copyright © 2024 Hidden Spectrum, LLC.
//

import Foundation


public struct LocalizableStringGroup {

    // MARK: Public
    
    public let comment: String?
    public let extractionState: ExtractionState?
    public let strings: [LocalizableString]
    public let shouldTranslate: Bool?
    
    // MARK: Lifecycle

    init(
        comment: String?,
        extractionState: ExtractionState?,
        strings: [LocalizableString],
        shouldTranslate: Bool?
    ) {
        self.comment = comment
        self.extractionState = extractionState
        self.strings = strings
        self.shouldTranslate = shouldTranslate
    }
}
