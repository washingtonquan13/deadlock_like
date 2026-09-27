# Hero base stat distributions

_Generated 2026-09-27T05:19:50+00:00 by tools/deadlock_data/analyze.py. REFERENCE ONLY - observations of Deadlock, not our tuning._

Sources:
- `heroes|https://api.deadlock-api.com/v1/assets/heroes?only_active=true&language=english|retrieved=2026-09-27|client_version=latest(6701)|source_type=community-datamine`

Units: `base_max_move_speed`, dash distances in m / m/s (field names say meters); `wpn_*_range` in engine units (1 unit = 0.0254 m, inferred), `_m` columns converted. `wpn_crit_bonus_start` = headshot multiplier at close range.

| stat | min | median | max | stdev | min hero | max hero |
|---|---|---|---|---|---|---|
| base_max_move_speed | 6.2 | 6.9 | 8.2 | 0.563 | Celeste | Yamato |
| base_sprint_speed | 1 | 1.6 | 4 | 0.656 | Venator | Rem |
| base_crouch_speed | 4.75 | 4.75 | 4.75 | 0 | all equal |  |
| base_move_acceleration | 4 | 4 | 4 | 0 | all equal |  |
| base_light_melee_damage | 42 | 50 | 63 | 4.61 | Paige | Viscous |
| base_heavy_melee_damage | 116 | 116 | 128 | 2.49 | Abrams | Yamato |
| base_max_health | 660 | 780 | 930 | 61.1 | Mina | Mo & Krill |
| base_weapon_power | 0 | 0 | 0 | 0 | all equal |  |
| base_reload_speed | 1 | 1 | 1 | 0 | all equal |  |
| base_weapon_power_scale | 1 | 1 | 1 | 0 | all equal |  |
| base_proc_build_up_rate_scale | 1 | 1 | 1 | 0 | all equal |  |
| base_stamina | 2 | 3 | 4 | 0.51 | Graves | Vyper |
| base_base_health_regen | 1 | 2 | 3.5 | 0.557 | Apollo | Drifter |
| base_stamina_regen_per_second | 0.167 | 0.222 | 0.238 | 0.0137 | Shiv | Mina |
| base_ability_resource_max | 0 | 0 | 0 | 0 | all equal |  |
| base_ability_resource_regen_per_second | 0 | 0 | 0 | 0 | all equal |  |
| base_crit_damage_received_scale | 0.45 | 1 | 1 | 0.0937 | Seven | Yamato |
| base_tech_duration | 1 | 1 | 1 | 0 | all equal |  |
| base_tech_range | 1 | 1 | 1 | 0 | all equal |  |
| base_ground_dash_distance_in_meters | 10 | 10 | 10 | 0 | all equal |  |
| base_ground_dash_duration | 0.62 | 0.68 | 0.72 | 0.0362 | Calico | Victor |
| base_air_dash_distance_in_meters | 8 | 8 | 8 | 0 | all equal |  |
| base_air_dash_duration | 0.43 | 0.47 | 0.51 | 0.0289 | Calico | Victor |
| perlvl_base_bullet_damage_from_level | 0.043 | 0.26 | 1.25 | 0.309 | Calico | The Doorman |
| perlvl_base_health_from_level | 27 | 42.5 | 65 | 9.54 | Mina | Mo & Krill |
| perlvl_base_melee_damage_from_level | 1.2 | 1.58 | 1.74 | 0.0695 | Paige | Abrams |
| perlvl_boon_count | 1 | 1 | 1 | 0 | all equal |  |
| perlvl_tech_power | 0.5 | 1.1 | 1.6 | 0.139 | Haze | Grey Talon |
| wpn_bullet_damage | 1.84 | 8.23 | 35 | 7.49 | Calico | Paige |
| wpn_bullets | 1 | 1 | 9 | 2.34 | Apollo | Calico |
| wpn_cycle_time | 0.07 | 0.263 | 0.85 | 0.194 | Vyper | Silver |
| wpn_clip_size | 7 | 17 | 66 | 14.5 | Silver | McGinnis |
| wpn_reload_duration | 0.3 | 2.5 | 3.29 | 0.585 | Silver | McGinnis |
| wpn_burst_shot_count | 1 | 1 | 5 | 0.776 | Abrams | Paradox |
| wpn_burst_shot_cooldown | 0 | 0 | 0 | 0 | all equal |  |
| wpn_bullet_speed | 1710 | 20435 | 62500 | 11935 | Paige | Venator |
| wpn_bullet_gravity_scale | 0 | 0.225 | 1.5 | 0.418 | Apollo | Haze |
| wpn_damage_falloff_start_range | 300 | 787 | 1000 | 115 | Graves | Sinclair |
| wpn_damage_falloff_end_range | 670 | 2146 | 2520 | 428 | Graves | Vindicta |
| wpn_damage_falloff_start_scale | 1 | 1 | 1 | 0 | all equal |  |
| wpn_damage_falloff_end_scale | 0.1 | 0.1 | 1 | 0.174 | Abrams | Apollo |
| wpn_damage_falloff_bias | 0.5 | 0.5 | 0.5 | 0 | all equal |  |
| wpn_crit_bonus_start | 1.65 | 1.65 | 1.65 | 0 | all equal |  |
| wpn_crit_bonus_end | 1.65 | 1.65 | 1.65 | 0 | all equal |  |
| wpn_crit_bonus_start_range | 500 | 500 | 500 | 0 | all equal |  |
| wpn_crit_bonus_end_range | 1500 | 1500 | 1500 | 0 | all equal |  |
| wpn_range | 1000 | 7000 | 7000 | 1437 | Apollo | Yamato |
| wpn_shoot_move_speed_percent | 0.75 | 0.75 | 0.85 | 0.016 | Abrams | Rem |
| wpn_shots_per_second | 1.18 | 3.91 | 14.3 | 3.66 | Silver | Vyper |
| wpn_damage_per_shot | 3.6 | 13.7 | 58.5 | 11.4 | Graves | Drifter |
| wpn_damage_per_second | 29 | 52.3 | 133 | 18.6 | McGinnis | Drifter |
| wpn_damage_per_second_with_reload | 17.6 | 33.4 | 87.9 | 11.2 | Mina | Drifter |
| wpn_damage_per_magazine | 87.7 | 251 | 702 | 109 | Mina | Drifter |
| wpn_damage_falloff_start_range_m | 7.62 | 20 | 25.4 | 2.93 | Graves | Sinclair |
| wpn_damage_falloff_end_range_m | 17 | 54.5 | 64 | 10.9 | Graves | Vindicta |
| perlvl_base_bullet_damage_from_level_alt_fire | 0.24 | 0.7 | 1.44 | 0.4 | Shiv | Viscous |
| base_tech_armor_damage_reduction | -15 | 0 | 10 | 10.3 | Pocket | Lash |

