# Win rate vs cost (items) and hero win rates

_Generated 2026-09-27T05:19:50+00:00 by tools/deadlock_data/analyze.py. REFERENCE ONLY - observations of Deadlock, not our tuning._

Sources:
- `item_stats|https://api.deadlock-api.com/v1/analytics/item-stats?min_unix_timestamp=1787894016&min_matches=500|retrieved=2026-09-27|client_version=n/a|source_type=community-measurement`

**Caveat:** item win rate is observational. Items bought late are bought by players who are already ahead (survivorship), so expensive items look stronger than they are. Treat as a sanity check, not as a balance target.

## By slot and tier

| slot | tier | items | mean WR | min WR | max WR | avg buy min |
|---|---|---|---|---|---|---|
| spirit | 1 | 8 | 0.496 | 0.45 | 0.511 | 8.52 |
| spirit | 2 | 12 | 0.509 | 0.473 | 0.53 | 15.9 |
| spirit | 3 | 13 | 0.495 | 0.413 | 0.532 | 22.4 |
| spirit | 4 | 16 | 0.547 | 0.495 | 0.584 | 32 |
| vitality | 1 | 8 | 0.5 | 0.488 | 0.511 | 8.73 |
| vitality | 2 | 15 | 0.5 | 0.427 | 0.532 | 17.1 |
| vitality | 3 | 14 | 0.49 | 0.397 | 0.522 | 22.8 |
| vitality | 4 | 17 | 0.55 | 0.513 | 0.572 | 34.2 |
| weapon | 1 | 7 | 0.494 | 0.487 | 0.502 | 5.3 |
| weapon | 2 | 16 | 0.499 | 0.482 | 0.514 | 13.5 |
| weapon | 3 | 19 | 0.504 | 0.478 | 0.551 | 21.5 |
| weapon | 4 | 11 | 0.559 | 0.527 | 0.589 | 32.8 |

Pearson r(cost, win rate) = 0.679; r(avg buy time, win rate) = 0.564

## Highest win rate

| item | slot | tier | cost | WR | matches | avg buy min |
|---|---|---|---|---|---|---|
| Frenzy | weapon | 4 | 6400 | 0.589 | 331265 | 36.3 |
| Scourge | spirit | 4 | 6400 | 0.584 | 724575 | 33.5 |
| Lucky Shot | weapon | 4 | 6400 | 0.582 | 480337 | 35 |
| Silencer | weapon | 4 | 6400 | 0.582 | 1088247 | 35 |
| Diviner's Kevlar | vitality | 4 | 6400 | 0.572 | 414187 | 35.8 |
| Infuser | vitality | 4 | 6400 | 0.57 | 801824 | 30.1 |
| Witchmail | vitality | 4 | 6400 | 0.57 | 1083565 | 34.1 |
| Magic Carpet | spirit | 4 | 6400 | 0.567 | 177302 | 29.8 |
| Colossus | vitality | 4 | 6400 | 0.566 | 413990 | 34.6 |
| Ethereal Shift | spirit | 4 | 6400 | 0.566 | 489848 | 35.9 |
| Glass Cannon | weapon | 4 | 6400 | 0.563 | 466592 | 32.1 |
| Mystic Reverb | spirit | 4 | 6400 | 0.562 | 1690391 | 31.5 |

## Lowest win rate

| item | slot | tier | cost | WR | matches | avg buy min |
|---|---|---|---|---|---|---|
| Metal Skin | vitality | 3 | 3200 | 0.397 | 534133 | 30.6 |
| Disarming Hex | spirit | 3 | 3200 | 0.413 | 390152 | 26.6 |
| Return Fire | vitality | 2 | 1600 | 0.427 | 137419 | 22.4 |
| Rusted Barrel | spirit | 1 | 800 | 0.45 | 341599 | 13.6 |
| Silence Wave | spirit | 3 | 3200 | 0.456 | 172634 | 26.5 |
| Bullet Resilience | vitality | 3 | 3200 | 0.462 | 524920 | 30.1 |
| Knockdown | spirit | 3 | 3200 | 0.466 | 736436 | 24.3 |
| Decay | spirit | 3 | 3200 | 0.471 | 312134 | 20.7 |
| Spirit Sap | spirit | 2 | 1600 | 0.473 | 354213 | 15.4 |
| Weapon Shielding | vitality | 2 | 1600 | 0.476 | 331780 | 17.8 |
| Express Shot | weapon | 3 | 3200 | 0.478 | 656042 | 19.3 |
| Battle Vest | vitality | 2 | 1600 | 0.481 | 1392268 | 12.6 |

## Heroes

Spread: min 0.438, median 0.502, max 0.567, stdev 0.033 over 38 heroes.

