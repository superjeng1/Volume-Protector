# Volume Protector
A simple program that ensures the volume of an audio device does not exceed a certain value. 
## What it does
It will set the volume of the target device to a defined default value, then keep an eye on the volume of the device, when it exceeds a defined dangerous value, it will set the volume of it to the defined default volume **immediately**. *So fast that if you change the volume in the menu bar tool, the UI would not know that this program has changed the volume down to the default.* Check the up-to-date volume with the built-in `Audio MIDI Setup` app in macOS. (Look at the volume number instead of the bar, the bar won't update.
As a bounus, it will also change the volume of [eqMac](https://eqmac.app/)'s virutal device.
## Usage
```
USAGE: volume-protector <target-device-name> <default-volume> <dangerous-volume> <channel> <scope> <eqmac>

ARGUMENTS:
  <target-device-name>  Audio device to monitor. Use `"` to wrap around if name includes space.
  <default-volume>      Default volume to set the audio device to. (Betweeen 0.0 and 1.0)
  <dangerous-volume>    Set volume of the audio device to 'default volume' if device volume exceeds this number.
  <channel>             Channel to change the volume for. (Use 0 in most cases.)
  <scope>               Scope to apply to when changing the volume. (output|global|input|main|playthrough|wildcard)
  <eqmac>               Whether to montior the eqMac device. (true|false)
```
The above are the command line arguments needed for the program to run. Consider adding it as an LaunchAgent so macOS would start the program at start up. Here is an example of the file, save this file as `~/Library/LaunchAgents/dev.jeng.Volume-Protector.plist`, and place the program binary at `/usr/local/bin/volume-protector`. Make sure it has executable privileges and owned by root. The device name don't have to be wrapped in quotes `"`.
```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>Label</key>
        <string>dev.jeng.Volume-Protector</string>
        <key>ProgramArguments</key>
        <array>
            <string>/usr/local/bin/volume-protector</string>
            <string>Moonriver 2</string>
            <string>0.035</string>
            <string>0.08</string>
            <string>0</string>
            <string>output</string>
            <string>false</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <true/>
        <key>ThrottleInterval</key>
        <integer>1</integer>
    </dict>
</plist>
```
## How it works
To react as instant as possible, this program subscribes to CoreAudio events with [SimplyCoreAudio](https://github.com/rnine/SimplyCoreAudio) and not polling CoreAudio for updates. It subscribes to `deviceListChanged` to see if the target device is plugged or unplugged. Then it subscribes to `deviceVolumeDidChange` for that device. (Even if the target device is not the default!) Every time the event fires, it checks if the volume exceeds the threshold set. If that's the case, it would set it to the default volume.
It also monitors `defaultOutputDeviceChanged` because sometimes starting [eqMac](https://eqmac.app/) doesn't trigger the `deviceListChanged` event. (That works since [eqMac](https://eqmac.app/) takes over the default device when it is running.) After that it monitors `deviceNameDidChange` to see if the user switches the output device in [eqMac](https://eqmac.app/) to the target device, and activate `deviceVolumeDidChange` for the virtual device too if that is the case.
