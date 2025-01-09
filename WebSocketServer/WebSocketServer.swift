//
//  WebSocketServer.swift
//  WebSocketServer
//
//  Created by digital on 22/10/2024.
//

import Swifter
import SwiftUI

/// Structure pour décrire la logique de traitement pour un "routeName"
struct RouteInfos {
    var routeName: String
    
    /// Closure appelée quand on reçoit un texte
    /// (session, texte) => Void
    var textCode: (WebSocketSession, String) -> ()
    
    /// Closure appelée quand on reçoit des données binaires
    /// (session, data) => Void
    var dataCode: (WebSocketSession, Data) -> ()
}

/// Info de session pour un routeName
struct SessionInfo {
    var session: WebSocketSession
    var isConnected: Bool
    var lastPongDate: Date
    var callbackName: String
}

@Observable
class WebSockerServer {
    static let instance = WebSockerServer()
    let server = HttpServer()
    
    // Dictionnaire des sessions et états (1 session par routeName).
    // Si tu veux supporter *plusieurs* sessions pour le même routeName,
    // il faudra transformer ceci en: [String: [SessionInfo]] ou similaire.
    var sessions: [String: SessionInfo] = [:]
    
    /// Queue concurrente + barrière pour synchroniser l'accès à `sessions`
    private let sessionsQueue = DispatchQueue(
        label: "fr.mathieu-dubart.sessionsQueue",
        attributes: .concurrent
    )
    
    // Paramètres ping/pong
    private let pingInterval: TimeInterval = 5.0
    private let pingTimeout: TimeInterval = 10.0
    
    // MARK: - Méthodes "safe" pour écrire sur la socket
    
    /// 1) Écriture quand on connaît le "routeName"
    ///    -> Sécurise l'accès à sessions[routeName] et fait `session.writeText(...)` dans un block .barrier
    private func writeTextSafe(routeName: String, text: String) {
        sessionsQueue.async(flags: .barrier) {
            guard let sessionInfo = self.sessions[routeName] else {
                print("[writeTextSafe(routeName)] Aucune session pour route: \(routeName)")
                return
            }
            sessionInfo.session.writeText(text)
        }
    }
    
    /// 2) Écriture quand on n’a que la session,
    ///    par ex. pour le dashboard qui n’a pas un "routeName" direct.
    private func writeTextSafe(forSession session: WebSocketSession, text: String) {
        sessionsQueue.async(flags: .barrier) {
            // On essaie de retrouver la route associée à cette session
            if let (routeName, _) = self.sessions.first(where: { $0.value.session == session }) {
                // On a trouvé un routeName => on écrit via la méthode n°1
                self.writeTextSafe(routeName: routeName, text: text)
            } else {
                // Session introuvable => on écrit directement pour au moins répondre
                // (ou on ignore, selon la logique souhaitée)
                print("[writeTextSafe(forSession)] Pas de routeName pour cette session. Écriture directe.")
                session.writeText(text)
            }
        }
    }
    
    // MARK: - Enregistrer un "routeName" + callbacks
    func setupWithRoutesInfos(routeInfos: RouteInfos) {
        server["/" + routeInfos.routeName] = websocket(
            text: { session, text in
                // Réception texte
                if text == "pong" {
                    // Mise à jour du lastPongDate
                    self.sessionsQueue.async(flags: .barrier) {
                        if var sessionInfo = self.sessions[routeInfos.routeName] {
                            sessionInfo.lastPongDate = Date()
                            sessionInfo.isConnected = true
                            self.sessions[routeInfos.routeName] = sessionInfo
                        } else {
                            print("No session found for route: \(routeInfos.routeName)")
                        }
                    }
                }
                else if text == "ping" {
                    // Au lieu de session.writeText("pong"), on fait:
                    self.writeTextSafe(routeName: routeInfos.routeName, text: "pong")
                }
                else {
                    // Attention: si routeInfos.textCode appelle session.writeText(...)
                    // directement, on a le même problème de concurrence.
                    // => Il faut aussi remplacer *là-bas* par un appel à `writeTextSafe`.
                    routeInfos.textCode(session, text)
                }
            },
            binary: { session, binary in
                // Réception binaire
                self.sessionsQueue.async(flags: .barrier) {
                    self.sessions[routeInfos.routeName] = SessionInfo(
                        session: session,
                        isConnected: true,
                        lastPongDate: Date(),
                        callbackName: routeInfos.routeName
                    )
                }
                routeInfos.dataCode(session, Data(binary))
            },
            connected: { session in
                print("Client connected to route: /\(routeInfos.routeName)")
                self.sessionsQueue.async(flags: .barrier) {
                    self.sessions[routeInfos.routeName] = SessionInfo(
                        session: session,
                        isConnected: true,
                        lastPongDate: Date(),
                        callbackName: routeInfos.routeName
                    )
                }
            },
            disconnected: { session in
                print("Client disconnected from route: /\(routeInfos.routeName)")
                self.sessionsQueue.async(flags: .barrier) {
                    if let route = self.sessions.first(where: { $0.value.session == session })?.key {
                        self.sessions.removeValue(forKey: route)
                        print("Session for route \(route) has been removed.")
                    }
                }
            }
        )
    }
    
