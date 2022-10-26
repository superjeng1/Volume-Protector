//
//  main.swift
//  Volume Protector
//
//  Created by Willy Hsiao on 2022/10/24.
//

import Foundation
import SimplyCoreAudio
import os

@main
class main {
    static func main() {
        logger.info("Greetings from Volume Protector!")
        
        guard let userOptions = getUserOptions() else { print(usageString); return }
        
        logger.info("Device: \"\(userOptions.targetDeviceName, privacy: .public)\"")
        logger.info("Default Volume: \"\(userOptions.defaultVolume, privacy: .public)\"")
        logger.info("Dangerous Volume: \"\(userOptions.dangerousVolume, privacy: .public)\"")
        logger.info("Channel: \"\(userOptions.deviceChannel, privacy: .public)\"")
        logger.info("Scope: \"\(str2scope.first(where: { $0.value == userOptions.deviceScope })!.key, privacy: .public)\"")
        
        _ = createDeviceListChangedObserver(userOptions: userOptions)
        
        RunLoop.main.run()
    }
}
