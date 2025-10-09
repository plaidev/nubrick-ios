//
//  ContentView.swift
//  Example
//
//  Created by Ryosuke Suzuki on 2023/10/27.
//

import SwiftUI
import Nubrick

struct ItemBuyButton: View {
    let price: String
    let onAction: () -> ()
    var body: some View {
        VStack {
            Divider()
            HStack {
                Text(self.price).fontWeight(.medium)
                Spacer()
                Button(action: {
                    self.onAction()
                }) {
                    Text("Book").foregroundColor(.white).fontWeight(.medium)
                }.padding(.horizontal, 38).padding(.vertical, 8).background(.primary).cornerRadius(8)
            }.padding(.horizontal, 16).padding(.vertical, 8)
        }
    }
}

struct ItemPanel: View {
    let image: String
    let title: String
    let subtitle: String
    let price: String
    var desc: String = "Lorem Ipsum"

    @State private var isShowingItemView = false

    var body: some View {
        VStack {
            AsyncImage(url: URL(string: self.image)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    ProgressView()
                }
            }.frame(width: UIScreen.main.bounds.size.width - 32, height: 200).cornerRadius(8).clipped()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(self.title).fontWeight(.medium).font(.caption)
                        Text(self.subtitle).foregroundColor(.secondary).font(.caption)
                    }
                    Text(self.price).fontWeight(.medium).font(.caption)
                }
                Spacer()
            }
        }.onTapGesture {
            self.isShowingItemView.toggle()
        }.sheet(isPresented: self.$isShowingItemView) {
            VStack(alignment: .leading, spacing: 8) {
                ScrollView(.vertical) {
                    AsyncImage(url: URL(string: self.image)) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            ProgressView()
                        }
                    }.frame(width: UIScreen.main.bounds.size.width, height: 280)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(self.title).fontWeight(.medium).font(.title)
                                Text(self.subtitle).foregroundColor(.secondary).font(.subheadline)
                                Text(self.desc).fontWeight(.light).padding(.top, 16)
                            }
                        }
                        Spacer()
                    }.padding()
                }
                ItemBuyButton(
                    price: self.price,
                    onAction: {
                        self.isShowingItemView.toggle()
                    }
                )
            }
        }
    }
}

struct SearchBar: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").padding(.leading, 8)
            VStack(alignment: .leading) {
                Text("Where you want to visit?").font(.caption)
                Text("Any area").foregroundColor(.secondary).font(.caption)
            }
            Spacer()
        }.padding(8).background(.background).cornerRadius(8).shadow(color: .init(.sRGBLinear, white: 0, opacity: 0.08), radius: 4)
    }
}

struct Header: View {
    var body: some View {
        SearchBar().padding().background(.background)
    }
}

struct AppView: View {
    let items: [ItemPanel] = [
        ItemPanel(image: "https://www.cairnsdiscoverytours.com/wp-content/uploads/2022/10/cairns-city-day-tours.jpg", title: "Cairns, Australia", subtitle: "A city in Queensland", price: "$800 round trip", desc: "Cairns is a vibrant and tropical city located in the far north of Queensland, Australia. Situated on the east coast, Cairns serves as the gateway to the Great Barrier Reef, one of the world's most renowned natural wonders. The city's stunning location between lush rainforests and the Coral Sea makes it a popular tourist destination."),
        ItemPanel(image: "https://lifeofdoing.com/wp-content/uploads/2020/05/5-Days-In-Kyoto-Itinerary-Higashiyama-District.jpg", title: "Kyoto, Japan", subtitle: "A city in Japan", price: "$300 round trip", desc: """
Kyoto, located in the Kansai region of Japan, is a city steeped in history, tradition, and natural beauty. As the former imperial capital of Japan for over a thousand years, Kyoto is renowned for its well-preserved historic sites, traditional culture, and stunning temples and gardens.
"""),
        ItemPanel(image: "https://dynamic-media-cdn.tripadvisor.com/media/photo-o/1b/6c/16/ce/caption.jpg?w=1200&h=-1&s=1", title: "Sao paulo, Brazil", subtitle: "A city in Brazil", price: "$1800 round trip", desc: """
São Paulo, often referred to as Sampa, is a bustling metropolis and the largest city in Brazil. Located in the southeastern part of the country, São Paulo is a dynamic hub of culture, business, and diversity. It is known for its vibrant energy, impressive skyline, and a wide range of attractions that cater to various interests.
"""),
        ItemPanel(image: "https://griffithobservatory.org/wp-content/uploads/2021/03/cameron-venti-c5GkEd-j5vI-unsplash_noCautionTape-1600x800-1638571089.jpg", title: "Los angeles, America", subtitle: "A city in California", price: "$900 round trip", desc: """
Los Angeles, often referred to as LA, is a vibrant and diverse city located on the west coast of the United States in Southern California. As the second-largest city in the country and the entertainment capital of the world, Los Angeles offers a unique blend of glamour, cultural richness, natural beauty, and a laid-back coastal lifestyle.
"""),
        ItemPanel(image: "https://www.nationsonline.org/gallery/Madagascar/Allee-des-Baobabs-Madagascar.jpg", title: "Morondava, Madagascar", subtitle: "A city in Madagascar", price: "$1400 round trip", desc: """
Morondava is a charming coastal town located on the western coast of Madagascar. Situated in the Menabe region, Morondava is known for its breathtaking natural beauty, unique baobab trees, and laid-back atmosphere. It offers visitors a chance to experience the rich culture, stunning landscapes, and warm hospitality of Madagascar.
""")
    ]
    @EnvironmentObject var nativebrik: NativebrikClient

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            nativebrik
                .experiment
                .embedding("HEADER_INFORMATION") { phase in
                    switch phase {
                    case .completed(let view):
                        view.frame(height: 60)
                    default:
                        EmptyView().frame(height: 0)
                    }
                }
            Header()
            ScrollView(.vertical) {
                nativebrik
                    .experiment
                    .embedding("TOP_COMPONENT") { phase in
                        switch phase {
                        case .completed(let view):
                            view.frame(width: nil, height: 280)
                        default:
                            EmptyView().frame(width: nil, height: 0)
                        }
                    }
                ForEach(self.items, id: \.title) { item in
                    item.padding()
                }
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        AppView()
    }
}

#Preview {
    NativebrikProvider(client: NativebrikClient(projectId: "cgv3p3223akg00fod19g")) {
        ContentView()
    }
}
