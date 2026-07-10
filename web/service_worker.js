/// <reference lib="webworker" />

const CACHE_NAME = 'finzy-v1';

const PRECACHE_URLS = [
  './',
  './index.html',
  './flutter.js',
  './flutter_bootstrap.js',
  './manifest.json',
  './sqlite3.wasm',
  './drift_worker.dart.js',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE_NAME);
      await cache.addAll(PRECACHE_URLS);
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const clients = await self.clients.matchAll({ type: 'window' });
      clients.forEach((client) => {
        client.postMessage({ type: 'SW_ACTIVATED' });
      });
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Skip non-GET and non-HTTP(S) requests
  if (event.request.method !== 'GET' || !url.protocol.startsWith('http')) return;

  // Cache-first for app shell assets (main.dart.js, .part.js, canvaskit, assets)
  if (
    url.pathname.endsWith('.js') ||
    url.pathname.endsWith('.wasm') ||
    url.pathname.endsWith('.png') ||
    url.pathname.endsWith('.jpg') ||
    url.pathname.endsWith('.svg') ||
    url.pathname.endsWith('.json') ||
    url.pathname.endsWith('.css') ||
    url.pathname.includes('/canvaskit/') ||
    url.pathname.includes('/assets/') ||
    url.pathname === '/' ||
    url.pathname === '/index.html'
  ) {
    event.respondWith(
      (async () => {
        const cached = await caches.match(event.request);
        if (cached) return cached;
        try {
          const response = await fetch(event.request);
          if (response.ok) {
            const cache = await caches.open(CACHE_NAME);
            cache.put(event.request, response.clone());
          }
          return response;
        } catch {
          return new Response('Offline', { status: 503 });
        }
      })(),
    );
    return;
  }

  // Network-only for API calls and media (don't cache Jellyfin responses)
  // Fall back to cache if offline for previously-fetched API responses
  event.respondWith(
    (async () => {
      try {
        const response = await fetch(event.request);
        return response;
      } catch {
        const cached = await caches.match(event.request);
        if (cached) return cached;
        return new Response('Offline', { status: 503 });
      }
    })(),
  );
});
