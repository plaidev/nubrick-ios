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
            Nubrick.embedding("EMBEDDING_FOR_E2E", onEvent: nil, content: { phase in
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
            Nubrick.remoteConfigAsView("REMOTE_CONFIG_FOR_E2E") { phase in
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

#Preview {
    Nubrick.initialize(projectId: "ckto7v223akg00ag3jsg")
    NubrickProvider {
        ContentView()
    }
}
