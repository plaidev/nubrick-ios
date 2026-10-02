import Nubrick
import SwiftUI

struct ContentView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Button("Dispatch test1 and test2") {
                    NubrickSDK.dispatch(NubrickEvent("test1"))
                    NubrickSDK.dispatch(NubrickEvent("test2"))
                }
                .buttonStyle(.borderedProminent)
                .padding()

                NubrickSDK.embedding("HEADER_INFORMATION")
                NubrickSDK.embedding("TOP_COMPONENT")
            }
        }
    }
}

@MainActor
private struct NubrickPreviewRoot: View {
    private static var didInit = false

    init() {
        if !Self.didInit {
            NubrickSDK.initialize(projectId: "cgv3p3223akg00fod19g")
            Self.didInit = true
        }
    }

    var body: some View {
        NubrickProvider {
            ContentView()
        }
    }
}

#Preview {
    NubrickPreviewRoot()
}
