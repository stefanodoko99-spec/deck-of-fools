var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// src/util.js
var CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, Content-Type",
  "Access-Control-Max-Age": "86400",
  // The web build is cross-origin isolated (COEP require-corp), so say this may be loaded.
  "Cross-Origin-Resource-Policy": "cross-origin"
};
var HttpError = class extends Error {
  static {
    __name(this, "HttpError");
  }
  constructor(status, message) {
    super(message);
    this.status = status;
  }
};
function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store", ...CORS }
  });
}
__name(json, "json");
function html(body2, status = 200) {
  return new Response(body2, { status, headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" } });
}
__name(html, "html");
async function body(request, limit = 11e5) {
  const text = await request.text();
  if (text.length > limit) throw new HttpError(413, "That is too big to send.");
  if (!text) return {};
  try {
    const data = JSON.parse(text);
    if (typeof data !== "object" || data === null || Array.isArray(data)) throw new Error();
    return data;
  } catch {
    throw new HttpError(400, "The request body must be a JSON object.");
  }
}
__name(body, "body");
var now = /* @__PURE__ */ __name(() => Math.floor(Date.now() / 1e3), "now");
function randomToken(bytes = 32) {
  const raw = crypto.getRandomValues(new Uint8Array(bytes));
  return base64url(raw);
}
__name(randomToken, "randomToken");
function base64url(bytes) {
  let text = "";
  for (const b of bytes) text += String.fromCharCode(b);
  return btoa(text).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
__name(base64url, "base64url");
function fromBase64url(text) {
  const padded = text.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((text.length + 3) % 4);
  const raw = atob(padded);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}
__name(fromBase64url, "fromBase64url");
async function sha256(text) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
__name(sha256, "sha256");
async function allow(db, key, max, windowSeconds) {
  const t = now();
  const row = await db.prepare("SELECT count, window_start FROM limits WHERE key = ?").bind(key).first();
  if (!row || t - row.window_start >= windowSeconds) {
    await db.prepare("INSERT INTO limits (key, count, window_start) VALUES (?, 1, ?) ON CONFLICT(key) DO UPDATE SET count = 1, window_start = excluded.window_start").bind(key, t).run();
    return true;
  }
  if (row.count >= max) return false;
  await db.prepare("UPDATE limits SET count = count + 1 WHERE key = ?").bind(key).run();
  return true;
}
__name(allow, "allow");

// src/auth.js
var ITERATIONS = 1e5;
async function hashPassword(password) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const hash = await pbkdf2(password, salt, ITERATIONS);
  return `pbkdf2$${ITERATIONS}$${base64url(salt)}$${base64url(hash)}`;
}
__name(hashPassword, "hashPassword");
async function checkPassword(password, stored) {
  if (!stored) return false;
  const [scheme, iterations, salt, hash] = stored.split("$");
  if (scheme !== "pbkdf2") return false;
  const actual = await pbkdf2(password, fromBase64url(salt), Number(iterations));
  const expected = fromBase64url(hash);
  if (actual.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < actual.length; i++) diff |= actual[i] ^ expected[i];
  return diff === 0;
}
__name(checkPassword, "checkPassword");
async function pbkdf2(password, salt, iterations) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits({ name: "PBKDF2", hash: "SHA-256", salt, iterations }, key, 256);
  return new Uint8Array(bits);
}
__name(pbkdf2, "pbkdf2");
async function createSession(db, userId) {
  const token = randomToken();
  const t = now();
  await db.prepare("INSERT INTO sessions (token_hash, user_id, created_at, last_seen) VALUES (?, ?, ?, ?)").bind(await sha256(token), userId, t, t).run();
  return token;
}
__name(createSession, "createSession");
async function sessionUser(db, request) {
  const header = request.headers.get("Authorization") || "";
  const match = header.match(/^Bearer\s+(\S+)$/);
  if (!match) return null;
  const tokenHash = await sha256(match[1]);
  const user = await db.prepare("SELECT u.* FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token_hash = ?").bind(tokenHash).first();
  if (user) await db.prepare("UPDATE sessions SET last_seen = ? WHERE token_hash = ?").bind(now(), tokenHash).run();
  return user ? { ...user, tokenHash } : null;
}
__name(sessionUser, "sessionUser");
async function requireUser(db, request) {
  const user = await sessionUser(db, request);
  if (!user) throw new HttpError(401, "Please sign in again.");
  return user;
}
__name(requireUser, "requireUser");
var PROVIDERS = {
  apple: { issuers: ["https://appleid.apple.com"], keys: "https://appleid.apple.com/auth/keys", audiences: "APPLE_CLIENT_IDS", override: "JWKS_APPLE" },
  google: { issuers: ["https://accounts.google.com", "accounts.google.com"], keys: "https://www.googleapis.com/oauth2/v3/certs", audiences: "GOOGLE_CLIENT_IDS", override: "JWKS_GOOGLE" }
};
var keyCache = /* @__PURE__ */ new Map();
async function verifyIdentityToken(env, provider, token) {
  const spec = PROVIDERS[provider];
  const parts = String(token || "").split(".");
  if (parts.length !== 3) throw new HttpError(400, "That sign-in token is not valid.");
  const decode = /* @__PURE__ */ __name((part) => JSON.parse(new TextDecoder().decode(fromBase64url(part))), "decode");
  let header;
  let claims;
  try {
    header = decode(parts[0]);
    claims = decode(parts[1]);
  } catch {
    throw new HttpError(400, "That sign-in token is not valid.");
  }
  if (header.alg !== "RS256") throw new HttpError(400, "That sign-in token is not valid.");
  const jwks = await providerKeys(env, spec);
  const jwk = jwks.keys.find((k) => k.kid === header.kid);
  if (!jwk) throw new HttpError(401, "That sign-in could not be checked. Try again.");
  const key = await crypto.subtle.importKey("jwk", jwk, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
  const signed = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
  if (!await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, fromBase64url(parts[2]), signed)) {
    throw new HttpError(401, "That sign-in could not be checked. Try again.");
  }
  const audiences = String(env[spec.audiences] || "").split(",").map((a) => a.trim()).filter(Boolean);
  if (!spec.issuers.includes(claims.iss) || !audiences.includes(claims.aud) || !(claims.exp > now()) || !claims.sub) {
    throw new HttpError(401, "That sign-in has expired or is for another app. Try again.");
  }
  return claims;
}
__name(verifyIdentityToken, "verifyIdentityToken");
async function providerKeys(env, spec) {
  if (env[spec.override]) return JSON.parse(env[spec.override]);
  const cached = keyCache.get(spec.keys);
  if (cached && cached.until > Date.now()) return cached.jwks;
  const res = await fetch(spec.keys);
  if (!res.ok) throw new HttpError(503, "Sign-in is unavailable right now. Try again soon.");
  const jwks = await res.json();
  keyCache.set(spec.keys, { jwks, until: Date.now() + 36e5 });
  return jwks;
}
__name(providerKeys, "providerKeys");

// src/mail.js
async function sendMail(env, to, subject, text) {
  if (env.RESEND_API_KEY) {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: env.MAIL_FROM, to, subject, text })
    });
    if (!res.ok) console.error("email not sent", res.status, await res.text());
    return;
  }
  if (env.DEV_MAIL === "1") {
    await env.DB.prepare("INSERT INTO outbox (to_addr, subject, body, created_at) VALUES (?, ?, ?, ?)").bind(to, subject, text, now()).run();
    console.log(`[mail to ${to}] ${subject}
${text}`);
    return;
  }
  console.warn(`No email sender is set up; "${subject}" to ${to} was not sent.`);
}
__name(sendMail, "sendMail");
var verifyEmail = /* @__PURE__ */ __name((link) => `Welcome to Deck of Fools!

Tap this link to confirm your email address:
${link}

If you didn't create an account, you can ignore this email.`, "verifyEmail");
var resetEmail = /* @__PURE__ */ __name((link) => `Someone asked to reset your Deck of Fools password.

Tap this link to choose a new one (it works for one hour):
${link}

If it wasn't you, you can ignore this email: your password hasn't changed.`, "resetEmail");

