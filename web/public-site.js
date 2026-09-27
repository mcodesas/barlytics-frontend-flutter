(function () {
  'use strict';

  const endpoint = '/api/v1/parametros/public/site';
  const localEndpoint = `${window.location.protocol}//${window.location.hostname}:8282${endpoint}`;
  const endpointCandidates = window.location.port && !['80', '443'].includes(window.location.port)
    ? [endpoint, localEndpoint]
    : [endpoint];
  const publicPaths = new Set([
    '/software-para-bares/',
    '/funcionalidades/',
    '/planes/',
    '/contacto/',
    '/descargas/',
    '/preguntas-frecuentes/',
  ]);
  const pageCache = new Map();
  let publicConfig = null;
  let configPromise = null;
  let navigationController = null;

  const normalizePath = (path) => path.endsWith('/') ? path : `${path}/`;
  const unwrap = (payload) => payload?.data?.data || payload?.data || payload || {};
  const digits = (value) => String(value || '').replace(/\D/g, '');
  const internationalDigits = (value) => {
    const number = digits(value);
    return number.length === 10 && number.startsWith('3') ? `57${number}` : number;
  };
  const displayPhone = (value) => {
    const number = digits(value);
    if (number.length === 12 && number.startsWith('57')) {
      return `+57 ${number.slice(2, 5)} ${number.slice(5, 8)} ${number.slice(8)}`;
    }
    if (number.length === 10) return `${number.slice(0, 3)} ${number.slice(3, 6)} ${number.slice(6)}`;
    return value || 'No configurado';
  };

  const requestConfig = () => {
    if (configPromise) return configPromise;
    configPromise = (async () => {
      let lastError;
      for (const url of endpointCandidates) {
        try {
          const response = await fetch(url, { headers: { Accept: 'application/json' } });
          if (!response.ok) throw new Error(`HTTP ${response.status}`);
          publicConfig = unwrap(await response.json());
          return publicConfig;
        } catch (error) {
          lastError = error;
        }
      }
      publicConfig = {};
      throw lastError || new Error('Configuración pública no disponible');
    })();
    return configPromise;
  };

  const setContact = (root, selector, value, protocol) => {
    root.querySelectorAll(selector).forEach((element) => {
      const number = internationalDigits(value);
      element.textContent = displayPhone(value);
      if (element.tagName !== 'A') return;
      if (!number) {
        element.removeAttribute('href');
        element.setAttribute('aria-disabled', 'true');
        return;
      }
      element.href = protocol === 'tel'
        ? `tel:+${number}`
        : `https://wa.me/${number}?text=${encodeURIComponent('Hola, quiero conocer más sobre BarLytics para mi negocio.')}`;
      element.removeAttribute('aria-disabled');
    });
  };

  const applyDownloads = (root, config) => {
    const storeKeys = {
      android: 'androidDownloadUrl',
      ios: 'iosDownloadUrl',
    };

    root.querySelectorAll('[data-download-platform]').forEach((card) => {
      const platform = String(card.getAttribute('data-download-platform') || '').toLowerCase();
      const button = card.querySelector('[data-download-action]');
      const status = card.querySelector('[data-download-status]');
      if (!button) return;

      if (platform === 'android' || platform === 'ios') {
        const url = String(config[storeKeys[platform]] || '').trim();
        card.classList.toggle('available', Boolean(url));
        if (status) status.textContent = url ? 'DISPONIBLE' : 'PRÓXIMAMENTE';
        button.textContent = url
          ? (platform === 'android' ? 'Abrir Play Store' : 'Abrir App Store')
          : 'Próximamente';
        button.classList.toggle('disabled', !url);
        if (url) {
          button.href = url;
          button.target = '_blank';
          button.rel = 'noopener noreferrer';
          button.removeAttribute('aria-disabled');
        } else {
          button.removeAttribute('href');
          button.setAttribute('aria-disabled', 'true');
        }
        return;
      }

      if (!['windows', 'macos', 'linux'].includes(platform)) return;
      card.classList.add('available');
      if (status) status.textContent = 'DISPONIBLE';
      button.textContent = 'Continuar';
      button.classList.remove('disabled');
      button.href = `/descargas/${platform}/`;
      button.removeAttribute('target');
      button.removeAttribute('rel');
      button.removeAttribute('aria-disabled');
    });
  };

  const updateConfiguredContent = (root = document) => {
    const apply = (config) => {
      setContact(root, '[data-public-phone]', config.phone, 'tel');
      setContact(root, '[data-public-whatsapp]', config.whatsapp, 'https');
      applyDownloads(root, config);
    };
    if (publicConfig) {
      apply(publicConfig);
      return;
    }
    requestConfig().then(apply).catch(() => apply({}));
  };

  const deviceLabel = (device) => ({ desktop: 'Escritorio', tablet: 'Tablet', phone: 'Celular' })[device] || 'Escritorio';

  const setupFeatureExplorer = (explorer) => {
    if (explorer.dataset.ready === 'true') return;
    explorer.dataset.ready = 'true';
    const moduleButtons = [...explorer.querySelectorAll('[data-feature-module]')];
    const deviceButtons = [...explorer.querySelectorAll('[data-feature-device]')];
    const shell = explorer.querySelector('[data-device-shell]');
    const image = explorer.querySelector('[data-feature-image]');
    const placeholder = explorer.querySelector('[data-feature-placeholder]');
    const title = explorer.querySelector('[data-feature-title]');
    const description = explorer.querySelector('[data-feature-description]');
    const highlights = explorer.querySelector('[data-feature-highlights]');
    const deviceName = explorer.querySelector('[data-feature-device-name]');
    const path = explorer.querySelector('[data-feature-path]');
    let activeModule = moduleButtons[0];
    let activeDevice = 'desktop';

    const render = (replay = false) => {
      if (!activeModule || !shell || !image) return;
      const slug = activeModule.dataset.slug;
      const label = activeModule.dataset.label;
      const gifPath = `/demos/${activeDevice}/${slug}.gif`;
      moduleButtons.forEach((button) => {
        const selected = button === activeModule;
        button.classList.toggle('active', selected);
        button.setAttribute('aria-selected', String(selected));
        button.tabIndex = selected ? 0 : -1;
      });
      deviceButtons.forEach((button) => {
        const selected = button.dataset.featureDevice === activeDevice;
        button.classList.toggle('active', selected);
        button.setAttribute('aria-pressed', String(selected));
      });
      shell.dataset.device = activeDevice;
      if (title) title.textContent = activeModule.dataset.title || label;
      if (description) description.textContent = activeModule.dataset.description || '';
      if (deviceName) deviceName.textContent = deviceLabel(activeDevice);
      if (path) path.textContent = `web${gifPath}`;
      if (highlights) {
        highlights.replaceChildren(...String(activeModule.dataset.highlights || '')
          .split('|')
          .filter(Boolean)
          .map((value) => {
            const chip = document.createElement('span');
            chip.textContent = value;
            return chip;
          }));
      }
      shell.classList.remove('media-loaded');
      if (placeholder) placeholder.hidden = false;
      image.alt = `${label} en BarLytics para ${deviceLabel(activeDevice).toLowerCase()}`;
      image.onload = () => {
        shell.classList.add('media-loaded');
        if (placeholder) placeholder.hidden = true;
      };
      image.onerror = () => {
        shell.classList.remove('media-loaded');
        if (placeholder) placeholder.hidden = false;
      };
      image.src = replay ? `${gifPath}?replay=${Date.now()}` : gifPath;
    };

    moduleButtons.forEach((button) => button.addEventListener('click', () => {
      activeModule = button;
      render();
    }));
    deviceButtons.forEach((button) => button.addEventListener('click', () => {
      activeDevice = button.dataset.featureDevice || 'desktop';
      render();
    }));
    explorer.querySelector('[data-feature-replay]')?.addEventListener('click', () => render(true));
    render();
  };

  const setupLegacyDemoMedia = (root) => {
    root.querySelectorAll('[data-demo-gif]').forEach((frame) => {
      if (frame.dataset.ready === 'true') return;
      frame.dataset.ready = 'true';
      const device = frame.getAttribute('data-device') || 'desktop';
      const slug = frame.getAttribute('data-demo-gif');
      const image = frame.querySelector('img');
      const placeholder = frame.querySelector('[data-demo-placeholder]');
      if (!image || !slug) return;
      image.addEventListener('load', () => {
        frame.classList.add('loaded');
        if (placeholder) placeholder.hidden = true;
      });
      image.addEventListener('error', () => {
        frame.classList.remove('loaded');
        if (placeholder) placeholder.hidden = false;
      });
      image.src = `/demos/${device}/${slug}.gif`;
    });
  };

  const initializePage = (root = document) => {
    root.querySelectorAll('[data-feature-explorer]').forEach(setupFeatureExplorer);
    setupLegacyDemoMedia(root);
    updateConfiguredContent(root);
    window.BarLyticsPublicPlans?.init(root);
  };

  const copyHead = (nextDocument) => {
    document.title = nextDocument.title;
    const selectors = [
      'meta[name="description"]',
      'meta[name="robots"]',
      'meta[property="og:title"]',
      'meta[property="og:description"]',
      'meta[property="og:url"]',
      'link[rel="canonical"]',
      'link[rel="alternate"][hreflang="es-CO"]',
    ];
    selectors.forEach((selector) => {
      const current = document.head.querySelector(selector);
      const next = nextDocument.head.querySelector(selector);
      if (current && next) current.replaceWith(next.cloneNode(true));
    });
    document.head.querySelectorAll('script[type="application/ld+json"]').forEach((node) => node.remove());
    nextDocument.head.querySelectorAll('script[type="application/ld+json"]').forEach((node) => {
      document.head.append(node.cloneNode(true));
    });
  };

  const scrollForUrl = (url) => {
    if (url.hash) {
      requestAnimationFrame(() => document.querySelector(url.hash)?.scrollIntoView({ behavior: 'smooth', block: 'start' }));
    } else {
      window.scrollTo({ top: 0, left: 0, behavior: 'auto' });
    }
  };

  const navigate = async (url, push = true) => {
    const path = normalizePath(url.pathname);
    if (!publicPaths.has(path)) {
      document.body.classList.add('page-exiting');
      window.setTimeout(() => window.location.assign(url.href), 120);
      return;
    }

    navigationController?.abort();
    navigationController = new AbortController();
    document.body.classList.add('page-is-loading');
    document.documentElement.setAttribute('aria-busy', 'true');
    try {
      let html = pageCache.get(url.pathname);
      if (!html) {
        const response = await fetch(url.pathname, {
          signal: navigationController.signal,
          headers: { Accept: 'text/html', 'X-BarLytics-Navigation': 'partial' },
        });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        html = await response.text();
        pageCache.set(url.pathname, html);
      }
      const nextDocument = new DOMParser().parseFromString(html, 'text/html');
      const nextMain = nextDocument.querySelector('main');
      const currentMain = document.querySelector('main');
      if (!nextMain || !currentMain) throw new Error('La página no contiene la región principal.');

      const apply = () => {
        copyHead(nextDocument);
        currentMain.replaceWith(nextMain);
        if (push) history.pushState({ publicPage: true }, '', url.href);
        window.BarLyticsPublicShell?.sync(url);
        initializePage(nextMain);
        document.dispatchEvent(new CustomEvent('barlytics:page-ready', { detail: { url: url.href } }));
        scrollForUrl(url);
      };

      if (document.startViewTransition) {
        const transition = document.startViewTransition(apply);
        await transition.finished;
      } else {
        apply();
      }
    } catch (error) {
      if (error.name !== 'AbortError') window.location.assign(url.href);
    } finally {
      document.body.classList.remove('page-is-loading');
      document.documentElement.removeAttribute('aria-busy');
    }
  };

  const setupNavigation = () => {
    document.addEventListener('click', (event) => {
      if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      const target = event.target instanceof Element ? event.target : null;
      const anchor = target?.closest('a[href]');
      if (!anchor || anchor.target || anchor.hasAttribute('download')) return;
      const rawHref = anchor.getAttribute('href');
      if (!rawHref || rawHref.startsWith('mailto:') || rawHref.startsWith('tel:') || rawHref.startsWith('javascript:')) return;
      const url = new URL(anchor.href, window.location.href);
      if (url.origin !== window.location.origin) return;
      if (url.pathname === window.location.pathname && url.search === window.location.search && url.hash) return;
      event.preventDefault();
      navigate(url);
    });
    window.addEventListener('popstate', () => navigate(new URL(window.location.href), false));
    window.addEventListener('pageshow', () => document.body.classList.remove('page-exiting'));
  };

  const lockZoom = () => {
    const stop = (event) => event.preventDefault();
    ['gesturestart', 'gesturechange', 'gestureend'].forEach((type) => {
      document.addEventListener(type, stop, { passive: false });
    });
    document.addEventListener('wheel', (event) => {
      if (event.ctrlKey || event.metaKey) event.preventDefault();
    }, { passive: false });
    document.addEventListener('keydown', (event) => {
      if ((event.ctrlKey || event.metaKey) && ['+', '-', '=', '0'].includes(event.key)) event.preventDefault();
    });
  };

  setupNavigation();
  lockZoom();
  initializePage();

  window.BarLyticsPublicSite = { initializePage, navigate };
})();
