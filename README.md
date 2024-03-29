# Deathrun GameMode Plugin

## Overview

The Deathrun GameMode plugin enhances your AMX Mod X server by introducing a Deathrun game mode. Players can experience exciting rounds with unique features such as respawn, lives, and voting for the game mode.

## Features

- **Respawn System:** Players have the ability to respawn during the game.
- **Lives System:** Each player gains lives by killing a member of the opposing team.
- **Gamemode Voting:** Players can vote for the game mode (Deathrun or Respawn) at the beginning of each map.
- **Manual Gamemode Toggle:** Administrators can manually toggle between Deathrun and Respawn game modes.
- **HUD Elements:** Displays relevant information about the game mode on the player's HUD.
- **Terminates Bots:** Ensures bots are removed when the game mode switches to Respawn.
- **Radio and Buyzone Blocking:** Prevents certain actions during specific game modes.

## Commands

- **/usp:** Gives the player a pistol.
- **/lives:** Displays the number of lives a player has.
- **/revive:** Allows a player to use a life and respawn.
- **/ct or /spec:** Switches a player to the Counter-Terrorist team or spectator mode.
- **deathrun_vote:** Initiates the gamemode voting process.
- **deathrun_toggle:** Toggles between Deathrun and Respawn game modes manually.

## Configuration

The plugin provides several cvars for configuration:

- **respawn_time:** Sets the duration of the respawn period (default: 30 seconds).

## Native Functions

The plugin offers native functions for advanced scripting:

- **bool:is_deathrun_enabled():** Returns the current deathrun mode status.
- **enable_deathrun(bool:value):** Enable/Disable the deathrun mode.
- **disable_respawn():** Temporarily disables respawn.
- **bool:is_respawn_active():** Checks if respawn is currently active.
- **get_next_terrorist:** Retrieves the ID of the next terrorist player.
- **set_next_terrorist:** Sets the id of the next terrorist player.

- **forward_deathrun_enable(bool:value):** Functin called if deathrun is enabled/disabled.

## Gamemode Voting

At the onset of each map, players have the opportunity to cast their votes for the preferred game mode. The choices include Classic (Deathrun) and No Terrorist (which involves utilizing a bot as a substitute for the terrorist, employing the yapb module) (Respawn). The plugin will declare the victorious game mode, determined by the collective votes of the players.

## Support and Issues

For support or reporting issues, please visit the [issue tracker](https://github.com/human416c6578/Deathrun-GameMode/issues).
