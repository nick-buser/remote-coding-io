import SwiftUI

extension Theme {
    /// Semantic state colors. These are constants — they communicate
    /// state, not project / feature accent. Both light and dark modes
    /// use identical values per the design.
    enum Semantic {
        static let green = Theme.srgb(52/255, 199/255, 89/255)
        static let orange = Theme.srgb(255/255, 149/255, 0/255)
        static let red = Theme.srgb(255/255, 59/255, 48/255)
        static let yellow = Theme.srgb(255/255, 204/255, 0/255)
    }
}
