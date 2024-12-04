//
//  WebSocketServer.swift
//  WebSocketServer
//
//  Created by digital on 22/10/2024.
//

import SwiftUI
import Swifter

struct RouteInfos {
    var routeName: String
    var textCode: (WebSocketSession, String) -> Void
    var dataCode: (WebSocketSession, Data) -> Void
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
                print(
                    "Client disconnected from route: /\(routeInfos.routeName)")
            }
        )
    }
    
    func start() {
        do {
            try server.start()
            print(
                "Server has started (port = \(try server.port())). Try to connect now..."
            )
        } catch {
            print("Server failed to start: \(error.localizedDescription)")
        }
    }
}

extension WebSocketSession {
    var id: String {
        return "\(ObjectIdentifier(self).hashValue)" // Identifiant unique basé sur l'objet en mémoire
    }
    
    /// Sérialise et envoie une liste de sessions sous forme de JSON à la session actuelle.
    /// - Parameter sessions: Dictionnaire des sessions actives avec clé `String` et valeur `WebSocketSession`.
    func writeSessionsList(_ sessions: [String: WebSocketSession]) {
        // Crée un dictionnaire contenant les identifiants et leurs descriptions
        let sessionInfo = sessions.mapValues { $0.id }
        
        do {
            // Sérialise en JSON
            let jsonData = try JSONSerialization.data(
                withJSONObject: sessionInfo, options: []
            )
            
            // Convertit en String et envoie via WebSocket
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                self.writeText(jsonString)
            }
        } catch {
            print("Erreur de sérialisation : \(error)")
        }
    }

    /// Notifie toutes les sessions des changements dans la liste des connexions.
    /// - Parameter sessions: Dictionnaire des sessions actives.
    func notifyConnectionChange(to sessions: [String: WebSocketSession]) {
        // Crée un dictionnaire des sessions
        let sessionInfo = sessions.mapValues { $0.id }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: sessionInfo, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                // Envoie la liste à toutes les sessions connectées
                for (_, session) in sessions {
                    session.writeText(jsonString)
                }
            }
        } catch {
            print("Erreur de sérialisation : \(error)")
        }
    }
}
