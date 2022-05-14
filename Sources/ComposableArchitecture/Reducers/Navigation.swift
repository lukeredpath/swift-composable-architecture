import Foundation
import SwiftUI

public enum PresentationAction<DestinationAction> {
  case presented(DestinationAction)
  case present
  case dismiss
  // case task // maybe?
}

extension PresentationAction: Equatable where DestinationAction: Equatable {}

public struct Navigates<Upstream: ReducerProtocol, Route, Destination: ReducerProtocol>: ReducerProtocol {
  let upstream: Upstream
  let toRouteState: WritableKeyPath<Upstream.State, Route?>
  let toDestinationState: CasePath<Route, Destination.State>
  let toPresentationAction: CasePath<Upstream.Action, PresentationAction<Destination.Action>>
  let destination: Destination
  let onDismiss: Destination.Action?
  
  public init(
    upstream: Upstream,
    unwrapping toRouteState: WritableKeyPath<Upstream.State, Route?>,
    case toDestinationState: CasePath<Route, Destination.State>,
    action toPresentationAction: CasePath<Upstream.Action, PresentationAction<Destination.Action>>,
    @ReducerBuilderOf<Destination> destination: () -> Destination,
    onDismiss: Destination.Action? = nil
  ) {
    self.upstream = upstream
    self.toRouteState = toRouteState
    self.toDestinationState = toDestinationState
    self.toPresentationAction = toPresentationAction
    self.destination = destination()
    self.onDismiss = onDismiss
  }
  
  var reducer: some ReducerProtocol<Upstream.State, Upstream.Action> {
    Pullback(state: self.toRouteState, action: self.toPresentationAction) {
      IfLetReducer {
        PullbackCase(state: self.toDestinationState, action: /PresentationAction.presented) {
          self.destination
        }
      }
    }
  }
  
  public func reduce(into state: inout Upstream.State, action: Upstream.Action) -> Effect<Upstream.Action, Never> {
    let previousRoute = state[keyPath: self.toRouteState]
    let previousTag = previousRoute.flatMap(self.toDestinationState.extract(from:)) != nil
      ? previousRoute.flatMap(enumTag)
      : nil
    
    var effects: [Effect<Action, Never>] = []
    effects.append(reducer.reduce(into: &state, action: action))
    
    let updatedDestinationState = state[keyPath: self.toRouteState]
      .flatMap(self.toDestinationState.extract(from:))
    
    effects.append(upstream.reduce(into: &state, action: action))
    
    let presentationAction = toPresentationAction.extract(from: action)
    
    if let route = state[keyPath: self.toRouteState],
       self.toDestinationState.extract(from: route) != nil,
       case .some(.dismiss) = presentationAction {
      state[keyPath: self.toRouteState] = nil
    }
    
    if let onDismiss = self.onDismiss,
       var finalDestinationState = updatedDestinationState,
       let previousTag = previousTag,
       previousTag != state[keyPath: self.toRouteState].flatMap(enumTag) {
      effects.append(
        self.destination
          .reduce(into: &finalDestinationState, action: onDismiss)
          .map(self.toPresentationAction.appending(path: /PresentationAction.presented).embed(_:))
      )
    }
    
    return .merge(effects)
  }
}

extension ReducerProtocol {
  public func navigates<Route, Destination: ReducerProtocol>(
    unwrapping toRouteState: WritableKeyPath<State, Route?>,
    case toDestinationState: CasePath<Route, Destination.State>,
    action toPresentationAction: CasePath<Action, PresentationAction<Destination.Action>>,
    onDismiss: Destination.Action? = nil,
    @ReducerBuilderOf<Destination> destination: () -> Destination
  ) -> Navigates<Self, Route, Destination> {
    Navigates(
      upstream: self,
      unwrapping: toRouteState,
      case: toDestinationState,
      action: toPresentationAction,
      destination: destination,
      onDismiss: onDismiss
    )
  }
}

private func enumTag<Case>(_ `case`: Case) -> UInt32? {
  let metadataPtr = unsafeBitCast(type(of: `case`), to: UnsafeRawPointer.self)
  let kind = metadataPtr.load(as: Int.self)
  let isEnumOrOptional = kind == 0x201 || kind == 0x202
  guard isEnumOrOptional else { return nil }
  let vwtPtr = (metadataPtr - MemoryLayout<UnsafeRawPointer>.size).load(as: UnsafeRawPointer.self)
  let vwt = vwtPtr.load(as: EnumValueWitnessTable.self)
  return withUnsafePointer(to: `case`) { vwt.getEnumTag($0, metadataPtr) }
}