| hero | WR | pick share | K | D | A | net worth | player dmg | accuracy |
|---|---|---|---|---|---|---|---|---|
| Graves | 0.567 | 0.033 | 6.12 | 7.1 | 12.9 | 45422 | 40065 |  |
| Victor | 0.563 | 0.0282 | 8.08 | 6.74 | 12.5 | 46935 | 43111 | 0.521 |
| Seven | 0.548 | 0.0293 | 5.9 | 7.02 | 13.4 | 47456 | 40157 | 0.523 |
| Paige | 0.547 | 0.0297 | 4.2 | 6.04 | 17 | 45049 | 32773 | 0.55 |
| Kelvin | 0.54 | 0.0161 | 5.23 | 5.83 | 16.2 | 43707 | 32668 | 0.521 |
| Ivy | 0.535 | 0.025 | 4.66 | 5.84 | 16.1 | 43324 | 29703 | 0.5 |
| Mo & Krill | 0.528 | 0.0277 | 6.83 | 6.72 | 16 | 45648 | 37579 | 0.461 |
| Warden | 0.525 | 0.0279 | 8.12 | 6.84 | 12 | 44943 | 40440 | 0.558 |
| Dynamo | 0.522 | 0.0256 | 4.82 | 6.16 | 16.8 | 43677 | 29929 | 0.533 |
| Haze | 0.517 | 0.0382 | 9.07 | 7.09 | 11.1 | 46605 | 37945 | 0.567 |
| Lash | 0.516 | 0.0373 | 7.41 | 6.55 | 15.3 | 43486 | 37688 | 0.497 |
| Celeste | 0.513 | 0.0288 | 6.79 | 6.9 | 13.4 | 44328 | 41792 | 0.464 |
| Calico | 0.512 | 0.0229 | 8.7 | 6.69 | 14.5 | 45877 | 36635 | 0.43 |
| Abrams | 0.51 | 0.0282 | 6.97 | 7.79 | 13.9 | 41995 | 32452 | 0.531 |
| Vindicta | 0.509 | 0.0275 | 8.57 | 6.77 | 12.7 | 42581 | 41816 | 0.504 |
| Drifter | 0.508 | 0.0383 | 8.9 | 8.2 | 14.6 | 44427 | 40006 | 0.414 |
| Lady Geist | 0.507 | 0.0225 | 6.29 | 7 | 13.2 | 45712 | 48385 | 0.585 |
| Apollo | 0.506 | 0.0229 | 7.22 | 7.65 | 13.4 | 42207 | 35240 | 0.56 |
| Wraith | 0.503 | 0.0306 | 7.28 | 6.29 | 10.6 | 46407 | 35135 | 0.525 |
| Vyper | 0.501 | 0.0163 | 8.38 | 7.65 | 10.8 | 44085 | 35102 | 0.381 |
| McGinnis | 0.498 | 0.0144 | 4.91 | 6.53 | 13.7 | 42839 | 38614 | 0.496 |
| Infernus | 0.493 | 0.0376 | 7.37 | 7.17 | 11.9 | 45629 | 37652 | 0.572 |
| Yamato | 0.489 | 0.0215 | 8.3 | 8.15 | 12.9 | 42231 | 36727 | 0.532 |
| Billy | 0.483 | 0.029 | 7.27 | 8 | 13.6 | 43216 | 34588 | 0.52 |
| Grey Talon | 0.478 | 0.0144 | 7.09 | 5.39 | 12.6 | 43413 | 39525 | 0.439 |
| Rem | 0.477 | 0.033 | 3.97 | 5.88 | 16.5 | 44218 | 24719 | 0.505 |
| Viscous | 0.476 | 0.0194 | 4.91 | 6.11 | 15.1 | 43066 | 35599 | 0.507 |
| Holliday | 0.474 | 0.0173 | 6.71 | 6.16 | 14.3 | 44060 | 34963 | 0.614 |
| Shiv | 0.469 | 0.0293 | 8.47 | 7.43 | 12 | 42533 | 36310 | 0.49 |
| Bebop | 0.469 | 0.0405 | 7.25 | 8.22 | 14.4 | 42604 | 37240 | 0.507 |
| Paradox | 0.466 | 0.0308 | 5.97 | 6.99 | 13.5 | 43160 | 40243 | 0.51 |
| The Doorman | 0.462 | 0.0163 | 5 | 5.77 | 14.3 | 44898 | 33147 | 0.6 |
| Pocket | 0.46 | 0.0216 | 6.31 | 6.86 | 13.4 | 45565 | 41473 | 0.514 |
| Silver | 0.456 | 0.0212 | 7.55 | 7.84 | 12.8 | 41961 | 33614 | 0.626 |
| Mina | 0.455 | 0.0342 | 7.86 | 6.73 | 12 | 43778 | 33892 | 0.588 |
| Venator | 0.452 | 0.0346 | 7.46 | 7.41 | 11.8 | 43769 | 37332 | 0.515 |
| Sinclair | 0.448 | 0.0149 | 5.27 | 6.59 | 13.3 | 42402 | 31147 | 0.481 |
| Mirage | 0.438 | 0.0138 | 6.54 | 6.22 | 12.8 | 44732 | 32875 | 0.613 |
