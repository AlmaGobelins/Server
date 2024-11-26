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


serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "espFireplaceConnect", textCode: { session, receivedText in
    serverWS.espFireplace = session
    print("ESP Connecté")
    session.writeText("CONNECTION AU SERVER RÉUSSIE")
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "iPhoneConnect", textCode: { session, receivedText in
    serverWS.iPhoneSession = session
    print("iPhone Connecté")
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "fireplace", textCode: { session, receivedText in
    print("received message frm fireplace : \(receivedText)")
    guard let espSession = serverWS.espFireplace else { session.writeText("Esp not connected"); return }
    espSession.writeText(receivedText)
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.start()

RunLoop.main.run()