private struct EnumValueWitnessTable {
  let f1, f2, f3, f4, f5, f6, f7, f8: UnsafeRawPointer
  let f9, f10: Int
  let f11, f12: UInt32
  let getEnumTag: @convention(c) (UnsafeRawPointer, UnsafeRawPointer) -> UInt32
  let f13, f14: UnsafeRawPointer
}

public struct NavigationLinkStore<DestinationState, DestinationAction, Destination: View, Label: View>: View {
  let store: Store<Bool, PresentationAction<DestinationAction>>
  let destination: Destination
  let label: Label
  
  public init<GlobalState, GlobalAction, Route, IfContent: View>(
    _ store: Store<GlobalState, GlobalAction>,
    unwrapping toRoute: KeyPath<GlobalState, Route?>,
    `case` toDestinationState: CasePath<Route, DestinationState>,
    action toGlobalAction: @escaping (PresentationAction<DestinationAction>) -> GlobalAction,
    destination: @escaping (Store<DestinationState, DestinationAction>) -> IfContent,
    @ViewBuilder label: @escaping () -> Label
  )
  where
    Destination == IfLetStore<DestinationState, DestinationAction, IfContent?>
  {
    self.store = store.scope(
      state: { $0[keyPath: toRoute].flatMap(toDestinationState.extract) != nil },
      action: toGlobalAction
    )
    self.destination = IfLetStore<DestinationState, DestinationAction, IfContent?>(
      store.scope(
        state: { $0[keyPath: toRoute] },
        action: toGlobalAction
      ).scope(
        state: { $0.flatMap(toDestinationState.extract) },
        action: PresentationAction.presented
      ),
      then: destination
    )
    self.label = label()
  }
  
  public var body: some View {
    WithViewStore(store) { viewStore in
      NavigationLink(
        destination: destination,
        isActive: viewStore.binding(
          send: { $0 ? .present : .dismiss }
        ).removeDuplicates(),
        label: { label }
      )
    }
  }
}

//public typealias NavigationLinkStoreOf<R: ReducerProtocol, Destination: View> = NavigationLinkStore<R.State, R.Action, Destination>

extension Binding {
  /// Creates a binding by projecting the base value to an unwrapped value.
  ///
  /// Useful for producing non-optional bindings from optional ones.
  ///
  /// See ``IfLet`` for a view builder-friendly version of this initializer.
  ///
  /// > Note: SwiftUI comes with an equivalent failable initializer, `Binding.init(_:)`, but using
  /// > it can lead to crashes at runtime. [Feedback][FB8367784] has been filed, but in the meantime
  /// > this initializer exists as a workaround.
  ///
  /// [FB8367784]: https://gist.github.com/stephencelis/3a232a1b718bab0ae1127ebd5fcf6f97
  ///
  /// - Parameter base: A value to project to an unwrapped value.
  /// - Returns: A new binding or `nil` when `base` is `nil`.
  public init?(unwrapping base: Binding<Value?>) {
    self.init(unwrapping: base, case: /Optional.some)
  }

  /// Creates a binding by projecting the base enum value to an unwrapped case.
  ///
  /// Useful for extracting bindings of non-optional state from the case of an enum.
  ///
  /// See ``IfCaseLet`` for a view builder-friendly version of this initializer.
  ///
  /// - Parameters:
  ///   - enum: An enum to project to a particular case.
  ///   - casePath: A case path that identifies a particular case to unwrap.
  /// - Returns: A new binding or `nil` when `base` is `nil`.
  public init?<Enum>(unwrapping enum: Binding<Enum>, case casePath: CasePath<Enum, Value>) {
    guard var `case` = casePath.extract(from: `enum`.wrappedValue)
    else { return nil }

    self.init(
      get: {
        `case` = casePath.extract(from: `enum`.wrappedValue) ?? `case`
        return `case`
      },
      set: {
        `case` = $0
        `enum`.transaction($1).wrappedValue = casePath.embed($0)
      }
    )
  }

