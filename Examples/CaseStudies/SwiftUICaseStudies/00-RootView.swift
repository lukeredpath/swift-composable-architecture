import Combine
import ComposableArchitecture
import SwiftUI

struct RootView: View {
  let store: StoreOf<Root>

  var body: some View {
    WithViewStore(self.store.stateless) { viewStore in
      NavigationView {
        Form {
          Section(header: Text("Getting started")) {
            NavigationLink(
              "Basics",
              destination: CounterDemoView(
                store: self.store.scope(
                  state: \.counter,
                  action: Root.Action.counter
                )
              )
            )

            NavigationLink(
              "Pullback and combine",
              destination: TwoCountersView(
                store: self.store.scope(
                  state: \.twoCounters,
                  action: Root.Action.twoCounters
                )
              )
            )

            NavigationLink(
              "Bindings",
              destination: BindingBasicsView(
                store: self.store.scope(
                  state: \.bindingBasics,
                  action: Root.Action.bindingBasics
                )
              )
            )

            #if compiler(>=5.4)
              NavigationLink(
                "Form bindings",
                destination: BindingFormView(
                  store: self.store.scope(
                    state: \.bindingForm,
                    action: Root.Action.bindingForm
                  )
                )
              )
            #endif

            NavigationLink(
              "Optional state",
              destination: OptionalBasicsView(
                store: self.store.scope(
                  state: \.optionalBasics,
                  action: Root.Action.optionalBasics
                )
              )
            )

            NavigationLink(
              "Shared state",
              destination: SharedStateView(
                store: self.store.scope(
                  state: \.shared,
                  action: Root.Action.shared
                )
              )
            )

//            NavigationLink(
//              "Alerts and Confirmation Dialogs",
//              destination: AlertAndConfirmationDialogView(
//                store: self.store.scope(
//                  state: \.alertAndConfirmationDialog,
//                  action: Root.Action.alertAndConfirmationDialog
//                )
//              )
//            )
            
            NavigationLinkStore(
              store,
              unwrapping: \.route,
              case: /Root.State.Route.alertAndConfirmationDialog,
              action: Root.Action.alertAndConfirmationDialog,
              destination: AlertAndConfirmationDialogView.init
            ) {
              Text("Alerts and Confirmation Dialogs")
            }

            #if compiler(>=5.5)
              NavigationLink(
                "Focus State",
                destination: FocusDemoView(
                  store: self.store.scope(
                    state: \.focusDemo,
                    action: Root.Action.focusDemo
                  )
                )
              )
            #endif

//            NavigationLink(
//              "Animations",
//              destination: AnimationsView(
//                store: self.store.scope(
//                  state: \.animation,
//                  action: Root.Action.animation
//                )
//              )
//            )
            
            NavigationLinkStore(
              store,
              unwrapping: \.route,
              case: /Root.State.Route.animation,
              action: Root.Action.animation,
              destination: AnimationsView.init
            ) {
              Text("Animations")
            }
          }

          Section(header: Text("Effects")) {
            NavigationLink(
              "Basics",
              destination: EffectsBasicsView(
                store: self.store.scope(
                  state: \.effectsBasics,
                  action: Root.Action.effectsBasics
                )
              )
            )

            NavigationLink(
              "Cancellation",
              destination: EffectsCancellationView(
                store: self.store.scope(
                  state: \.effectsCancellation,
                  action: Root.Action.effectsCancellation)
              )
            )

            NavigationLink(
              "Long-living effects",
              destination: LongLivingEffectsView(
                store: self.store.scope(
                  state: \.longLivingEffects,
                  action: Root.Action.longLivingEffects
                )
              )
            )

            #if compiler(>=5.5)
              NavigationLink(
                "Refreshable",
                destination: RefreshableView(
                  store: self.store.scope(
                    state: \.refreshable,
                    action: Root.Action.refreshable
                  )
                )
              )
            #endif

            NavigationLink(
              "Timers",
              destination: TimersView(
                store: self.store.scope(
                  state: \.timers,
                  action: Root.Action.timers
                )
              )
            )

            NavigationLink(
              "System environment",
              destination: MultipleDependenciesView(
                store: self.store.scope(
                  state: \.multipleDependencies,
                  action: Root.Action.multipleDependencies
                )
              )
            )

            NavigationLink(
              "Web socket",
              destination: WebSocketView(
                store: self.store.scope(
                  state: \.webSocket,
                  action: Root.Action.webSocket
                )
              )
            )
          }

          Section(header: Text("Navigation")) {
            NavigationLink(
              "Navigate and load data",
              destination: NavigateAndLoadView(
                store: self.store.scope(
                  state: \.navigateAndLoad,
                  action: Root.Action.navigateAndLoad
                )
              )
            )

            NavigationLink(
              "Load data then navigate",
              destination: LoadThenNavigateView(
                store: self.store.scope(
                  state: \.loadThenNavigate,
                  action: Root.Action.loadThenNavigate
                )
              )
            )

            NavigationLink(
              "Lists: Navigate and load data",
              destination: NavigateAndLoadListView(
                store: self.store.scope(
                  state: \.navigateAndLoadList,
                  action: Root.Action.navigateAndLoadList
                )
              )
            )

            NavigationLink(
              "Lists: Load data then navigate",
              destination: LoadThenNavigateListView(
                store: self.store.scope(
                  state: \.loadThenNavigateList,
                  action: Root.Action.loadThenNavigateList
                )
              )
            )

            NavigationLink(
              "Sheets: Present and load data",
              destination: PresentAndLoadView(
                store: self.store.scope(
                  state: \.presentAndLoad,
                  action: Root.Action.presentAndLoad
                )
              )
            )

            NavigationLink(
              "Sheets: Load data then present",
              destination: LoadThenPresentView(
                store: self.store.scope(
                  state: \.loadThenPresent,
                  action: Root.Action.loadThenPresent
                )
              )
            )
          }

          Section(header: Text("Higher-order reducers")) {
            NavigationLink(
              "Reusable favoriting component",
              destination: EpisodesView(
                store: self.store.scope(
                  state: \.episodes,
                  action: Root.Action.episodes
                )
              )
            )

            NavigationLink(
              "Reusable offline download component",
              destination: CitiesView(
                store: self.store.scope(
                  state: \.map,
                  action: Root.Action.map
                )
              )
            )

            NavigationLink(
              "Lifecycle",
              destination: LifecycleDemoView(
                store: self.store.scope(
                  state: \.lifecycle,
                  action: Root.Action.lifecycle
                )
              )
            )

            NavigationLink(
              "Strict reducers",
              destination: DieRollView(
                store: self.store.scope(
                  state: \.dieRoll,
                  action: Root.Action.dieRoll
                )
              )
            )

            NavigationLink(
              "Elm-like subscriptions",
              destination: ClockView(
                store: self.store.scope(
                  state: \.clock,
                  action: Root.Action.clock
                )
              )
            )

            NavigationLink(
              "Recursive state and actions",
              destination: NestedView(
                store: self.store.scope(
                  state: \.nested,
                  action: Root.Action.nested
                )
              )
            )
          }
        }
        .navigationBarTitle("Case Studies")
        .onAppear { viewStore.send(.onAppear) }
      }
    }
  }
}

struct RootView_Previews: PreviewProvider {
  static var previews: some View {
    RootView(
      store: .init(
        initialState: .init(),
        reducer: Root()
      )
    )
  }
}
