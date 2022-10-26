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
        
        _ = createDeviceListChangedObserver(userOptions: userOptions)
        
        RunLoop.main.run()
    }
}
