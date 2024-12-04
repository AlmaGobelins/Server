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
var cancellable:AnyCancellable? = nil

var message: String = "Esp non connecté"
var timer: Timer?

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "telecommande", textCode: { session, receivedText in
    serverWS.telecommandeSession = session

    cancellable = Timer
            .publish(every: 2.0, on: .main, in: .default)
            .autoconnect()
            .sink { _ in
                guard let telecommandeSession = serverWS.telecommandeSession else {
                    print("Télécommande session introuvable")
                    return
                }
                telecommandeSession.writeText(message)
            }

}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "espConnect", textCode: { session, receivedText in
    serverWS.espSession = session

    guard let telecommandeSession = serverWS.telecommandeSession else {
        print("Télécommande session introuvable")
        return
    }

    message = "Esp Connecté"
    telecommandeSession.writeText(message)
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "rpiConnect", textCode: { session, receivedText in
    serverWS.rpiSession = session
    
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
    if let rpiSess = serverWS.rpiSession {
        rpiSess.writeText("read")
        print("Read RFID --> Received Text:\(receivedText)")

    } else {
        print("RPI Non connecté")
    }
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "allumerFeu", textCode: { session, receivedText in
    if let espSess = serverWS.espSession {
        espSess.writeText("allumer")
    } else {
        print("ESP Non connecté")
    }
    print("--> Received Text: \(receivedText)")
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "espFireplace", textCode: { session, receivedText in
    serverWS.espFireplace = session
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "phoneFireplace", textCode: { session, receivedText in
    print("Fireplce phone - msg reçu : \(receivedText)")
    guard let espSession = serverWS.espFireplace else { session.writeText("Esp Fireplace not connected"); return }
    espSession.writeText(receivedText)
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "phoneMixer", textCode: { session, receivedText in
    print("currentSession  : \(session)")
    session.writeText("Connected to route : 'phoneMixer'")
    serverWS.phoneMixer = session
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "espMixer", textCode: { session, receivedText in
    print("Mixer esp - msg reçu : \(receivedText)")
    guard let pMixerSession = serverWS.phoneMixer else { session.writeText("Phone mixer not connected"); return }
    pMixerSession.writeText(receivedText)
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.start()

RunLoop.main.run()

