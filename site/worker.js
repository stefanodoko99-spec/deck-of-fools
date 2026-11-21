// worker.js
var worker_default = {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (url.pathname === "/index.wasm") {
      const r = await env.ASSETS.fetch(new Request(new URL("/index.wasm.gz", url), req));
      return new Response(r.body, { status: r.status, encodeBody: "manual", headers: {
        "Content-Type": "application/wasm",
        "Content-Encoding": "gzip",
        "Cache-Control": "public, max-age=3600"
      } });
    }
    return env.ASSETS.fetch(req);
  }
};
export {
  worker_default as default
};
