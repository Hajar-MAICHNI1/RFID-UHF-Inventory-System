// ═══════════════════════════════════════════════════════════
// Service Worker — Hôtel RFID UHF
// Strategy:
//   - Static shell (login.html, manifest.json, icon.png) → cache-first
//   - Main app (/) → network-first  (auth redirects must work)
//   - API / WebSocket / POST routes → network-only  (never cache)
// ═══════════════════════════════════════════════════════════
const CACHE_NAME  = 'rfid-v1';
const SHELL_FILES = [
    '/login',
    '/manifest.json',
    '/icon.png'
];

// ── Install: pre-cache the login shell ──────────────────────
self.addEventListener('install', event => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(cache => cache.addAll(SHELL_FILES))
            .then(() => self.skipWaiting())
    );
});

// ── Activate: remove old cache versions ─────────────────────
self.addEventListener('activate', event => {
    event.waitUntil(
        caches.keys().then(keys =>
            Promise.all(
                keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))
            )
        ).then(() => self.clients.claim())
    );
});

// ── Fetch: routing strategy ─────────────────────────────────
self.addEventListener('fetch', event => {
    const url = new URL(event.request.url);

    // Never intercept: POST requests, WebSocket upgrades, logout
    if (event.request.method !== 'GET') return;
    if (url.pathname === '/logout')     return;
    if (url.pathname === '/save')       return;

    // Network-first for the main authenticated page
    if (url.pathname === '/') {
        event.respondWith(
            fetch(event.request)
                .catch(() => caches.match(event.request))
        );
        return;
    }

    // Cache-first for static shell files (login, manifest, icon)
    event.respondWith(
        caches.match(event.request).then(cached => {
            if (cached) return cached;
            return fetch(event.request).then(response => {
                // Cache valid GET responses for shell files
                if (response && response.status === 200) {
                    const clone = response.clone();
                    caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
                }
                return response;
            });
        })
    );
});