## Per-hero summary

| hero | type | HP | move m/s | DPS | clip | falloff start m | falloff end m |
|---|---|---|---|---|---|---|---|
| Abrams | brawler | 800 | 6.4 | 51.4 | 9 | 17 | 40 |
| Apollo | assassin | 770 | 7.2 | 48.7 | 15 | 25.4 | 25.4 |
| Bebop | brawler | 880 | 6.45 | 59.3 | 66 | 20 | 50.8 |
| Billy | brawler | 820 | 7 | 74.1 | 30 | 14 | 31.8 |
| Calico | assassin | 730 | 6.8 | 78.9 | 12 | 20 | 57.5 |
| Celeste | marksman | 690 | 6.2 | 31 | 8 | 22 | 60 |
| Drifter | assassin | 755 | 6.9 | 133 | 12 | 22 | 27 |
| Dynamo | mystic | 880 | 6.7 | 48 | 20 | 20 | 57.5 |
| Graves | marksman | 730 | 7 | 35.3 | 40 | 7.62 | 17 |
| Grey Talon | marksman | 780 | 6.3 | 39.2 | 17 | 18 | 54 |
| Haze | assassin | 730 | 8.2 | 50.1 | 25 | 20 | 46 |
| Holliday | marksman | 780 | 8.2 | 41.7 | 10 | 20 | 57.5 |
| Infernus | marksman | 830 | 6.7 | 52.4 | 27 | 18 | 55 |
| Ivy | marksman | 755 | 7.2 | 60.5 | 33 | 20 | 57.5 |
| Kelvin | brawler | 880 | 6.7 | 70.9 | 14 | 20 | 57.5 |
| Lady Geist | mystic | 880 | 6.3 | 43.8 | 9 | 17 | 48 |
| Lash | assassin | 780 | 7.2 | 49.3 | 29 | 16 | 48 |
| McGinnis | mystic | 780 | 6.7 | 29 | 66 | 20 | 57.5 |
| Mina | marksman | 660 | 6.5 | 29 | 12 | 20 | 46 |
| Mirage | assassin | 730 | 7 | 40.3 | 16 | 20 | 57.5 |
| Mo & Krill | brawler | 930 | 8 | 59.7 | 20 | 20 | 57.5 |
| Paige | mystic | 680 | 6.9 | 58.3 | 14 | 20 | 57.5 |
| Paradox | marksman | 730 | 6.7 | 51.4 | 40 | 20 | 57.5 |
| Pocket | assassin | 780 | 7.2 | 57.1 | 11 | 16 | 45.7 |
| Rem |  | 680 | 7.2 | 61.5 | 13 | 20 | 57.5 |
| Seven | mystic | 730 | 6.7 | 63 | 29 | 20 | 57.5 |
| Shiv | brawler | 830 | 6.5 | 52.2 | 10 | 19.8 | 41.1 |
| Silver | marksman | 830 | 6.7 | 42 | 7 | 17 | 42 |
| Sinclair | mystic | 730 | 7.2 | 48.3 | 16 | 25.4 | 61 |
| The Doorman | mystic | 755 | 7.9 | 35.3 | 8 | 20 | 57.5 |
| Venator | marksman | 820 | 6.4 | 63.5 | 33 | 18 | 47 |
| Victor | brawler | 800 | 6.3 | 60.6 | 24 | 20 | 57.5 |
| Vindicta | marksman | 755 | 7.9 | 53.4 | 19 | 20 | 64 |
| Viscous | mystic | 780 | 7.2 | 49.2 | 20 | 20 | 57.5 |
| Vyper | assassin | 780 | 6.9 | 94 | 24 | 15 | 33 |
| Warden | brawler | 805 | 6.3 | 66.1 | 17 | 18 | 47 |
| Wraith | marksman | 730 | 7.2 | 59.7 | 52 | 18 | 52 |
| Yamato | assassin | 730 | 8.2 | 63.2 | 12 | 20 | 45.7 |