// src/daily.js
var DECKS = [
  "d_bergamo",
  "d_venezia",
  "d_genova",
  "d_siena",
  "d_napoli",
  "d_palermo",
  "d_padova",
  "d_benevento",
  "d_verona",
  "d_ferrara",
  "d_bologna",
  "d_firenze",
  "d_roma",
  "d_mantova",
  "d_carnevale"
];
function today(date = /* @__PURE__ */ new Date()) {
  return date.toISOString().slice(0, 10);
}
__name(today, "today");
function dailySetup(dateText) {
  const [y, m, d] = dateText.split("-").map(Number);
  const day = Math.floor(Date.UTC(y, m - 1, d) / 864e5);
  return { date: dateText, seed: `DAY${dateText.replace(/-/g, "")}`, deck: DECKS[day % DECKS.length], stake: 1 };
}
__name(dailySetup, "dailySetup");
function acceptableDates(date = /* @__PURE__ */ new Date()) {
  const yesterday = new Date(date.getTime() - 864e5);
  return [today(date), today(yesterday)];
}
__name(acceptableDates, "acceptableDates");

// src/pages.js
var page = /* @__PURE__ */ __name((title, inner) => `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<style>
  body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #1b1026; color: #f3ead8; font: 16px/1.5 system-ui, sans-serif; padding: 16px; box-sizing: border-box; }
  main { max-width: 380px; width: 100%; background: #2b1a3d; border: 2px solid #3d2756; border-radius: 10px; padding: 24px; }
  h1 { color: #f0b84a; font-size: 22px; margin: 0 0 8px; }
  p { margin: 0 0 16px; color: #d8cce6; }
  label { display: block; font-size: 14px; margin: 12px 0 4px; }
  input { width: 100%; box-sizing: border-box; padding: 10px; border-radius: 6px; border: 1px solid #3d2756; background: #1b1026; color: #f3ead8; font: inherit; }
  button { margin-top: 16px; width: 100%; padding: 12px; border: 0; border-bottom: 3px solid #8a2a1e; border-radius: 6px; background: #e0503c; color: #fff; font: inherit; cursor: pointer; }
  #message { margin-top: 12px; min-height: 1.5em; }
</style></head><body><main>${inner}</main></body></html>`, "page");
var escape = /* @__PURE__ */ __name((text) => String(text).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]), "escape");
var verifiedPage = /* @__PURE__ */ __name((ok) => page("Deck of Fools", ok ? "<h1>Email confirmed</h1><p>Thanks! You can go back to the game.</p>" : "<h1>That link has expired</h1><p>Ask the game for a new confirmation email from your profile.</p>"), "verifiedPage");
var resetPage = /* @__PURE__ */ __name((token) => page("Deck of Fools: new password", `
  <h1>Choose a new password</h1>
  <p>At least 8 characters.</p>
  <form id="form">
    <label for="password">New password</label>
    <input id="password" type="password" autocomplete="new-password" minlength="8" required>
    <label for="again">Type it again</label>
    <input id="again" type="password" autocomplete="new-password" minlength="8" required>
    <button type="submit">Save the new password</button>
    <div id="message" role="status"></div>
  </form>
  <script>
    const form = document.getElementById('form');
    const message = document.getElementById('message');
    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      const password = document.getElementById('password').value;
      if (password !== document.getElementById('again').value) { message.textContent = "The two passwords don't match."; return; }
      const res = await fetch('/v1/auth/reset', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ token: ${JSON.stringify(escape(token))}, password }) });
      const data = await res.json();
      message.textContent = res.ok ? 'Done. Sign in with your new password in the game.' : data.error;
      if (res.ok) form.querySelector('button').disabled = true;
    });
  <\/script>`), "resetPage");

