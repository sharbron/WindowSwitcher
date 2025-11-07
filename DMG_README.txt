========================================
   WindowSwitcher Installation
========================================

IMPORTANT: macOS Security Notice
---------------------------------
This app is not code-signed. macOS will block it by default.

INSTALLATION STEPS:
---------------------------------

1. Drag WindowSwitcher.app to the Applications folder

2. Open Terminal and run this command:

   xattr -cr /Applications/WindowSwitcher.app

3. Launch WindowSwitcher from Applications folder

4. Grant permissions when macOS asks:
   • Accessibility (required) - for Cmd+Tab monitoring
   • Screen Recording (optional) - for window previews

5. If you still see a warning, right-click the app → Open → Open Anyway


ALTERNATIVE METHOD:
---------------------------------
• Right-click WindowSwitcher.app → Open → Open Anyway
• System Settings → Privacy & Security → Open Anyway


WHY THIS HAPPENS:
---------------------------------
This app is unsigned (code signing requires a $99/year Apple Developer
account). macOS blocks unsigned apps downloaded from the internet as
a security measure. The command above simply tells macOS "I trust this app."


PERMISSIONS EXPLAINED:
---------------------------------
• Accessibility: Required to intercept Cmd+Tab and activate windows
• Screen Recording: Optional for window previews (uses app icons if denied)


NEED HELP?
---------------------------------
Full documentation: https://github.com/sharbron/WindowSwitcher
Installation guide: See INSTALL.md in the repository
Email: steve.harbron@icloud.com


Thank you for trying WindowSwitcher! 🎉
