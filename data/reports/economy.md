# Match economy reference

_Generated 2026-09-27T05:19:50+00:00 by tools/deadlock_data/analyze.py. REFERENCE ONLY - observations of Deadlock, not our tuning._

Sources:
- `game_stats|https://api.deadlock-api.com/v1/analytics/game-stats?min_unix_timestamp=1787894018|retrieved=2026-09-27|client_version=n/a|source_type=community-measurement`

Average match: 38.4 min, K/D/A 6.9/6.9/13.6, end net worth 44245 souls, end level 33.0.

## Soul income by source (per player per match)

| source | avg souls | share of listed income | per minute |
|---|---|---|---|
| lane_creep | 10824 | 0.361 | 282 |
| lane_creep_orbs | 8620 | 0.287 | 224 |
| player | 8475 | 0.282 | 220 |
| neutral_creep | 5401 | 0.18 | 140 |
| boss | 3137 | 0.105 | 81.6 |
| treasure | 2171 | 0.0724 | 56.5 |
| death_loss | 744 | 0.0248 | 19.3 |
| denied | 240 | 0.00801 | 6.25 |
| neutral_creep_orbs | 224 | 0.00746 | 5.83 |

`*_orbs` rows are the part of that source delivered as orbs (subset, excluded from share).

## All aggregate fields

| field | value |
|---|---|
| abandon_rate | 0.00612 |
| avg_accuracy | 0.506 |
| avg_assists | 13.6 |
| avg_boss_damage | 6894 |
| avg_creep_damage | 43153 |
| avg_creep_kills | 102 |
| avg_crit_rate | 0.137 |
| avg_damage_absorbed | 1998 |
| avg_damage_mitigated | 14802 |
| avg_deaths | 6.94 |
| avg_denies | 3.56 |
| avg_duration_s | 2307 |
| avg_ending_level | 33 |
| avg_first_mid_boss_time_s | 1617 |
| avg_first_objective_destroyed_time_s | 477 |
| avg_gold_boss | 3137 |
| avg_gold_boss_orb | 0 |
| avg_gold_death_loss | 744 |
| avg_gold_denied | 240 |
| avg_gold_lane_creep | 10824 |
| avg_gold_lane_creep_orbs | 8620 |
| avg_gold_neutral_creep | 5401 |
| avg_gold_neutral_creep_orbs | 224 |
| avg_gold_player | 8475 |
| avg_gold_player_orbs | 0 |
| avg_gold_treasure | 2171 |
| avg_heal_prevented | 495 |
| avg_kd_ratio | 1.57 |
| avg_kills | 6.91 |
| avg_last_hits | 180 |
| avg_max_health | 3578 |
| avg_net_worth | 44245 |
| avg_neutral_damage | 19297 |
| avg_neutral_kills | 37.2 |
| avg_player_damage | 36715 |
| avg_player_damage_taken | 36715 |
| avg_player_healing | 13214 |
| avg_possible_creeps | 140 |
| avg_self_healing | 11960 |
| avg_tech_power | 147 |
| avg_weapon_power | 95.2 |
| bucket | 0 |
| mid_boss_kill_rate | 0.956 |
| team0_wins | 641974 |
| team1_wins | 638830 |
| total_matches | 1276120 |
| total_players | 899439 |

## Economy constants (community-datamine)

| key | value |
|---|---|
| item_price_per_tier | [0, 800, 1600, 3200, 6400, 9999] |
| trooper_kill_gold_share_frac | [1.0, 0.54, 0.36, 0.25, 0.2, 0.16] |
| hero_kill_gold_share_frac | [1.25, 0.575, 0.283, 0.175, 0.11, 0.083] |
| objective_params.gold_per_orb | 0 |
| objective_params.near_player_split_pct | 25.0 |
| objective_params.tier1_gold_kill | 1375 |
| objective_params.tier1_gold_orbs | 0 |
| objective_params.tier2_gold_kill | 3675 |
| objective_params.tier2_gold_orbs | 0 |
| objective_params.base_guardians_gold_kill | 1000 |
| objective_params.base_guardians_gold_orbs | 0 |
| objective_params.shrines_gold_kill | 2000 |
| objective_params.shrines_gold_orbs | 0 |
| objective_params.patron_phase1_gold_kill | 0 |
| objective_params.patron_phase1_gold_orbs | 0 |
| rejuv_params.rejuvinator_expiration_warning_timing | 30.0 |
| rejuv_params.rejuvinator_buff_duration | 180.0 |
| rejuv_params.rejuvinator_drop_height | 500.0 |
| rejuv_params.rejuvinator_drop_duration | 6.0 |
| rejuv_params.trooper_health_mult | [1.7, 2.0, 2.3] |
| rejuv_params.player_respawn_mult | [0.5, 0.4, 0.3] |
| rejuv_params.rejuvinator_rebirth_duration | [180.0, 180.0, 180.0] |
