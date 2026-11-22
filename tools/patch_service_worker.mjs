// Patch Godot's PWA service worker (build/web/index.service.worker.js) so the engine,
// index.wasm (about 7 MB compressed), survives game updates.
//
// Godot names the whole cache after the export (CACHE_VERSION changes every build) and
// deletes old caches when a new version activates, so every game update made
// returning players download the unchanged engine again. Here index.wasm gets a cache
// of its own, named after a hash of its contents: it is only fetched again when the
// engine itself changes (a Godot upgrade). index.pck still updates with every build.
//
// Usage: node tools/patch_service_worker.mjs build/web <engine-hash>
// Fails loudly if Godot's service worker no longer looks as expected.
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const [dir, hash] = process.argv.slice(2);
if (!dir || !/^[0-9a-f]{8,64}$/.test(hash || "")) {
  console.error("usage: node tools/patch_service_worker.mjs <web build dir> <hex engine hash>");
  process.exit(2);
}
const file = join(dir, "index.service.worker.js");
let src = readFileSync(file, "utf8");

function replaceOnce(before, after, what) {
  const at = src.indexOf(before);
  if (at < 0 || src.indexOf(before, at + before.length) >= 0) {
    console.error(`patch_service_worker: can't find exactly one "${what}" in ${file}; Godot's service worker changed, update this script.`);
    process.exit(1);
  }
  src = src.slice(0, at) + after + src.slice(at + before.length);
}

if (src.includes("ENGINE_CACHE")) {
  console.error("patch_service_worker: already patched");
  process.exit(1);
}

replaceOnce(
  "const FULL_CACHE = CACHED_FILES.concat(CACHEABLE_FILES);",
  `const FULL_CACHE = CACHED_FILES.concat(CACHEABLE_FILES);
// Deck of Fools: the engine only changes when Godot is upgraded, so it lives in its own
// cache, named after its contents, which game updates leave alone.
const ENGINE_FILE = 'index.wasm';
const ENGINE_CACHE_PREFIX = 'Deck of Fools-engine-';
const ENGINE_CACHE = ENGINE_CACHE_PREFIX + '${hash}';
/** @param {string} name */
function cacheFor(name) {
	return caches.open(name === ENGINE_FILE ? ENGINE_CACHE : CACHE_NAME);
}`,
  "FULL_CACHE",
);

replaceOnce(
  "return Promise.all(keys.filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME).map((key) => caches.delete(key)));",
  "return Promise.all(keys.filter((key) => (key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME) || (key.startsWith(ENGINE_CACHE_PREFIX) && key !== ENGINE_CACHE)).map((key) => caches.delete(key)));",
  "old cache cleanup",
);

replaceOnce(
  "const cache = await caches.open(CACHE_NAME);",
  "const cache = await cacheFor(local);",
  "cache open in fetch",
);

replaceOnce(
  "const fullCache = await Promise.all(FULL_CACHE.map((name) => cache.match(name)));",
  "const fullCache = await Promise.all(FULL_CACHE.map(async (name) => (await cacheFor(name)).match(name)));",
  "full cache check",
);

writeFileSync(file, src);
console.log(`patched ${file}: engine cache ${hash}`);
