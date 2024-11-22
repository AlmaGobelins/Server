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


serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "rpiConnect", textCode: { session, receivedText in
    serverWS.rpiSession = session
    print("RPI Connecté")
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "iPhoneConnect", textCode: { session, receivedText in
    serverWS.iPhoneSession = session
    print("IPhone Connecté")
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "testRobot", textCode: { session, receivedText in
    if let rpiSess = serverWS.rpiSession {
        rpiSess.writeText("python3 drive.py")
    } else {
        print("RPI Non connecté")
    }
}, dataCode: { session, receivedData in
    print(receivedData)
}))


serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "moveRobot", textCode: { session, receivedText in
    if let rpiSess = serverWS.rpiSession {
        print("Mouvement du robot \(receivedText)")
        rpiSess.writeText("python3 \(receivedText).py")
        print("Mouvement du robot fini")
    } else {
        print("RPI Non connecté")
    }
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "say", textCode: { session, receivedText in
    cmd.say(textToSay: receivedText)
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "imagePrompting", textCode: { session, receivedText in
    if let jsonData = receivedText.data(using: .utf8),
       let imagePrompting = try? JSONDecoder().decode(ImagePrompting.self, from: jsonData) {
        let dataImageArray = imagePrompting.toDataArray()
        let tmpImagesPath = TmpFileManager.instance.saveImageDataArray(dataImageArray: dataImageArray)
        
        if (tmpImagesPath.count == 1) {
            cmd.imagePrompting(imagePath: tmpImagesPath[0], prompt: imagePrompting.prompt)
        } else {
            print("You are sending too much images.")
        }
    }
}, dataCode: { session, receivedData in
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "imagePromptingToText", textCode: { session, receivedText in
    
    cancellable?.cancel()
    cancellable = cmd.$output.sink { newValue in
        session.writeText(newValue)
    }
    
    if let jsonData = receivedText.data(using: .utf8),
       let imagePrompting = try? JSONDecoder().decode(ImagePrompting.self, from: jsonData) {
        let dataImageArray = imagePrompting.toDataArray()
        let tmpImagesPath = TmpFileManager.instance.saveImageDataArray(dataImageArray: dataImageArray)
        
        if (tmpImagesPath.count == 1) {
            cmd.imagePrompting(imagePath: tmpImagesPath[0], prompt: imagePrompting.prompt)
        } else {
            print("You are sending too much images.")
        }
    }
}, dataCode: { session, receivedData in
}))

serverWS.start()

RunLoop.main.run()

