/* Pantalla de carga de eventos públicos; no modifica otras rutas de BarLytics. */
(() => {
  'use strict';

  const loader = document.getElementById('barlytics-loader');
  if (!loader) return;

  // GoRouter utiliza /#/evento/slug en web; admitir también rutas sin hash.
  const rawRoute = location.hash.startsWith('#/')
    ? location.hash.slice(1) : location.pathname;
  const route = rawRoute.split('?')[0]; // Soporta enlaces con parámetros UTM.
  const match = /^\/evento\/([^/?#]+)\/?$/.exec(route);
  if (!match) return; // No aplicar el tema de un evento a login ni al SaaS.

  let slug;
  try { slug = decodeURIComponent(match[1]); } catch (_) { return; }
  // Evitar URLs arbitrarias y rutas de entradas privadas.
  if (!/^[a-z0-9_-]{1,180}$/i.test(slug)) return;

  loader.classList.add('barlytics-loader--event');
  loader.setAttribute('aria-label', 'Cargando evento');
  const name = loader.querySelector('.barlytics-loader__event-venue');
  const title = loader.querySelector('.barlytics-loader__event-title');
  const logo = loader.querySelector('.barlytics-loader__event-logo');
  const status = loader.querySelector('.barlytics-loader__status');
  if (status) status.textContent = 'Preparando tu experiencia…';

  const validColor = (raw, fallback) =>
    typeof raw === 'string' && /^#[a-f0-9]{6}$/i.test(raw.trim())
      ? raw.trim() : fallback;
  const channel = (value) =>
    value <= .04045 ? value / 12.92 : Math.pow((value + .055) / 1.055, 2.4);
  const luminance = (hex) => {
    const value = parseInt(hex.slice(1), 16);
    const r = channel(((value >> 16) & 255) / 255);
    const g = channel(((value >> 8) & 255) / 255);
    const b = channel((value & 255) / 255);
    return .2126 * r + .7152 * g + .0722 * b;
  };
  const isLight = (hex) => luminance(hex) > .38;
  const contrast = (a, b) => {
    const x = luminance(a) + .05, y = luminance(b) + .05;
    return Math.max(x, y) / Math.min(x, y);
  };
  const validImage = (raw) => {
    if (typeof raw !== 'string') return null;
    const src = raw.trim();
    if (/^data:image\/(?:png|jpeg|jpg|gif|webp);base64,[a-z0-9+/=\r\n]+$/i.test(src)) {
      return src;
    }
    try {
      const url = new URL(src, location.origin);
      return url.protocol === 'https:' && (src.startsWith('https://') ||
        src.startsWith('/')) ? url.toString() : null;
    } catch (_) { return null; }
  };

  const apply = (data) => {
    if (!data || typeof data !== 'object' || loader.classList.contains('barlytics-loader--hidden')) return;
    const background = validColor(data.colorFondo, '#102735');
    const accent = validColor(data.colorPrimario, '#35D0C5');
    const selectedText = validColor(data.colorTexto, isLight(background)
      ? '#211B18' : '#F2FBFF');
    // Las combinaciones personalizadas pueden ser ilegibles. Igual que
    // EventPagePalette.readable, privilegiar contraste suficiente.
    const ink = contrast('#000000', background) >=
      contrast('#FFFFFF', background) ? '#000000' : '#FFFFFF';
    const foreground = contrast(selectedText, background) >= 4.5
      ? selectedText : ink;
    loader.style.setProperty('--event-loader-bg', background);
    loader.style.setProperty('--event-loader-accent', accent);
    loader.style.setProperty('--event-loader-ink', foreground);
    loader.style.setProperty('--event-loader-muted', ink);
    const scheme = isLight(background) ? 'light' : 'dark';
    loader.style.colorScheme = scheme;
    document.documentElement.style.setProperty('color-scheme', scheme);
    document.body.style.setProperty('color-scheme', scheme);

    document.documentElement.style.setProperty('background-color', background, 'important');
    document.body.style.setProperty('background-color', background, 'important');
    document.querySelectorAll('meta[name="theme-color"]').forEach((element) => {
      element.setAttribute('content', background);
    });

    if (name && typeof data.sucursal === 'string') {
      name.textContent = data.sucursal.trim() || 'Tu evento';
    }
    if (title && typeof data.titulo === 'string') {
      title.textContent = data.titulo.trim() || 'Preparando tu experiencia';
    }
    const source = validImage(data.fotoSucursal) || validImage(data.logo);
    if (logo && source) {
      logo.onload = () => { logo.style.display = 'block'; };
      logo.onerror = () => { logo.style.display = 'none'; };
      logo.src = source;
    }
  };

  // El API ya dispone de información pública de identidad/colores.
  // Consulta en paralelo al arranque de Flutter: un error no bloquea la web.
  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), 5500);
  fetch('/api/v1/eventos/public/' + encodeURIComponent(slug), {
    credentials: 'same-origin',
    signal: controller.signal,
    cache: 'no-store',
    headers: { 'Accept': 'application/json' },
  }).then((response) => {
    if (!response.ok) throw new Error('Evento no disponible');
    return response.json();
  }).then(apply).catch(() => {
    // Se conserva la pantalla neutral; Flutter mostrará el error real.
  }).finally(() => {
    window.clearTimeout(timeout);
    // La pantalla HTML solo se oculta cuando el tema y Flutter estén listos.
    // También se dispara en error: el usuario nunca queda bloqueado.
    window.dispatchEvent(new Event('barlytics-event-brand-ready'));
  });
})();
