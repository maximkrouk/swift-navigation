package struct UncheckedSendable<Value>: @unchecked Sendable {
  package var value: Value

  package init(_ value: Value) {
    self.value = value
  }

  package var wrappedValue: Value {
    _read { yield value }
    _modify { yield &value }
  }
}
