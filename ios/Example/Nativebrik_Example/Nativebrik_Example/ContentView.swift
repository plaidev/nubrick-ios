//
//  ContentView.swift
//  Nativebrik_Example
//
//  Created by Ryosuke Suzuki on 2023/05/25.
//

import SwiftUI
import Nativebrik

struct ContentView: View {
    var body: some View {
        ZStack {
            Nativebrik(
                apiKey: "1G67fRWJlE9dNZoJffmLTFzAhHhMRh7R",
                environment: "http://localhost:8060/client"
            ).TriggerManager()
            Text("Hello, world!")
                .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
