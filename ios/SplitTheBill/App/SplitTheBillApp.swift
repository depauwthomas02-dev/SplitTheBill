import SwiftUI

@main
struct SplitTheBillApp: App {
    @State private var store = BillStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .onOpenURL { store.handle(url: $0) }
        }
    }
}
