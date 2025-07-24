# PingCooldowns

PingCooldowns is a World of Warcraft addon that allows players to quickly share the cooldown status of their abilities with their group or raid. With a simple click, you can broadcast whether a spell is ready or on cooldown, making group coordination easier and more efficient.

## Features
- **One-click Cooldown Pings:** Instantly share the status of your abilities in party or raid chat.
- **Talent & Spell Override Detection:** Automatically detects talent-based spell overrides to ensure accurate cooldown reporting.
- **Rate Limiting:** Prevents chat spam by limiting the number of pings within a set time window.
- **Modular Design:** Easily extendable and maintainable codebase.

## Installation
1. Download the latest release of PingCooldowns.
2. Extract the contents into your `World of Warcraft/_retail_/Interface/AddOns/PingCooldowns` directory.
3. Restart WoW or reload your UI with `/reload`.

## Usage
- Hover over a cooldown icon in your cooldown viewer.
- Left-click to ping the cooldown status to your group or raid chat.

## Supported Cooldown Viewers
- Blizzard_CooldownViewer
- WeakAuras
- TellMeWhen
- OmniCC
- ElvUI
- Bartender4
- Dominos

## Technical Details
- Written in Lua, using WoW's API for event handling and UI integration.
- Detects spell overrides using multiple API methods for maximum compatibility.
- Rate limiting is configurable and prevents chat spam.
- Modular structure: core logic, detection, output, and processing modules.

## Troubleshooting
- If the addon does not appear to work, ensure your cooldown viewer addon is enabled and loaded before PingCooldowns.
- If you encounter issues, try reloading your UI or restarting the game.

## Credits
Developed by Jacuv01. Inspired by the need for better group coordination in dungeons and raids.

## Project Status & Feedback
PingCooldowns is an ongoing project and will continue to receive new features and improvements in the future. Suggestions, feedback, and contributions are welcome! If you have ideas or requests, feel free to open an issue or contact the author.

## License
This project is licensed under the GNU General Public License v3.0. See the `LICENSE` file for details.