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
    let accessor: __DO_NOT_USE__NativebrikBridgedViewAccessor?
}

struct RemoteConfigEntity {
    let variant: RemoteConfigVariant?
}

class NativebrikBridgeManager {
    private var nativebrikClient: NativebrikClient? = nil
    private var embeddingMaps: [String:EmbeddingEntity]
    private var configMaps: [String:RemoteConfigEntity]

    init() {
        self.embeddingMaps = [:]
        self.configMaps = [:]
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

    func getUserId() -> String? {
        guard let nativebrikClient = self.nativebrikClient else {
            return nil
        }
        return nativebrikClient.user.id
    }

    func setUserProperties(properties: [String: String]) {
        guard let nativebrikClient = self.nativebrikClient else {
            return
        }
        nativebrikClient.user.setProperties(properties)
    }

    func getUserProperties() -> [String: String]? {
        guard let nativebrikClient = self.nativebrikClient else {
            return nil
        }
        return nativebrikClient.user.getProperties()
    }

    // embedding
    func connectEmbedding(id: String, channelId: String, arguments: Any?, messenger: FlutterBinaryMessenger) {
        guard let nativebrikClient = self.nativebrikClient else {
            return
        }
        let channel = FlutterMethodChannel(name: "Nativebrik/Embedding/\(channelId)", binaryMessenger: messenger)
        let uiview = nativebrikClient.experiment.embeddingUIView(id, arguments: arguments, onEvent: { event in
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
            case .failed:
                channel.invokeMethod(EMBEDDING_PHASE_UPDATE_METHOD, arguments: "failed")
                return UIView()
            case .loading:
                return UIView()
            }
        }
        let embeedingEntity = EmbeddingEntity(
            uiview: uiview,
            channel: channel,
            accessor: nil
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
        print("get embedding entity \(channelId)")
        return entity
    }

    // remote config
    func connectRemoteConfig(id: String, channelId: String, onPhase:  @escaping ((RemoteConfigPhase) -> Void)) {
        guard let nativebrikClient = self.nativebrikClient else {
            return
        }
        let entity = RemoteConfigEntity(variant: nil)
        self.configMaps[channelId] = entity

        nativebrikClient.experiment.remoteConfig(id) { phase in
            switch phase {
            case .completed(let config):
                if self.configMaps[channelId] == nil {
                    // disconnected already
                    return
                }
                let entity = RemoteConfigEntity(variant: config)
                self.configMaps[channelId] = entity
                onPhase(phase)
            case .notFound:
                onPhase(phase)
            case .failed:
                onPhase(phase)
            default:
                break
            }
        }
    }

    func disconnectRemoteConfig(channelId: String) {
        self.configMaps[channelId] = nil
    }

    func connectEmbeddingInRemoteConfigValue(key: String, channelId: String, arguments: Any?, embeddingChannelId: String, messenger: FlutterBinaryMessenger) {
        guard let entity = self.configMaps[channelId] else {
            return
        }
        guard let variant = entity.variant else {
            return
        }
        let channel = FlutterMethodChannel(name: "Nativebrik/Embedding/\(embeddingChannelId)", binaryMessenger: messenger)
        guard let uiview = variant.getAsUIView(key, arguments: arguments, onEvent: { event in
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
        }, content: { phase in
            switch phase {
            case .completed(let view):
                channel.invokeMethod(EMBEDDING_PHASE_UPDATE_METHOD, arguments: "completed")
                return view
            case .notFound:
                channel.invokeMethod(EMBEDDING_PHASE_UPDATE_METHOD, arguments: "not-found")
                return UIView()
            case .failed:
                channel.invokeMethod(EMBEDDING_PHASE_UPDATE_METHOD, arguments: "failed")
                return UIView()
            case .loading:
                return UIView()
            }
        }) else {
            return
        }
        let embeedingEntity = EmbeddingEntity(
            uiview: uiview,
            channel: channel,
            accessor: nil
        )
        self.embeddingMaps[embeddingChannelId] = embeedingEntity
    }

    func getRemoteConfigValue(channelId: String, key: String) -> String? {
        guard let entity = self.configMaps[channelId] else {
            return nil
        }
        guard let variant = entity.variant else {
            return nil
        }
        return variant.get(key)
    }

    // tooltip
    func connectTooltip(name: String, onFetch: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        guard let nativebrikClient = self.nativebrikClient else {
            onError("NativebrikClient is not set")
            return
        }
        Task {
            let result = await nativebrikClient.experiment.__do_not_use__fetch_tooltip_data(trigger: name)
            switch result {
            case .success(let data):
                onFetch(data)
            case .failure(let error):
                onError(error.localizedDescription)
            }
        }
    }

    func connectTooltipEmbedding(channelId: String, rootBlock: String, messenger: FlutterBinaryMessenger) {
        guard let nativebrikClient = self.nativebrikClient else {
            return
        }
        let channel = FlutterMethodChannel(name: "Nativebrik/Embedding/\(channelId)", binaryMessenger: messenger)
        print("connect tooltip embedding", channelId)
        let accessor = nativebrikClient.experiment.__do_not_use__render_uiview(
            json: rootBlock,
            onEvent: { event in
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
            },
            onNextTooltip: { pageId in
                print("NativebrikBridgeManager onNextTooltip: \(pageId))")
                channel.invokeMethod(ON_NEXT_TOOLTIP_METHOD, arguments: [
                    "pageId": pageId,
                ])
            },
            onDismiss: {
                channel.invokeMethod(ON_DISMISS_TOOLTIP_METHOD, arguments: nil)
            }
        )
        print("accessor", accessor)
        let embeedingEntity = EmbeddingEntity(
            uiview: accessor.view,
            channel: channel,
            accessor: accessor
        )
        print("add emedding: \(channelId)")
        self.embeddingMaps[channelId] = embeedingEntity
    }
    
    func callTooltipEmbeddingDispatch(channelId: String, event: String) {
        guard let entity = self.embeddingMaps[channelId] else {
            return
        }
        guard let accessor = entity.accessor else {
            return
        }
        do {
            try accessor.dispatch(event: event)
        } catch {}
    }

    func disconnectTooltipEmbedding(channelId: String) {
        self.embeddingMaps[channelId] = nil
    }

    // trigger
    func dispatch(name: String) {
        guard let nativebrikClient = self.nativebrikClient else {
            return
        }
        nativebrikClient.experiment.dispatch(NativebrikEvent(name))
    }

    /**
     * Records a crash with the given exception.
     *
     * This method forwards the exception to the Nativebrik SDK for crash reporting.
     */
    func recordCrash(exception: NSException) {
        guard let nativebrikClient = self.nativebrikClient else {
            return
        }
        nativebrikClient.experiment.record(exception: exception)
    }
}

