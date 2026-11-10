/* عامل الخدمة — يجعل التطبيق يعمل بلا إنترنت بعد أول فتح.
   استراتيجية: الشبكة أولًا للصفحة نفسها (ليصلك أحدث إصدار)،
   والذاكرة أولًا للأيقونات والملفات الثابتة. */

const V = "qadaya-v1";
const SHELL = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./icon-192.png",
  "./icon-512.png",
  "./icon-maskable.png",
  "./apple-touch-icon.png"
];

self.addEventListener("install", e => {
  e.waitUntil(
    caches.open(V)
      .then(c => c.addAll(SHELL).catch(() => {}))   /* ملف ناقص لا يُفشل التثبيت */
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys()
      .then(ks => Promise.all(ks.filter(k => k !== V).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;

  const url = new URL(req.url);
  /* لا تلمس نداءات Supabase ولا مزوّدي الذكاء الاصطناعي إطلاقًا */
  if (url.origin !== self.location.origin) return;

  const isPage = req.mode === "navigate" ||
                 (req.headers.get("accept") || "").includes("text/html");

  if (isPage) {
    /* الشبكة أولًا: يصلك التحديث فور نشره، والذاكرة احتياط عند الانقطاع */
    e.respondWith(
      fetch(req)
        .then(r => {
          const copy = r.clone();
          caches.open(V).then(c => c.put("./index.html", copy));
          return r;
        })
        .catch(() => caches.match("./index.html").then(r => r || caches.match("./")))
    );
    return;
  }

  /* الأصول الثابتة: الذاكرة أولًا */
  e.respondWith(
    caches.match(req).then(hit =>
      hit || fetch(req).then(r => {
        if (r && r.status === 200 && r.type === "basic") {
          const copy = r.clone();
          caches.open(V).then(c => c.put(req, copy));
        }
        return r;
      }).catch(() => hit)
    )
  );
});
