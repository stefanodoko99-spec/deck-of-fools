# Getting Deck of Fools onto the App Store

The game already runs on iPhone as a web app: open it in Safari, tap Share, then Add to Home Screen. It installs with its own icon, opens full screen in landscape, works offline once loaded, and asks portrait players to turn the phone sideways.

This file lists what is still needed for a native App Store release, in order. Items marked ✅ are already done in this repository.

## 1. Accounts and tools (you)

- [ ] Join the **Apple Developer Program** ($99 a year) with the Apple ID that will own the app.
- [ ] Install **Xcode** from the Mac App Store. This Mac only has the Command Line Tools, and Godot's iOS export needs full Xcode to build and sign.
- [ ] Install Godot's **iOS export template**. Only the web templates are installed now (in `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`). `ios.zip` comes from the same official 4.7.2 template bundle.

## 2. Project settings

- [ ] Choose the **bundle ID**, for example `com.yourname.deckoffools`. It can never change once the app is in App Store Connect.
- [ ] Fill `application/bundle_identifier` and `application/app_store_team_id` in the **iOS** preset (`game/export_presets.cfg`, or Project → Export in the editor).
- ✅ App icon: `game/icons/ios-1024.png`, 1024×1024 with no transparency, as Apple requires. Its source is `game/icons/icon.svg`.
- ✅ Landscape only, iPhone and iPad (`application/targeted_device_family=2`).
- [ ] Launch screen: Godot generates one from the boot splash colour (`#1b1026`); check it in the first TestFlight build.

## 3. App Review requirements

- ✅ **Delete account inside the app** (guideline 5.1.1(v)): Profile → Delete account removes the account and all of its data from the server.
- [ ] **Sign in with Apple** (guideline 4.8): the account sheet is built to show "Continue with Apple" and "Continue with Google" in the phone apps (`ui/account_sheet.gd`; `Online.native_signin_available()` returns false until native sign-in exists). If Google sign-in ships on iOS, Sign in with Apple must ship too. The server already accepts Apple identity tokens (`POST /v1/auth/apple`, checked against `APPLE_CLIENT_IDS`); the iOS build still needs a Sign in with Apple plugin, the capability turned on in Xcode, and the bundle ID added to `APPLE_CLIENT_IDS` in `api/wrangler.jsonc`.
- [ ] **Email must actually send.** `RESEND_API_KEY` is not set on the API, so verification and password-reset emails only land in the `outbox` table. Reviewers often test sign-up and password reset. Add the key with `cd api && npx wrangler secret put RESEND_API_KEY`, and set `MAIL_FROM` to an address on a domain you own.
- [ ] **Export compliance**: the game only uses standard HTTPS, so answer that it uses exempt encryption (`ITSAppUsesNonExemptEncryption = NO`).

## 4. App Store Connect listing

- [ ] Create the app record: name "Deck of Fools" (check it's free), bundle ID, SKU, primary language.
- [ ] **Privacy Policy URL**: `https://deck-of-fools.stefanodoko-radari.workers.dev/privacy.html`
- [ ] **Support URL**: `https://deck-of-fools.stefanodoko-radari.workers.dev/support.html`
  Both pages are in `site/public/`. They are published by `build.sh` once the `CONTACT_EMAIL` placeholder is replaced with a real address.
- [ ] **App Privacy** answers, matching the privacy policy:
  - Contact Info → Email Address: collected, linked to the user, used for App Functionality (only if they create an account).
  - Identifiers → User ID: collected, linked, App Functionality.
  - User Content → Gameplay Content (saves, runs, leaderboard name): collected, linked, App Functionality.
  - Not used for tracking. No ads, no analytics, no third-party advertising SDKs.
- [ ] **Age rating**: the questionnaire asks about simulated gambling. The game uses poker hands and in-game coins but no real money, wagers or prizes. Answer truthfully; poker-themed games often land at 12+ or higher.
- [ ] **Screenshots** in landscape for 6.9" iPhone and 13" iPad. The gallery build (`./preview.sh`, then `?screen=run`) helps set up scenes.

## 5. Ship

- [ ] Export the iOS preset to an Xcode project, open it, select your team, archive, and upload to App Store Connect.
- [ ] Test through **TestFlight** on a real iPhone: sign-in, saving, the daily run, delete account, sound, and rotation.
- [ ] Submit for review.

## Worth fixing before launch

- The API keeps the IP address of every new guest account in its `limits` table, and those rows are never deleted. The privacy policy says so honestly, but it would be better to store a hash of the IP, or clear rows older than a day.
