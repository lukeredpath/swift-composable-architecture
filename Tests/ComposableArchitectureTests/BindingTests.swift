#if compiler(>=5.4)
  import ComposableArchitecture
  import XCTest

  final class BindingTests: XCTestCase {
    func testNestedBindableState() {
      struct State: Equatable {
        @BindableState var nested = Nested()

        struct Nested: Equatable {
          var field = ""
        }
      }

      enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
      }

      let reducer = Reducer<State, Action, ()> { state, action, _ in
        switch action {
        case .binding(\.$nested.field):
          state.nested.field += "!"
          return .none
        default:
          return .none
        }
      }
      .binding()

      let store = Store(initialState: .init(), reducer: reducer, environment: ())

      let viewStore = ViewStore(store)

      viewStore.binding(\.$nested.field).wrappedValue = "Hello"

      XCTAssertNoDifference(viewStore.state, .init(nested: .init(field: "Hello!")))
    }

    func testBindingActionWithPullback() {
      struct State: Equatable {
        @BindableState var value: String
        var count: Int = 0

        var viewState: ViewState {
          get { .init(value: value) }
          set { value = newValue.value }
        }
      }

      enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
      }

      let reducer = Reducer<State, Action, ()> { state, action, _ in
        switch action {
        case .binding(\.$value):
          state.count += 1
          return .none
        default:
          return .none
        }
      }
      .binding()

      struct ViewState: Equatable {
        @BindableState var value: String
      }

      enum ViewAction: BindableAction, Equatable {
        case binding(BindingAction<ViewState>)
      }

      let store = Store(initialState: .init(value: "a"), reducer: reducer, environment: ())
      let viewStore = ViewStore(store)

      let childStore: Store<ViewState, ViewAction> = store.scope(
        state: \.viewState,
        action: { viewAction in
          switch viewAction {
          case let .binding(action):
            return .binding(action.pullback(\.viewState))
          }
        }
      )
      let childViewStore = ViewStore(childStore)

      viewStore.binding(\.$value).wrappedValue = "b"
      XCTAssertNoDifference(viewStore.state.value, "b")
      XCTAssertNoDifference(viewStore.count, 1)

      childViewStore.binding(\.$value).wrappedValue = "c"
      XCTAssertNoDifference(viewStore.state.value, "c")
      XCTAssertNoDifference(viewStore.count, 2)
    }
  }
#endif
