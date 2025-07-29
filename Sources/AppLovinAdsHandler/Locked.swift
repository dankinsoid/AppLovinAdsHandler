import Foundation

@propertyWrapper
internal final class Locked<Value> {
    private let lock = NSLock()
    private var value: Value

    internal var wrappedValue: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            value = newValue
        }
    }

    internal init(wrappedValue: Value) {
        self.value = wrappedValue
    }
}