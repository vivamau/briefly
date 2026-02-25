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

### Future Improvements
To eliminate these Gatekeeper warnings and local-signing workarounds entirely, the application would need to be officially signed and notarized using a paid Apple Developer Program account ($99/year).
