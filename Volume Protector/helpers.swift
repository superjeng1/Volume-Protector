//
//  helpers.swift
//  Volume Protector
//
//  Created by Willy Hsiao on 2022/10/26.
//

import Foundation
import SimplyCoreAudio
import os

let simplyCA = SimplyCoreAudio()
var volumeChangeObservers:[NSObjectProtocol] = []

let logger = Logger(subsystem: "dev.jeng.Volume-Protector", category: "earSafety")

let str2scope = [
    "output": Scope.output,
    "global": Scope.global,
    "input": Scope.input,
    "main": Scope.main,
    "playthrough": Scope.playthrough,
    "wildcard": Scope.wildcard,
]

struct Options {
    let targetDeviceName: String
    let defaultVolume: Float32
    let dangerousVolume: Float32
    let deviceChannel: UInt32
    let deviceScope: Scope
}

extension StringProtocol {
    var float32: Float32? { Float32(self) }
    var uint32: UInt32? { UInt32(self) }
}

let usageString = """
USAGE: volume-protector <target-device-name> <default-volume> <dangerous-volume> <channel> <scope>

ARGUMENTS:
  <target-device-name>    Audio device to monitor.
  <default-volume>        Default volume to set the audio device to.
  <dangerous-volume>      Set volume of the audio device to 'default volume' if device volume exceeds this number.
  <channel>               Channel to change the volume for.
  <scope>                 Scope to apply to when changing the volume.
"""

func getUserOptions() -> Options? {
    if CommandLine.arguments.count < 6 { logger.fault("Invalid input length"); return nil }
    CommandLine.arguments.removeFirst()
    var targetDeviceName = CommandLine.arguments.removeFirst()
    if targetDeviceName.first == "\"" {
        while targetDeviceName.last != "\"" {
            targetDeviceName += CommandLine.arguments.removeFirst()
        }
    }
    if CommandLine.arguments.count != 4 { logger.fault("Invalid input length"); return nil }
    guard let defaultVolume = CommandLine.arguments.removeFirst().float32 else { logger.fault("Invalid input."); return nil }
    guard let dangerousVolume = CommandLine.arguments.removeFirst().float32 else { logger.fault("Invalid input."); return nil }
    guard let deviceChannel = CommandLine.arguments.removeFirst().uint32 else { logger.fault("Invalid input."); return nil }
    let deviceScopeStr = CommandLine.arguments.removeFirst()
    
    guard let deviceScope: Scope = str2scope[deviceScopeStr] else {
        logger.fault("Invalid scope.")
        return nil
    }
    
    return Options(targetDeviceName: targetDeviceName, defaultVolume: defaultVolume, dangerousVolume: dangerousVolume, deviceChannel: deviceChannel, deviceScope: deviceScope)
}

func createVolumeChangeObserver(device: AudioDevice, userOptions: Options) -> NSObjectProtocol {
    return NotificationCenter.default.addObserver(forName: .deviceVolumeDidChange, object: device, queue: .main) { (notification) in
        guard let channel = notification.userInfo?["channel"] as? UInt32 else { return }
        guard let scope = notification.userInfo?["scope"] as? Scope else { return }
        guard let volume = device.volume(channel: channel, scope: scope) else { return }
        logger.info("Volume of \"\(device.name, privacy: .public)\" was altered to \(volume * 100)%")
        if volume > userOptions.dangerousVolume {
            device.setVolume(userOptions.defaultVolume, channel: channel, scope: scope)
            logger.info("WARNING: Volume reduced to \(userOptions.defaultVolume * 100)% from DANGEROUS volume \(volume * 100)% for \"\(device.name, privacy: .public)\"!")
        }
    }
}

func deviceListChangedHandler(userOptions: Options) -> Void {
    let deviceList = simplyCA.allDevices
    
    if let targetDevice = deviceList.first(where: { $0.name == userOptions.targetDeviceName }) {
        let eqMacDevice = deviceList.first(where: { $0.name.contains("eqMac") })
        let targetDevices = [targetDevice, eqMacDevice].compactMap { $0 }
        for device in targetDevices {
            logger.info("Setting volume for \"\(device.name, privacy: .public)\" to a default value of \(userOptions.defaultVolume * 100)%")
            device.setVolume(userOptions.defaultVolume, channel: userOptions.deviceChannel, scope: userOptions.deviceScope)
            logger.info("Starting volume observer for \"\(device.name, privacy: .public)\".")
            volumeChangeObservers.append(
                createVolumeChangeObserver(device: device, userOptions: userOptions)
            )
        }
    } else {
        while let observer = volumeChangeObservers.popLast() {
            logger.info("Removing Observer")
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

func createDeviceListChangedObserver(userOptions: Options) -> NSObjectProtocol {
    deviceListChangedHandler(userOptions: userOptions)
    return NotificationCenter.default.addObserver(forName: .deviceListChanged, object: nil, queue: .main) { (notification) in
        deviceListChangedHandler(userOptions: userOptions)
    }
}
