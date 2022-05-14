import Foundation
import SwiftUI

public enum PresentationAction<DestinationAction> {
  case presented(DestinationAction)
  case onAppear
  case onDisappear
  // case task // maybe?
}

extension PresentationAction: Equatable where DestinationAction: Equatable {}

public struct Navigates<State, Action, Route, Destination: ReducerProtocol>: ReducerProtocol {
  let toRouteState: WritableKeyPath<State, Route?>
  let toDestinationState: CasePath<Route, Destination.State>
  let toDestinationAction: CasePath<Action, PresentationAction<Destination.Action>>
  let destination: Destination
  let onAppear: (inout Destination.State) -> Effect<Destination.Action, Never>
  let onDisappear: (inout Destination.State) -> Effect<Destination.Action, Never>
  
  public init(
    unwrapping toRouteState: WritableKeyPath<State, Route?>,
    case toDestinationState: CasePath<Route, Destination.State>,
    action toDestinationAction: CasePath<Action, PresentationAction<Destination.Action>>,
    @ReducerBuilderOf<Destination> destination: () -> Destination,
    onAppear: @escaping (inout Destination.State) -> Effect<Destination.Action, Never> = { _ in .none },
    onDisappear: @escaping (inout Destination.State) -> Effect<Destination.Action, Never> = { _ in .none }
  ) {
    self.toRouteState = toRouteState
    self.toDestinationState = toDestinationState
    self.toDestinationAction = toDestinationAction
    self.destination = destination()
    self.onAppear = onAppear
    self.onDisappear = onDisappear
  }
  
  var presentationReducer: some ReducerProtocol<Destination.State, PresentationAction<Destination.Action>> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        return self.onAppear(&state)
          .map(PresentationAction.presented)
      case .onDisappear:
        return self.onDisappear(&state)
          .map(PresentationAction.presented)
      case let .presented(action):
        return self.destination
          .reduce(into: &state, action: action)
          .map(PresentationAction.presented)
      }
    }
  }
  
  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    guard let destinationAction = toDestinationAction.extract(from: action)
    else { return .none }
    
    guard var routeValue = state[keyPath: toRouteState]
    else { return .none } // this should warn if route is nil
    
    guard var destinationState = toDestinationState.extract(from: routeValue)
    else { return .none } // this should warn if destination state is nil
    
    let effect = presentationReducer.reduce(into: &destinationState, action: destinationAction)
    routeValue = toDestinationState.embed(destinationState)
    state[keyPath: toRouteState] = routeValue
    
    return effect.map(toDestinationAction.embed)
  }
}

struct ExampleReducer: ReducerProtocol {
  struct State: Equatable {
    var route: Route? = nil
    
    enum Route: Equatable {
      case screenOne(ScreenOne.State)
      case screenTwo(ScreenTwo.State)
    }
  }
  
  enum Action: Equatable {
    case screenOne(PresentationAction<ScreenOne.Action>)
    case screenTwo(PresentationAction<ScreenTwo.Action>)
  }
  
  var body: some ReducerProtocol<State, Action> {
    Navigates(unwrapping: \.route, case: /State.Route.screenOne, action: /Action.screenOne) {
      ScreenOne()
    }
    Navigates(unwrapping: \.route, case: /State.Route.screenTwo, action: /Action.screenTwo) {
      ScreenTwo()
    }
  }
}

struct ScreenOne: ReducerProtocol {
  struct State: Equatable {
    let text: String
  }
  enum Action: Equatable {
    case stub
  }
  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    .none
  }
}

struct ScreenTwo: ReducerProtocol {
  struct State: Equatable{
    let text: String
  }
  enum Action: Equatable {
    case stub
  }
  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    .none
  }
}



struct ExampleView: View {
  var body: some View {
    Text("Hello World")
  }
}
