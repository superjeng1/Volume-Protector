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

let logger = Logger(subsystem: "dev.jeng.Volume-Protector", category: "earSafety")

class Observers {
    var targetDeviceVolume = DeviceVolume()
    var eqMacName = DeviceName()
    var eqMacVolume = DeviceVolume()
    var defaultDevice = DefaultDevice()

    class Observer {
        var observer: NSObjectProtocol?
        func stop() {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
                self.observer = nil
            }
        }
    }

    class DeviceVolume: Observer {
        func createVolumeChangeObserver(_ device: AudioDevice, _ userOptions: Options) -> NSObjectProtocol {
            device.setVolume(
                userOptions.defaultVolume,
                channel: userOptions.deviceChannel,
                scope: userOptions.deviceScope)
            return NotificationCenter.default.addObserver(forName: .deviceVolumeDidChange,
                                                          object: device,
                                                          queue: .main) { (notification) in
                guard let channel = notification.userInfo?["channel"] as? UInt32 else { return }
                guard let scope = notification.userInfo?["scope"] as? Scope else { return }
                guard let volume = device.volume(channel: channel, scope: scope) else { return }
                logger.info("Volume of \"\(device.name, privacy: .public)\" was altered to \(volume * 100)%")
                if volume > userOptions.dangerousVolume {
                    device.setVolume(userOptions.defaultVolume, channel: channel, scope: scope)
                    logger.info("WARNING: Volume reduced to \(userOptions.defaultVolume * 100)%")
                    logger.info("from DANGEROUS volume \(volume * 100)% for \"\(device.name, privacy: .public)\"!")
                }
            }
        }
        func start(device: AudioDevice, userOptions: Options) {
            self.observer = self.observer ?? createVolumeChangeObserver(device, userOptions)
        }
    }

    class DeviceName: Observer {
        func createNameChangeObserver(_ eqMacDevice: AudioDevice,
                                      _ userOptions: Options,
                                      _ observers: Observers) -> NSObjectProtocol {
            return NotificationCenter.default.addObserver(forName: .deviceNameDidChange,
                                                                      object: eqMacDevice,
                                                                      queue: .main) { (_) in
                eqMacHandler(userOptions, observers, eqMacDevice: eqMacDevice)
                logger.info("Name changed.\(eqMacDevice.name)")
            }
        }
        func start(device: AudioDevice, userOptions: Options, observers: Observers) {
            self.observer = self.observer ?? createNameChangeObserver(device, userOptions, observers)
        }
    }

    class DefaultDevice: Observer {
        func createDefaultDeviceObserver(_ userOptions: Options, _ observers: Observers) -> NSObjectProtocol {
            return NotificationCenter.default.addObserver(forName: .defaultOutputDeviceChanged,
                                                                        object: nil,
                                                                        queue: .main) { (_) in
                guard let device = simplyCA.defaultOutputDevice else { return }
                if device.name.contains("eqMac") {
                    eqMacHandler(userOptions, observers, eqMacDevice: device)
                }
                logger.info("Default output changed.\(simplyCA.defaultOutputDevice!.name)")
            }
        }
        func start(userOptions: Options, observers: Observers) {
            self.observer = self.observer ?? createDefaultDeviceObserver(userOptions, observers)
        }
    }
}

func eqMacHandler(_ userOptions: Options,
                  _ observers: Observers,
                  eqMacDevice: AudioDevice? = simplyCA.allDevices.first(where: { $0.name.contains("eqMac") })) {
    guard let eqMacDevice else {
        observers.defaultDevice.start(userOptions: userOptions, observers: observers)
        observers.eqMacName.stop()
        return
    }
    
    let deviceName = eqMacDevice.name
    logger.info("eqMac virtual device found.\(deviceName, privacy: .public)")

    observers.defaultDevice.stop()
    observers.eqMacName.start(device: eqMacDevice, userOptions: userOptions, observers: observers)

    if deviceName.contains(userOptions.targetDeviceName) {
        logger.info("eqMac output device is the target device.")
        observers.eqMacVolume.start(device: eqMacDevice, userOptions: userOptions)
    } else {
        observers.eqMacVolume.stop()
    }
}

func targetDeviceHandler(_ userOptions: Options, _ observers: Observers) {
    let deviceList = simplyCA.allDevices

    if let device = deviceList.first(where: { $0.name == userOptions.targetDeviceName }) {
        logger.info("Setting volume for \"\(device.name, privacy: .public)\"")
        logger.info("to a default value of \(userOptions.defaultVolume * 100)%")
        logger.info("Starting volume observer for \"\(device.name, privacy: .public)\".")
        observers.targetDeviceVolume.start(device: device, userOptions: userOptions)
    } else {
        logger.info("Removing volume observer.")
        observers.targetDeviceVolume.stop()
    }
}

func createDeviceListChangedObserver(_ userOptions: Options, _ observers: Observers) -> NSObjectProtocol {
    targetDeviceHandler(userOptions, observers)
    eqMacHandler(userOptions, observers)
    return NotificationCenter.default.addObserver(forName: .deviceListChanged,
                                                  object: nil,
                                                  queue: .main) { (_) in
        targetDeviceHandler(userOptions, observers)
        eqMacHandler(userOptions, observers)
    }
}
