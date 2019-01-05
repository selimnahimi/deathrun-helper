# Description:
This plugin is made for **Team Fortress 2**, and specifically for **Deathrun** maps. *(maps starting with dr_\*)*

# Features:
- Only allows 1 player in the BLU team at a time.
- Movement speed modifier for both teams
- Queue system based on points, similar to Versus Saxxton Hale
    - Every round as a RED, you get 10 points for playing
    - Next round, the RED player with the most points gets to be BLU
    - As a BLU, your points are reset

# Commands:
| Command | Description |
| ------ | ------ |
| !next | Open the queue menu to view queue and points |

# CVars:
| CVar | Default value | Description |
| ------ | ------ | ------ |
| dr_speed_blu | "400" | BLU team movement speed (in hammer units) |
| dr_speed_red | "300" | RED team movement speed (in hammer units) |
| dr_speed_enabled | "1" | Enable/Disable the movement speed modifier |