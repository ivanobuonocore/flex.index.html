// Service worker dedicato alle notifiche push (Web Push, RFC 8291) — file sorgente
// versionato, distinto da `flutter_service_worker.js` (generato e sovrascritto a ogni
// `flutter build web`, gestisce solo la cache offline). Registrato in aggiunta a
// quello di Flutter, dal codice Dart web (vedi
// apps/mobile/lib/features/notifications/data/push_notification_service_web.dart),
// non da index.html: le due registrazioni coesistono sullo stesso scope senza
// conflitti (ambiti diversi: caching delle risorse vs. eventi push).

self.addEventListener("push", (event) => {
  let data = { title: "PIP", body: "Hai una nuova notifica." };
  if (event.data) {
    try {
      data = event.data.json();
    } catch (_error) {
      data = { title: "PIP", body: event.data.text() };
    }
  }

  event.waitUntil(
    self.registration.showNotification(data.title || "PIP", {
      body: data.body || "",
      icon: "icons/Icon-192.png",
      badge: "icons/Icon-192.png",
    }),
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then(
      (clientList) => {
        for (const client of clientList) {
          if ("focus" in client) {
            return client.focus();
          }
        }
        if (self.clients.openWindow) {
          return self.clients.openWindow("/");
        }
      },
    ),
  );
});