  /// Creates a binding by projecting the current optional enum value to the value at a particular
  /// case.
  ///
  /// > Note: This method is constrained to optionals so that the projected value can write `nil`
  /// > back to the parent, which is useful for navigation, particularly dismissal.
  ///
  /// - Parameter casePath: A case path that identifies a particular case to unwrap.
  /// - Returns: A binding to an enum case.
  public func `case`<Enum, Case>(_ casePath: CasePath<Enum, Case>) -> Binding<Case?>
  where Value == Enum? {
    .init(
      get: { self.wrappedValue.flatMap(casePath.extract(from:)) },
      set: { newValue, transaction in
        self.transaction(transaction).wrappedValue = newValue.map(casePath.embed)
      }
    )
  }

  /// Creates a binding by projecting the current optional enum value to a boolean describing
  /// whether or not it matches the given case path.
  ///
  /// Writing `false` to the binding will `nil` out the base enum value. Writing `true` does
  /// nothing.
  ///
  /// Useful for interacting with APIs that take a binding of a boolean that you want to drive with
  /// with an enum case that has no associated data.
  ///
  /// For example, a view may model all of its presentations in a single route enum to prevent the
  /// invalid states that can be introduced by holding onto many booleans and optionals, instead.
  /// Even the simple case of two booleans driving two alerts introduces a potential runtime state
  /// where both alerts are presented at the same time. By modeling these alerts using a two-case
  /// enum instead of two booleans, we can eliminate this invalid state at compile time. Then we
  /// can transform a binding to the route enum into a boolean binding using `isPresent`, so that it
  /// can be passed to various presentation APIs.
  ///
  /// ```swift
  /// enum Route {
  ///   case deleteAlert
  ///   ...
  /// }
  ///
  /// struct ProductView: View {
  ///   @State var route: Route?
  ///   @State var product: Product
  ///
  ///   var body: some View {
  ///     Button("Delete") {
  ///       self.viewModel.route = .deleteAlert
  ///     }
  ///     // SwiftUI's vanilla alert modifier
  ///     .alert(
  ///       self.product.name
  ///       isPresented: self.$viewModel.route.isPresent(/Route.deleteAlert),
  ///       actions: {
  ///         Button("Delete", role: .destructive) {
  ///           self.viewModel.deleteConfirmationButtonTapped()
  ///         }
  ///       },
  ///       message: {
  ///         Text("Are you sure you want to delete this product?")
  ///       }
  ///     )
  ///   }
  /// }
  /// ```
  ///
  /// - Parameter casePath: A case path that identifies a particular case to match.
  /// - Returns: A binding to a boolean.
  public func isPresent<Enum, Case>(_ casePath: CasePath<Enum, Case>) -> Binding<Bool>
  where Value == Enum? {
    self.case(casePath).isPresent()
  }

  /// Creates a binding that ignores writes to its wrapped value when equivalent to the new value.
  ///
  /// Useful to minimize writes to bindings passed to SwiftUI APIs. For example, [`NavigationLink`
  /// may write `nil` twice][FB9404926] when dismissing its destination via the navigation bar's
  /// back button. Logic attached to this dismissal will execute twice, which may not be desirable.
  ///
  /// [FB9404926]: https://gist.github.com/mbrandonw/70df235e42d505b3b1b9b7d0d006b049
  ///
  /// - Parameter isDuplicate: A closure to evaluate whether two elements are equivalent, for
  ///   purposes of filtering writes. Return `true` from this closure to indicate that the second
  ///   element is a duplicate of the first.
  public func removeDuplicates(by isDuplicate: @escaping (Value, Value) -> Bool) -> Self {
    .init(
      get: { self.wrappedValue },
      set: { newValue, transaction in
        guard !isDuplicate(self.wrappedValue, newValue) else { return }
        self.transaction(transaction).wrappedValue = newValue
      }
    )
  }
}

extension Binding where Value: Equatable {
  /// Creates a binding that ignores writes to its wrapped value when equivalent to the new value.
  ///
  /// Useful to minimize writes to bindings passed to SwiftUI APIs. For example, [`NavigationLink`
  /// may write `nil` twice][FB9404926] when dismissing its destination via the navigation bar's
  /// back button. Logic attached to this dismissal will execute twice, which may not be desirable.
  ///
  /// [FB9404926]: https://gist.github.com/mbrandonw/70df235e42d505b3b1b9b7d0d006b049
  public func removeDuplicates() -> Self {
    self.removeDuplicates(by: ==)
  }
}
