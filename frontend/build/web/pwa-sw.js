// Minimale service worker zodat Houvast installeerbaar is als app.
// Bewust geen caching: altijd de nieuwste versie van de server laden.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  event.respondWith(
    fetch(event.request).catch(
      () =>
        new Response(
          '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' +
            '<body style="font-family:sans-serif;background:#F7F3EA;color:#24302F;padding:32px">' +
            '<h2>Geen verbinding</h2><p>Houvast heeft internet nodig. Probeer het opnieuw zodra je online bent.</p></body>',
          { headers: { 'Content-Type': 'text/html; charset=utf-8' } },
        ),
    ),
  );
});
