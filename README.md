# PingCooldowns

PingCooldowns is a World of Warcraft addon that allows players use the Cooldown Manager to quickly share the cooldown status of their abilities with their group or raid. With a simple click, you can broadcast whether a spell is ready or on cooldown, making group coordination easier and more efficient.

## ✨ Features
- **One-click Cooldown Pings:** Instantly share the status of your abilities in party or raid chat
- **Smart Charge Detection:** Automatically detects and displays charge-based abilities with precise timing
- **Talent & Spell Override Detection:** Automatically detects talent-based spell overrides to ensure accurate cooldown reporting
- **Intelligent Chat Routing:** 
  - Sends to group chat (RAID/PARTY) when in groups
  - Uses SAY channel for nearby players in PvE instances
  - Avoids SAY in PvP instances (arenas/battlegrounds) for tactical security
- **Precise Timing Display:** Shows exact cooldown times in readable format (seconds, minutes, hours)
- **Rate Limiting:** Prevents chat spam by limiting the number of pings within a set time window
- **Modular Design:** Easily extendable and maintainable codebase

## 📦 Installation
1. Download the latest release of PingCooldowns
2. Extract the contents into your `World of Warcraft/_retail_/Interface/AddOns/PingCooldowns` directory
3. Restart WoW or reload your UI with `/reload`

## 🎮 Usage
- Hover over a cooldown icon in your cooldown manager
- **Left-click** to ping the cooldown status to your group or raid chat
- **Right-click** to trigger the default action of the cooldown viewer (if any)

### Message Examples
- **Single charge spells:**
  - `[Spell Link] - Ready!`
  - `[Spell Link] - On cooldown (45s)`
  
- **Charge-based spells:**
  - `[Spell Link] - 2/2 Charges Ready!`
  - `[Spell Link] - 1/2 Charge Ready!, next charge in (23s)`
  - `[Spell Link] - 0/2 Charges, next charge in (45s)`

## 🔧 Supported Cooldown Viewers
- Blizzard_CooldownViewer

## ⚙️ Technical Details
- Written in Lua, using WoW's API for event handling and UI integration
- Detects spell overrides using multiple API methods for maximum compatibility
- Advanced charge detection using `C_Spell.GetSpellCharges()` API
- Smart instance detection for appropriate chat channel selection
- Rate limiting is configurable and prevents chat spam
- Modular structure: core logic, detection, output, and processing modules

## 🐛 Troubleshooting
- If the addon does not appear to work, ensure your cooldown viewer addon is enabled and loaded before PingCooldowns
- For debugging, enable logging via the addon's debug features
- If you encounter issues, try reloading your UI with `/reload` or restarting the game
- Make sure you're using the latest version compatible with your WoW client

## 🎯 Roadmap
- [ ] Configuration UI for rate limiting settings
- [ ] Support for more cooldown viewer addons
- [ ] Custom message templates
- [ ] Multi-language support

## 💖 Support the Project
If you enjoy using PingCooldowns and would like to support its development, consider buying me a coffee! I LOVE COFFEE =)

What started as a hyperfocus-driven dive into addon development has become a passion for creating tools that enhance the WoW experience. Every line of code reflects hours of dedicated work, fueled by that special kind of focus that turns a simple idea into something meaningful. Your support not only helps maintain this addon but also encourages the continued exploration of new features and improvements.

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-support-yellow.svg?style=flat-square&logo=buy-me-a-coffee)](https://buymeacoffee.com/jacuv)

## Credits
Developed by **Jacuv01**.

## 📢 Project Status & Feedback
PingCooldowns is an ongoing project and will continue to receive new features and improvements in the future. Suggestions, feedback, and contributions are welcome! 

- **Found a bug?** Open an issue on GitHub
- **Have a feature request?** Let me know through GitHub issues
- **Want to contribute?** Pull requests are welcome!

## 📄 License
This project is licensed under the GNU General Public License v3.0. See the `LICENSE` file for details.