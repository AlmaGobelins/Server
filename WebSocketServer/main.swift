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

/* ** TODO: vérifier les noms des routes sur les clients ** */

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

