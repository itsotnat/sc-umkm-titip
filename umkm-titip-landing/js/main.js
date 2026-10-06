/* KONFIGURASI
   APK_URL  : alamat unduhan APK, misal "/unduh/umkm-titip.apk" atau tautan Google Drive.
              Dikosongkan = tombol Unduh APK nonaktif dan tampil "APK segera hadir".
   KODE_URL : tautan kode program (Google Drive). Dikosongkan = tautan di footer disembunyikan. */
var APK_URL = "";
var KODE_URL = "";
document.querySelectorAll("[data-apk]").forEach(function(a) {
  if (APK_URL) {
    a.href = APK_URL
  } else {
    a.removeAttribute("href");
    a.classList.add("off");
    a.setAttribute("aria-disabled", "true");
    a.title = "APK segera hadir"
  }
});
document.querySelectorAll("[data-soon]").forEach(function(p) {
  p.hidden = !!APK_URL
});
document.querySelectorAll("[data-kode]").forEach(function(a) {
  if (KODE_URL) {
    a.href = KODE_URL;
    a.hidden = false
  }
});
/* Tahun footer otomatis */
document.getElementById("y").textContent = new Date().getFullYear();
/* PEMBELAH KATA (dipakai animasi 2 dan 6) */
function split(el) {
  el.innerHTML = el.textContent.trim().split(/\s+/).map(function(w, i) {
    return '<span class="w" style="--i:' + i + '">' + w + '</span>'
  }).join(" ")
}
var h1 = document.getElementById("h1"),
  st = document.getElementById("stmt");
split(h1);
split(st);
var ws = st.children;
/* ANIMASI 6 - KATA MENYALA SAAT SCROLL*/
function sc() {
  var r = st.getBoundingClientRect(),
    h = innerHeight,
    p = Math.min(1, Math.max(0, (h * .85 - r.top) / (r.height + h * .3))),
    n = Math.round(p * ws.length);
  for (var i = 0; i < ws.length; i++) ws[i].classList.toggle("on", i < n)
}
addEventListener("scroll", sc, {
  passive: true
});
sc();
/* ANIMASI 7 - LANGKAH CARA KERJA*/
var chs = [].slice.call(document.querySelectorAll(".ch")),
  scr = [].slice.call(document.querySelectorAll(".stick img"));
var io = new IntersectionObserver(function(es) {
  es.forEach(function(e) {
    if (e.isIntersecting) {
      var i = chs.indexOf(e.target);
      chs.forEach(function(c) {
        c.classList.toggle("on", c === e.target)
      });
      scr.forEach(function(s, k) {
        s.classList.toggle("on", k === i)
      })
    }
  })
}, {
  rootMargin: "-45% 0px -45% 0px"
});
chs.forEach(function(c) {
  io.observe(c)
});
/* ANIMASI 8 - MUNCUL SAAT SCROLL*/
var rv = new IntersectionObserver(function(es) {
  es.forEach(function(e) {
    if (e.isIntersecting) {
      e.target.classList.add("in");
      rv.unobserve(e.target)
    }
  })
}, {
  threshold: .2
});
document.querySelectorAll(".rv").forEach(function(el, i) {
  el.style.transitionDelay = (i % 3) * 90 + "ms";
  rv.observe(el)
});
/* ANIMASI 9 - SOROTAN KARTU */
document.querySelectorAll(".fc").forEach(function(c) {
  c.addEventListener("pointermove", function(e) {
    var r = c.getBoundingClientRect();
    c.style.setProperty("--mx", e.clientX - r.left + "px");
    c.style.setProperty("--my", e.clientY - r.top + "px")
  })
});
/* ANIMASI 3 - MIRING 3D PONSEL HERO */
if (matchMedia("(pointer:fine)").matches) {
  var tl = document.getElementById("tilt");
  document.getElementById("atas").addEventListener("pointermove", function(e) {
    tl.style.setProperty("--ry", ((e.clientX / innerWidth - .5) * 16) + "deg");
    tl.style.setProperty("--rx", (-(e.clientY / innerHeight - .5) * 10) + "deg")
  })
}
/* TOMBOL TEMA TERANG/GELAP */
(function() {
  var r = document.documentElement,
    b = document.getElementById("tgl");

  function cur() {
    return r.dataset.theme || (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
  }

  function ic() {
    var d = cur() === "dark";
    b.textContent = d ? "\u2600\uFE0F" : "\uD83C\uDF19";
    b.setAttribute("aria-label", d ? "Ganti ke mode terang" : "Ganti ke mode gelap")
  }
  try {
    var t = localStorage.getItem("theme");
    if (t) r.dataset.theme = t
  } catch (e) {}
  ic();
  b.addEventListener("click", function() {
    var n = cur() === "dark" ? "light" : "dark";
    r.dataset.theme = n;
    try {
      localStorage.setItem("theme", n)
    } catch (e) {}
    ic()
  })
})();