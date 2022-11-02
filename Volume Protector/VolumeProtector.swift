//
//  main.swift
//  Volume Protector
//
//  Created by Willy Hsiao on 2022/10/24.
//

import Foundation
import SimplyCoreAudio

@main
struct Main {
    static func main() {
        logger.info("Greetings from Volume Protector!")

        logger.info("Device: \"\(Cli.User.options.targetDeviceName, privacy: .public)\"")
        logger.info("Default Volume: \"\(Cli.User.options.defaultVolume, privacy: .public)\"")
        logger.info("Dangerous Volume: \"\(Cli.User.options.dangerousVolume, privacy: .public)\"")
        logger.info("Channel: \"\(Cli.User.options.deviceChannel, privacy: .public)\"")
        guard let scopeStr = Cli.str2scope.first(where: { $0.value == Cli.User.options.deviceScope })?.key else {
            return
        }
        logger.info("Scope: \"\(scopeStr, privacy: .public)\"")

        Observers.deviceList.start()

        RunLoop.main.run()
    }
}
