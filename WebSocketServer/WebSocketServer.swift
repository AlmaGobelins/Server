import SwiftUI
import Swifter

// MARK: - Structures
struct RouteInfos {
    let routeName: String
    let textCode: (WebSocketSession, String) -> Void
    let dataCode: (WebSocketSession, Data) -> Void
}

struct SessionClient {
    let name: String
    var session: WebSocketSession?
    var status: Bool
    var lastPongTime: Date?

    mutating func connect(_ session: WebSocketSession) {
        self.session = session
        self.status = true
        self.lastPongTime = Date()
    }

    mutating func disconnect() {
        self.session = nil
        self.status = false
        self.lastPongTime = nil
    }

    mutating func updatePongTime() {
        self.lastPongTime = Date()
    }
}

// MARK: - WebSocketServer
class WebSockerServer: ObservableObject {
    // MARK: - Properties
    static let instance = WebSockerServer()
    let server = HttpServer()
    private let pingInterval: TimeInterval = 5.0
    private let timeoutInterval: TimeInterval = 10.0

    @Published var allClients: [SessionClient] = [] {
        didSet {
            // Vérifier si un changement de statut a eu lieu
            let statusChanged = zip(oldValue, allClients).contains { old, new in
                return old.status != new.status
            }
            
            if statusChanged {
                notifyClients()
            }
        }
    }

    // MARK: - Client Management
    private func addClientIfNeeded(name: String) {
        if !allClients.contains(where: { $0.name == name }) {
            allClients.append(
                SessionClient(
                    name: name, session: nil, status: false, lastPongTime: nil))
        }
    }

    private func findClient(named name: String) -> Int? {
        return allClients.firstIndex(where: { $0.name == name })
    }

    private func updateClient(
        named name: String, action: (inout SessionClient) -> Void
    ) {
        if let index = findClient(named: name) {
            var updatedClients = allClients
            action(&updatedClients[index])
            allClients = updatedClients
        }
    }

    private func checkClientsTimeout() {
        let currentTime = Date()
        var needsUpdate = false
        var updatedClients = allClients

        for (index, client) in updatedClients.enumerated() {
            if client.status && client.lastPongTime != nil {
                let timeSinceLastPong = currentTime.timeIntervalSince(
                    client.lastPongTime!)
                if timeSinceLastPong > timeoutInterval {
                    print("Client \(client.name) timed out (no pong response)")
                    updatedClients[index].disconnect()
                    needsUpdate = true
                }
            }
        }

        if needsUpdate {
            allClients = updatedClients
        }
    }

    // MARK: - Status Updates & Notifications
    private func startPingTimer() {
        Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) {
            [weak self] _ in
            self?.pingAllClients()
            self?.checkClientsTimeout()
        }
    }

    private func pingAllClients() {
        allClients.forEach { client in
            if client.status {
                client.session?.writeText("ping")
            }
        }
    }

    private func createStatusMessage() -> String {
        return allClients
            .map { "\($0.name): \($0.status ? "Connecté" : "Déconnecté")" }
            .joined(separator: "\n")
    }

    private func notifyClients() {
        let statusMessage = createStatusMessage()
        allClients.forEach { client in
            if client.status {
                client.session?.writeText(statusMessage)
            }
        }
    }

    // MARK: - WebSocket Setup
    func setupWithRoutesInfos(routeInfos: RouteInfos) {
        addClientIfNeeded(name: routeInfos.routeName)

        server["/" + routeInfos.routeName] = websocket(
            text: { [weak self] session, text in
                self?.handleTextMessage(text, from: session, route: routeInfos)
            },
            binary: { session, receivedData in
                print(receivedData)
            },
            connected: { [weak self] session in
                self?.handleConnection(session, route: routeInfos)
            },
            disconnected: { [weak self] _ in
                self?.handleDisconnection(route: routeInfos)
            }
        )
    }

    private func handleConnection(
        _ session: WebSocketSession, route: RouteInfos
    ) {
        print("Client connected to route: /\(route.routeName)")
        updateClient(named: route.routeName) { client in
            client.connect(session)
        }
        // Le statut initial sera envoyé automatiquement via le didSet de allClients
    }

    private func handleTextMessage(
        _ text: String, from session: WebSocketSession, route: RouteInfos
    ) {
        if text == "pong" {
            updateClient(named: route.routeName) { client in
                if !client.status {
                    client.status = true  // Cela déclenchera une notification seulement si le statut change
                }
                client.updatePongTime()
            }
        } else {
            route.textCode(session, text)
        }
    }

    private func handleDisconnection(route: RouteInfos) {
        print("Client disconnected from route: /\(route.routeName)")
        updateClient(named: route.routeName) { client in
            client.disconnect()
        }
    }

    // MARK: - Server Lifecycle
    func start() {
        do {
            try server.start()
            print(
                "Server has started (port = \(try server.port())). Try to connect now..."
            )
            // L'état initial est déjà configuré lors de l'ajout des clients
            startPingTimer()
        } catch {
            print("Server failed to start: \(error.localizedDescription)")
        }
    }
}
