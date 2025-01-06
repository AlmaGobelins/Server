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

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "readRFID", textCode: { session, receivedText in
    if let rpiSess = serverWS.getSession(forRoute: "rpiConnect") {
        rpiSess.writeText("read")
        print("Read RFID --> Received Text: \(receivedText)")
    } else {
        print("RPI Non connecté")
    }
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "allumerFeu", textCode: { session, receivedText in
    if let espSess = serverWS.getSession(forRoute: "espConnect") {
        espSess.writeText("allumer")
    } else {
        print("ESP Non connecté")
    }
    print("--> Received Text: \(receivedText)")
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "espFire", textCode: { session, receivedText in
    print("Esp Fire connecté ---> \(receivedText)")

}, dataCode: { session, receivedData in
    print("ESP Fire data received: \(receivedData)")
}))


serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "espBougie", textCode: { session, receivedText in
    print("Esp bougie connecté ---> \(receivedText)")

}, dataCode: { session, receivedData in
    print("Esp bougie data received: \(receivedData)")
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "ipadRoberto", textCode: { session, receivedText in
    print("receivedText : \(receivedText)")
}, dataCode: { session, receivedData in
    print("Ipad data received: \(receivedData)")
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "espBanderolleConnect", textCode: { session, receivedText in
    print("Esp Banderolle connecté ---> \(receivedText)")
    
    if receivedText == "both"{
        if let ipadSession = serverWS.getSession(forRoute: "ipadRoberto") {
            ipadSession.writeText(receivedText)
        } else {
            session.writeText("Ipad Roberto not connected")
        }
    }

}, dataCode: { session, receivedData in
    print("Esp Banderolle data received: \(receivedData)")
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "phoneFire", textCode: { session, receivedText in
    print("Fireplace phone - msg reçu : \(receivedText)")
    
    if receivedText == "souffle" {
        if let espSession = serverWS.getSession(forRoute: "espFire") {
            espSession.writeText(receivedText)
        } else {
            session.writeText("Esp Fireplace not connected")
        }
    }
    
    
    if receivedText == "allumer" {
        if let espSession = serverWS.getSession(forRoute: "espBougie") {
            espSession.writeText(receivedText)
        } else {
            session.writeText("Esp Bougie not connected")
        }
    }
    
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupDashboardRoute()
serverWS.start()

RunLoop.main.run()
