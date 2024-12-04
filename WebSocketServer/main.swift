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
var cancellable: AnyCancellable? = nil

var message: String = "Esp non connecté"
var timer: Timer?

// Tableau pour suivre toutes les sessions
var allSessions: [WebSocketSession] = []

// Fonction pour envoyer un message de connexion à chaque appareil
func sendConnectionMessage(to session: WebSocketSession, for device: String) {
    let connectionMessage = "\(device) connecté"
    session.writeText(connectionMessage)
}

// Fonction pour envoyer un ping toutes les 5 secondes à toutes les sessions
func startPingTimer() {
    cancellable = Timer
        .publish(every: 5.0, on: .main, in: .default)
        .autoconnect()
        .sink { _ in
            // Envoi du ping à toutes les sessions actives
            for session in allSessions {
                session.writeText("ping")
            }
        }
}

// Route "telecommande"
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "telecommande", textCode: { session, receivedText in
    serverWS.telecommandeSession = session
    allSessions.append(session)  // Ajouter la session à la liste des sessions actives
    
    // Envoi du message de connexion à la télécommande
    sendConnectionMessage(to: session, for: "Télécommande")

    // Démarrer le timer pour les pings toutes les 5 secondes (une seule fois)
    if allSessions.count == 1 {
        startPingTimer()
    }

}, dataCode: { session, receivedData in
    print(receivedData)
}))

// Route "espConnect"
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "espConnect", textCode: { session, receivedText in
    serverWS.espSession = session
    allSessions.append(session)  // Ajouter la session à la liste des sessions actives
    
    // Envoi du message de connexion à l'ESP
    sendConnectionMessage(to: session, for: "ESP")

    guard let telecommandeSession = serverWS.telecommandeSession else {
        print("Télécommande session introuvable")
        return
    }

    message = "ESP Connecté"
    telecommandeSession.writeText(message)
}, dataCode: { session, receivedData in
    print(receivedData)
}))

// Route "rpiConnect"
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

serverWS.start()

RunLoop.main.run()


