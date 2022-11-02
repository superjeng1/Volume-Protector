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

protocol Observer: AnyObject {
    var observer: NSObjectProtocol? { get set }
    func create(_ device: AudioDevice) -> NSObjectProtocol
    func create() -> NSObjectProtocol
    func start(device: AudioDevice)
    func start()
    func stop()
}

extension Observer {
    func create(_ device: AudioDevice) -> NSObjectProtocol { return NSObject() }
    func create() -> NSObjectProtocol { return NSObject() }
    func start(device: AudioDevice) { self.observer = self.observer ?? create(device) }
    func start() { self.observer = self.observer ?? create() }
    func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }
}

class Observers {
    static let targetDeviceVolume = DeviceVolume()
    static let eqMacName = DeviceName()
    static let eqMacVolume = DeviceVolume()
    static let defaultDevice = DefaultDevice()
    static let deviceList = DeviceList()

    class DeviceVolume: Observer {
        var observer: NSObjectProtocol?
        func create(_ device: AudioDevice) -> NSObjectProtocol {
            device.setVolume(
                Cli.User.options.defaultVolume,
                channel: Cli.User.options.deviceChannel,
                scope: Cli.User.options.deviceScope)
            return NotificationCenter.default.addObserver(forName: .deviceVolumeDidChange,
                                                          object: device,
                                                          queue: .main) { (notification) in
                guard let channel = notification.userInfo?["channel"] as? UInt32 else { return }
                guard let scope = notification.userInfo?["scope"] as? Scope else { return }
                guard let volume = device.volume(channel: channel, scope: scope) else { return }
                logger.info("Volume of \"\(device.name, privacy: .public)\" was altered to \(volume * 100)%")
                if volume > Cli.User.options.dangerousVolume {
                    device.setVolume(Cli.User.options.defaultVolume, channel: channel, scope: scope)
                    logger.info("WARNING: Volume reduced to \(Cli.User.options.defaultVolume * 100)%")
                    logger.info("from DANGEROUS volume \(volume * 100)% for \"\(device.name, privacy: .public)\"!")
                }
            }
        }
    }

    class DeviceName: Observer {
        var observer: NSObjectProtocol?
        func create(_ device: AudioDevice) -> NSObjectProtocol {
            return NotificationCenter.default.addObserver(forName: .deviceNameDidChange,
                                                                      object: device,
                                                                      queue: .main) { (_) in
                Handler.eqMac(eqMacDevice: device)
                logger.info("Name changed.\(device.name)")
            }
        }
    }

    class DefaultDevice: Observer {
        var observer: NSObjectProtocol?
        func create() -> NSObjectProtocol {
            return NotificationCenter.default.addObserver(forName: .defaultOutputDeviceChanged,
                                                                        object: nil,
                                                                        queue: .main) { (_) in
                guard let device = simplyCA.defaultOutputDevice else { return }
                if device.name.contains("eqMac") {
                    Handler.eqMac(eqMacDevice: device)
                }
                logger.info("Default output changed.\(simplyCA.defaultOutputDevice!.name)")
            }
        }
    }

    class DeviceList: Observer {
        var observer: NSObjectProtocol?
        func create() -> NSObjectProtocol {
            Handler.targetDevice()
            Handler.eqMac()
            return NotificationCenter.default.addObserver(forName: .deviceListChanged,
                                                          object: nil,
                                                          queue: .main) { (_) in
                Handler.targetDevice()
                Handler.eqMac()
            }
        }
    }
}

class Handler {
    static func eqMac(eqMacDevice: AudioDevice? = simplyCA.allDevices.first(where: { $0.name.contains("eqMac") })) {
        guard let eqMacDevice else {
            Observers.defaultDevice.start()
            Observers.eqMacName.stop()
            return
        }

        let deviceName = eqMacDevice.name
        logger.info("eqMac virtual device found.\(deviceName, privacy: .public)")

        Observers.defaultDevice.stop()
        Observers.eqMacName.start(device: eqMacDevice)

        if deviceName.contains(Cli.User.options.targetDeviceName) {
            logger.info("eqMac output device is the target device.")
            Observers.eqMacVolume.start(device: eqMacDevice)
        } else {
            Observers.eqMacVolume.stop()
        }
    }

    static func targetDevice() {
        let deviceList = simplyCA.allDevices

        if let device = deviceList.first(where: { $0.name == Cli.User.options.targetDeviceName }) {
            logger.info("Setting volume for \"\(device.name, privacy: .public)\"")
            logger.info("to a default value of \(Cli.User.options.defaultVolume * 100)%")
            logger.info("Starting volume observer for \"\(device.name, privacy: .public)\".")
            Observers.targetDeviceVolume.start(device: device)
        } else {
            logger.info("Removing volume observer.")
            Observers.targetDeviceVolume.stop()
        }
    }
}
