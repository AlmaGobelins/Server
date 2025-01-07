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
    private let pingInterval: TimeInterval = 5.0
    private let pingTimeout: TimeInterval = 10.0
    
    func setupWithRoutesInfos(routeInfos: RouteInfos) {
        server["/" + routeInfos.routeName] = websocket(
            text: { session, text in
                if text == "pong" {
                    self.sessions[routeInfos.routeName]?.lastPongDate = Date()
                    self.sessions[routeInfos.routeName]?.isConnected = true
                    print("Received pong from route: \(routeInfos.routeName)")
                } else {
                    routeInfos.textCode(session, text)
                }
            },
            binary: { session, binary in
                // Ajout ou mise à jour de la session dans le dictionnaire
                self.sessions[routeInfos.routeName] = (session: session, isConnected: true, lastPongDate: Date(), callbackName: routeInfos.routeName)
                routeInfos.dataCode(session, Data(binary))
            },
            connected: { session in
                print("Client connected to route: /\(routeInfos.routeName)")
                // Ajouter la session à la collection des sessions
                self.sessions[routeInfos.routeName] = (session: session, isConnected: true, lastPongDate: Date(), callbackName: routeInfos.routeName)
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
                        var statusDict: [String: [Any]] = [:]
                        for (routeName, sessionInfo) in self.sessions {
                            statusDict[routeName] = [sessionInfo.isConnected, sessionInfo.callbackName]
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
                            'espAutel2',
                            'espLeds'
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
                            triggerSugar: function() {
                                socket.send("ipadRoberto:trigger_sugar")
                            },
                            triggerVideoBougie: function() {
                                socket.send("ipadRoberto:play_video_bougie")
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
                                socket.send("espLeds:water")
                            },
                            triggerEarth: function () {
                                socket.send("espLeds:earth")
                            },
                            triggerFire: function () {
                                socket.send("espLeds:fire")
                            },
                            triggerEnd: function () {
                                socket.send("espLeds:end")
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
                        };
                        
                        function triggerAction(callbackName) {
                            if (callbacks[callbackName]) {
                                callbacks[callbackName]();
                            } else {
                                console.error(`Callback ${callbackName} not found`);
                            }
                        }
                        
                        const deviceStatusElement = document.getElementById('deviceStatus');
                        let websocket;
                        
                        function createWebSocket() {
                            websocket = new WebSocket(`ws://${window.location.host}/dashboard`);
                            
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
            
                                        const actionButtonSugar = document.createElement('button');
                                        actionButtonSugar.className = 'trigger-button';
                                        actionButtonSugar.textContent = 'Trigger Sugar Video';
                                        actionButtonSugar.disabled = !isConnected;
                                        actionButtonSugar.onclick = () => triggerAction('triggerSugar');
                                        buttonGroup.appendChild(actionButtonSugar);
            
                                        const actionButtonVideoBougie = document.createElement('button');
                                        actionButtonVideoBougie.className = 'trigger-button';
                                        actionButtonVideoBougie.textContent = 'Trigger Video Bougie';
                                        actionButtonVideoBougie.disabled = !isConnected;
                                        actionButtonVideoBougie.onclick = () => triggerAction('triggerVideoBougie');
                                        buttonGroup.appendChild(actionButtonVideoBougie);

                                    }
            
                                    if (route === "espLeds") {
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
                        
                        const socket = createWebSocket();
                    </script>
                </body>
            </html>
            """
            
            return HttpResponse.ok(.text(htmlContent))
        }
    }
    
    private func dispatchMessage(_ message: String) {
        var newMessage = message
        for (routeName, sessionInfo) in self.sessions {
            if newMessage.trimmingCharacters(in: .whitespacesAndNewlines).contains(routeName) {
                newMessage.trimPrefix("\(routeName):")
                sessionInfo.session.writeText(newMessage)
            }
        }
    }
    
    func start() {
        do {
            print("🔄 Starting server...")
            serveStaticHTML()
            
            // Ajoutez ces options
            server.middleware.append { request in
                print("📝 Incoming request: \(request.method) \(request.path)")
                return nil
            }
            
            try server.start(8080, priority: .userInteractive)
            
            print("✅ Server started successfully on port \(try server.port())")
            startPingRoutine()
        } catch {
            print("❌ Server failed to start: \(error.localizedDescription)")
        }
    }
    
    private func startPingRoutine() {
        Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { _ in
            for (routeName, sessionInfo) in self.sessions {
                guard sessionInfo.isConnected else { continue }
                
                // Envoi du ping
                sessionInfo.session.writeText("ping")
                print("Ping envoyé à \(routeName)")

                    if Date().timeIntervalSince(sessionInfo.lastPongDate) > self.pingTimeout {
                    // Si aucun pong reçu dans le délai, marquer comme non connecté
                    self.sessions[routeName]?.isConnected = false
                    sessionInfo.session.socket.close()
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