// src/index.js
var EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
// New sign-ups take plain addresses only: letters, digits and . _ % + - (after lower-casing).
// Quotes, semicolons, brackets, $ and backticks are valid in an address but could carry SQL
// or shell text into a support lookup (docs/LIVE_OPS.md); existing accounts still log in.
var NEW_EMAIL = /^[a-z0-9._%+-]+@[a-z0-9-]+(\.[a-z0-9-]+)*\.([a-z]{2,}|xn--[a-z0-9-]+)$/;
var NAME = /^[\p{L}\p{N} _.'-]{2,20}$/u;
var TOKEN = /^[A-Za-z0-9_-]{20,100}$/;
var MAX_SAVE = 1e6;
var LEADERBOARD_SIZE = 50;
var NEWS_SIZE = 20;
var LETTERS_SIZE = 50;
var LETTER_ID = /^[1-9]\d{0,11}$/;
var CLAIM_KEY = /^[A-Za-z0-9_-]{8,64}$/;
// The same rule as the news table's CHECK and the game's PlaybillSheet.is_web_link: an https
// link of 12 to 300 characters without spaces, tabs, line breaks, quotes or < >.
var NEWS_ACTION = /^(shop|collection|daily|https:\/\/[^\t\n\v\f\r "'<>]{4,292})$/;
var NEWS_COLOUR = /^(gold|orange|red|pink|purple|blue|teal|green|#[0-9a-fA-F]{6})$/;
var index_default = {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
    try {
      return await route(request, env);
    } catch (error) {
      if (error instanceof HttpError) return json({ error: error.message }, error.status);
      console.error(error);
      return json({ error: "Something went wrong on our side. Try again." }, 500);
    }
  }
};
async function route(request, env) {
  const url = new URL(request.url);
  const path = url.pathname;
  const method = request.method;
  const db = env.DB;
  const key = `${method} ${path}`;
  switch (key) {
    case "GET /v1/health":
      return json({ ok: true, time: now() });
    case "POST /v1/auth/guest":
      return guest(request, env);
    case "POST /v1/auth/signup":
      return signup(request, env);
    case "POST /v1/auth/login":
      return login(request, env);
    case "POST /v1/auth/logout": {
      const user = await requireUser(db, request);
      await db.prepare("DELETE FROM sessions WHERE token_hash = ?").bind(user.tokenHash).run();
      return json({ ok: true });
    }
    case "POST /v1/auth/apple":
      return identity(request, env, "apple");
    case "POST /v1/auth/google":
      return identity(request, env, "google");
    case "POST /v1/auth/forgot":
      return forgot(request, env);
    case "POST /v1/auth/reset":
      return reset(request, env);
    case "POST /v1/auth/resend-verification": {
      const user = await requireUser(db, request);
      if (user.email && !user.email_verified) await sendVerification(env, user);
      return json({ ok: true });
    }
    case "GET /verify":
      return verify(url, env);
    case "GET /reset": {
      const token = url.searchParams.get("token") || "";
      return TOKEN.test(token) ? html(resetPage(token)) : html(verifiedPage(false), 400);
    }
    case "GET /v1/me":
      return json({ user: publicUser(await requireUser(db, request)) });
    case "PATCH /v1/me":
      return rename(request, env);
    case "DELETE /v1/me":
      return deleteAccount(request, env);
    case "GET /v1/me/stats":
      return stats(request, env);
    case "GET /v1/save":
      return getSave(request, env);
    case "PUT /v1/save":
      return putSave(request, env);
    case "GET /v1/daily":
      return daily(request, env);
    case "POST /v1/daily/start":
      return startDaily(request, env);
    case "POST /v1/runs":
      return submitRun(request, env);
    case "GET /v1/leaderboards/daily":
      return dailyBoard(request, env, url);
    case "GET /v1/leaderboards/best_hand":
      return bestHandBoard(request, env);
    case "GET /v1/leaderboards/town":
      return townBoard(request, env, url);
    case "GET /v1/news":
      return news(request, env);
    case "GET /v1/letters":
      return letters(request, env);
    case "GET /v1/dev/outbox":
      if (env.DEV_MAIL !== "1") break;
      return json({ emails: (await db.prepare("SELECT * FROM outbox ORDER BY id DESC LIMIT 20").all()).results });
  }
  const claim = method === "POST" ? path.match(/^\/v1\/letters\/([^/]+)\/claim$/) : null;
  if (claim) return claimLetter(request, env, claim[1]);
  throw new HttpError(404, "Not found.");
}
__name(route, "route");
function publicUser(user) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    verified: Boolean(user.email_verified),
    guest: Boolean(user.guest),
    signins: { password: Boolean(user.password_hash), apple: Boolean(user.apple_sub), google: Boolean(user.google_sub) },
    created_at: user.created_at
  };
}
__name(publicUser, "publicUser");
async function signedIn(env, user) {
  const fresh = await env.DB.prepare("SELECT * FROM users WHERE id = ?").bind(user.id).first();
  return { token: await createSession(env.DB, user.id), user: publicUser(fresh) };
}
__name(signedIn, "signedIn");
var ip = /* @__PURE__ */ __name((request) => request.headers.get("CF-Connecting-IP") || "local", "ip");
function guestName() {
  return `Guest ${1e3 + Math.floor(Math.random() * 9e3)}`;
}
__name(guestName, "guestName");
async function guest(request, env) {
  if (!await allow(env.DB, `guest:${ip(request)}`, 30, 3600)) throw new HttpError(429, "Too many new players from here. Try again later.");
  const id = crypto.randomUUID();
  await env.DB.prepare("INSERT INTO users (id, name, guest, created_at) VALUES (?, ?, 1, ?)").bind(id, guestName(), now()).run();
  return json(await signedIn(env, { id }), 201);
}
__name(guest, "guest");
function cleanEmail(value, fresh = false) {
  const email = String(value || "").trim().toLowerCase();
  if (email.length > 254 || !EMAIL.test(email)) throw new HttpError(400, "Enter a valid email address.");
  if (fresh && !NEW_EMAIL.test(email)) throw new HttpError(400, "Use an email address made of letters, numbers and the marks . _ % + - only.");
  return email;
}
__name(cleanEmail, "cleanEmail");
function cleanPassword(value) {
  const password = String(value || "");
  if (password.length < 8) throw new HttpError(400, "Your password needs at least 8 characters.");
  if (password.length > 200) throw new HttpError(400, "That password is too long.");
  return password;
}
__name(cleanPassword, "cleanPassword");
function cleanName(value) {
  const name = String(value || "").trim().replace(/\s+/g, " ");
  if (!NAME.test(name)) throw new HttpError(400, "Names are 2 to 20 letters, numbers or spaces.");
  return name;
}
__name(cleanName, "cleanName");
async function signup(request, env) {
  const data = await body(request);
  const email = cleanEmail(data.email, true);
  const password = cleanPassword(data.password);
  const name = cleanName(data.name);
  const db = env.DB;
  if (await db.prepare("SELECT 1 FROM users WHERE email = ?").bind(email).first()) {
    throw new HttpError(409, "That email already has an account. Log in instead.");
  }
  const hash = await hashPassword(password);
  const current = await sessionUser(db, request);
  let user;
  if (current && current.guest) {
    await db.prepare("UPDATE users SET email = ?, password_hash = ?, name = ?, guest = 0 WHERE id = ?").bind(email, hash, name, current.id).run();
    user = { ...current, email, name };
  } else {
    user = { id: crypto.randomUUID(), email, name };
    await db.prepare("INSERT INTO users (id, name, email, password_hash, guest, created_at) VALUES (?, ?, ?, ?, 0, ?)").bind(user.id, name, email, hash, now()).run();
  }
  await sendVerification(env, user);
  return json({ ...await signedIn(env, user), linked: Boolean(current && current.guest) }, 201);
}
__name(signup, "signup");
async function login(request, env) {
  const data = await body(request);
  const email = cleanEmail(data.email);
  if (!await allow(env.DB, `login:${email}`, 10, 900)) throw new HttpError(429, "Too many tries. Wait 15 minutes and try again.");
  const user = await env.DB.prepare("SELECT * FROM users WHERE email = ?").bind(email).first();
  if (!user || !await checkPassword(String(data.password || ""), user.password_hash)) {
    throw new HttpError(401, "That email and password don't match.");
  }
  return json(await signedIn(env, user));
}
__name(login, "login");
async function identity(request, env, provider) {
  const data = await body(request);
  const claims = await verifyIdentityToken(env, provider, data.id_token);
  const column = provider === "apple" ? "apple_sub" : "google_sub";
  const db = env.DB;
  const existing = await db.prepare(`SELECT * FROM users WHERE ${column} = ?`).bind(claims.sub).first();
  if (existing) return json({ ...await signedIn(env, existing), linked: false, created: false });
  const current = await sessionUser(db, request);
  const email = claims.email && claims.email_verified !== false && claims.email_verified !== "false" ? String(claims.email).toLowerCase() : null;
  const emailFree = email && !await db.prepare("SELECT 1 FROM users WHERE email = ?").bind(email).first();
  if (current) {
    await db.prepare(`UPDATE users SET ${column} = ?, guest = 0, email = COALESCE(email, ?), email_verified = CASE WHEN email IS NULL AND ? IS NOT NULL THEN 1 ELSE email_verified END WHERE id = ?`).bind(claims.sub, emailFree ? email : null, emailFree ? email : null, current.id).run();
    return json({ ...await signedIn(env, current), linked: true, created: false });
  }
  const id = crypto.randomUUID();
  const name = data.name ? cleanName(data.name) : guestName().replace("Guest", "Player");
  await db.prepare(`INSERT INTO users (id, name, email, email_verified, ${column}, guest, created_at) VALUES (?, ?, ?, ?, ?, 0, ?)`).bind(id, name, emailFree ? email : null, emailFree ? 1 : 0, claims.sub, now()).run();
  return json({ ...await signedIn(env, { id }), linked: false, created: true }, 201);
}
__name(identity, "identity");
async function sendVerification(env, user) {
  const token = randomToken();
  await env.DB.prepare("INSERT INTO tokens (token_hash, user_id, kind, expires_at) VALUES (?, ?, ?, ?)").bind(await sha256(token), user.id, "verify", now() + 7 * 86400).run();
  await sendMail(env, user.email, "Confirm your Deck of Fools email", verifyEmail(`${env.PUBLIC_URL}/verify?token=${token}`));
}
__name(sendVerification, "sendVerification");
async function useToken(env, token, kind) {
  if (!TOKEN.test(String(token || ""))) return null;
  const tokenHash = await sha256(token);
  const row = await env.DB.prepare("SELECT * FROM tokens WHERE token_hash = ? AND kind = ?").bind(tokenHash, kind).first();
  if (!row) return null;
  await env.DB.prepare("DELETE FROM tokens WHERE token_hash = ?").bind(tokenHash).run();
  return row.expires_at > now() ? row : null;
}
__name(useToken, "useToken");
async function verify(url, env) {
  const row = await useToken(env, url.searchParams.get("token"), "verify");
  if (row) await env.DB.prepare("UPDATE users SET email_verified = 1 WHERE id = ?").bind(row.user_id).run();
  return html(verifiedPage(Boolean(row)), row ? 200 : 400);
}
__name(verify, "verify");
async function forgot(request, env) {
  const data = await body(request);
  const email = cleanEmail(data.email);
  if (await allow(env.DB, `forgot:${email}`, 3, 3600)) {
    const user = await env.DB.prepare("SELECT * FROM users WHERE email = ?").bind(email).first();
    if (user) {
      const token = randomToken();
      await env.DB.prepare("INSERT INTO tokens (token_hash, user_id, kind, expires_at) VALUES (?, ?, ?, ?)").bind(await sha256(token), user.id, "reset", now() + 3600).run();
      await sendMail(env, email, "Reset your Deck of Fools password", resetEmail(`${env.PUBLIC_URL}/reset?token=${token}`));
    }
  }
  return json({ ok: true });
}
__name(forgot, "forgot");
async function reset(request, env) {
  const data = await body(request);
  const password = cleanPassword(data.password);
  const row = await useToken(env, data.token, "reset");
  if (!row) throw new HttpError(400, "That link has expired. Ask for a new one in the game.");
  await env.DB.batch([
    env.DB.prepare("UPDATE users SET password_hash = ? WHERE id = ?").bind(await hashPassword(password), row.user_id),
    env.DB.prepare("DELETE FROM sessions WHERE user_id = ?").bind(row.user_id)
  ]);
  return json({ ok: true });
}
__name(reset, "reset");
async function rename(request, env) {
  const user = await requireUser(env.DB, request);
  const data = await body(request);
  const name = cleanName(data.name);
  await env.DB.prepare("UPDATE users SET name = ? WHERE id = ?").bind(name, user.id).run();
  return json({ user: publicUser({ ...user, name }) });
}
__name(rename, "rename");
// The player's claims and personal letters (migration 0002) go with the users row through
// ON DELETE CASCADE, so deleting an account doesn't depend on that migration being applied.
async function deleteAccount(request, env) {
  const user = await requireUser(env.DB, request);
  await env.DB.batch(["daily", "runs", "saves", "tokens", "sessions"].map((table) => env.DB.prepare(`DELETE FROM ${table} WHERE user_id = ?`).bind(user.id)).concat([env.DB.prepare("DELETE FROM users WHERE id = ?").bind(user.id)]));
  return json({ deleted: true });
}
__name(deleteAccount, "deleteAccount");
async function getSave(request, env) {
  const user = await requireUser(env.DB, request);
  const row = await env.DB.prepare("SELECT version, data, device, updated_at FROM saves WHERE user_id = ?").bind(user.id).first();
  return json(row ? { version: row.version, data: JSON.parse(row.data), device: row.device, updated_at: row.updated_at } : { version: 0, data: null });
}
__name(getSave, "getSave");
async function putSave(request, env) {
  const user = await requireUser(env.DB, request);
  const data = await body(request, MAX_SAVE + 1e4);
  if (typeof data.data !== "object" || data.data === null) throw new HttpError(400, "Nothing to save.");
  const text = JSON.stringify(data.data);
  if (text.length > MAX_SAVE) throw new HttpError(413, "That save is too big.");
  const db = env.DB;
  const row = await db.prepare("SELECT version, data, device, updated_at FROM saves WHERE user_id = ?").bind(user.id).first();
  const current = row ? row.version : 0;
  if (!data.force && Number(data.base_version || 0) !== current) {
    return json({ error: "The cloud has a newer save.", version: current, data: JSON.parse(row.data), device: row.device, updated_at: row.updated_at }, 409);
  }
  const version = current + 1;
  const device = String(data.device || "").slice(0, 60);
  await db.prepare("INSERT INTO saves (user_id, version, data, device, updated_at) VALUES (?, ?, ?, ?, ?) ON CONFLICT(user_id) DO UPDATE SET version = excluded.version, data = excluded.data, device = excluded.device, updated_at = excluded.updated_at").bind(user.id, version, text, device, now()).run();
  return json({ version });
}
__name(putSave, "putSave");
async function daily(request, env) {
  const setup = dailySetup(today());
  const user = await sessionUser(env.DB, request);
  let attempt = null;
  if (user) {
    const row = await env.DB.prepare("SELECT d.run_id, r.town, r.best_hand, r.won FROM daily d LEFT JOIN runs r ON r.id = d.run_id WHERE d.date = ? AND d.user_id = ?").bind(setup.date, user.id).first();
    if (row) attempt = { finished: row.run_id !== null, town: row.town, best_hand: row.best_hand, won: Boolean(row.won) };
  }
  return json({ ...setup, attempt });
}
__name(daily, "daily");
async function startDaily(request, env) {
  const user = await requireUser(env.DB, request);
  const setup = dailySetup(today());
  const result = await env.DB.prepare("INSERT OR IGNORE INTO daily (date, user_id, started_at) VALUES (?, ?, ?)").bind(setup.date, user.id, now()).run();
  if (!result.meta.changes) throw new HttpError(409, "You've already played today's ranked daily run. Practice is unlimited.");
  return json(setup, 201);
}
__name(startDaily, "startDaily");
async function submitRun(request, env) {
  const user = await requireUser(env.DB, request);
  const data = await body(request);
  const seed = String(data.seed || "");
  const deck = String(data.deck || "");
  const stake = Number(data.stake);
  const town = Number(data.town);
  const bestHand = Number(data.best_hand);
  const challenge = String(data.challenge || "");
  const actions = Array.isArray(data.actions) ? data.actions : null;
  const jesters = Array.isArray(data.jesters) ? data.jesters.map(String).slice(0, 20) : [];
  if (!/^[A-Z0-9]{4,24}$/.test(seed) || !DECKS.includes(deck) || !Number.isInteger(stake) || stake < 1 || stake > 8 || !Number.isInteger(town) || town < 1 || town > 1e3 || !Number.isFinite(bestHand) || bestHand < 0 || challenge && !/^c_[a-z0-9_]+$/.test(challenge) || !actions || actions.length > 5e4 || actions.some((a) => typeof a !== "object" || a === null || typeof a.a !== "string")) {
    throw new HttpError(400, "That run doesn't look right.");
  }
  const plays = actions.filter((a) => a.a === "play").length;
  const plausible = plays >= Math.max(town - 1, bestHand > 0 ? 1 : 0) && (town > 8 || bestHand <= 1e18);
  if (!plausible) throw new HttpError(422, "That run doesn't add up, so it wasn't ranked.");
  if (!await allow(env.DB, `runs:${user.id}`, 30, 3600)) throw new HttpError(429, "Too many runs handed in. Try again later.");
  let dailyDate = null;
  if (data.daily_date) {
    const date = String(data.daily_date);
    const setup = acceptableDates().includes(date) ? dailySetup(date) : null;
    const attempt = setup && await env.DB.prepare("SELECT run_id FROM daily WHERE date = ? AND user_id = ?").bind(date, user.id).first();
    if (!setup || !attempt || attempt.run_id !== null || seed !== setup.seed || deck !== setup.deck || stake !== setup.stake || challenge) {
      throw new HttpError(409, "That isn't today's ranked daily attempt.");
    }
    dailyDate = date;
  }
  const result = await env.DB.prepare("INSERT INTO runs (user_id, seed, deck, stake, challenge, daily_date, won, town, best_hand, jesters, actions, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)").bind(user.id, seed, deck, stake, challenge, dailyDate, data.won ? 1 : 0, town, bestHand, JSON.stringify(jesters), JSON.stringify(actions), now()).run();
  const runId = result.meta.last_row_id;
  if (dailyDate) await env.DB.prepare("UPDATE daily SET run_id = ? WHERE date = ? AND user_id = ?").bind(runId, dailyDate, user.id).run();
  return json({ run_id: runId, daily_date: dailyDate }, 201);
}
__name(submitRun, "submitRun");
async function board(env, user, query, binds, rankQuery) {
  const rows = (await env.DB.prepare(`${query} LIMIT ${LEADERBOARD_SIZE}`).bind(...binds).all()).results;
  const entries = rows.map((row, i) => ({ rank: i + 1, ...row, me: Boolean(user && row.user_id === user.id) }));
  let me = entries.find((e) => e.me) || null;
  if (!me && user) me = await rankQuery(user);
  return json({ entries: entries.map(({ user_id, ...rest }) => rest), me: me && (({ user_id, ...rest }) => rest)(me) });
}
__name(board, "board");
async function dailyBoard(request, env, url) {
  const user = await sessionUser(env.DB, request);
  const date = url.searchParams.get("date") || today();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) throw new HttpError(400, "Dates look like 2026-10-21.");
  const ranked = "FROM daily d JOIN runs r ON r.id = d.run_id JOIN users u ON u.id = d.user_id WHERE d.date = ?";
  return board(env, user, `SELECT u.name, d.user_id, r.town, r.best_hand, r.won ${ranked} ORDER BY r.town DESC, r.best_hand DESC, r.created_at ASC`, [date], async (u) => {
    const mine = await env.DB.prepare(`SELECT u.name, d.user_id, r.town, r.best_hand, r.won, r.created_at ${ranked} AND d.user_id = ?`).bind(date, u.id).first();
    if (!mine) return null;
    const ahead = await env.DB.prepare(`SELECT COUNT(*) AS n ${ranked} AND (r.town > ? OR (r.town = ? AND (r.best_hand > ? OR (r.best_hand = ? AND r.created_at < ?))))`).bind(date, mine.town, mine.town, mine.best_hand, mine.best_hand, mine.created_at).first();
    const { created_at, ...row } = mine;
    return { rank: ahead.n + 1, ...row, me: true };
  });
}
__name(dailyBoard, "dailyBoard");
async function bestHandBoard(request, env) {
  const user = await sessionUser(env.DB, request);
  const best = "SELECT r.user_id, u.name, MAX(r.best_hand) AS best_hand FROM runs r JOIN users u ON u.id = r.user_id GROUP BY r.user_id";
  return board(env, user, `${best} ORDER BY best_hand DESC`, [], async (u) => {
    const mine = await env.DB.prepare(`SELECT * FROM (${best}) WHERE user_id = ?`).bind(u.id).first();
    if (!mine) return null;
    const ahead = await env.DB.prepare(`SELECT COUNT(*) AS n FROM (${best}) WHERE best_hand > ?`).bind(mine.best_hand).first();
    return { rank: ahead.n + 1, ...mine, me: true };
  });
}
__name(bestHandBoard, "bestHandBoard");
async function townBoard(request, env, url) {
  const user = await sessionUser(env.DB, request);
  const stake = Number(url.searchParams.get("stake") || 1);
  if (!Number.isInteger(stake) || stake < 1 || stake > 8) throw new HttpError(400, "Stakes go from 1 to 8.");
  const best = "SELECT r.user_id, u.name, MAX(r.town) AS town FROM runs r JOIN users u ON u.id = r.user_id WHERE r.stake = ? AND r.challenge = '' GROUP BY r.user_id";
  return board(env, user, `${best} ORDER BY town DESC`, [stake], async (u) => {
    const mine = await env.DB.prepare(`SELECT * FROM (${best}) WHERE user_id = ?`).bind(stake, u.id).first();
    if (!mine) return null;
    const ahead = await env.DB.prepare(`SELECT COUNT(*) AS n FROM (${best}) WHERE town > ?`).bind(stake, mine.town).first();
    return { rank: ahead.n + 1, ...mine, me: true };
  });
}
__name(townBoard, "townBoard");
async function stats(request, env) {
  const user = await requireUser(env.DB, request);
  const db = env.DB;
  const perDeck = (await db.prepare("SELECT deck, stake, COUNT(*) AS runs, SUM(won) AS wins FROM runs WHERE user_id = ? AND challenge = '' GROUP BY deck, stake ORDER BY deck, stake").bind(user.id).all()).results;
  const totals = await db.prepare("SELECT COUNT(*) AS runs, COALESCE(SUM(won), 0) AS wins, COALESCE(MAX(best_hand), 0) AS best_hand, COALESCE(MAX(town), 0) AS best_town FROM runs WHERE user_id = ?").bind(user.id).first();
  const held = (await db.prepare("SELECT jesters FROM runs WHERE user_id = ? ORDER BY id DESC LIMIT 500").bind(user.id).all()).results;
  const counts = {};
  for (const row of held) for (const id of JSON.parse(row.jesters)) counts[id] = (counts[id] || 0) + 1;
  const favourite = Object.entries(counts).sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))[0];
  return json({ ...totals, per_deck: perDeck, favourite_jester: favourite ? favourite[0] : null });
}
__name(stats, "stats");
// The Playbill (GET /v1/news) is public and the same for everyone, like the leaderboards.
// A one-minute copy kept in this isolate answers most calls, and the per-isolate counter
// turns away a client that hammers it; the D1 limiter would cost a write on every call.
// The copy looks an hour ahead, so items still start and end on the second.
// An ends_at of 0 means the item stays up (the table refuses NULL and text times).
var newsCopy = { at: -Infinity, rows: [] };
var newsHits = /* @__PURE__ */ new Map();
async function news(request, env) {
  const t = now();
  if (!newsAllowed(ip(request), t)) throw new HttpError(429, "Too many requests. Try again in a few minutes.");
  const ttl = Number(env.NEWS_CACHE_SECONDS ?? 60);
  if (!(t - newsCopy.at < ttl)) {
    const rows = (await env.DB.prepare("SELECT id, kind, title, body, colour, action, version, starts_at, ends_at FROM news WHERE starts_at <= ? AND (ends_at = 0 OR ends_at > ?) ORDER BY starts_at DESC, id DESC LIMIT 60").bind(t + 3600, t).all()).results;
    newsCopy = { at: t, rows };
  }
  const items = newsCopy.rows.filter((n) => n.starts_at <= t && (n.ends_at === 0 || n.ends_at > t)).slice(0, NEWS_SIZE).map(cleanNews);
  return json({ news: items, time: t });
}
__name(news, "news");
function newsAllowed(address, t) {
  const hit = newsHits.get(address);
  if (!hit || t - hit.start >= 600) {
    if (newsHits.size >= 1e4) newsHits.clear();
    newsHits.set(address, { start: t, count: 1 });
    return true;
  }
  hit.count += 1;
  return hit.count <= 60;
}
__name(newsAllowed, "newsAllowed");
function cleanNews(row) {
  return {
    id: row.id,
    kind: row.kind,
    title: cut(row.title, 80),
    body: cut(row.body, 600),
    colour: NEWS_COLOUR.test(row.colour || "") ? row.colour : "",
    action: NEWS_ACTION.test(row.action || "") ? row.action : "",
    version: cut(row.version, 20),
    starts_at: row.starts_at,
    ends_at: row.ends_at || 0
  };
}
__name(cleanNews, "cleanNews");
// At most `limit` characters as the database counts them (code points, so an emoji is one
// and is never cut in half).
function cut(text, limit) {
  return Array.from(String(text || "")).slice(0, limit).join("");
}
__name(cut, "cut");
// The inbox: letters for this player or for everyone, delivered (created_at reached) and not
// expired (an expires_at of 0 never expires), newest first, each saying whether this account
// has claimed it.
async function letters(request, env) {
  const user = await requireUser(env.DB, request);
  if (!await allow(env.DB, `letters:${user.id}`, 120, 3600)) throw new HttpError(429, "Too many requests. Try again later.");
  const t = now();
  const rows = (await env.DB.prepare("SELECT l.id, l.title, l.body, l.coins, l.created_at, l.expires_at, l.user_id IS NOT NULL AS personal, c.letter_id IS NOT NULL AS claimed FROM letters l LEFT JOIN letter_claims c ON c.letter_id = l.id AND c.user_id = ?1 WHERE (l.user_id IS NULL OR l.user_id = ?1) AND l.created_at <= ?2 AND (l.expires_at = 0 OR l.expires_at > ?2) ORDER BY l.created_at DESC, l.id DESC LIMIT ?3").bind(user.id, t, LETTERS_SIZE).all()).results;
  return json({ letters: rows.map((row) => ({ ...row, personal: Boolean(row.personal), claimed: Boolean(row.claimed) })), time: t });
}
__name(letters, "letters");
// Claiming is idempotent: the first call answers { coins } and every later call
// { coins: 0, already: true }, so coins are paid once per account however often it is sent.
// A call may carry a key; repeating the key of the call that claimed the letter (its answer
// was lost on the way) gets { coins, repeat: true }, and the game pays only if it hasn't yet.
// A letter claimed in time stays claimed after it expires.
async function claimLetter(request, env, idText) {
  if (!LETTER_ID.test(idText)) throw new HttpError(400, "That isn't a letter.");
  const db = env.DB;
  const user = await requireUser(db, request);
  const data = await body(request, 2e3);
  const claimKey = data.key === void 0 || data.key === null ? "" : data.key;
  if (claimKey !== "" && (typeof claimKey !== "string" || !CLAIM_KEY.test(claimKey))) throw new HttpError(400, "That claim doesn't look right.");
  if (!await allow(db, `claim:${user.id}`, 60, 3600)) throw new HttpError(429, "Too many claims. Try again later.");
  const id = Number(idText);
  const t = now();
  const letter = await db.prepare("SELECT coins, created_at, expires_at FROM letters WHERE id = ? AND (user_id IS NULL OR user_id = ?)").bind(id, user.id).first();
  if (!letter || letter.created_at > t) throw new HttpError(404, "That letter isn't in your inbox.");
  const findClaim = /* @__PURE__ */ __name(() => db.prepare("SELECT claim_key FROM letter_claims WHERE letter_id = ? AND user_id = ?").bind(id, user.id).first(), "findClaim");
  const earlier = await findClaim();
  if (earlier) return json(claimedAgain(letter, earlier, claimKey));
  if (letter.expires_at > 0 && letter.expires_at <= t) throw new HttpError(410, "That letter has expired.");
  const result = await db.prepare("INSERT OR IGNORE INTO letter_claims (letter_id, user_id, claimed_at, claim_key) VALUES (?, ?, ?, ?)").bind(id, user.id, t, claimKey).run();
  if (!result.meta.changes) return json(claimedAgain(letter, await findClaim() || {}, claimKey));
  return json({ coins: letter.coins });
}
__name(claimLetter, "claimLetter");
function claimedAgain(letter, claim, claimKey) {
  return claimKey && claim.claim_key === claimKey ? { coins: letter.coins, repeat: true } : { coins: 0, already: true };
}
__name(claimedAgain, "claimedAgain");
export {
  index_default as default
};
