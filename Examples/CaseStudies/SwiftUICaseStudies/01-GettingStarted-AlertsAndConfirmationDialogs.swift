import ComposableArchitecture
import SwiftUI

private let readMe = """
  This demonstrates how to best handle alerts and confirmation dialogs in the Composable \
  Architecture.

  Because the library demands that all data flow through the application in a single direction, we \
  cannot leverage SwiftUI's two-way bindings because they can make changes to state without going \
  through a reducer. This means we can't directly use the standard API to display alerts and sheets.

  However, the library comes with two types, `AlertState` and `ConfirmationDialogState`, which can \
  be constructed from reducers and control whether or not an alert or confirmation dialog is \
  displayed. Further, it automatically handles sending actions when you tap their buttons, which \
  allows you to properly handle their functionality in the reducer rather than in two-way bindings \
  and action closures.

  The benefit of doing this is that you can get full test coverage on how a user interacts with \
  alerts and dialogs in your application
  """

struct AlertAndConfirmationDialog: ReducerProtocol {
  struct State: Equatable {
    var alert: AlertState<Action>?
    var confirmationDialog: ConfirmationDialogState<Action>?
    var count = 0
  }

  enum Action: Equatable {
    case alertButtonTapped
    case alertDismissed
    case confirmationDialogButtonTapped
    case confirmationDialogDismissed
    case decrementButtonTapped
    case incrementButtonTapped
    case onDismiss
  }

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    switch action {
    case .alertButtonTapped:
      state.alert = .init(
        title: .init("Alert!"),
        message: .init("This is an alert"),
        primaryButton: .cancel(.init("Cancel")),
        secondaryButton: .default(.init("Increment"), action: .send(.incrementButtonTapped))
      )
      return .none

    case .alertDismissed:
      state.alert = nil
      return .none

    case .confirmationDialogButtonTapped:
      state.confirmationDialog = .init(
        title: .init("Confirmation dialog"),
        message: .init("This is a confirmation dialog."),
        buttons: [
          .cancel(.init("Cancel")),
          .default(.init("Increment"), action: .send(.incrementButtonTapped)),
          .default(.init("Decrement"), action: .send(.decrementButtonTapped)),
        ]
      )
      return .none

    case .confirmationDialogDismissed:
      state.confirmationDialog = nil
      return .none

    case .decrementButtonTapped:
      state.alert = .init(title: .init("Decremented!"))
      state.count -= 1
      return .none

    case .incrementButtonTapped:
      state.alert = .init(title: .init("Incremented!"))
      state.count += 1
      return .none
        
    case .onDismiss:
      print("Before dismissing my count was: \(state.count)")
      return .none
    }
  }
}

struct AlertAndConfirmationDialogView: View {
  let store: StoreOf<AlertAndConfirmationDialog>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(template: readMe, .caption)) {
          Text("Count: \(viewStore.count)")
          Button("Alert") { viewStore.send(.alertButtonTapped) }
          Button("Confirmation Dialog") { viewStore.send(.confirmationDialogButtonTapped) }
        }
      }
    }
    .navigationBarTitle("Alerts & Confirmation Dialogs")
    .alert(
      self.store.scope(state: \.alert),
      dismiss: .alertDismissed
    )
    .confirmationDialog(
      self.store.scope(state: \.confirmationDialog),
      dismiss: .confirmationDialogDismissed
    )
  }
}

struct AlertAndConfirmationDialog_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      AlertAndConfirmationDialogView(
        store: .init(
          initialState: .init(),
          reducer: AlertAndConfirmationDialog()
        )
      )
    }
  }
}
