# Coins, diamonds, the shop and ads

How Deck of Fools earns money without getting in the way of the game, what is built,
and what is left to connect at launch.

## The two currencies

- **Coins** are earned by playing: every show won pays coins (more for the Patron
  and in later towns), winning a run pays a bonus, finishing the daily run pays once
  a day, and the 7-day daily gift pays coins (and a few diamonds on days 3 and 7).
  Numbers: `game/core/economy.gd`.
- **Diamonds** are bought with real money (diamond packs, the Starter pack) and
  given now and then by the daily gift.
- Ducats stay what they were: the money inside a run, spent in The Market. They are
  never converted to or from coins or diamonds.

Neither currency changes a run's rules, so ranked play stays fair. The one
exception is the **Encore**, and it makes the run unranked.

## What they buy

`game/core/shop_catalog.gd`:

| Item | Price | What it is |
| --- | --- | --- |
| Gilded sun, Venetian glass card backs | 500 / 900 coins | Cosmetic |
| Opera night, Carnival gold card backs | 150 / 250 diamonds | Cosmetic |
| Encore ticket (1 or 3) | 25 / 60 diamonds | An Encore for later |
| Purse / Chest of coins | 50 / 140 diamonds | 600 / 2,000 coins |

Real-money products (ids to create in App Store Connect):

| Product id | Reference price | Contents |
| --- | --- | --- |
| `dof.starter` | $2.99, once | 300 diamonds, 1,000 coins, 1 Encore ticket, Starter's crest card back |
| `dof.remove_ads` | $3.99, non-consumable | No intermissions (rewarded ads stay optional) |
| `dof.diamonds.100` | $0.99 | 100 diamonds |
| `dof.diamonds.550` | $4.99 | 500 + 50 bonus |
| `dof.diamonds.1200` | $9.99 | 1,000 + 200 bonus |
| `dof.diamonds.2500` | $19.99 | 2,000 + 500 bonus |
| `dof.diamonds.6500` | $49.99 | 5,000 + 1,500 bonus |

Nothing is random (no loot boxes), so there are no odds to disclose.

## The Encore

After losing a show (running out of hands, not giving up), the run waits before it
ends and offers an Encore: one more hand and one more discard, score kept, a fresh
hand dealt. Once per run. It can be paid with a rewarded ad, an Encore ticket, 25
diamonds or 250 coins. It is never offered in the ranked daily run, and a tour run
that took one is not submitted to the leaderboards. This is the moment players most
want to keep going, which is why it is the main rewarded-ad placement.

## When ads appear

Rules: `game/core/ad_policy.gd`. Placements:

- **Rewarded, always the player's choice:** the Encore after losing a show; doubling
  a show's coins on the cash-out screen (once per show); doubling the daily gift.
  At most 15 rewarded ads a day. The reward is only paid if the ad runs to the end,
  and the button says what it gives before the ad starts.
- **Intermissions (interstitials), only at natural breaks:** between towns (leaving
  The Market for a new town) and when leaving a finished run for the menu. Never
  during a show, a scoring animation, the Encore offer or the guided first run, and
  never at launch. They are themed as the theatre's intermission.
  - none until the player has finished 3 runs;
  - none in the first 3 minutes of a session;
  - at least 5 minutes between two, and 3 minutes after any rewarded ad or purchase;
  - at most 3 per session and 6 per day;
  - never for anyone who has bought anything or bought No intermissions.

## Modes

`game/core/monetization.gd` decides per build:

- **off**: coins, the daily gift and coin purchases only; no ads and a closed diamond
  store. The published web game uses this until the store and ads are connected.
- **test**: everything works with stand-ins that charge nothing (`ui/purchase_sheet.gd`)
  and show a placeholder instead of an ad (`ui/ad_sheet.gd`). Active in the dev
  gallery, debug runs and builds exported with the custom feature `store_test`
  (`WEB_PRESET="Web Test Store" ./build.sh`, `IOS_PRESET="iOS Test Store" ./ios.sh`).
  Never ship a test-store build.
- **live**: builds exported with the custom feature `store_live`, once the hooks below
  are connected.

## Connecting at launch

- **Store, iPhone:** StoreKit 2 through a Godot iOS plugin. Fill in
  `Store._buy_live`, `Store._restore_live` and `Store._live_price` in `ui/store.gd`.
  Create the product ids above in App Store Connect (Starter pack and No
  intermissions as non-consumables so they can be restored). Validate receipts on
  the server (App Store Server API) before crediting diamonds, and move the diamond
  balance server-side: today the wallet lives in the player's profile (cloud save),
  which is fine for coins but not for money.
- **Store, web:** a checkout (for example Stripe) started from the API, with the
  webhook crediting diamonds server-side.
- **Ads, iPhone:** AdMob (or another network) through a Godot plugin in
  `Ads._play_live` (`ui/ads.gd`); it must return true only when a rewarded ad was
  watched to the end. Show Apple's App Tracking Transparency prompt before
  personalised ads, and Google's consent form (UMP) in the EU/UK.
- **Ads, web:** Google's H5 Games Ads (adBreak / adConfig) through JavaScriptBridge.

## Tests

`game/tests/money_tests.gd` checks the wallet, the economy, the catalog, every ad
rule and the Encore. Run it with:

```sh
~/Developer/godot-4.7.2/Godot.app/Contents/MacOS/Godot --headless --path game -s tests/money_tests.gd
```
