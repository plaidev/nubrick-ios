//
//  Manager.swift
//  nativebrik_bridge
//
//  Created by Ryosuke Suzuki on 2024/03/10.
//

import Foundation
import Flutter
import UIKit
import Nativebrik

struct EmbeddingEntity {
    let uiview: UIView
    let channel: FlutterMethodChannel
}

class NativebrikBridgeManager {
    private var nativebrikClient: NativebrikClient? = nil
    private var embeddingMaps: [String:EmbeddingEntity]

    init() {
        self.embeddingMaps = [:]
    }

    func setNativebrikClient(nativebrik: NativebrikClient) {
        if self.nativebrikClient != nil {
            return print("NativebrikClient is already set")
        }
        self.nativebrikClient = nativebrik
        if let vc = UIApplication.shared.delegate?.window??.rootViewController {
            let overlay = nativebrik.experiment.overlayViewController()
            vc.addChild(overlay)
            vc.view.addSubview(overlay.view)
        }
    }

    func connectEmbedding(id: String, channelId: String, messenger: FlutterBinaryMessenger) {
        guard let nativebrikClient = self.nativebrikClient else {
            return
        }
        let channel = FlutterMethodChannel(name: "Nativebrik/Embedding/\(channelId)", binaryMessenger: messenger)
        let uiview = nativebrikClient.experiment.embeddingUIView(id, onEvent: { event in
            channel.invokeMethod(ON_EVENT_METHOD, arguments: [
                "name": event.name as Any?,
                "deepLink": event.deepLink as Any?,
                "payload": event.payload?.map({ prop in
                    return [
                        "name": prop.name,
                        "value": prop.value,
                        "type": prop.type
                    ]
                }),
            ])
        }) { phase in
            switch phase {
            case .completed(let view):
                channel.invokeMethod(EMBEDDING_PHASE_UPDATE_METHOD, arguments: "completed")
                return view
            case .notFound:
                channel.invokeMethod(EMBEDDING_PHASE_UPDATE_METHOD, arguments: "not-found")
                return UIView()
            case .failed(let err):
                channel.invokeMethod(EMBEDDING_PHASE_UPDATE_METHOD, arguments: "failed")
                return UIView()
            case .loading:
                return UIView()
            }
        }
        let embeedingEntity = EmbeddingEntity(
            uiview: uiview,
            channel: channel
        )
        self.embeddingMaps[channelId] = embeedingEntity
    }

    func disconnectEmbedding(channelId: String) {
        self.embeddingMaps[channelId] = nil
    }

    func getEmbeddingEntity(channelId: String) -> EmbeddingEntity? {
        guard let entity = self.embeddingMaps[channelId] else {
            return nil
        }
        return entity
    }
}

