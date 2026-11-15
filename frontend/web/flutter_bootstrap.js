{{flutter_js}}
{{flutter_build_config}}

(async () => {
  if ('serviceWorker' in navigator) {
    // Oude Flutter service workers opruimen (voorkomt verouderde cache),
    // maar de PWA-service worker behouden zodat de app installeerbaar blijft.
    const registrations = await navigator.serviceWorker.getRegistrations();
    await Promise.all(
      registrations
        .filter((registration) => {
          const worker =
            registration.active || registration.waiting || registration.installing;
          return !(worker && worker.scriptURL.endsWith('/pwa-sw.js'));
        })
        .map((registration) => registration.unregister()),
    );
    try {
      await navigator.serviceWorker.register('pwa-sw.js', { scope: './' });
    } catch (error) {
      console.warn('PWA service worker registratie mislukt', error);
    }
  }

  await _flutter.loader.load();
})();
