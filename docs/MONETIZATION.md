# Coins, diamonds, the shop and ads

How Deck of Fools earns money without getting in the way of the game, what is built,
and what is left to connect at launch. The rules follow web research done on 22
November 2026 and checked by a second, skeptical pass (sources were Apple and Google
policy pages, the EU CPC principles on in-game currencies, PEGI's 2026 criteria,
AdMob and H5 Games Ads documentation, and industry data from Unity, Sensor Tower,
AppMagic and others).

## The two currencies

- **Coins** are earned only, never sold, never in a paid pack and never exchanged
  for diamonds. That keeps them a pure reward for playing and outside the EU rules
  for purchasable virtual currencies. Sources (`game/core/economy.gd`):
  - every show won: Matinee 5, Evening show 8, Patron 15, plus 1 per town after the first;
  - the first show won each day: +50;
  - winning a run: tour 100 (+15 per stake above 1), quick run 40, boss rush 50;
  - finishing the daily run (ranked or practice): 50, once a day;
  - the daily gift (30 to 150 coins over a 7-day calendar that never resets);
  - every 25 Jesters found in the collection: 250 coins and 20 diamonds;
  - the curtain call: a finished run's show and win coins can be doubled once by a
    rewarded ad.
  - Daily practice pays half, and after 1,500 coins from shows in a day further shows
    pay a quarter, so replaying the same cards isn't a farm.
- **Diamonds** are bought with real money and also trickle in from the daily gift
  (days 3 and 7) and album milestones. 100 diamonds cost $0.99 at the base rate;
  every diamond price and pack is a multiple of 100, and diamond prices show their
  money value ("about $2.97"), so nothing leaves leftovers or hides its cost.
- Ducats stay the money inside a run, spent in The Market. They never convert.

## What they buy

`game/core/shop_catalog.gd`. Nothing is random (no loot boxes, so no odds to
disclose) and nothing sold changes a run.

| Item | Price |
| --- | --- |
| Gilded sun card back | 600 coins |
| Venetian glass card back | 900 coins |
| Opera night card back | 300 diamonds |
| Carnival gold card back | 300 diamonds |

Real-money products (create these ids in App Store Connect; ids can never be reused):

| Product id | Reference price | Contents |
| --- | --- | --- |
| `dof.starter` | $1.99, once (non-consumable) | 300 diamonds and the Starter's crest card back |
| `dof.remove_ads` | $3.99, non-consumable | No intermissions (rewarded ads stay optional) |
| `dof.diamonds.100` | $0.99 | 100 diamonds |
| `dof.diamonds.500` | $4.99 | 500 diamonds |
| `dof.diamonds.1000` | $9.99 | 1,100 diamonds |
| `dof.diamonds.2000` | $19.99 | 2,300 diamonds |
| `dof.diamonds.5000` | $49.99 | 6,000 diamonds |

No intermissions only removes ad breaks. It never turns a rewarded ad into a free
reward: that would sell coins or Encores for money indirectly.

## The Encore

After losing a show (running out of hands, not giving up), the run waits and offers
an Encore: one more hand and one more discard, score kept, a fresh hand drawn as a
later draw. Once per run. Paid with a rewarded ad or 100 coins (less than one won
quick run pays); free in the guided first run, to teach it. Never paid with diamonds
or money: right after a loss is the most predatory moment to sell something. Never in
the ranked daily run; a tour run that took one is not submitted to the leaderboards.
If the app is closed on the offer and a new run is started, the old run is finished
and counted first.

## When ads appear

Rules: `game/core/ad_policy.gd`, all checked by `tests/money_tests.gd`.

- **Rewarded, always the player's choice, reward stated before the ad:** the Encore,
  doubling a finished run's coins (once per run), doubling the daily gift's coins
  (once a day). At most 10 a day. Paid only when the ad runs to the end. The
  research expects 2-5 views a day per engaged player, below the 4-7 that earn best,
  so rewarded revenue will be modest by design.
