//
//  ContentView.swift
//  E2E
//
//  Created by Ryosuke Suzuki on 2023/11/14.
//

import SwiftUI
import Nubrick

struct ContentView: View {
    var body: some View {
        VStack {
            NubrickSDK.embedding("EMBEDDING_FOR_E2E", onEvent: nil, content: { phase in
                    switch phase {
                    case .completed(let view):
                        view
                    case .loading:
                        ProgressView()
                    default:
                        Text("EMBED IS FAILED")
                    }
                })
            .frame(height: 240)
            NubrickSDK.remoteConfigAsView("REMOTE_CONFIG_FOR_E2E") { phase in
                    switch phase {
                    case .completed(let config):
                        Text(config.getAsString("message") ?? "")
                    case .loading:
                        ProgressView()
                    default:
                        Text("CONFIG IS FAILED")
                    }
                }
        }
    }
}

@MainActor
private struct NubrickPreviewRoot: View {
    private static var didInit = false

    init() {
        if !Self.didInit {
            NubrickSDK.initialize(projectId: "ckto7v223akg00ag3jsg")
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
