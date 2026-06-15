import SwiftUI
import Nubrick

private enum SampleUserPlan {
    static var value = "pro"

    static func toggle() -> String {
        value = value == "pro" ? "free" : "pro"
        return value
    }
}

struct ContentView: View {
    @State private var counter = 0
    @State private var plan = "pro"

    var arguments: [String: any Sendable] {
        ["counter": counter]
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack {
                NubrickSDK.embedding("HEADER_INFORMATION", arguments: arguments) { phase in
                    switch phase {
                    case .completed(let view):
                        view.frame(height: 100)
                    default:
                        EmptyView().frame(height: 0)
                    }
                }
                NubrickSDK.embedding("TOP_COMPONENT", arguments: arguments) { phase in
                    switch phase {
                    case .completed(let view):
                        view.frame(height: 270)
                    default:
                        EmptyView().frame(height: 0)
                    }
                }
                Spacer().frame(height: 16)
                VStack(spacing: 8) {
                    HStack {
                        Button("arg counter: \(counter)") {
                            counter += 1
                        }
                        Spacer().frame(width: 8)
                        Button("user plan + state: \(plan)") {
                            plan = plan == "pro" ? "free" : "pro"
                            NubrickSDK.setUserProperty("plan", value: plan)
                        }
                    }
                    Button("user plan SDK only") {
                        let plan = SampleUserPlan.toggle()
                        NubrickSDK.setUserProperty("plan", value: plan)
                    }
                }.padding(.horizontal)
            }
        }
    }
}

#Preview {
    ContentView()
}
