import SwiftUI

@main
struct MovieScopeApp: App {
    private let environment = AppEnvironment(processEnvironment: ProcessInfo.processInfo.environment)
    @State private var dependencies: AppDependencies?

    var body: some Scene {
        WindowGroup {
            if environment.isHostingUnitTests {
                // Unit tests run inside the app process; don't start networking or UI.
                Color.clear
            } else if let dependencies {
                RootView(dependencies: dependencies)
                    .environment(\.imageProvider, dependencies.imageProvider)
                    .environment(dependencies.favorites)
            } else {
                Color.clear.onAppear {
                    dependencies = AppDependencies(environment: environment)
                }
            }
        }
    }
}
