import Combine
@_spi(Internals) import ComposableArchitecture
import XCTest

@MainActor
final class CancellationHandlingTests: BaseTCATestCase {
  struct CancellingReducer: ReducerProtocol {
    let effect: () async throws -> Void
    
    struct State: Equatable {
      var isEffectInFlight: Bool = false
    }
    enum Action: Equatable {
      case startEffect
      case cancelEffect
      case effectFinished
      case effectCancelled
    }
    
    enum CancellationId {}
    
    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
      switch action {
      case .startEffect:
        state.isEffectInFlight = true
        return .run { send in
          do {
            try await withTaskCancellation(id: CancellationId.self) {
              try await self.effect()
              await send(.effectFinished)
            }
          } catch is CancellationError {
            await send(.effectCancelled)
            throw CancellationError()
          }
        }
      case .effectFinished, .effectCancelled:
        state.isEffectInFlight = false
        return .none
      case .cancelEffect:
        return .cancel(id: CancellationId.self)
      }
    }
  }
  
  func testEffectCancellationError() async {
    let store = TestStore(
      initialState: CancellingReducer.State(),
      reducer: CancellingReducer {
        throw CancellationError()
      }
    )
    await store.send(.startEffect) {
      $0.isEffectInFlight = true
    }
    await store.receive(.effectCancelled) {
      $0.isEffectInFlight = false
    }
  }
  
  func testEffectExplicitCancellation() async {
    let scheduler = DispatchQueue.test
    let store = TestStore(
      initialState: CancellingReducer.State(),
      reducer: CancellingReducer {
        try await scheduler.sleep(for: .seconds(1))
      }
    )
    await store.send(.startEffect) {
      $0.isEffectInFlight = true
    }
    await store.send(.cancelEffect)
    await store.receive(.effectCancelled) {
      $0.isEffectInFlight = false
    }
  }
  
  func testEffectTaskCancellation() async {
    let scheduler = DispatchQueue.test
    let store = TestStore(
      initialState: CancellingReducer.State(),
      reducer: CancellingReducer {
        try await scheduler.sleep(for: .seconds(1))
      }
    )
    let task = await store.send(.startEffect) {
      $0.isEffectInFlight = true
    }
    await task.cancel()
    await store.receive(.effectCancelled) {
      $0.isEffectInFlight = false
    }
  }
}
