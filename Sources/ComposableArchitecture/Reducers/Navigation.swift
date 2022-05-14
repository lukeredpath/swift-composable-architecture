import Foundation
import SwiftUI

public enum PresentationAction<DestinationAction> {
  case presented(DestinationAction)
  case present
  case dismiss
}

extension PresentationAction: Equatable where DestinationAction: Equatable {}

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

extension Binding {
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
