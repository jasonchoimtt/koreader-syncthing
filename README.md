# Syncthing plugin for KOReader

This is a plugin for running Syncthing on e-readers. The Syncthing instance can
be managed directly in the KOReader menu.

## Project status

- This plugin has not been widely tested. Make frequent data backups and use it
  at your own risk!
- Tested on Kobo Libra 2
- Some features are not working yet, such as global discovery service

## Installation

1.  Copy `syncthing.koplugin` to your KOReader installation.
2.  The Syncthing menu will be available under the Tools tab.
3.  On your other Syncthing device, add the e-reader by scanning the QR code or
    entering the device ID manually.
4.  Go to the Pending menu and accept the device.
5.  On your other Syncthing device, add the e-reader to a folder.
6.  Go to the Pending menu and accept the folder.
7.  View the Status menu to see sync status.
8.  For other options you will need to use the Syncthing GUI, use the menu to
    set GUI password and go to `http://<ereader-ip>:8384` on another device.
    Login using username `syncthing` and your password.

## TODO

- [ ] Pull latest syncthing binary from official releases
- [ ] Allow adding device to folder from e-reader
- [ ] Fix global discovery service functionality
- [ ] Implement conflict resolution for KOReader metadata file
