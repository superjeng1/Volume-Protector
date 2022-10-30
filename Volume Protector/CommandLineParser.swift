//
//  CommandLineParser.swift
//  Volume Protector
//
//  Created by Willy Hsiao on 2022/10/30.
//

import Foundation
import SimplyCoreAudio

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

struct Options {
    let targetDeviceName: String
    let defaultVolume: Float32
    let dangerousVolume: Float32
    let deviceChannel: UInt32
    let deviceScope: Scope
}

let str2scope = [
    "output": Scope.output,
    "global": Scope.global,
    "input": Scope.input,
    "main": Scope.main,
    "playthrough": Scope.playthrough,
    "wildcard": Scope.wildcard
]

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
