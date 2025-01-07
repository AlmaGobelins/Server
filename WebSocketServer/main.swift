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
    
    if let ipadAlma = serverWS.getSession(forRoute: "ipadAlma") {
        if receivedText == "step_6_finished"{
            ipadAlma.writeText(receivedText)
        }
    }
}, dataCode: { session, receivedData in
    print("Ipad data received: \(receivedData)")
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "ipadAlma", textCode: { session, receivedText in
    print("receivedText : \(receivedText)")
    if let ledsSession = serverWS.getSession(forRoute: "espLeds") {
        ledsSession.writeText(receivedText)
    } else {
        session.writeText("Leds not connected")
    }
}, dataCode: { session, receivedData in
    print("Ipad data received: \(receivedData)")
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "espPapel1", textCode: { session, receivedText in
    print("espPapel1: \(receivedText)")
    if receivedText == "papel_1_both"{
        if let ipadSession = serverWS.getSession(forRoute: "ipadRoberto") {
            ipadSession.writeText(receivedText)
        } else {
            session.writeText("Ipad Roberto not connected")
        }
    }

}, dataCode: { session, receivedData in
    print("Esp Banderolle data received: \(receivedData)")
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "espPapel2", textCode: { session, receivedText in
    print("espPapel2: \(receivedText)")
    
    if receivedText == "papel_2_both"{
        if let ipadSession = serverWS.getSession(forRoute: "ipadRoberto") {
            ipadSession.writeText(receivedText)
        } else {
            session.writeText("Ipad Roberto not connected")
        }
    }
    
}, dataCode: { session, receivedData in
    print("Esp Banderolle data received: \(receivedData)")
}))


serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "espAutel1", textCode: { session, receivedText in
    print("espAutel1: \(receivedText)")
    if receivedText == "autel_1" || receivedText == "autel_2"{
        if let ledsSession = serverWS.getSession(forRoute: "espLeds") {
            ledsSession.writeText(receivedText)
        } else {
            session.writeText("Leds not connected")
        }
    }
}, dataCode: { session, receivedData in
    print("Esp Banderolle data received: \(receivedData)")
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "espAutel2", textCode: { session, receivedText in
    print("espAutel2: \(receivedText)")
    if receivedText == "autel_3" || receivedText == "autel_4"{
        if let ledsSession = serverWS.getSession(forRoute: "espLeds") {
            ledsSession.writeText(receivedText)
        } else {
            session.writeText("Leds not connected")
        }
    }
}, dataCode: { session, receivedData in
    print("Esp Banderolle data received: \(receivedData)")
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "espLeds", textCode: { session, receivedText in
    print("espLeds: \(receivedText)")
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
