#if swift(>=6)
  import SwiftNavigation
  import XCTest

  class IsolationTests: XCTestCase {
    func testIsolationOnMainActor() async throws {
      try await Task { @MainActor in
        let model = MainActorModel()
        var didObserve = false
        let token = SwiftNavigation.observe {
          _ = model.count
          MainActor.assertIsolated()
          didObserve = true
        }
        model.count += 1
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(didObserve, true)
        _ = token

        withActorProxy { @MainActor in
          MainActor.assertIsolated()
        }

        withActorProxy { @GlobalActorIsolated in
          GlobalActorIsolated.assertIsolated()
        }

        withActorProxy {
          MainActor.assertIsolated()
        }
        try await Task.sleep(nanoseconds: 300_000_000)

      }
      .value

    }

    func testIsolationOnGlobalActor() async throws {
      try await Task { @GlobalActorIsolated in
        let model = GlobalActorModel()
        var didObserve = false
        let token = SwiftNavigation.observe {
          _ = model.count
          GlobalActorIsolated.assertIsolated()
          didObserve = true
        }
        model.count += 1
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(didObserve, true)
        _ = token

        withActorProxy { @MainActor in // override isolation
          MainActor.assertIsolated()
        }

        withActorProxy { @GlobalActorIsolated in // override with the same isolation
          GlobalActorIsolated.assertIsolated()
        }

        withActorProxy { // inherit isolation
          GlobalActorIsolated.assertIsolated()
        }
        try await Task.sleep(nanoseconds: 300_000_000)
      }
      .value
    }
  }

  @globalActor private actor GlobalActorIsolated: GlobalActor {
    static let shared = GlobalActorIsolated()
  }

  @Perceptible
  @MainActor
  class MainActorModel {
    var count = 0
  }

  @Perceptible
  @GlobalActorIsolated
  private class GlobalActorModel {
    var count = 0
  }

  func removeIsolation(_ f: @escaping @Sendable () -> Void) -> @Sendable () -> Void {
    return f
  }

  func withActorProxy(
    @_inheritActorContext
    perform operation: @escaping @isolated(any) @Sendable () -> Void
  ) {
    let actor = ActorProxy(base: operation.isolation)
    Task {
      await actor.perform {
        removeIsolation(operation)()
      }
    }
  }

  private actor ActorProxy {
    let base: (any Actor)?
    init(base: (any Actor)?) {
      self.base = base
    }
    nonisolated var unownedExecutor: UnownedSerialExecutor {
      (base ?? MainActor.shared).unownedExecutor
    }
    func perform(_ operation: @Sendable () -> Void) {
      operation()
    }
  }
#endif
