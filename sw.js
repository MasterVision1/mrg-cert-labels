/* Service worker — makes Cert Label Station an installable PWA and speeds cold
   starts. Same-origin static assets: stale-while-revalidate. HTML navigations,
   /api, the DYMO localhost service, and CDN libs are ALWAYS network (never
   cached/intercepted). Bump CACHE to force a refresh on a breaking deploy. */
const CACHE = "cert-labels-shell-v3";
const STATIC = /\.(?:js|css|png|jpe?g|svg|gif|webp|ico|woff2?|ttf|json|webmanifest)$/i;

self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (e) => e.waitUntil(
  caches.keys()
    .then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
    .then(() => self.clients.claim())
));
self.addEventListener("message", (e) => {
  const d = e.data;
  if (d === "SKIP_WAITING" || (d && d.type === "SKIP_WAITING")) self.skipWaiting();
});
self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  let url;
  try { url = new URL(req.url); } catch (_) { return; }
  if (url.origin !== location.origin) return;   // CDN libs, DYMO 127.0.0.1, the API → network
  if (req.mode === "navigate") return;           // always-fresh HTML shell
  if (!STATIC.test(url.pathname)) return;
  event.respondWith(
    caches.open(CACHE).then((cache) => cache.match(req).then((hit) => {
      const net = fetch(req).then((res) => { if (res && res.ok) cache.put(req, res.clone()); return res; }).catch(() => hit);
      return hit || net;
    }))
  );
});
