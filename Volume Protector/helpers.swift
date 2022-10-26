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

func volumeChangeHandler(notification: Notification, device: AudioDevice, defaultVolume: Float32, dangerousVolume: Float32) -> Void {
    guard let channel = notification.userInfo?["channel"] as? UInt32 else { return }
    guard let scope = notification.userInfo?["scope"] as? Scope else { return }
    guard let volume = device.volume(channel: channel, scope: scope) else { return }
    logger.info("Volume of \"\(device.name, privacy: .public)\" was altered to \(volume * 100)%")
    if volume > dangerousVolume {
        device.setVolume(defaultVolume, channel: channel, scope: scope)
        logger.info("WARNING: Volume reduced to \(defaultVolume * 100)% from DANGEROUS volume \(volume * 100)% for \"\(device.name, privacy: .public)\"!")
    }
}

func createVolumeChangeObserver(device: AudioDevice, defaultVolume: Float32, dangerousVolume: Float32) -> NSObjectProtocol {
    return NotificationCenter.default.addObserver(forName: .deviceVolumeDidChange, object: device, queue: .main) { (notification) in
        volumeChangeHandler(
            notification: notification,
            device: device,
            defaultVolume: defaultVolume,
            dangerousVolume: dangerousVolume
        )
    }
}

func deviceListChangedHandler(targetDeviceName: String, defaultVolume: Float32, dangerousVolume: Float32, deviceChannel: UInt32, deviceScope: Scope) -> Void {
    let deviceList = simplyCA.allDevices
    
    if let targetDevice = deviceList.first(where: { $0.name == targetDeviceName }) {
        let eqMacDevice = deviceList.first(where: { $0.name.contains("eqMac") })
        let targetDevices = [targetDevice, eqMacDevice].compactMap { $0 }
        for device in targetDevices {
            logger.info("Setting volume for \"\(device.name, privacy: .public)\" to a default value of \(defaultVolume * 100)%")
            device.setVolume(defaultVolume, channel: deviceChannel, scope: deviceScope)
            logger.info("Starting volume observer for \"\(device.name, privacy: .public)\".")
            volumeChangeObservers.append(
                createVolumeChangeObserver(device: device, defaultVolume: defaultVolume, dangerousVolume: dangerousVolume)
            )
        }
    } else {
        while let observer = volumeChangeObservers.popLast() {
            logger.info("Removing Observer")
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

func createDeviceListChangedObserver(targetDeviceName: String, defaultVolume: Float32, dangerousVolume: Float32, deviceChannel: UInt32, deviceScope: Scope) -> NSObjectProtocol {
    deviceListChangedHandler(
        targetDeviceName: targetDeviceName,
        defaultVolume: defaultVolume,
        dangerousVolume: dangerousVolume,
        deviceChannel: deviceChannel,
        deviceScope: deviceScope
    )
    return NotificationCenter.default.addObserver(forName: .deviceListChanged, object: nil, queue: .main) { (notification) in
        deviceListChangedHandler(
            targetDeviceName: targetDeviceName,
            defaultVolume: defaultVolume,
            dangerousVolume: dangerousVolume,
            deviceChannel: deviceChannel,
            deviceScope: deviceScope
        )
    }
}
