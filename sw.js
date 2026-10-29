// Service worker do Sessão a Dois: deixa o app instalável e abre mesmo sem internet.
// Ao mudar index.html/config.js não precisa mexer aqui (as páginas vêm sempre da rede primeiro).
// Só troque VERSAO se mudar a lista de arquivos abaixo.
const VERSAO = "sad-v2";
const SHELL = ["./", "index.html", "config.js", "manifest.webmanifest",
  "icons/icon-192.png", "icons/icon-512.png", "icons/apple-touch-icon.png", "icons/favicon-32.png"];
const CDN = ["fonts.googleapis.com", "fonts.gstatic.com", "cdn.jsdelivr.net"];
const CAPAS = "sad-capas";

self.addEventListener("install", e => {
  e.waitUntil(caches.open(VERSAO).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== VERSAO && k !== CAPAS).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);

  // Arquivos do próprio app: rede primeiro (sempre a versão mais nova), cache se estiver offline.
  if (url.origin === location.origin) {
    e.respondWith(fetch(req).then(r => {
      if (r.ok) { const cp = r.clone(); caches.open(VERSAO).then(c => c.put(req.mode === "navigate" ? "./" : req, cp)); }
      return r;
    }).catch(() => caches.match(req.mode === "navigate" ? "./" : req, { ignoreSearch: true })));
    return;
  }
  // Fontes e biblioteca do Supabase: cache, atualizando em segundo plano.
  if (CDN.includes(url.hostname)) {
    e.respondWith(caches.open(VERSAO).then(async c => {
      const hit = await c.match(req);
      const net = fetch(req).then(r => { if (r.ok || r.type === "opaque") c.put(req, r.clone()); return r; }).catch(() => hit);
      return hit || net;
    }));
    return;
  }
  // Capas do TMDB: cache primeiro (não mudam).
  if (url.hostname === "image.tmdb.org") {
    e.respondWith(caches.open(CAPAS).then(async c => {
      const hit = await c.match(req);
      if (hit) return hit;
      const r = await fetch(req);
      if (r.ok || r.type === "opaque") c.put(req, r.clone());
      return r;
    }));
    return;
  }
  // Supabase, Google e API do TMDB: sempre direto na rede (nada de cache).
});
