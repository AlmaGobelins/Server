import Swifter
import SwiftUI

struct RouteInfos {
    var routeName: String
    var textCode: (WebSocketSession, String) -> ()
    var dataCode: (WebSocketSession, Data) -> ()
}

class WebSockerServer: ObservableObject {
    static let instance = WebSockerServer()
    let server = HttpServer()
    
    // Sessions pour chaque périphérique
    var telecommandeSession: WebSocketSession?
    var espSession: WebSocketSession?
    var rpiSession: WebSocketSession?
    var espFireplace: WebSocketSession?
    var phoneMixer: WebSocketSession?
    
    // Dictionnaire des états des périphériques
    @Published var devicesStatus: [String: Bool] = [String:Bool]()
    
    // Démarrer la mise à jour régulière des états
    func startStatusUpdates() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.updateDevicesStatus()
        }
    }
    
    // Mettre à jour les états des périphériques
    func updateDevicesStatus() {
        self.devicesStatus = [
            "telecommande": telecommandeSession != nil,
            "espConnect": espSession != nil,
            "rpiConnect": rpiSession != nil,
            "espFireplace": espFireplace != nil,
            "phoneMixer": phoneMixer != nil
        ]
        
        // Informer tous les clients des mises à jour
        notifyClients()
    }
    
    // Notifier les clients connectés avec les états mis à jour
    func notifyClients() {
        let devicesStatusString = devicesStatus.map { "\($0.key): \($0.value ? "Connecté" : "Déconnecté")" }
            .joined(separator: "\n")
        
        for session in [telecommandeSession, espSession, rpiSession, espFireplace, phoneMixer] {
            session?.writeText(devicesStatusString)
        }
    }
    
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
                // On met à jour le statut du périphérique correspondant
                self.updateDeviceStatus(forRoute: routeInfos.routeName, isConnected: true)
            },
            disconnected: { session in
                print("Client disconnected from route: /\(routeInfos.routeName)")
                // On met à jour le statut du périphérique correspondant
                self.updateDeviceStatus(forRoute: routeInfos.routeName, isConnected: false)
            }
        )
    }
    
    func updateDeviceStatus(forRoute route: String, isConnected: Bool) {
        switch route {
        case "telecommande":
            telecommandeSession = isConnected ? telecommandeSession : nil
        case "espConnect":
            espSession = isConnected ? espSession : nil
        case "rpiConnect":
            rpiSession = isConnected ? rpiSession : nil
        case "espFireplace":
            espFireplace = isConnected ? espFireplace : nil
        case "phoneMixer":
            phoneMixer = isConnected ? phoneMixer : nil
        default:
            break
        }
        
        // Mise à jour des états des périphériques
        updateDevicesStatus()
    }
    
    func start() {
        do {
            try server.start()
            print("Server has started (port = \(try server.port())). Try to connect now...")
            startStatusUpdates()
        } catch {
            print("Server failed to start: \(error.localizedDescription)")
        }
    }
}
