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


serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "telecommande", textCode: { session, receivedText in
    print("telecommandeSession connected : \(serverWS.allClients)")
    print(receivedText)
}, dataCode: { session, receivedData in
    print(receivedData)
}))


serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "espConnect", textCode: { session, receivedText in

}, dataCode: { session, receivedData in
    print(receivedData)
}))


serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "rpiConnect", textCode: { session, receivedText in
    print("rpiConnect connected : \(serverWS.allClients)")

    print("Rpi Received Text \(receivedText)")
    
    if receivedText.trimmingCharacters(in: .whitespacesAndNewlines) == "good" {
        if let espIndex = serverWS.allClients.firstIndex(where: { $0.name == "espConnect" }),
           let espSession = serverWS.allClients[espIndex].session {
            espSession.writeText("allumer")
        }
    }
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "readRFID", textCode: { session, receivedText in
    if let rpiIndex = serverWS.allClients.firstIndex(where: { $0.name == "rpiConnect" }),
       let rpiSession = serverWS.allClients[rpiIndex].session {
        rpiSession.writeText("read")
        print("Read RFID --> Received Text: \(receivedText)")
    } else {
        print("RPI Non connecté")
    }
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "allumerFeu", textCode: { session, receivedText in
    if let espIndex = serverWS.allClients.firstIndex(where: { $0.name == "espConnect" }),
       let espSession = serverWS.allClients[espIndex].session {
        espSession.writeText("allumer")
    } else {
        print("ESP Non connecté")
    }
    print("--> Received Text: \(receivedText)")
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "espFireplace", textCode: { session, receivedText in
    print("ESP Fireplace Received Text: \(receivedText)")
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "phoneFireplace", textCode: { session, receivedText in
    print("Fireplace phone - msg reçu : \(receivedText)")
    if let espIndex = serverWS.allClients.firstIndex(where: { $0.name == "espFireplace" }),
       let espSession = serverWS.allClients[espIndex].session {
        espSession.writeText(receivedText)
    } else {
        session.writeText("Esp Fireplace not connected")
    }
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "phoneMixer", textCode: { session, receivedText in
    print("Phone Mixer Received Text: \(receivedText)")
    session.writeText("Connected to route : 'phoneMixer'")
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "espMixer", textCode: { session, receivedText in
    print("Mixer esp - msg reçu : \(receivedText)")
    if let phoneIndex = serverWS.allClients.firstIndex(where: { $0.name == "phoneMixer" }),
       let phoneSession = serverWS.allClients[phoneIndex].session {
        phoneSession.writeText(receivedText)
    } else {
        session.writeText("Phone mixer not connected")
    }
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.start()

RunLoop.main.run()