    // MARK: - Dashboard
    func setupDashboardRoute() {
        server["/dashboard"] = websocket(
            text: { session, text in
                // Réception texte sur la route /dashboard
                self.sessionsQueue.sync {
                    if let data = text.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let type = json["type"] as? String,
                       type == "get_status"
                    {
                        // Constructeur d'un dictionnaire "routeName -> [isConnected, callbackName]"
                        var statusDict: [String: [Any]] = [:]
                        for (routeName, sessionInfo) in self.sessions {
                            statusDict[routeName] = [sessionInfo.isConnected, sessionInfo.callbackName]
                        }
                        
                        if let jsonData = try? JSONSerialization.data(withJSONObject: statusDict, options: []),
                           let jsonString = String(data: jsonData, encoding: .utf8)
                        {
                            // Avant: session.writeText(jsonString)
                            // Maintenant: writeTextSafe(forSession: session, text: ...)
                            self.writeTextSafe(forSession: session, text: jsonString)
                        }
                    }
                    else {
                        print("Received non-JSON message on dashboard: \(text)")
                        // dispatcher le message (ex: "ipadRoberto:next_step")
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
    
    /// Envoi du message à toutes les sessions dont le routeName est présent dans le message
    private func dispatchMessage(_ message: String) {
        var newMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        
        self.sessionsQueue.sync {
            for (routeName, _) in self.sessions {
                // Exemple: si newMessage contient "ipadRoberto:next_step"
                // on détecte "ipadRoberto", et on envoie "next_step"
                if newMessage.contains(routeName) {
                    // Retirer "routeName:" du message
                    let prefix = "\(routeName):"
                    if newMessage.hasPrefix(prefix) {
                        newMessage = String(newMessage.dropFirst(prefix.count))
                    }
                    // Écriture "safe"
                    self.writeTextSafe(routeName: routeName, text: newMessage)
                }
            }
        }
    }
    
    // MARK: - Servir la page HTML
    func serveStaticHTML() {
        server["/"] = { _ in
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
                        margin: 10px 0;
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
                    .button-group {
                        display: flex;
                        flex-direction: column;
                        gap: 10px;
                        margin-top: 10px;
                    }
                    .trigger-button {
                        background-color: #2196F3;
                        color: white;
                        border: none;
                        padding: 8px 16px;
                        border-radius: 4px;
                        cursor: pointer;
                    }
                    .trigger-button:hover {
                        background-color: #1976D2;
                    }
                    .trigger-button:disabled {
                        background-color: #9E9E9E;
                        cursor: not-allowed;
                    }
                </style>
            </head>
            <body>
                <h1>Devices Connection Dashboard</h1>
                <div id="deviceStatus" class="device-list"></div>
                <script>
                    const routes = [
                        'espPapel1',
                        'espPapel2',
                        'espBougie',
                        'espFire',
                        'ipadRoberto',
                        'phoneFire',
                        'ipadAlma',
                        'espAutel1',
                        'espAutel-20',
                        'espLeds',
                        'phoneMix'
                    ];
                    
                    const callbacks = {
                        espBougie: function() {
                            socket.send("espBougie:turn_on_bougie")
                        },
                        espFire: function() {
                            socket.send("espFire:turn_on_fire")
                        },
                        ipadRoberto: function() {
                            socket.send("ipadRoberto:next_step")
                        },
                        previousStep: function() {
                            socket.send("ipadRoberto:previous_step")
                        },
                        triggerCoucou: function(){
                            socket.send("ipadRoberto:trigger_coucou")
                        },
                        triggerVideoY: function() {
                            socket.send("ipadRoberto:trigger_video_correct")
                        },
                        triggerVideoN: function() {
                            socket.send("ipadRoberto:trigger_video_incorrect")
                        },
                        ipadAlma: function() {
                            socket.send("ipadAlma:next_step")
                        },
                        previousStepAlma: function() {
                            socket.send("ipadAlma:previous_step")
                        },
                        launchVideoAlma: function() {
                            socket.send("ipadAlma:step_6_finished")
                        },
                        triggerWater: function () {
                            socket.send("espLeds:eau")
                            socket.send("ipadAlma:eau")
                        },
                        triggerEarth: function () {
                            socket.send("espLeds:terre")
                            socket.send("ipadAlma:terre")
                        },
                        triggerEnd: function () {
                            socket.send("espLeds:fin")
                            socket.send("ipadAlma:fin")
                        },
                        triggerFire: function () {
                            socket.send("espLeds:feu")
                            socket.send("ipadAlma:feu")
                        },
                        triggerEnd: function () {
                            socket.send("espLeds:air")
                            socket.send("ipadAlma:air")
                        },
                        turnOnBlue: function () {
                            socket.send("espLeds:autel_1")
                        },
                        turnOnGreen: function () {
                            socket.send("espLeds:autel_2")
                        },
                        turnOnRed: function () {
                            socket.send("espLeds:autel_3")
                        },
                        turnOnWhite: function () {
                            socket.send("espLeds:autel_4")
                        },
                        triggerVideoYAlma: function() {
                            socket.send("ipadAlma:trigger_video_correct")
                        },
                        resetLeds: function() { socket.send("espLeds:reset_leds") },
                        phoneMix: function() { socket.send("phoneMix:mix") }
                    };
                    
                    function triggerAction(callbackName) {
                        if (callbacks[callbackName]) {
                            callbacks[callbackName]();
                        } else {
                            console.error(`Callback ${callbackName} not found`);
                        }
                    }
                    
                    const deviceStatusElement = document.getElementById('deviceStatus');
                    
                    function createWebSocket() {
                        const websocket = new WebSocket(`ws://${window.location.host}/dashboard`);
                        
                        websocket.onopen = () => {
                            console.log('Dashboard WebSocket connection established');
                            websocket.send(JSON.stringify({ type: 'get_status' }));
                        };
                        
                        websocket.onmessage = (event) => {
                            try {
                                const data = JSON.parse(event.data);
                                updateDeviceStatus(data);
                            } catch (error) {
                                console.error('Error parsing message:', error);
                            }
                        };
                        
                        websocket.onclose = () => {
                            console.log('WebSocket connection closed. Reconnecting...');
                            setTimeout(createWebSocket, 6000);
                        };
                        
                        return websocket;
                    }
                    
                    function updateDeviceStatus(statusData) {
                        deviceStatusElement.innerHTML = '';
                        
                        routes.forEach(route => {
                            const deviceCard = document.createElement('div');
                            deviceCard.className = 'device-card';
                            
                            const deviceName = document.createElement('h2');
                            deviceName.textContent = route;
                            
                            const statusElement = document.createElement('div');
                            statusElement.className = 'device-status';
                            
                            const deviceInfo = statusData[route];
                            const isConnected = deviceInfo ? deviceInfo[0] : false;
                            const callbackName = deviceInfo ? deviceInfo[1] : 'unknown';
                            
                            statusElement.textContent = isConnected ? 'Connecté' : 'Déconnecté';
                            statusElement.classList.add(isConnected ? 'connected' : 'disconnected');
                            
                            const buttonGroup = document.createElement('div');
                            buttonGroup.className = 'button-group';
                            
                            if(callbacks[route]) {
                                const actionButton = document.createElement('button');
                                actionButton.className = 'trigger-button';
                                actionButton.textContent = 'Trigger Action/Next Step';
                                actionButton.disabled = !isConnected;
                                actionButton.onclick = () => triggerAction(route);
                                buttonGroup.appendChild(actionButton);
                            }
                            
                            if (route === "ipadRoberto") {
                                const actionButtonPrevious = document.createElement('button');
                                actionButtonPrevious.className = 'trigger-button';
                                actionButtonPrevious.textContent = 'Trigger Previous Step';
                                actionButtonPrevious.disabled = !isConnected;
                                actionButtonPrevious.onclick = () => triggerAction('previousStep');
                                buttonGroup.appendChild(actionButtonPrevious);
                                
                                const actionButtonCoucou = document.createElement('button');
                                actionButtonCoucou.className = 'trigger-button';
                                actionButtonCoucou.textContent = 'Trigger Coucou';
                                actionButtonCoucou.disabled = !isConnected;
                                actionButtonCoucou.onclick = () => triggerAction('triggerCoucou');
                                buttonGroup.appendChild(actionButtonCoucou);
                                
                                const actionButtonVideoY = document.createElement('button');
                                actionButtonVideoY.className = 'trigger-button';
                                actionButtonVideoY.textContent = 'Trigger Video Correct';
                                actionButtonVideoY.disabled = !isConnected;
                                actionButtonVideoY.onclick = () => triggerAction('triggerVideoY');
                                buttonGroup.appendChild(actionButtonVideoY);
                                
                                const actionButtonVideoN = document.createElement('button');
                                actionButtonVideoN.className = 'trigger-button';
                                actionButtonVideoN.textContent = 'Trigger Video Incorrect';
                                actionButtonVideoN.disabled = !isConnected;
                                actionButtonVideoN.onclick = () => triggerAction('triggerVideoN');
                                buttonGroup.appendChild(actionButtonVideoN);
                            }
                            
                            if (route === "espLeds") {
                                const actionResetLeds = document.createElement('button');
                                actionResetLeds.className = 'trigger-button';
                                actionResetLeds.textContent = 'Trigger reset leds';
                                actionResetLeds.disabled = !isConnected;
                                actionResetLeds.onclick = () => triggerAction('resetLeds');
                                buttonGroup.appendChild(actionResetLeds);
                                
                                const actionButtonBlue = document.createElement('button');
                                actionButtonBlue.className = 'trigger-button';
                                actionButtonBlue.textContent = 'Trigger leds blue';
                                actionButtonBlue.disabled = !isConnected;
                                actionButtonBlue.onclick = () => triggerAction('turnOnBlue');
                                buttonGroup.appendChild(actionButtonBlue);
                                
                                const actionButtonGreen = document.createElement('button');
                                actionButtonGreen.className = 'trigger-button';
                                actionButtonGreen.textContent = 'Trigger leds green';
                                actionButtonGreen.disabled = !isConnected;
                                actionButtonGreen.onclick = () => triggerAction('turnOnGreen');
                                buttonGroup.appendChild(actionButtonGreen);
                                
                                const actionButtonRed = document.createElement('button');
                                actionButtonRed.className = 'trigger-button';
                                actionButtonRed.textContent = 'Trigger leds red';
                                actionButtonRed.disabled = !isConnected;
                                actionButtonRed.onclick = () => triggerAction('turnOnRed');
                                buttonGroup.appendChild(actionButtonRed);
                                
                                const actionButtonWhite = document.createElement('button');
                                actionButtonWhite.className = 'trigger-button';
                                actionButtonWhite.textContent = 'Trigger leds white';
                                actionButtonWhite.disabled = !isConnected;
                                actionButtonWhite.onclick = () => triggerAction('turnOnWhite');
                                buttonGroup.appendChild(actionButtonWhite);
                            }
                            
                            if (route === "ipadAlma") {
                                const actionPreviousStep = document.createElement('button');
                                actionPreviousStep.className = 'trigger-button';
                                actionPreviousStep.textContent = 'Previous Step';
                                actionPreviousStep.disabled = !isConnected;
                                actionPreviousStep.onclick = () => triggerAction('previousStepAlma');
                                buttonGroup.appendChild(actionPreviousStep);
                                
                                const buttonLaunchVideoAlma = document.createElement('button');
                                buttonLaunchVideoAlma.className = 'trigger-button';
                                buttonLaunchVideoAlma.textContent = 'Launch Video Alma';
                                buttonLaunchVideoAlma.disabled = !isConnected;
                                buttonLaunchVideoAlma.onclick = () => triggerAction('launchVideoAlma');
                                buttonGroup.appendChild(buttonLaunchVideoAlma);
                                
                                const actionButtonVideoYAlma = document.createElement('button');
                                actionButtonVideoYAlma.className = 'trigger-button';
                                actionButtonVideoYAlma.textContent = 'Trigger Video Correct';
                                actionButtonVideoYAlma.disabled = !isConnected;
                                actionButtonVideoYAlma.onclick = () => triggerAction('triggerVideoYAlma');
                                buttonGroup.appendChild(actionButtonVideoYAlma);
                                
                                const actionButtonWater = document.createElement('button');
                                actionButtonWater.className = 'trigger-button';
                                actionButtonWater.textContent = 'Trigger leds water';
                                actionButtonWater.disabled = !isConnected;
                                actionButtonWater.onclick = () => triggerAction('triggerWater');
                                buttonGroup.appendChild(actionButtonWater);
                                
                                const actionButtonEarth = document.createElement('button');
                                actionButtonEarth.className = 'trigger-button';
                                actionButtonEarth.textContent = 'Trigger leds earth';
                                actionButtonEarth.disabled = !isConnected;
                                actionButtonEarth.onclick = () => triggerAction('triggerEarth');
                                buttonGroup.appendChild(actionButtonEarth);
                                
                                const actionButtonFire = document.createElement('button');
                                actionButtonFire.className = 'trigger-button';
                                actionButtonFire.textContent = 'Trigger leds fire';
                                actionButtonFire.disabled = !isConnected;
                                actionButtonFire.onclick = () => triggerAction('triggerFire');
                                buttonGroup.appendChild(actionButtonFire);
                                
                                const actionButtonEnd = document.createElement('button');
                                actionButtonEnd.className = 'trigger-button';
                                actionButtonEnd.textContent = 'Trigger leds end';
                                actionButtonEnd.disabled = !isConnected;
                                actionButtonEnd.onclick = () => triggerAction('triggerEnd');
                                buttonGroup.appendChild(actionButtonEnd);
                            }
                            
                            deviceCard.appendChild(deviceName);
                            deviceCard.appendChild(statusElement);
                            deviceCard.appendChild(buttonGroup);
                            deviceStatusElement.appendChild(deviceCard);
                        });
                    }
                    
                    let socket = createWebSocket();
                </script>
            </body>
            </html>
            """
            return HttpResponse.ok(.text(htmlContent))
        }
    }
    
    // MARK: - Démarrage du serveur
    func start() {
        do {
            print("🔄 Starting server...")
            serveStaticHTML()
            
            // Simple middleware pour loguer les requêtes entrantes
            server.middleware.append { request in
                print("📝 Incoming request: \(request.method) \(request.path)")
                return nil
            }
            
            try server.start(8080, priority: .userInteractive)
            print("✅ Server started successfully on port \(try server.port())")
            
            // Lancement du mécanisme de ping/pong
            startPingRoutine()
            
            // Gestion d'arrêt propre (Ctrl+C / SIGINT)
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
    
    // MARK: - Routine ping/pong
    private func startPingRoutine() {
        Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { _ in
            self.sessionsQueue.async(flags: .barrier) {
                for (routeName, sessionInfo) in self.sessions {
                    guard sessionInfo.isConnected else { continue }
                    
                    // On envoie un "ping" en mode safe
                    self.writeTextSafe(routeName: routeName, text: "ping")
                    
                    let intervalSincePong = Date().timeIntervalSince(sessionInfo.lastPongDate)
                    if intervalSincePong > self.pingTimeout {
                        print("No pong received from \(routeName) (>\(self.pingTimeout)s). Disconnecting.")
                        
                        // Fermer la socket proprement
                        sessionInfo.session.socket.close()
                        // Retirer la session
                        self.sessions.removeValue(forKey: routeName)
                    }
                }
            }
        }
    }
    
    // MARK: - Getter session
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
    
    // MARK: - Déconnecter tout le monde
    func disconnectAllSessions() {
        self.sessionsQueue.async(flags: .barrier) {
            for (routeName, sessionInfo) in self.sessions {
                print("Disconnecting session for route: \(routeName)")
                sessionInfo.session.socket.close()
            }
            self.sessions.removeAll()
            print("All sessions have been disconnected.")
        }
    }
}
