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
    var sessions: [String: (session: WebSocketSession, isConnected: Bool, lastPongDate: Date)] = [:]
    private let pingInterval: TimeInterval = 5.0
    private let pingTimeout: TimeInterval = 5.0
    
    func setupWithRoutesInfos(routeInfos: RouteInfos) {
        server["/" + routeInfos.routeName] = websocket(
            text: { session, text in
                if text == "pong" {
                    self.sessions[routeInfos.routeName]?.lastPongDate = Date()
                    self.sessions[routeInfos.routeName]?.isConnected = true
                    print("Received pong from route: \(routeInfos.routeName)")
              } else {
                  // Traitez d'autres messages normalement
                  routeInfos.textCode(session, text)
              }
            },
            binary: { session, binary in
                // Ajout ou mise à jour de la session dans le dictionnaire
                self.sessions[routeInfos.routeName] = (session: session, isConnected: true, lastPongDate: Date())
                routeInfos.dataCode(session, Data(binary))
            },
            connected: { session in
                print("Client connected to route: /\(routeInfos.routeName)")
                // Ajouter la session à la collection des sessions
                self.sessions[routeInfos.routeName] = (session: session, isConnected: true, lastPongDate: Date())
            },
            disconnected: { session in
                print("Client disconnected from route: /\(routeInfos.routeName)")
                // Marquer la session comme déconnectée
                self.sessions[routeInfos.routeName]?.isConnected = false
            }
        )
    }
    
    func setupDashboardRoute() {
        server["/dashboard"] = websocket(
            text: { session, text in
                // Traiter les messages du dashboard
                if let data = text.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let type = json["type"] as? String {
                    
                    if type == "get_status" {
                        // Construire un dictionnaire des états de connexion
                        var statusDict: [String: Bool] = [:]
                        for (routeName, sessionInfo) in self.sessions {
                            statusDict[routeName] = sessionInfo.isConnected
                        }
                        
                        // Convertir le dictionnaire en JSON
                        if let jsonData = try? JSONSerialization.data(withJSONObject: statusDict, options: []),
                           let jsonString = String(data: jsonData, encoding: .utf8) {
                            session.writeText(jsonString)
                        }
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
    
    
    func serveStaticHTML() {
        server["/"] = { request in
            let htmlContent = """
            <!DOCTYPE html>
            <html lang="fr">
            <head>
                <meta charset="UTF-8">
                <title>WebSocket Devices Dashboard</title>
                <style>
                    body {
                        font-family: Arial, sans-serif;
                        max-width: 800px;
                        margin: 0 auto;
                        padding: 20px;
                        background-color: #f0f0f0;
                    }
                    h1 {
                        text-align: center;
                        color: #333;
                    }
                    .device-list {
                        display: grid;
                        grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                        gap: 15px;
                    }
                    .device-card {
                        background-color: white;
                        border-radius: 8px;
                        box-shadow: 0 4px 6px rgba(0,0,0,0.1);
                        padding: 15px;
                        text-align: center;
                    }
                    .device-status {
                        font-weight: bold;
                        padding: 10px;
                        border-radius: 4px;
                    }
                    .connected {
                        background-color: #4CAF50;
                        color: white;
                    }
                    .disconnected {
                        background-color: #F44336;
                        color: white;
                    }
                </style>
            </head>
            <body>
                <h1>Devices Connection Dashboard</h1>
                <div id="deviceStatus" class="device-list"></div>

                <script>
                    // Liste des routes à surveiller
                    const routes = [
                        'telecommande', 
                        'espConnect', 
                        'rpiConnect', 
                        'allumerFeu',
                        'espFireplace', 
                        'phoneMixer', 
                        'espMixer'
                    ];

                    const deviceStatusElement = document.getElementById('deviceStatus');

                    function createWebSocket() {
                        const socket = new WebSocket(`ws://${window.location.host}/dashboard`);

                        socket.onopen = () => {
                            console.log('Dashboard WebSocket connection established');
                            // Demander l'état initial des connexions
                            socket.send(JSON.stringify({ type: 'get_status' }));
                        };

                        socket.onmessage = (event) => {
                            try {
                                const data = JSON.parse(event.data);
                                updateDeviceStatus(data);
                            } catch (error) {
                                console.error('Error parsing message:', error);
                            }
                        };

                        socket.onclose = () => {
                            console.log('WebSocket connection closed. Reconnecting...');
                            setTimeout(createWebSocket, 6000);
                        };

                        return socket;
                    }

                    function updateDeviceStatus(statusData) {
                        // Vider le conteneur actuel
                        deviceStatusElement.innerHTML = '';

                        // Créer une carte pour chaque device
                        routes.forEach(route => {
                            const deviceCard = document.createElement('div');
                            deviceCard.className = 'device-card';
                            
                            const deviceName = document.createElement('h2');
                            deviceName.textContent = route;
                            
                            const statusElement = document.createElement('div');
                            statusElement.className = 'device-status';
                            
                            // Déterminer le statut
                            const isConnected = statusData[route] === true;
                            statusElement.textContent = isConnected ? 'Connecté' : 'Déconnecté';
                            statusElement.classList.add(isConnected ? 'connected' : 'disconnected');

                            deviceCard.appendChild(deviceName);
                            deviceCard.appendChild(statusElement);
                            deviceStatusElement.appendChild(deviceCard);
                        });
                    }

                    // Initialiser la connexion WebSocket
                    const socket = createWebSocket();
                </script>
            </body>
            </html>
            """
            
            return HttpResponse.ok(.text(htmlContent))
        }
    }
    
    func start() {
        do {
            serveStaticHTML()
            
            try server.start()
            
            print("Server has started (port = \(try server.port())). Try to connect now...")
            startPingRoutine()
        } catch {
            print("Server failed to start: \(error.localizedDescription)")
        }
    }
    
    private func startPingRoutine() {
        Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { _ in
            for (routeName, sessionInfo) in self.sessions {
                guard sessionInfo.isConnected else { continue }

                // Envoi du ping
                sessionInfo.session.writeText("ping")
                print("Ping envoyé à \(routeName)")

                // Vérification du délai pour le pong
                if Date().timeIntervalSince(sessionInfo.lastPongDate) > self.pingTimeout {
                    // Si aucun pong reçu dans le délai, marquer comme non connecté
                    self.sessions[routeName]?.isConnected = false
                    print("No pong received from \(routeName), marking as disconnected.")
                }
            }
        }
    }

    func getSession(forRoute routeName: String) -> WebSocketSession? {
        return sessions[routeName]?.session
    }
    

    func isDeviceConnected(forRoute routeName: String) -> Bool {
        return sessions[routeName]?.isConnected ?? false
    }
}
