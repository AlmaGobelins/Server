//
//  main.swift
//  WebSocketServer
//
//  Created by Al on 22/10/2024.
//

import Foundation
import Combine
import Swifter

var serverWS = WebSockerServer()
var cmd = TerminalCommandExecutor()
var pingCancellable: AnyCancellable? = nil
var sensSessionsCancellable: AnyCancellable? = nil

var message: String = "Esp non connecté"
var timer: Timer?

// Tableau pour suivre toutes les sessions
var allSessions: [String:WebSocketSession] = [String:WebSocketSession]()

let maxMissedPings = 1 // Nombre maximum de pings manqués avant suppression
var missedPingCounts: [String: Int] = [:]

// Fonction pour envoyer un message de connexion à chaque appareil
func sendConnectionMessage(to session: WebSocketSession, for device: String) {
    let connectionMessage = "\(device) connecté"
    session.writeText(connectionMessage)
}

// Timer général pour surveiller les pings manqués
func startPingTimer() {
    pingCancellable = Timer
        .publish(every: 5.0, on: .main, in: .default)
        .autoconnect()
        .sink { _ in
            for (key, session) in allSessions {
                // Envoyer un ping
                session.writeText("ping")
                
                // Incrémenter le compteur de pings manqués
                missedPingCounts[key, default: 0] += 1
                
                // Vérifier si la session doit être supprimée
                if missedPingCounts[key]! >= maxMissedPings {
                    print("Session \(key) supprimée pour inactivité")
                    
                    // Supprimer la session
                    allSessions.removeValue(forKey: key)
                    missedPingCounts.removeValue(forKey: key)
                    
                    // Mise à jour immédiate de la télécommande
                    notifyTelecommandeAboutSessionChange()
                }
            }
        }
}

// Fonction pour notifier la télécommande des modifications
func notifyTelecommandeAboutSessionChange() {
    guard let telecommandeSession = serverWS.telecommandeSession else { return }
    telecommandeSession.writeSessionsList(allSessions)
}


func startSendingSessions() {
    sensSessionsCancellable = Timer
        .publish(every: 5.0, on: .main, in: .default)
        .autoconnect()
        .sink { _ in
            guard let tel = serverWS.telecommandeSession else { print("Telecommande non connectée"); return }
            tel.writeSessionsList(allSessions)
        }
}

// Route "telecommande"
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "telecommande", textCode: { session, receivedText in
    serverWS.telecommandeSession = session
    allSessions["telecommande"] = session  // Ajouter la session à la liste des sessions actives
    
    // Envoi du message de connexion à la télécommande
    sendConnectionMessage(to: session, for: "Télécommande")

    // Démarrer le timer pour les pings toutes les 5 secondes (une seule fois)
    if allSessions.count == 1 {
        startPingTimer()
        startSendingSessions()
    }
    
    if receivedText.trimmingCharacters(in: .whitespacesAndNewlines) != ""  {
        missedPingCounts["telecommande"] = 0
        return
    }
    notifyTelecommandeAboutSessionChange() 
}, dataCode: { session, receivedData in
    print(receivedData)
}))

// Exemple pour une route spécifique (e.g., "espConnect")
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "espConnect", textCode: { session, receivedText in
    // Ajouter ou mettre à jour la session
    serverWS.espSession = session
    allSessions["espConnect"] = session
    missedPingCounts["espConnect"] = 0 // Initialiser ou réinitialiser les pings manqués
    
    // Si le message est "pong", réinitialiser le compteur de pings
    if receivedText.trimmingCharacters(in: .whitespacesAndNewlines) != ""  {
        missedPingCounts["espConnect"] = 0
        return
    }
    
    // Envoi du message de connexion
    sendConnectionMessage(to: session, for: "ESP")
    
    // Mise à jour immédiate de la télécommande
    notifyTelecommandeAboutSessionChange()
}, dataCode: { session, receivedData in
    print(receivedData)
}))

