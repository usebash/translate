import SwiftUI
import Translation

struct ContentView: View {
    @State private var appState = AppState()

    var body: some View {
        TabView {
            TextTranslateView()
                .tabItem {
                    Label("Text", systemImage: "text.bubble")
                }

            PhotoTranslateView()
                .tabItem {
                    Label("Camera", systemImage: "camera.viewfinder")
                }
        }
        .environment(appState)
        .translationTask(appState.configuration) { session in
            await appState.handle(session: session)
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
