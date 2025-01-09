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
    
    // Dictionnaire des sessions et états
    var sessions: [String: (session: WebSocketSession, isConnected: Bool, lastPongDate: Date, callbackName: String)] = [:]
    
    private let pingInterval: TimeInterval = 10.0
    private let pingTimeout: TimeInterval = 30.0
    
    private var missedPingCounts: [String: Int] = [:]
    private let maxMissedPings = 3
    
    private let sessionsQueue = DispatchQueue(label: "fr.mathieu-dubart.sessionsQueue", attributes: .concurrent)
    
    /// Méthode utilitaire pour déclarer (et gérer) les routes WebSocket
    func setupWithRoutesInfos(routeInfos: RouteInfos) {
        server["/" + routeInfos.routeName] = websocket(
            text: { session, text in
                // Réception d'un message texte
                if text == "pong" {
                    self.sessionsQueue.async(flags: .barrier) {
                        if var sessionInfo = self.sessions[routeInfos.routeName] {
                            sessionInfo.lastPongDate = Date()
                            sessionInfo.isConnected = true
                            self.sessions[routeInfos.routeName] = sessionInfo
                            
                            // Réinitialiser le compteur de pings manqués
                            self.missedPingCounts[routeInfos.routeName] = 0
                        } else {
                            print("No session found for route: \(routeInfos.routeName)")
                        }
                    }
                } else {
                    // Toute autre commande texte spécifique à l'ESP
                    routeInfos.textCode(session, text)
                }
            },
            binary: { session, binary in
                // Réception d'un message binaire
                self.sessionsQueue.async(flags: .barrier) {
                    self.sessions[routeInfos.routeName] = (
                        session: session,
                        isConnected: true,
                        lastPongDate: Date(),
                        callbackName: routeInfos.routeName
                    )
                    // Réinitialiser le compteur de pings manqués
                    self.missedPingCounts[routeInfos.routeName] = 0
                }
                // Traitement éventuel des datas binaires
                routeInfos.dataCode(session, Data(binary))
            },
            connected: { session in
                print("Client connected to route: /\(routeInfos.routeName)")
                self.sessionsQueue.async(flags: .barrier) {
                    self.sessions[routeInfos.routeName] = (
                        session: session,
                        isConnected: true,
                        lastPongDate: Date(),
                        callbackName: routeInfos.routeName
                    )
                    // Compteur de pings manqués initial à 0
                    self.missedPingCounts[routeInfos.routeName] = 0
                }
            },
            disconnected: { session in
                print("Client disconnected from route: /\(routeInfos.routeName)")
                self.sessionsQueue.async(flags: .barrier) {
                    if let route = self.sessions.first(where: { $0.value.session == session })?.key {
                        self.sessions.removeValue(forKey: route)
                        self.missedPingCounts.removeValue(forKey: route)
                        print("Session for route \(route) has been removed.")
                    }
                }
            }
        )
    }
    
    /// Route WebSocket “tableau de bord”
    func setupDashboardRoute() {
        server["/dashboard"] = websocket(
            text: { session, text in
                // Traiter les messages du dashboard
                self.sessionsQueue.sync {
                    if let data = text.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let type = json["type"] as? String {
                        
                        if type == "get_status" {
                            var statusDict: [String: [Any]] = [:]
                            for (routeName, sessionInfo) in self.sessions {
                                statusDict[routeName] = [
                                    sessionInfo.isConnected,
                                    sessionInfo.callbackName
                                ]
                            }
                            
                            if let jsonData = try? JSONSerialization.data(withJSONObject: statusDict, options: []),
                               let jsonString = String(data: jsonData, encoding: .utf8) {
                                session.writeText(jsonString)
                            }
                        }
                    } else {
                        print("Received non-JSON message: \(text)")
                        self.dispatchMessage(text)
                    }
                }
            },
            connected: { session in
                print("Dashboard client connected")
            },
            disconnected: { session in
                print("Dashboard client disconnected")
            }
        )
    }
    
    /// Méthode interne pour propager un message texte à qui de droit
    private func dispatchMessage(_ message: String) {
        var newMessage = message
        self.sessionsQueue.sync {
            for (routeName, sessionInfo) in self.sessions {
                // Ex: "espBougie:turn_on_bougie"
                if newMessage.trimmingCharacters(in: .whitespacesAndNewlines).contains(routeName) {
                    newMessage.trimPrefix("\(routeName):")
                    // On envoie le texte épuré au device correspondant
                    sessionInfo.session.writeText(newMessage)
                }
            }
        }
    }
    
    /// Exemple : sert un HTML statique (dashboard)
    func serveStaticHTML() {
        server["/"] = { request in
            let htmlContent = """
            <!DOCTYPE html>
            <html lang="fr">
              <head>
                <meta charset="UTF-8">
                <title>WebSocket Devices Dashboard</title>
                <style>/* votre CSS ici */</style>
              </head>
              <body>
                <h1>Devices Connection Dashboard</h1>
                <!-- ... votre code HTML/JS existant ... -->
              </body>
            </html>
            """
            return HttpResponse.ok(.text(htmlContent))
        }
    }
    
    /// Méthode de démarrage
    func start() {
        do {
            print("🔄 Starting server...")
            
            // Déclare une page statique
            serveStaticHTML()
            
            // Loggue toutes les requêtes HTTP entrantes (y compris WebSocket handshake)
            server.middleware.append { request in
                print("📝 Incoming request: \(request.method) \(request.path)")
                return nil
            }
            
            // --- Exemple d’utilisation :
            // 1) On met en place la route "espAutel1"
            setupWithRoutesInfos(
                routeInfos: RouteInfos(
                    routeName: "espAutel1",
                    textCode: { session, text in
                        print("[espAutel1] Reçu texte:", text)
                        // Traitement éventuel côté serveur...
                    },
                    dataCode: { session, data in
                        print("[espAutel1] Reçu data de taille:", data.count)
                    }
                )
            )
            
            // 2) On met en place la route "espPapel2"
            setupWithRoutesInfos(
                routeInfos: RouteInfos(
                    routeName: "espPapel2",
                    textCode: { session, text in
                        print("[espPapel2] Reçu texte:", text)
                        // Traitement éventuel...
                    },
                    dataCode: { session, data in
                        print("[espPapel2] Reçu data de taille:", data.count)
                    }
                )
            )
            
            // Et si besoin, on gère la route /dashboard
            setupDashboardRoute()
            
            // On démarre le serveur sur le port 8080
            try server.start(8080, priority: .userInteractive)
            print("✅ Server started successfully on port \(try server.port())")
            
            // On démarre la routine de ping
            startPingRoutine()
            
            // Gestion d'arrêt propre (Ctrl+C)
            let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
            signal(SIGINT, SIG_IGN)
            signalSource.setEventHandler {
                print("\n⚠️ Server stopping...")
                self.disconnectAllSessions()
                signalSource.cancel()
                exit(0)
            }
            signalSource.resume()
            
        } catch {
            print("❌ Server failed to start: \(error.localizedDescription)")
        }
    }
    
    /// Routine de ping pour vérifier la connexion de chaque client
    private func startPingRoutine() {
        Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { _ in
            self.sessionsQueue.async(flags: .barrier) {
                for (routeName, sessionInfo) in self.sessions {
                    guard sessionInfo.isConnected else { continue }
                    
                    // Envoi du ping
                    sessionInfo.session.writeText("ping")
                    
                    let timeSinceLastPong = Date().timeIntervalSince(sessionInfo.lastPongDate)
                    
                    // On check si on dépasse un timeout
                    if self.missedPingCounts[routeName] == nil {
                        self.missedPingCounts[routeName] = 0
                    }
                    
                    if timeSinceLastPong > self.pingTimeout {
                        self.missedPingCounts[routeName]! += 1
                        
                        if self.missedPingCounts[routeName]! >= self.maxMissedPings {
                            print("No pong received from \(routeName) for \(self.missedPingCounts[routeName]!) times, closing.")
                            sessionInfo.session.socket.close()
                            self.sessions.removeValue(forKey: routeName)
                            self.missedPingCounts.removeValue(forKey: routeName)
                        } else {
                            print("No pong from \(routeName) => missed \(self.missedPingCounts[routeName]!) times.")
                        }
                    } else {
                        // Réception OK => reset
                        self.missedPingCounts[routeName] = 0
                    }
                }
            }
        }
    }
    
    func getSession(forRoute routeName: String) -> WebSocketSession? {
        return sessionsQueue.sync {
            return sessions[routeName]?.session
        }
    }
    
    func isDeviceConnected(forRoute routeName: String) -> Bool {
        return sessionsQueue.sync {
            return sessions[routeName]?.isConnected ?? false
        }
    }
    
    func disconnectAllSessions() {
        self.sessionsQueue.async(flags: .barrier) {
            for (routeName, sessionInfo) in self.sessions {
                print("Disconnecting session for route: \(routeName)")
                sessionInfo.session.socket.close()
            }
            self.sessions.removeAll()
            self.missedPingCounts.removeAll()
            print("All sessions have been disconnected.")
        }
    }
}
