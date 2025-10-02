//
//  ContentView.swift
//  E2E
//
//  Created by Ryosuke Suzuki on 2023/11/14.
//

import SwiftUI
import Nativebrik

struct ContentView: View {
    @EnvironmentObject var nativebrik: NativebrikClient

    var body: some View {
        VStack {
            nativebrik
                .experiment
                .embedding("EMBEDDING_FOR_E2E", onEvent: nil, content: { phase in
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
            nativebrik
                .experiment
                .remoteConfigAsView("REMOTE_CONFIG_FOR_E2E") { phase in
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
    NativebrikProvider(client: NativebrikClient(projectId: "ckto7v223akg00ag3jsg")) {
        ContentView()
    }
}
