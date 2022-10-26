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

let targetDeviceName = "Moonriver 2"
let dangerousVolume: Float = 0.08
let defaultVolume: Float = 0.035
let deviceChannel: UInt32 = 0
let deviceScope: Scope = Scope.output

let simplyCA = SimplyCoreAudio()
var observers:[NSObjectProtocol] = []

let logger = Logger(subsystem: "dev.jeng.Volume-Protector", category: "earSafety")
logger.info("Greetings from Volume Protector!")

func addVolumeChangeObserver(device: AudioDevice) -> Void {
    observers.append(
        NotificationCenter.default.addObserver(forName: .deviceVolumeDidChange, object: device, queue: .main) { (notification) in
            // Handle notification.
            guard let channel = notification.userInfo?["channel"] as? UInt32 else { return }
            guard let scope = notification.userInfo?["scope"] as? Scope else { return }
            guard let volume = device.volume(channel: channel, scope: scope) else { return }
            logger.info("Volume of \"\(device.name, privacy: .public)\" was altered to \(volume * 100)%")
            if volume > dangerousVolume {
                device.setVolume(defaultVolume, channel: channel, scope: scope)
                logger.info("WARNING: Volume reduced to \(defaultVolume * 100)% from DANGEROUS volume \(volume * 100)% for \"\(device.name, privacy: .public)\"!")
            }
        }
    )
}

func deviceListChangedHandler() -> Void {
    let deviceList = simplyCA.allDevices
    
    if let targetDevice = deviceList.first(where: { $0.name == targetDeviceName }) {
        let eqMacDevice = deviceList.first(where: { $0.name.contains("eqMac") })
        let targetDevices = [targetDevice, eqMacDevice].compactMap { $0 }
        for device in targetDevices {
            logger.info("Setting volume for \"\(device.name, privacy: .public)\" to a default value of \(defaultVolume * 100)%")
            device.setVolume(defaultVolume, channel: deviceChannel, scope: deviceScope)
            logger.info("Starting volume observer for \"\(device.name, privacy: .public)\".")
            addVolumeChangeObserver(device: device)
        }
    } else {
        while let observer = observers.popLast() {
            logger.info("Removing Observer")
            NotificationCenter.default.removeObserver(observer)
        }
        /*
        for observer in observers {
            logger.info("Removing Observer")
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        */
    }
}


deviceListChangedHandler()

for await _ in NotificationCenter.default.notifications(named: .deviceListChanged) {
    deviceListChangedHandler()
}


//let d = simplyCA.allDevices.filter { $0.name == targetDeviceName }[0]
//d.setVolume(defaultVolume, channel: deviceChannel, scope: deviceScope)
//addVolumeChangeObserver(device: d)

/*
func findTargetDevice(devices: [AudioDevice]) -> AudioDevice? {
    for device in devices {
        if device.name == targetDeviceName {
            print("INFO: The target device \"\(targetDeviceName)\" is found!")
            return device
        }
    }
    return nil
}
*/
/*
 func findTargetDevices(devices: [AudioDevice]) -> [AudioDevice] {
    var matchingDevices:[AudioDevice] = []
    for device in devices {
        if device.name.contains(targetDeviceName) {
            print("INFO: The target device \"\(device.name)\" is found!")
            matchingDevices.append(device)
        }
    }
    return matchingDevices
}
*/


/*
for await notification in NotificationCenter.default.notifications(named: .deviceListChanged) {
    guard let addedDevices = notification.userInfo?["addedDevices"] as? [AudioDevice] else {
        print("ERROR: addedDevices is nil!")
        continue
    }
    guard let removedDevices = notification.userInfo?["removedDevices"] as? [AudioDevice] else {
        print("ERROR: removedDevices is nil!")
        continue
    }

    if let addedDevice = findTargetDevice(devices: addedDevices) {
        print("INFO: Setting volume for \"\(targetDeviceName)\" to default value of \(defaultVolume * 100)%")
        addedDevice.setVolume(defaultVolume, channel: deviceChannel, scope: deviceScope)
        print("INFO: Starting volume observer.")
        addVolumeChangeObserver(device: addedDevice)
    }

    if findTargetDevice(devices: removedDevices) != nil {
        if observer != nil {
            print("INFO: Removing Observer")
            NotificationCenter.default.removeObserver(observer!)
        }
    }
}
*/