// Route "rpiConnect"
/*
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "rpiConnect", textCode: { session, receivedText in
    serverWS.rpiSession = session
    allSessions.append(session)  // Ajouter la session à la liste des sessions actives
    
    // Envoi du message de connexion à Raspberry Pi
    sendConnectionMessage(to: session, for: "Raspberry Pi")

    print("Raspberry connected")
    print("Rpi Received Text \(receivedText)")
    
    if let espSess = serverWS.espSession {
        if receivedText.trimmingCharacters(in: .whitespacesAndNewlines) == "good" {
            espSess.writeText("allumer")
        }
    }
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "readRFID", textCode: { session, receivedText in
    allSessions.append(session)  // Ajouter la session à la liste des sessions actives
    
    // Envoi du message de connexion à la session
    sendConnectionMessage(to: session, for: "readRFID")

    // Démarrer le timer si c'est la première connexion
    if allSessions.count == 1 {
        startPingTimer()
    }

    if let rpiSess = serverWS.rpiSession {
        rpiSess.writeText("read")
        print("Read RFID --> Received Text:\(receivedText)")
    } else {
        print("RPI Non connecté")
    }

}, dataCode: { session, receivedData in
    print(receivedData)
}))

// Route "allumerFeu"
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "allumerFeu", textCode: { session, receivedText in
    allSessions.append(session)  // Ajouter la session à la liste des sessions actives
    
    // Envoi du message de connexion à la session
    sendConnectionMessage(to: session, for: "allumerFeu")

    // Démarrer le timer si c'est la première connexion
    if allSessions.count == 1 {
        startPingTimer()
    }

    if let espSess = serverWS.espSession {
        espSess.writeText("allumer")
    } else {
        print("ESP Non connecté")
    }
    print("--> Received Text: \(receivedText)")
}, dataCode: { session, receivedData in
    print(receivedData)
}))

// Route "espFireplace"
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "espFireplace", textCode: { session, receivedText in
    serverWS.espFireplace = session
    allSessions.append(session)  // Ajouter la session à la liste des sessions actives
    
    // Envoi du message de connexion à la session
    sendConnectionMessage(to: session, for: "espFireplace")

    // Démarrer le timer si c'est la première connexion
    if allSessions.count == 1 {
        startPingTimer()
    }
}, dataCode: { session, receivedData in
    print(receivedData)
}))

// Route "phoneFireplace"
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "phoneFireplace", textCode: { session, receivedText in
    print("Fireplace phone - msg reçu : \(receivedText)")
    allSessions.append(session)  // Ajouter la session à la liste des sessions actives
    
    // Envoi du message de connexion à la session
    sendConnectionMessage(to: session, for: "phoneFireplace")

    // Démarrer le timer si c'est la première connexion
    if allSessions.count == 1 {
        startPingTimer()
    }
    
    guard let espSession = serverWS.espFireplace else {
        session.writeText("Esp Fireplace not connected")
        return
    }
    espSession.writeText(receivedText)
}, dataCode: { session, receivedData in
    print(receivedData)
}))

// Route "phoneMixer"
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "phoneMixer", textCode: { session, receivedText in
    print("currentSession  : \(session)")
    session.writeText("Connected to route : 'phoneMixer'")
    serverWS.phoneMixer = session
    allSessions.append(session)  // Ajouter la session à la liste des sessions actives
    
    // Envoi du message de connexion à la session
    sendConnectionMessage(to: session, for: "phoneMixer")

    // Démarrer le timer si c'est la première connexion
    if allSessions.count == 1 {
        startPingTimer()
    }
}, dataCode: { session, receivedData in
    print(receivedData)
}))

// Route "espMixer"
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "espMixer", textCode: { session, receivedText in
    print("Mixer esp - msg reçu : \(receivedText)")
    allSessions.append(session)  // Ajouter la session à la liste des sessions actives
    
    // Envoi du message de connexion à la session
    sendConnectionMessage(to: session, for: "espMixer")

    // Démarrer le timer si c'est la première connexion
    if allSessions.count == 1 {
        startPingTimer()
    }
    
    guard let pMixerSession = serverWS.phoneMixer else {
        session.writeText("Phone mixer not connected")
        return
    }
    pMixerSession.writeText(receivedText)
}, dataCode: { session, receivedData in
    print(receivedData)
}))
*/
serverWS.start()

RunLoop.main.run()


