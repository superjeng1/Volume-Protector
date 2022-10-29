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
var observers: [NSObjectProtocol] = []
var targetDeviceVolumeobserver: NSObjectProtocol?
var eqMacNameObserver: NSObjectProtocol?
var eqMacVolumeObserver: NSObjectProtocol?
var defaultDeviceObserver: NSObjectProtocol?

let logger = Logger(subsystem: "dev.jeng.Volume-Protector", category: "earSafety")

let str2scope = [
    "output": Scope.output,
    "global": Scope.global,
    "input": Scope.input,
    "main": Scope.main,
    "playthrough": Scope.playthrough,
    "wildcard": Scope.wildcard
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
  <target-device-name>    Audio device to monitor. Use `"` to wrap around if name includes space.
  <default-volume>        Default volume to set the audio device to.
  <dangerous-volume>      Set volume of the audio device to 'default volume' if device volume exceeds this number.
  <channel>               Channel to change the volume for. (Use 0 in most cases.)
  <scope>                 Scope to apply to when changing the volume. (output|global|input|main|playthrough|wildcard)
"""

func getUserOptions() -> Options? {
    var args: [String] = CommandLine.arguments.dropFirst().reversed()

    guard let targetDeviceName = args.popLast() else { print("Too few arguments!"); return nil }
    guard let defaultVolume = args.popLast()?.float32 else { print("<default-volume> is not Float32."); return nil }
    guard let dangerousVolume = args.popLast()?.float32 else { print("<dangerous-volume> is not Float32."); return nil }
    guard let deviceChannel = args.popLast()?.uint32 else { print("<channel> is not UInt32."); return nil }
    guard let deviceScope = args.popLast().flatMap({str2scope[$0]}) else { print("<scope> is invalid."); return nil }
    guard args.isEmpty else { print("Too many arguments!"); return nil }

    return Options(
        targetDeviceName: targetDeviceName,
        defaultVolume: defaultVolume,
        dangerousVolume: dangerousVolume,
        deviceChannel: deviceChannel,
        deviceScope: deviceScope)
}

func createVolumeChangeObserver(device: AudioDevice, userOptions: Options) -> NSObjectProtocol {
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

func eqMacHandler(userOptions: Options, eqMacDevice: AudioDevice? = nil) {
    let deviceList: [AudioDevice] = simplyCA.allDevices
    guard let device: AudioDevice = eqMacDevice ?? deviceList.first(where: { $0.name.contains("eqMac") }) else {
        if defaultDeviceObserver == nil {
            defaultDeviceObserver = createDefaultDeviceObserver(userOptions: userOptions)
        }
        return
    }
    if let deviceObserver = defaultDeviceObserver {
        NotificationCenter.default.removeObserver(deviceObserver)
        defaultDeviceObserver = nil
    }
    let deviceName: String = device.name
    logger.info("eqMac virtual device found.\(deviceName, privacy: .public)")
    if eqMacNameObserver == nil {
        eqMacNameObserver = createEQMacObserver(eqMacDevice: device, userOptions: userOptions)
    }
    if deviceName.contains(userOptions.targetDeviceName) {
        logger.info("eqMac output device is the target device.")
        if eqMacVolumeObserver == nil {
            eqMacVolumeObserver = createVolumeChangeObserver(device: device, userOptions: userOptions)
        }
    } else {
        if let volumeObserver = eqMacVolumeObserver {
            NotificationCenter.default.removeObserver(volumeObserver)
            eqMacVolumeObserver = nil
        }
    }
}

func createEQMacObserver(eqMacDevice: AudioDevice, userOptions: Options) -> NSObjectProtocol {
    return NotificationCenter.default.addObserver(forName: .deviceNameDidChange,
                                                   object: eqMacDevice,
                                                    queue: .main) { (_) in
        eqMacHandler(userOptions: userOptions, eqMacDevice: eqMacDevice)
        logger.info("Name changed.\(eqMacDevice.name)")
    }
}

func createDefaultDeviceObserver(userOptions: Options) -> NSObjectProtocol {
    return NotificationCenter.default.addObserver(forName: .defaultOutputDeviceChanged,
                                                   object: nil,
                                                    queue: .main) { (_) in
        if let device: AudioDevice = simplyCA.defaultOutputDevice {
            let deviceName: String = device.name
            if deviceName.contains("eqMac") {
                eqMacHandler(userOptions: userOptions, eqMacDevice: device)
            }
        }
        logger.info("Default output changed.\(simplyCA.defaultOutputDevice!.name)")
    }
}

func targetDeviceHandler(userOptions: Options) {
    let deviceList = simplyCA.allDevices
    var newObservers: [NSObjectProtocol] = []

    if let device = deviceList.first(where: { $0.name == userOptions.targetDeviceName }) {
        logger.info("Setting volume for \"\(device.name, privacy: .public)\"")
        logger.info("to a default value of \(userOptions.defaultVolume * 100)%")
        device.setVolume(userOptions.defaultVolume, channel: userOptions.deviceChannel, scope: userOptions.deviceScope)
        logger.info("Starting volume observer for \"\(device.name, privacy: .public)\".")
        newObservers.append(createVolumeChangeObserver(device: device, userOptions: userOptions))
    }

    while let observer = observers.popLast() {
        logger.info("Removing volume observer.")
        NotificationCenter.default.removeObserver(observer)
    }
    observers = newObservers
}

func createDeviceListChangedObserver(userOptions: Options) -> NSObjectProtocol {
    targetDeviceHandler(userOptions: userOptions)
    eqMacHandler(userOptions: userOptions)
    return NotificationCenter.default.addObserver(forName: .deviceListChanged,
                                                   object: nil,
                                                    queue: .main) { (_) in
        targetDeviceHandler(userOptions: userOptions)
        eqMacHandler(userOptions: userOptions)
    }
}
