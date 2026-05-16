import Foundation

enum StatusItemDefaults {
    struct Key<Value> {
        let rawValue: String
        func stringKey(for autosaveName: String) -> String {
            "NSStatusItem \(rawValue) \(autosaveName)"
        }
    }

    static subscript<Value>(key: Key<Value>, autosaveName: String) -> Value? {
        get {
            let stringKey = key.stringKey(for: autosaveName)
            return UserDefaults.standard.object(forKey: stringKey) as? Value
        }
        set {
            let stringKey = key.stringKey(for: autosaveName)
            UserDefaults.standard.set(newValue, forKey: stringKey)
        }
    }
}

extension StatusItemDefaults.Key<CGFloat> {
    static let preferredPosition = Self(rawValue: "Preferred Position")
}

extension StatusItemDefaults.Key<Bool> {
    static let visible = Self(rawValue: "Visible")
}
