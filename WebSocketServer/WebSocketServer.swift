//
//  WebSocketServer.swift
//  WebSocketServer
//
//  Created by digital on 22/10/2024.
//

import Swifter
import SwiftUI

struct RouteInfos {
    var routeName: String
    var textCode: (WebSocketSession, String) -> ()
    var dataCode: (WebSocketSession, Data) -> ()
}

@Observable class WebSockerServer {
    static let instance = WebSockerServer()
    let server = HttpServer()
    
    var telecommandeSession: WebSocketSession?
    var espSession: WebSocketSession?
    var rpiSession: WebSocketSession?
    var espFireplace: WebSocketSession?
    var phoneMixer: WebSocketSession?
    
    func setupWithRoutesInfos(routeInfos: RouteInfos) {
        server["/" + routeInfos.routeName] = websocket(
            text: { session, text in
                routeInfos.textCode(session, text)
            },
            binary: { session, binary in
                routeInfos.dataCode(session, Data(binary))
            },
            connected: { session in
                print("Client connected to route: /\(routeInfos.routeName)")
            },
            disconnected: { session in
                print("Client disconnected from route: /\(routeInfos.routeName)")
            }
        )
    }
    
    func start() {
        do {
            try server.start()
            print("Server has started (port = \(try server.port())). Try to connect now...")
        } catch {
            print("Server failed to start: \(error.localizedDescription)")
        }
    }
}
