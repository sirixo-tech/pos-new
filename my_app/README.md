# SELFX POS

Flutter point-of-sale application. Release versions come from `pubspec.yaml`
(currently `3.1.12+2005`). The source directory and Dart package remain `my_app`;
the application name shown to users is **SELFX POS**. Platform bundle IDs are
preserved for update compatibility.

## Windows installer

Requirements: Flutter with Windows desktop support, Visual Studio's Desktop
development with C++ workload, and [Inno Setup 6.3 or newer](https://jrsoftware.org/isdl.php).

From this directory, run:

```powershell
./scripts/build-windows-installer.ps1
```

The script builds the release and creates
`build/installer/SELFX-POS-3.1.12+2005-windows-setup.exe` plus a SHA-256 file.
Use `-IsccPath 'C:\path\to\ISCC.exe'` for a custom compiler location. Use
`-SkipBuild` only with a complete release matching `pubspec.yaml`.

Setup includes the Flutter bundle, plugins, assets and MSVC runtime. It installs
for the current user, adds a Start menu shortcut, and offers a desktop shortcut
and launch after setup. Keep the installer AppId stable across releases.
Setup copies legacy `com.example/my_app` application data to the renamed data
directories without overwriting existing files. Close the old app before setup.
Uninstall leaves application data intact.

The release workflow builds a portable ZIP and setup EXE. Tagged releases
publish both; `latest.json` points Windows updates to the setup EXE and its
SHA-256 digest. Use setup when upgrading from the old name to migrate settings.

Manual verification: install on Windows, launch from the Start menu, rerun
setup to check upgrades, and uninstall from Settings.
