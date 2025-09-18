import Foundation

@propertyWrapper
internal final class Locked<Value> {
    private var value: Value

    internal var wrappedValue: Value {
        get {
            if Thread.isMainThread {
                return value
            }
            return DispatchQueue.main.sync {
                value
            }
        }
        set {
            if Thread.isMainThread {
                value = newValue
            } else {
                DispatchQueue.main.async {
                    self.value = newValue
                }
            }
        }
    }

    internal init(wrappedValue: Value) {
        self.value = wrappedValue
    }
}
