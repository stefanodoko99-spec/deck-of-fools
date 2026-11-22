# Roadmap: the 21 picks (22 November 2026)

The player picked every option on the "Next acts" page
(https://claude.ai/artifact/8ztYs31B3LDd33Ww9AKyC5). They are built in waves, each
wave on separate branches with clear file ownership, then reviewed by independent
agents, tested (`./test.sh`) and played through in the gallery before it ships.

Rules that apply to every wave (from docs/MONETIZATION.md and the fact-checks):
- nothing bought or watched changes a run, except the Encore (which unranks it);
- nothing punishes a missed day (PEGI 2026), no timers that push, no pop-ups after a loss;
- coins are earned only; diamonds buy looks;
- the daily run, dares and festivals leave every Rare Jester out of the Market so a
  seed deals the same cards to everyone;
- every new screen fits the 640x360 stage, respects Reduce motion and is tested.

## Status

Done and live-ready: Music as Ogg, Music after the menu (first visit about 8.7 MB).
Not doing for now: A smaller engine build (its download was not approved).

## Wave 1: the first minute and the reasons to come back

| Pick | Owner files | Notes |
| --- | --- | --- |
| Play first | ui/main.gd | New installs go straight into the guided Matinee; check the cloud profile first so a returning player on a new device isn't treated as new. |
| Continue-first home | ui/menu_screen.gd, new ui/home_*.gd | One big button: Continue the tour, else Today's daily, else New tour. Setup moves one tap deeper. |
| Living stage | new ui/living_stage.gd | Curtains part (skippable, off with Reduce motion), the wagon in your town, found Jesters on stage. |
| Event banners | home | Up to three cards (daily with hours left, the festival, a new illustration); hidden until the first run is finished. |
| Instant start screen (web) | game/web/shell.html, build.sh | Key art, logo, progress ring, a tip, then Tap to play or Continue (status saved by the game in localStorage). |
| Daily goals | new core/goals.gd, ui/goals_sheet.gd | Three daily goals and one weekly, paid in coins; they wait for the player, nothing resets against them. |
| Tips at the right moment | new ui/tips.gd | One insight after a lost show; a Jester of the day on the home. |
| Playbill news | api (news), ui/online.gd, new ui/playbill_sheet.gd | News cards from the server; What's new once after an update. |
| Inbox of letters | api (letters + claim), ui/online.gd, new ui/inbox_sheet.gd | Claimable coins and messages; claims are idempotent by letter id. |

Shared groundwork done first (core, by the integrator): a `Game.run_event` signal
(hand played, show won or lost, run finished, Jester bought) that goals, tips, seasons
and mastery listen to, and per-feature state in the profile
(`Game.profile.state("goals")`), so no two features edit the same core files.

## Wave 2: playing together

| Pick | Notes |
| --- | --- |
| Dare a friend | A code or link with seed, deck, stake and mode; Rares left out; a share card; a small board per dare (server). |
| Weekly Festival | One of the 20 challenges on a weekly seed, unlimited tries, a weekly board, a cosmetic prize. |
| Rival ghosts | In the daily, a rival's per-show scores on the goal bar (server keeps per-show scores of ranked runs). |
| Game Center | GameCenterKit plugin (approved download): sign-in, leaderboards, achievements for the 22 Rare feats; switched on with the Apple Developer account. |

## Wave 3: collecting and progressing

| Pick | Notes |
| --- | --- |
| Collection 2.0 | Themed sets with rewards, Jester mastery frames (bronze, silver, gold), a wardrobe. |
| Troupe Chronicle | Unlock goals shown as chapters, from the rules in content/unlocks.gd. |
| Touring Season | 6-8 weeks, free and premium (diamonds) tracks, cosmetics only, no timers that push. |
| Daily Lazzo | A three-minute puzzle of the day; a generator that checks a solution exists without trying all 20 million lines. |

## Wave 4: accessibility

Contrast of at least 4.5:1 for text and buttons (today 3.14:1 and 3.54:1), a larger
text mode, nothing told by colour alone, Reduce motion everywhere, then claim the
Accessibility Nutrition Labels the game honestly meets.
