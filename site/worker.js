// Serves the Godot web export from Workers static assets (../build/web).
// The engine (index.wasm) and the game data (index.pck) are stored pre-compressed by
// build.sh: Brotli for browsers that accept it (all current ones), gzip or the plain
// file otherwise. The raw index.wasm (~38 MiB) is over the 25 MiB static-asset limit
// and is never uploaded; the plain pck is stored as index.pck.raw so that requests for
// /index.pck reach this worker instead of being answered by the static files directly.
// encodeBody "manual" sends the compressed bytes as they are.
const COMPRESSED = {
  "/index.wasm": { type: "application/wasm", variants: [["br", "/index.wasm.br"], ["gzip", "/index.wasm.gz"]] },
  "/index.pck": { type: "application/octet-stream", variants: [["br", "/index.pck.br"], ["gzip", "/index.pck.gz"], ["", "/index.pck.raw"]] },
};

/** The first variant whose encoding the browser accepts (the last one otherwise). */
function pick(acceptEncoding, variants) {
  const accepted = acceptEncoding.toLowerCase().split(",").map((part) => part.trim().split(";")[0]);
  return variants.find(([encoding]) => encoding === "" || accepted.includes(encoding)) || variants[variants.length - 1];
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    const entry = COMPRESSED[url.pathname];
    if (!entry || (req.method !== "GET" && req.method !== "HEAD")) {
      return env.ASSETS.fetch(req);
    }
    const [encoding, path] = pick(req.headers.get("Accept-Encoding") || "", entry.variants);
    const asset = await env.ASSETS.fetch(new Request(new URL(path, url), req));
    const headers = new Headers({
      "Content-Type": entry.type,
      "Vary": "Accept-Encoding",
      // An hour, then a cheap revalidation (ETag): the file names don't change
      // between builds, and the engine and index.js must always match.
      "Cache-Control": "public, max-age=3600",
    });
    const etag = asset.headers.get("ETag");
    if (etag) headers.set("ETag", etag);
    if (encoding) headers.set("Content-Encoding", encoding);
    return new Response(asset.body, { status: asset.status, headers, encodeBody: encoding ? "manual" : "automatic" });
  },
};
