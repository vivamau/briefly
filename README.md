# Briefly

Briefly is a macOS application that allows you to record voice notes and transcribe/summarize them.

## App Distribution & Installation

The application can be compiled and packaged into a freely distributable disk image (DMG) format.

If you have been provided with the `Briefly-Installer.dmg` file, follow these instructions to install it.

### ⚠️ Important Note About Apple Gatekeeper

Because the application is **not signed with a paid Apple Developer Certificate**, macOS will try to block users from opening it when downloaded from the internet to protect them from unverified software.

When you download `Briefly-Installer.dmg` and attempt to open the app, you may see an error saying:
> **"Briefly" cannot be opened because the developer cannot be verified.**
> or "Briefly is damaged and can't be opened."

### How to bypass Gatekeeper:

Please follow these steps to open the app:

**Method 1: Right-Click to Open (Easiest)**
1. Open the `Briefly-Installer.dmg` file.
2. Drag `Briefly.app` from the DMG into your `Applications` folder.
3. Open your `Applications` folder on your Mac.
4. Instead of double-clicking the app, **Right-click** (or Control-click) on `Briefly.app` and select **Open**.
5. You will see a warning message, but this time there will be an **Open** button. Click it. 
6. The next time you open the app, you can double-click it normally.

**Method 2: Using Terminal (If the app says it is "damaged")**
If you followed Method 1 and the app says it is "damaged and can't be opened" or "moved to Trash":
1. Open the **Terminal** application on your Mac (you can find it using Spotlight Search).
2. Paste the following command and press Enter:
   ```bash
   xattr -cr /Applications/Briefly.app
   ```
3. Open the app as usual from your Applications folder.

### Microphone Permissions & Recording Issues
When you first open the application and attempt to record a voice note, macOS will prompt you to grant Microphone permissions to Briefly. Make sure to click **OK** so the application can capture your audio. If you accidentally decline, you can enable it in `System Settings > Privacy & Security > Microphone`.

#### ⚠️ "App opens but no audio is recorded":
Even if you bypass Gatekeeper and open the app, macOS has a deep security feature (TCC - Transparency, Consent, and Control) that **silently blocks microphone access** for apps with "foreign" ad-hoc signatures. Because this app was ad-hoc signed on the developer's Mac, your Mac does not trust the signature for privacy permissions.

To fix this, you must **virtually sign the app on your own Mac** using the Terminal:
1. Make sure you moved `Briefly.app` into your `Applications` folder.
2. Open **Terminal**.
3. Run this command to re-sign the app locally on your machine, preserving the required permissions:
   ```bash
   codesign --force --deep -s - --preserve-metadata=entitlements /Applications/Briefly.app
   ```
4. Re-open the app. When you press Record, it should now properly prompt you for Microphone access and record successfully!

---

## Building from Source

Follow these steps to build the app yourself and package it as a distributable DMG.

### Prerequisites

1. **macOS** — the build must be run on a Mac.
2. **Xcode** — install from the Mac App Store (the full IDE, not just Command Line Tools).
3. **Xcode Command Line Tools** must point to the full Xcode installation:
   ```bash
   # Check the current path
   xcode-select -p
   # If it shows /Library/Developer/CommandLineTools, switch it:
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

### Build the DMG

A build script is included that handles everything — archiving, ad-hoc code signing, and DMG creation:

```bash
cd briefly
./build_dmg.sh
```

The script will:
1. **Verify** that Xcode is properly configured
2. **Archive** the app in Release configuration for macOS
3. **Export** the `.app` bundle from the archive
4. **Code sign** with an ad-hoc signature (no Apple Developer account needed)
5. **Package** into a DMG with a drag-to-Applications layout

### Output

When the build completes, you'll find the DMG at:

```
briefly/build/briefly.dmg
```

You can distribute this file freely — share it via a website, GitHub Releases, Google Drive, etc.

> **Note:** Each time you run the script, the `build/` directory is cleaned and rebuilt from scratch.

### Troubleshooting

| Problem | Solution |
|---------|----------|
| `xcode-select: error: tool 'xcodebuild' requires Xcode` | Run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| `No App Category is set` warning | This is cosmetic — the build still succeeds. To fix, add `LSApplicationCategoryType` to `Info.plist`. |
| Archive fails with signing errors | Make sure `CODE_SIGN_STYLE = Automatic` is set in the Xcode project and no specific team is required. |

---

### Future Improvements
To eliminate these Gatekeeper warnings and local-signing workarounds entirely, the application would need to be officially signed and notarized using a paid Apple Developer Program account ($99/year).

---

## License
This project is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0). See the [LICENSE](LICENSE) file for details.
