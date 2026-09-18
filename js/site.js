/* [Your Name] — portfolio site behaviour.
   The phone menu, the album archive on work.html, and the album page with its
   frame viewer. Album data lives in js/albums.js. No build step, no
   dependencies. */

(function () {
  "use strict";

  /* --- Phone menu ------------------------------------------------------- */

  var toggle = document.querySelector(".nav-toggle");
  var nav = document.getElementById("site-nav");

  if (toggle && nav) {
    toggle.addEventListener("click", function () {
      var open = nav.getAttribute("data-open") === "true";
      nav.setAttribute("data-open", String(!open));
      toggle.setAttribute("aria-expanded", String(!open));
      toggle.setAttribute("aria-label", open ? "Open menu" : "Close menu");
    });

    // Close it again when the layout grows past the phone breakpoint,
    // otherwise the panel can be left stuck open.
    var wide = window.matchMedia("(min-width: 52rem)");
    var reset = function (e) {
      if (e.matches) {
        nav.setAttribute("data-open", "false");
        toggle.setAttribute("aria-expanded", "false");
        toggle.setAttribute("aria-label", "Open menu");
      }
    };
    if (wide.addEventListener) {
      wide.addEventListener("change", reset);
    } else if (wide.addListener) {
      wide.addListener(reset);
    }
  }

  /* --- Shared bits ------------------------------------------------------ */

  var SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  var LONG  = ["January", "February", "March", "April", "May", "June",
               "July", "August", "September", "October", "November", "December"];

  function el(tag, className, text) {
    var node = document.createElement(tag);
    if (className) { node.className = className; }
    if (text != null) { node.textContent = text; }
    return node;
  }

  function each(list, fn) { Array.prototype.forEach.call(list, fn); }

  // Newest first. Dates are ISO, so a string compare is a date compare.
  // Frame lists come from js/photos.js, which build-photos.bat generates from
  // whatever is actually in the photos/ folder.
  function albums() {
    var frames = window.ALBUM_PHOTOS || {};

    return (window.ALBUMS || []).slice().map(function (album) {
      album.photos = frames[album.dir] || [];
      return album;
    }).sort(function (a, b) {
      return a.date < b.date ? 1 : a.date > b.date ? -1 : 0;
    });
  }

  // Folder and file names hold spaces and dots, so every segment is encoded.
  function photoSrc(album, name) {
    var dir = album.dir.split("/").map(encodeURIComponent).join("/");
    return dir + "/" + encodeURIComponent(name);
  }

  function hasFrames(album) {
    return Boolean(album.dir) && album.photos.length > 0;
  }

  function shortDate(iso) {
    var p = iso.split("-");
    return Number(p[2]) + " " + SHORT[Number(p[1]) - 1];
  }

  function longDate(iso) {
    var p = iso.split("-");
    return Number(p[2]) + " " + LONG[Number(p[1]) - 1] + " " + p[0];
  }

  function count(n, one, many) {
    return n + " " + (n === 1 ? one : many);
  }

  /* --- The archive (work.html) ------------------------------------------ */

  var archive = document.getElementById("archive");
  if (archive) { buildArchive(archive); }

  function buildArchive(root) {
    var all = albums();
    var filterRow = document.getElementById("album-filters");
    var status = document.getElementById("archive-status");
    var empty = document.getElementById("archive-empty");
    var buttons = [];

    var years = [];
    var byYear = {};
    each(all, function (album) {
      var year = album.date.slice(0, 4);
      if (!byYear[year]) { byYear[year] = []; years.push(year); }
      byYear[year].push(album);
    });

    each(years, function (year) {
      var section = el("section", "year");
      var head = el("h2", "year__head");
      head.appendChild(el("span", "year__num", year));
      head.appendChild(el("span", "year__count"));
      section.appendChild(head);

      var grid = el("div", "grid grid--albums");
      each(byYear[year], function (album) { grid.appendChild(card(album)); });
      section.appendChild(grid);
      root.appendChild(section);
    });

    if (filterRow) {
      var sports = [];
      each(all, function (album) {
        if (album.sport && sports.indexOf(album.sport) < 0) { sports.push(album.sport); }
      });
      sports.sort();

      buttons.push(filterButton("all", "All games"));
      each(sports, function (sport) { buttons.push(filterButton(sport, sport)); });
      each(buttons, function (button) { filterRow.appendChild(button); });
    }

    function filterButton(value, label) {
      var button = el("button", "filter", label);
      button.type = "button";
      button.setAttribute("data-filter", value);
      button.setAttribute("aria-pressed", "false");
      button.addEventListener("click", function () { apply(value); });
      return button;
    }

    function apply(wanted) {
      var shown = 0;

      each(root.querySelectorAll(".year"), function (section) {
        var inYear = 0;

        each(section.querySelectorAll(".album"), function (node) {
          var match = wanted === "all" || node.getAttribute("data-sport") === wanted;
          node.classList.toggle("is-hidden", !match);
          if (match) { inYear += 1; }
        });

        section.classList.toggle("is-hidden", inYear === 0);
        section.querySelector(".year__count").textContent = count(inYear, "game", "games");
        shown += inYear;
      });

      each(buttons, function (button) {
        button.setAttribute("aria-pressed", String(button.getAttribute("data-filter") === wanted));
      });

      if (empty) { empty.hidden = shown > 0; }
      if (status) { status.textContent = count(shown, "album", "albums") + " shown."; }
    }

    apply("all");
  }

  function card(album) {
    var live = hasFrames(album);
    var node = document.createElement(live ? "a" : "div");

    node.className = live ? "album" : "album album--empty";
    node.setAttribute("data-sport", album.sport || "");
    if (live) { node.href = "album.html?album=" + encodeURIComponent(album.slug); }

    var cover = el("div", "frame album__cover");
    if (live) {
      var img = el("img");
      img.src = photoSrc(album, album.cover || album.photos[0]);
      img.alt = "";
      img.setAttribute("loading", "lazy");
      cover.appendChild(img);
    } else {
      cover.appendChild(el("div", "frame__ph", "[Cover frame]"));
    }
    node.appendChild(cover);

    var meta = el("div", "album__meta");
    meta.appendChild(el("p", "album__date", shortDate(album.date)));
    meta.appendChild(el("h3", "album__title", album.title));
    meta.appendChild(el("p", "album__detail",
      album.sport + " — " + (live ? count(album.photos.length, "frame", "frames") : "frames to come")));
    node.appendChild(meta);

    return node;
  }

  /* --- One album (album.html) ------------------------------------------- */

  var grid = document.getElementById("album-grid");
  if (grid) { buildAlbum(grid); }

  function buildAlbum(grid) {
    var all = albums();
    var match = /[?&]album=([^&]*)/.exec(window.location.search);
    var slug = match ? decodeURIComponent(match[1]) : "";

    var index = -1;
    each(all, function (album, i) { if (album.slug === slug) { index = i; } });

    var body = document.getElementById("album-body");
    var missing = document.getElementById("album-missing");

    if (index < 0 || !hasFrames(all[index])) {
      if (body) { body.hidden = true; }
      if (missing) { missing.hidden = false; }
      return;
    }

    var album = all[index];

    document.title = album.title + ", " + longDate(album.date) + " — [Your Name]";
    text("album-title", album.title);
    text("album-sport", album.sport);
    text("album-date", longDate(album.date));
    text("album-venue", album.venue);
    text("album-note", album.note);
    text("album-count", count(album.photos.length, "frame", "frames"));

    each(album.photos, function (name, i) {
      var button = el("button", "shot");
      button.type = "button";
      button.setAttribute("aria-label", "Open frame " + (i + 1) + " full size");

      var img = el("img");
      img.src = photoSrc(album, name);
      img.alt = album.title + ", " + longDate(album.date) + " — frame " + (i + 1);
      img.setAttribute("loading", "lazy");
      img.setAttribute("decoding", "async");

      button.appendChild(img);
      button.addEventListener("click", function () { openViewer(album, i); });
      grid.appendChild(button);
    });

    // Sorted newest first, so the entry before this one is the newer game.
    link("album-newer", all[index - 1]);
    link("album-older", all[index + 1]);
  }

  function text(id, value) {
    var node = document.getElementById(id);
    if (node) { node.textContent = value || ""; }
  }

  function link(id, album) {
    var node = document.getElementById(id);
    if (!node) { return; }

    if (!album || !hasFrames(album)) {
      node.hidden = true;
      return;
    }

    node.href = "album.html?album=" + encodeURIComponent(album.slug);
    node.querySelector(".album-nav__title").textContent = album.title;
    node.querySelector(".album-nav__date").textContent = longDate(album.date);
  }

  /* --- Frame viewer ----------------------------------------------------- */

  function openViewer(album, start) {
    var box = document.getElementById("lightbox");
    if (!box) { return; }

    var image = document.getElementById("lightbox-img");
    var label = document.getElementById("lightbox-count");
    var close = document.getElementById("lightbox-close");
    var prev = document.getElementById("lightbox-prev");
    var next = document.getElementById("lightbox-next");
    var opener = document.activeElement;
    var at = start;

    var goPrev = function () { go(-1); };
    var goNext = function () { go(1); };

    show(at);
    box.hidden = false;
    document.body.style.overflow = "hidden";
    close.focus();

    document.addEventListener("keydown", onKey);
    close.addEventListener("click", shut);
    prev.addEventListener("click", goPrev);
    next.addEventListener("click", goNext);
    box.addEventListener("click", onBackdrop);

    function show(i) {
      image.src = photoSrc(album, album.photos[i]);
      image.alt = album.title + " — frame " + (i + 1);
      label.textContent = (i + 1) + " / " + album.photos.length;
    }

    function go(by) {
      at = (at + by + album.photos.length) % album.photos.length;
      show(at);
    }

    function onKey(e) {
      if (e.key === "Escape") { shut(); }
      else if (e.key === "ArrowLeft") { go(-1); }
      else if (e.key === "ArrowRight") { go(1); }
    }

    function onBackdrop(e) {
      if (e.target === box) { shut(); }
    }

    function shut() {
      box.hidden = true;
      image.removeAttribute("src");
      document.body.style.overflow = "";

      document.removeEventListener("keydown", onKey);
      close.removeEventListener("click", shut);
      prev.removeEventListener("click", goPrev);
      next.removeEventListener("click", goNext);
      box.removeEventListener("click", onBackdrop);

      if (opener && opener.focus) { opener.focus(); }
    }
  }
})();