- **Intermissions, only at natural breaks:** travelling on into towns 3, 5 and 7, and
  leaving a finished run for the menu. Never during a show, a scoring animation, the
  Encore offer, the guided first run, the ranked daily run, at launch or on resume.
  - none until the player has finished 5 runs and played for 14 days;
  - none in the first 5 minutes of a session (a session restarts after 30 minutes
    away);
  - at least 10 minutes apart, and 15 minutes after any rewarded ad or purchase;
  - at most 2 a session and 4 a day;
  - never for anyone who has bought anything or bought No intermissions.
- No banners, no app-open ads, no offer pop-ups after a loss, no timers or
  "only today" offers (PEGI 2026 rates those 12+), no energy systems.
- The game's sound is muted while an ad plays, and a live ad gets 45 seconds at most
  so a network that never answers can't block the game.

## Modes

`game/core/monetization.gd` decides per build:

- **off**: coins, the daily gift and coin purchases only; no ads and a closed diamond
  store. The published web game uses this until the store and ads are connected.
- **test**: everything works with stand-ins that charge nothing (`ui/purchase_sheet.gd`)
  and show a placeholder instead of an ad (`ui/ad_sheet.gd`). It uses a separate
  test wallet, so free test diamonds never reach a real one. Active in the dev
  gallery, debug runs and builds exported with the custom feature `store_test`
  (`WEB_PRESET="Web Test Store" ./build.sh`, `IOS_PRESET="iOS Test Store" ./ios.sh`).
  Never ship a test-store build.
- **live**: builds exported with the custom feature `store_live`, once the hooks below
  are connected.

## Before turning on the store and ads

- **Privacy:** `site/public/privacy.html` says there are no ads, analytics or tracking,
  and `docs/APP_STORE.md` answers App Privacy with no ads. Both are true while the
  mode is off; update them, the App Store privacy label and `PrivacyInfo.xcprivacy`
  before any ad SDK ships.
- **Consent:** EEA, UK and Swiss players need a Google-certified consent tool (UMP)
  before personalised ads; iOS needs the App Tracking Transparency prompt (after the
  guided first run, never on first launch, never rewarded).
- **Age rating:** a poker theme is "simulated gambling" in Apple's 2025 age ratings
  (13+ if infrequent). Set AdMob's maximum ad content rating to T and check the
  gambling ad categories in the AdMob console.
- **Store, iPhone:** StoreKit 2 through a Godot iOS plugin. Fill in
  `Store._buy_live`, `_restore_live` and `_live_price` (`ui/store.gd`). Make the
  starter pack and No intermissions non-consumables (restorable). Validate
  receipts on the server (App Store Server API) and keep diamonds in a server
  ledger: today the wallet lives in the cloud save, where a conflict choice or a
  logout copy can lose or duplicate it, which is fine for coins but not for money.
  Finish StoreKit transactions only after the server has credited them.
- **Store, web:** check that the payment provider onboards the studio's country
  (Stripe does not onboard Albanian businesses; a merchant of record may be needed),
  and start web prices at $4.99 because small card payments lose a large share to
  fees. Apple allows linking out to web purchases in the US and, since 1 October
  2026, in the EU (with a commission); items bought on the web must also be sold as
  in-app purchases to be usable in the iPhone app.
- **Ads, iPhone:** AdMob through a maintained Godot plugin tested with Godot 4.7
  (Poing Studios v5.1.0, or godot-sdk-integrations v7.0); add GADApplicationIdentifier
  and SKAdNetworkItems to Info.plist and app-ads.txt on the studio's website.
  Implement `Ads._play_live` (`ui/ads.gd`): resolve true only when a rewarded ad
  finished; Ads.can_offer should also check that an ad is loaded.
- **Ads, web:** Google's H5 Games Ads (adBreak) through JavaScriptBridge. There, a
  rewarded ad's availability is only known inside its beforeReward callback, so the
  web buttons must appear from that callback. It needs AdSense approval on a domain
  the studio controls (not the workers.dev address).
- **Measure:** keep about 10% of non-payers without intermissions as a holdout for
  two weeks and watch day-7 and day-30 retention before keeping any ad change.

## Tests

`./test.sh` runs everything headless: the game's suites and play bot, then
`game/tests/money_tests.gd` (wallet, economy, catalog, every ad rule and the Encore).
