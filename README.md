# Syncthing plugin for KOReader

This is a plugin for running Syncthing on e-readers running KOReader. Syncthing
is a peer-to-peer file synchronization program. This makes it possible to sync
files between your e-reader and computer / phone automatically. The Syncthing
instance on your e-reader can be managed directly in the KOReader menu.

The method of running Syncthing is originally based on [The Anarcat's blog post](https://anarc.at/hardware/tablet/kobo-clara-hd/#install-syncthing).

## Project status

- This plugin is provided as-is. Make frequent data backups and use it
  at your own risk!
- Some features are not working yet, such as global discovery service

## Tested devices

- Kobo Libra 2
- (Please send pull requests to add your tested device here!)

## Installation

### Prerequisites

- Currently the plugin is only tested on a Kobo device. Maybe it will also work
  on Kindle and other Linux-based environments, but additional testing will be
  needed.
- You should have installed KOReader and will need to copy files to the device.
- You need to setup Syncthing on another device, which will be able to connect
  to your e-reader in your local Wi-Fi network.

### Install plugin

1.  Download the [latest ZIP from GitHub](https://github.com/jasonchoimtt/koreader-syncthing/archive/refs/heads/main.zip)
    and extract the archive.
2.  Copy the folder `syncthing.koplugin` to your KOReader installation, under
    the `plugins` folder. For Kobo devices, this is usually
    `.adds/koreader/plugins` in the device storage.
3.  Restart KOReader.

### Configure devices and folders

4.  The Syncthing menu will be available under the Tools tab in the file
    browser. Check *Syncthing* menu item to start the Syncthing server. Make
    sure the e-reader is also connected to Wi-Fi.
5.  On your other Syncthing device, add the e-reader by scanning the QR code or
    entering the device ID manually.
6.  Go to the *Pending* menu and accept the device.
7.  On your other Syncthing device, add the e-reader to a folder.
8.  Go to the *Pending* menu and accept the folder.
    - Make sure that you set the path to under your user storage.
    - For Kobo device, this should be a directory under `/mnt/onboard`.
9.  View the *Status* menu to see sync status.
10. For other options you will need to use the Syncthing GUI. Use *Set GUI
    Password* menu item to set GUI password and go to `http://<ereader-ip>:8384`
    on another device. Login with username `syncthing` and your password. You
    can tap *Syncthing Web GUI* menu item to see network info.

## FAQ

- **Why would you want Syncthing on an e-reader?**

  It keeps my books and annotations continuously synchronized with my computer.
  For the privacy-conscious people, Syncthing does not require you to create a
  cloud account, and does not store your data in the cloud.

  If you have multiple e-readers, it is also convenient to synchronize books
  between the e-readers.

  If you have an Android e-reader, you can use the Android [Syncthing
  Fork](https://github.com/Catfriend1/syncthing-android) app for syncing. You
  can then use the KOReader app on Android. Using this plugin on Android is not
  supported.

- **How well does it work?**

  The synchronization itself usually works quite well on the e-reader side, but
  the connectivity is also affected by your other devices and the local network
  conditions. Having a Syncthing menu right in KOReader is the first step in
  making this accessible to the community.

## Developing

- Syncthing binaries are included in the repository from the [official
  releases](https://syncthing.net/downloads/)
  - Using Linux ARM 32-bit binary

## Limitations

- Currently, global discovery and relay is not working. That means it will not
  be possible to sync devices over the internet.
- The Syncthing menu is still limited in functionality when it comes to managing
  devices and folders.

## TODO

- [ ] Pull latest syncthing binary from official releases
- [ ] Allow adding device to folder from e-reader
- [ ] Properly accept three-way sharing
- [ ] Fix global discovery service functionality
- [ ] Implement conflict resolution for KOReader metadata file
