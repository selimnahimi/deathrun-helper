# Description:
This plugin is made for **Team Fortress 2**, and specifically for **Deathrun** maps. *(maps starting with dr_\*)*

# Features:
- Only allows 1 player in the BLU team at a time.
- Movement speed modifier for both teams
- Queue system based on points, similar to Versus Saxxton Hale
    - Every round as a RED, you get 10 points for playing
    - Next round, the RED player with the most points gets to be BLU
    - As a BLU, your points are reset
- A custom timer shown on the HUD
- A config file for different cvar values for different maps

# Commands:
| Command | Description |
| ------ | ------ |
| !next | Open the queue menu to view queue and points |

# Admin Commands:
| Command | Description |
| ------ | ------ |
| sm_reloadmapconfig | Reload the map config |

# CVars:
| CVar | Default value | Description |
| ------ | ------ | ------ |
| dr_speed_blu | "400" | BLU team movement speed (in hammer units) |
| dr_speed_red | "300" | RED team movement speed (in hammer units) |
| dr_speed_enabled | "1" | Enable/Disable the movement speed modifier |
| dr_timer_enabled | "1" | Enable/Disable the HUD timer |
| dr_timer_time | "300" | Timer start time |
| dr_timer_team | "2" | Which team should win when the timer runs out (0: STALEMATE, 1: RED, 2: BLU) |