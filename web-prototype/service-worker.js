const CACHE = "maiditquick-v6";
const ASSETS = ["./portal.html", "./dispatch.html", "./styles.css", "./app.js", "./manifest.webmanifest", "./icon.svg", "./brand-wordmark.jpeg", "./brand-icon.jpeg", "./maid-hero-v1.png"];

self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(ASSETS)));
  self.skipWaiting();
});

self.addEventListener("activate", event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys
    .filter(key => key !== CACHE)
    .map(key => caches.delete(key)))));
  self.clients.claim();
});

self.addEventListener("fetch", event => {
  if (event.request.method !== "GET") return;
  const requestUrl = new URL(event.request.url);
  // The portal changes frequently during MVP work: always load its latest copy.
  if (requestUrl.pathname.endsWith("/portal.html")) {
    event.respondWith(fetch(event.request).catch(() => caches.match(event.request)));
    return;
  }
  event.respondWith(caches.match(event.request).then(cached => cached || fetch(event.request)));
});
