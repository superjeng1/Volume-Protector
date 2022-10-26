//
//  main.swift
//  Volume Protector
//
//  Created by Willy Hsiao on 2022/10/24.
//

import Foundation
import SimplyCoreAudio
import os
import ArgumentParser

@main
struct VolumeProtector: ParsableCommand {
    @Argument(help: "Audio device to monitor.")
    var targetDeviceName: String
    
    @Argument(help: "Default volume to set the audio device to.")
    var defaultVolume: Float32
    
    @Argument(help: "Set volume of the audio device to 'default volume' if device volume exceeds this number.")
    var dangerousVolume: Float32
    
    @Option(name: .shortAndLong, help: "Channel to change the volume for. (Default: 0)")
    var channel: UInt32?
    
    @Option(name: .shortAndLong, help: "Scope to apply to when changing the volume. (Default: output)")
    var scope: String?
    
    func run() throws {
        logger.info("Greetings from Volume Protector!")
        
        let deviceChannel: UInt32 = channel ?? 0
        guard let deviceScope: Scope = str2scope[scope ?? "output"] else {
            logger.fault("Invalid scope.")
            return
        }
        
        _ = createDeviceListChangedObserver(targetDeviceName: targetDeviceName, defaultVolume: defaultVolume, dangerousVolume: dangerousVolume, deviceChannel: deviceChannel, deviceScope: deviceScope)
        
        RunLoop.main.run()
    }
}
