# HUD (crosshair, ammo, hit feedback, damage numbers)

Public sources only: the community wiki, its gameplay screenshots and videos, and the official
update pages. Colours are pixel samples from compressed images and videos, so they are
approximate. Confidence is marked per item. **Guess** marks values we picked ourselves because
no source shows them.

Sources:
- [A] https://deadlock.wiki/File:Ammo_under_stamina_bar.png (2024-style HUD)
- [B] https://deadlock.wiki/File:Dash_Jump.mp4 (Mar 2025, 1080p)
- [C] https://deadlock.wiki/File:Geist_targeting_hand.jpeg (Aug 2026, centre crop)
- [D] https://www.playdeadlock.com/oldgods (Jan 22 2026 update: reticle editor, damage numbers)
- [E] https://deadlock.wiki/Ammo, https://deadlock.wiki/Stamina, https://deadlock.wiki/Movement,
  https://deadlock.wiki/Active_Reload, https://deadlock.wiki/McGinnis, https://deadlock.wiki/Health
- [F] https://forums.playdeadlock.com/threads/headshot-indicator-hitmarker-not-properly-showing-with-multiple-pellets-based-weapons.928/ (May 2024)

## 1. Crosshair
1. Default reticle: centre dot plus 4 short lines with a gap from the centre, white, optional
   dark border. The 2026 reticle editor exposes line width/height/gap/opacity/border and dot
   size/opacity/border [D]. *High.*
2. Stamina: thick arc segments below the crosshair, one per charge, symmetric about the
   vertical [A][C]. Full = light grey-white, about #E0E0E0 at 85%. Spent = dark empty segment.
   The regenerating segment shows a yellow fill, about #E8C040 [B]. *Medium.*
3. Dash-jump window: the stamina segments turn light blue/cyan, about #6CC8E8 [E Movement].
   *High for behaviour, medium for colour.* (movement.md §9 already says they flash.)
4. Spin-up guns: a grey indicator around the crosshair shows the spin [E McGinnis]. *Medium.*
5. Reload indicator: **unknown.** Guess: a thin white ring around the crosshair that fills
   clockwise over the reload.

## 2. Ammo
1. Centred under the stamina arc, not in the bottom HUD [A][B][C][E Ammo]. *High.*
2. Format: current ammo bold white (#F0F0F0), then " / max" in grey (#A0A0A0, ~60%), same size,
   about 16–18 px at 1080p. *High.*
3. While sliding, a light-green infinity symbol shows the infinite ammo [E Ammo]. *High.*
   Placement unknown; we replace the ammo count with it (user preference).
4. Low-ammo colour: unknown, not implemented.

## 3. Hit markers
1. 4 short lines around the crosshair [F]. *Medium.*
2. Headshot: yellow lines with a red outline (plus a yellow head icon, not implemented) [F].
   *Medium.*
3. Body hit colour: unknown. Guess: white.
4. Duration: a user setting exists; guess 0.15 s.

## 4. Floating damage numbers (Jan 2026 system [D])
1. Per-hit numbers: small (about 18 px), bold, spawn at the impact point, rise in a column and
   fade toward olive. Seen with yellow fill (#F0D020) and orange outline (#FF9C00) on head
   impacts. *High for layout, medium for colour.*
2. Body-hit per-hit colour: unconfirmed. Guess: white fill with a dark outline, so crits stand out.
3. Running total: one large number (about 40 px), cream-white (#FFFFE0) with a thick black
   outline, beside the target, growing as hits land. *High.* How long it lingers after the
   last hit: unknown; guess 2 s.
4. Spirit damage has its own lavender (#D0A8F8) number. Not used: the sim has no spirit damage.

## 5. Bottom HUD (Mar 2025 [B]; may be outdated)
Health wedge left of centre, abilities bottom-centre, items bottom-left, minimap bottom-right.
Not implemented: the sandbox has no player health, abilities, items or map.
