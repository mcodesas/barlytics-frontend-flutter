(() => {
  'use strict';

  const THEME = '#061723';
  const ICONS = {
    home: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 11.5 12 4l9 7.5"/><path d="M5.5 10.5V20h13v-9.5"/><path d="M9.5 20v-6h5v6"/></svg>',
    tables: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4" y="6" width="16" height="9" rx="2"/><path d="M7 15v5M17 15v5M4 10h16"/></svg>',
    bolt: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m13 2-8 12h6l-1 8 9-13h-6z"/></svg>',
    receipt: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 3h12v18l-3-2-3 2-3-2-3 2z"/><path d="M9 8h6M9 12h6M9 16h4"/></svg>',
    card: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 10h18M7 15h4"/></svg>',
    history: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 12a8 8 0 1 0 2.3-5.7L4 8.5"/><path d="M4 4v4.5h4.5M12 8v5l3 2"/></svg>',
    box: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m4 7 8-4 8 4-8 4z"/><path d="M4 7v10l8 4 8-4V7M12 11v10"/></svg>',
    tag: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20 13 11 22l-9-9V4h9z"/><circle cx="7.5" cy="9.5" r="1.5"/></svg>',
    inventory: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 5h16v15H4zM8 5V2h8v3M8 10h8M8 14h8"/></svg>',
    swap: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h14M15 4l3 3-3 3M20 17H6M9 14l-3 3 3 3"/></svg>',
    chart: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/></svg>',
    users: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="9" cy="8" r="3"/><circle cx="17" cy="9" r="2.5"/><path d="M3 20c.4-4 2.4-6 6-6s5.6 2 6 6M15 14c3.3.1 5.2 2.1 5.5 5"/></svg>',
    desktop: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8M12 17v4"/></svg>',
    tablet: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="5" y="2" width="14" height="20" rx="2"/><path d="M11 18h2"/></svg>',
    phone: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="7" y="2" width="10" height="20" rx="2"/><path d="M11 18h2"/></svg>'
  };
  const PUBLIC_ROUTES = new Set([
    '/software-para-bares/', '/funcionalidades/', '/nosotros/', '/planes/', '/descargas/', '/contacto/', '/preguntas-frecuentes/', '/documentacion/', '/privacidad/', '/terminos/'
  ]);

  const FEATURES = [
    {slug:'inicio', name:'Inicio e indicadores', icon:ICONS.home, description:'Empieza la jornada con una vista rápida del estado del negocio. Reúne indicadores operativos y accesos directos para que puedas identificar qué necesita atención sin recorrer módulo por módulo.', benefits:['Resumen del día','Indicadores operativos','Accesos rápidos'], outcome:'Entender cómo va la operación desde el primer vistazo.'},
    {slug:'mesas', name:'Mesas y zonas', icon:ICONS.tables, description:'Organiza la atención por mesas y zonas, identifica cuáles están libres u ocupadas y entra directamente a la venta activa. El equipo puede continuar el servicio sin perder el contexto de cada consumo.', benefits:['Estado de mesas','Atención por zona','Venta activa por mesa'], outcome:'Atender más rápido y reducir confusiones entre cuentas.'},
    {slug:'venta-rapida', name:'Venta directa', icon:ICONS.bolt, description:'Registra ventas de mostrador o consumos que no necesitan una mesa. Usa el mismo catálogo, precios y flujo de cobro para mantener toda la operación consolidada.', benefits:['Venta sin mesa','Catálogo unificado','Cobro inmediato'], outcome:'Despachar operaciones rápidas sin crear pasos innecesarios.'},
    {slug:'cuenta', name:'Cuentas', icon:ICONS.receipt, description:'Consulta los productos consumidos, cantidades, subtotales, pagos y saldo pendiente de cada cuenta. Permite mantener claridad sobre lo que se ha servido y lo que todavía falta por cobrar.', benefits:['Detalle del consumo','Saldo pendiente','Propina y pagos'], outcome:'Tener una cuenta clara antes de cobrar al cliente.'},
    {slug:'cobro', name:'Cobros', icon:ICONS.card, description:'Cobra con los medios de pago configurados, registra efectivo recibido y calcula el cambio. El recaudo queda asociado a la cuenta para conservar trazabilidad de cómo se pagó cada venta.', benefits:['Múltiples medios','Efectivo y cambio','Trazabilidad del pago'], outcome:'Cobrar con agilidad y reducir errores al recibir dinero.'},
    {slug:'historial-ventas', name:'Historial de ventas', icon:ICONS.history, description:'Consulta ventas anteriores y revisa la información asociada a cada operación. Sirve para seguimiento, aclaraciones, control interno y análisis de periodos anteriores.', benefits:['Consulta histórica','Filtros por fecha','Detalle de ventas'], outcome:'Encontrar rápidamente qué ocurrió en una venta anterior.'},
    {slug:'productos', name:'Productos', icon:ICONS.box, description:'Administra el catálogo que usa cada sucursal: productos, tipos, marcas y datos comerciales. Mantiene ordenada la oferta para que ventas, inventario y reportes trabajen sobre la misma información.', benefits:['Catálogo central','Tipos y marcas','Uso por sucursal'], outcome:'Mantener el catálogo organizado y listo para vender.'},
    {slug:'precios', name:'Precios', icon:ICONS.tag, description:'Gestiona precios de compra y venta por sucursal y conserva el historial de cambios. Esto permite trabajar con valores vigentes y revisar cómo han evolucionado los costos y precios comerciales.', benefits:['Compra y venta','Precio vigente','Historial de cambios'], outcome:'Controlar mejor márgenes y evitar precios desactualizados.'},
    {slug:'inventario', name:'Inventario', icon:ICONS.inventory, description:'Consulta existencias por producto y sucursal, realiza conteos y contrasta lo esperado con lo encontrado. El inventario se alimenta de los movimientos operativos para reflejar mejor la realidad del negocio.', benefits:['Stock por sucursal','Conteo físico','Control de existencias'], outcome:'Saber qué tienes disponible y detectar diferencias a tiempo.'},
    {slug:'movimientos', name:'Movimientos', icon:ICONS.swap, description:'Registra entradas, salidas, compras, ajustes, préstamos y devoluciones con motivo y referencia. Cada movimiento deja trazabilidad sobre por qué cambió la existencia de un producto.', benefits:['Entradas y salidas','Ajustes y préstamos','Devoluciones y compras'], outcome:'Entender por qué cambia el inventario, no solo cuánto queda.'},
    {slug:'reportes', name:'Reportes', icon:ICONS.chart, description:'Analiza ventas, productos, medios de pago, inventario y movimientos desde reportes operativos. Los filtros ayudan a convertir la actividad diaria en información útil para tomar decisiones.', benefits:['Ventas y ganancias','Inventario y rotación','Filtros por periodo'], outcome:'Tomar decisiones con datos del negocio y no solo con percepción.'},
    {slug:'roles', name:'Roles y permisos', icon:ICONS.users, description:'Define qué puede ver y ejecutar cada perfil mediante roles, opciones de menú y permisos. El equipo accede solo a las herramientas necesarias para su responsabilidad.', benefits:['Permisos personalizados','Menús por rol','Separación de funciones'], outcome:'Dar autonomía al equipo sin perder control sobre el sistema.'}
  ];

  const VIDEO_DEMO_SLUGS = {
    desktop: new Set(['inicio','mesas','venta-rapida','cuenta','cobro','inventario','productos','reportes','roles','historial-ventas','precios','movimientos']),
    phone: new Set(['inicio','mesas','venta-rapida','cuenta','cobro','inventario','productos','reportes','roles','historial-ventas','precios','movimientos']),
    tablet: new Set(['inicio','mesas','venta-rapida','cuenta','cobro','inventario','productos','reportes','roles','historial-ventas','precios','movimientos'])
  };
  const demoMediaPath = (deviceKey, slug) => {
    const device = DEVICES[deviceKey];
    if (!device) return '';
    return VIDEO_DEMO_SLUGS[deviceKey]?.has(slug) ? `/demos/${device.dir}/${slug}.mp4` : '';
  };

  // No descargar todas las demostraciones al abrir el sitio.
  // Solo se cargan los videos del módulo visible cuando el usuario
  // llega a la sección y elige el dispositivo.

  const DEVICES = {
    desktop: {label:'Escritorio', dir:'desktop', cls:'desktop', icon:ICONS.desktop},
    tablet: {label:'Tablet', dir:'tablet', cls:'tablet', icon:ICONS.tablet},
    phone: {label:'Celular', dir:'phone', cls:'phone', icon:ICONS.phone}
  };

  const setTheme = () => {
    document.documentElement.style.colorScheme = 'dark';
    document.documentElement.style.backgroundColor = THEME;
    document.body.style.backgroundColor = THEME;
    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.content = THEME;
  };

  const preventZoom = () => {
    if (window.__barlyticsZoomGuard) return;
    window.__barlyticsZoomGuard = true;
    window.addEventListener('keydown', (event) => {
      if ((event.ctrlKey || event.metaKey) && ['+', '-', '=', '0'].includes(event.key)) event.preventDefault();
    }, {passive: false});
    window.addEventListener('wheel', (event) => {
      if (event.ctrlKey || event.metaKey) event.preventDefault();
    }, {passive: false});
    ['gesturestart', 'gesturechange', 'gestureend'].forEach((name) => {
      document.addEventListener(name, (event) => event.preventDefault(), {passive: false});
    });
  };

  let sharedLayoutPromise;

  const loadSharedFragment = async (url) => {
    const response = await fetch(url, {headers: {'Accept': 'text/html'}});
    if (!response.ok) throw new Error(`HTTP ${response.status} al cargar ${url}`);
    return response.text();
  };

  const ensureSharedLayout = () => {
    if (document.querySelector('.site-header') && document.querySelector('.site-footer')) {
      return Promise.resolve();
    }
    if (sharedLayoutPromise) return sharedLayoutPromise;

    sharedLayoutPromise = Promise.all([
      document.querySelector('.site-header') ? Promise.resolve(null) : loadSharedFragment('/public-site/header.html'),
      document.querySelector('.site-footer') ? Promise.resolve(null) : loadSharedFragment('/public-site/footer.html')
    ]).then(([headerHtml, footerHtml]) => {
      const main = document.querySelector('main');
      if (headerHtml && main && !document.querySelector('.site-header')) {
        const template = document.createElement('template');
        template.innerHTML = headerHtml.trim();
        const header = template.content.firstElementChild;
        if (header) main.before(header);
      }
      if (footerHtml && !document.querySelector('.site-footer')) {
        const template = document.createElement('template');
        template.innerHTML = footerHtml.trim();
        const footer = template.content.firstElementChild;
        if (footer) document.body.appendChild(footer);
      }
    }).catch((error) => {
      console.warn('BarLytics: no fue posible cargar el encabezado o pie compartido.', error);
    });

    return sharedLayoutPromise;
  };

  const activeRoute = () => {
    const path = location.pathname.endsWith('/') ? location.pathname : `${location.pathname}/`;
    const activeKey = path === '/' ? 'demo' : ({
      '/nosotros/': 'nosotros',
      '/funcionalidades/': 'funcionalidades',
      '/planes/': 'planes',
      '/descargas/': 'descargas',
      '/contacto/': 'contacto'
    }[path] || '');

    document.querySelectorAll('[data-nav]').forEach((link) => {
      if (link.dataset.nav === activeKey) link.setAttribute('aria-current', 'page');
      else link.removeAttribute('aria-current');
    });
  };

  const initMenu = () => {
    const button = document.querySelector('[data-menu-toggle]');
    const menu = document.querySelector('[data-menu]');
    if (!button || !menu || button.dataset.bound === 'true') return;

    button.dataset.bound = 'true';

    const closeMenu = ({focusButton = false} = {}) => {
      if (!menu.classList.contains('is-open')) return;
      menu.classList.remove('is-open');
      button.setAttribute('aria-expanded', 'false');
      if (focusButton) button.focus({preventScroll: true});
    };

    const openMenu = () => {
      menu.classList.add('is-open');
      button.setAttribute('aria-expanded', 'true');
    };

    button.addEventListener('click', (event) => {
      event.stopPropagation();
      if (menu.classList.contains('is-open')) closeMenu();
      else openMenu();
    });

    menu.addEventListener('click', (event) => {
      if (event.target.closest('a')) closeMenu();
    });

    document.addEventListener('click', (event) => {
      if (!menu.classList.contains('is-open')) return;
      if (menu.contains(event.target) || button.contains(event.target)) return;
      closeMenu();
    });

    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape' && menu.classList.contains('is-open')) {
        closeMenu({focusButton: true});
      }
    });

    window.addEventListener('resize', () => {
      if (window.innerWidth > 1100) closeMenu();
    });
  };

  const copyHead = (sourceDoc) => {
    document.title = sourceDoc.title;
    const selectors = [
      'meta[name="description"]', 'meta[name="robots"]', 'link[rel="canonical"]',
      'link[rel="alternate"][hreflang="es-CO"]', 'link[rel="alternate"][hreflang="x-default"]',
      'meta[property="og:title"]', 'meta[property="og:description"]', 'meta[property="og:url"]',
      'meta[name="twitter:title"]', 'meta[name="twitter:description"]'
    ];
    selectors.forEach((selector) => {
      const current = document.head.querySelector(selector);
      const incoming = sourceDoc.head.querySelector(selector);
      if (current && incoming) current.replaceWith(incoming.cloneNode(true));
    });
    document.querySelectorAll('script[data-page-jsonld]').forEach((node) => node.remove());
    sourceDoc.querySelectorAll('script[data-page-jsonld]').forEach((node) => document.head.appendChild(node.cloneNode(true)));
  };

  const loadPage = async (url, push = true) => {
    const target = new URL(url, location.href);
    if (target.origin !== location.origin || !PUBLIC_ROUTES.has(target.pathname)) {
      location.href = target.href;
      return;
    }
    const currentMain = document.querySelector('main');
    if (!currentMain) { location.href = target.href; return; }
    document.body.classList.add('page-loading');
    try {
      const response = await fetch(target.pathname, {headers: {'X-BarLytics-Navigation': 'partial'}});
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const html = await response.text();
      const parsed = new DOMParser().parseFromString(html, 'text/html');
      const incomingMain = parsed.querySelector('main');
      if (!incomingMain) throw new Error('La página no contiene <main>.');
      const apply = async () => {
        currentMain.replaceWith(incomingMain);
        copyHead(parsed);
        if (push) history.pushState({barlytics: true}, '', target.pathname + target.search + target.hash);
        await initPage();

        if (target.hash) {
          const id = decodeURIComponent(target.hash.slice(1));
          const anchor = document.getElementById(id);
          if (anchor) anchor.scrollIntoView({behavior: 'smooth', block: 'start'});
          else window.scrollTo({top: 0, behavior: 'instant'});
        } else {
          window.scrollTo({top: 0, behavior: 'instant'});
        }
        activeRoute();
      };
      if (document.startViewTransition) await document.startViewTransition(apply).finished;
      else await apply();
    } catch (error) {
      console.warn('BarLytics: navegación parcial no disponible; se usa navegación normal.', error);
      location.href = target.href;
    } finally {
      document.body.classList.remove('page-loading');
    }
  };

  const initPartialNavigation = () => {
    if (document.documentElement.dataset.partialBound === 'true') return;
    document.documentElement.dataset.partialBound = 'true';
    document.addEventListener('click', (event) => {
      const link = event.target.closest('a[data-partial]');
      if (!link || event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      const url = new URL(link.href, location.href);
      if (!PUBLIC_ROUTES.has(url.pathname)) return;
      event.preventDefault();
      loadPage(url, true);
    });
    window.addEventListener('popstate', () => {
      if (PUBLIC_ROUTES.has(location.pathname)) loadPage(location.href, false);
      else location.reload();
    });
  };

  const apiCandidates = (path) => {
    const candidates = [path];
    const nonStandardPort = location.port && !['80', '443'].includes(location.port);
    if (nonStandardPort) {
      candidates.push(`${location.protocol}//${location.hostname}:8282${path}`);
    }
    return [...new Set(candidates)];
  };

  const apiJson = async (path) => {
    let lastError;
    for (const url of apiCandidates(path)) {
      try {
        const response = await fetch(url, {headers: {'Accept': 'application/json'}});
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const contentType = response.headers.get('content-type') || '';
        if (!contentType.toLowerCase().includes('application/json')) {
          throw new Error(`Respuesta no JSON desde ${url}`);
        }
        const payload = await response.json();
        return payload && Object.prototype.hasOwnProperty.call(payload, 'data') ? payload.data : payload;
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError || new Error('No fue posible consultar la API pública.');
  };

  let siteConfigPromise;
  const siteConfig = () => siteConfigPromise ||= apiJson('/api/v1/parametros/public/site')
    .then((config) => ({ ...config, turnstileSiteKey: '0x4AAAAAAFFUhgh2d9bsD9xw' }))
    .catch(() => ({ turnstileSiteKey: '0x4AAAAAAFFUhgh2d9bsD9xw' }));

  const formatMoney = (value, currency = 'COP') => {
    try { return new Intl.NumberFormat('es-CO', {style: 'currency', currency, maximumFractionDigits: 0}).format(Number(value || 0)); }
    catch (_) { return `${currency} ${Number(value || 0).toLocaleString('es-CO')}`; }
  };

  const renderPlans = async () => {
    const host = document.querySelector('[data-plans]');
    if (!host) return;
    host.innerHTML = '<div class="status-box">Consultando planes disponibles…</div>';
    try {
      let plans = await apiJson('/api/v1/subscriptions/public/plans');
      if (!Array.isArray(plans)) plans = [];
      plans = plans.filter((plan) => plan && plan.publicVisible !== false).sort((a,b) => (a.displayOrder ?? 100) - (b.displayOrder ?? 100));
      if (!plans.length) {
        host.innerHTML = '<div class="status-box">No hay planes públicos disponibles en este momento.</div>';
        return;
      }
      host.innerHTML = plans.map((plan) => {
        const recommended = plan.recommended === true;
        const quote = plan.quoteRequired === true;
        const hasDiscount = plan.promotionActive === true && Number(plan.regularPrice) > Number(plan.price) && Number(plan.discountPercentage) > 0;
        const features = Array.isArray(plan.features) ? plan.features.filter(Boolean) : [];
        const action = String(plan.buttonAction || 'REGISTER').toUpperCase();
        const buttonText = plan.buttonText || (quote ? 'Hablar con nosotros' : 'Empezar con este plan');
        const code = encodeURIComponent(plan.code || '');
        const href = quote || action === 'WHATSAPP' ? '#plan-whatsapp' : `/#/registro?plan=${code}`;
        const disabled = action === 'NONE';
        const badge = plan.badge || (recommended ? 'RECOMENDADO' : (quote ? 'EMPRESAS' : ''));
        const icon = recommended ? '✦' : (quote ? '▦' : '↗');
        return `<article class="plan-card ${recommended ? 'is-recommended' : ''} ${quote ? 'is-quote' : ''}" data-plan-code="${escapeHtml(plan.code || '')}">
          <span class="plan-card__glow" aria-hidden="true"></span>
          <div class="plan-card__top"><span class="plan-card__icon" aria-hidden="true">${icon}</span>${badge ? `<span class="plan-badge">${escapeHtml(badge)}</span>` : ''}</div>
          <h2>${escapeHtml(plan.name || 'Plan')}</h2>
          ${hasDiscount ? `<div class="plan-price-old"><span>${formatMoney(plan.regularPrice, plan.currency || 'COP')}</span><strong>-${Number(plan.discountPercentage).toLocaleString('es-CO', {maximumFractionDigits:0})}%</strong></div>` : ''}
          <div class="plan-price-row"><div class="plan-price">${quote ? 'Cotizar' : formatMoney(plan.price, plan.currency || 'COP')}</div>${!quote ? `<span class="plan-period">${escapeHtml(periodLabel(plan))}</span>` : ''}</div>
          ${plan.promotionActive && plan.promotionText ? `<div class="plan-promo">⌁ ${escapeHtml(plan.promotionText)}</div>` : ''}
          <p class="plan-description">${escapeHtml(plan.description || '')}</p>
          ${features.length ? `<ul class="plan-features">${features.map((item) => `<li><span class="plan-check">✓</span><span>${escapeHtml(item)}</span></li>`).join('')}</ul>` : ''}
          <a class="button ${recommended ? 'button--primary' : 'button--ghost'} plan-action" ${disabled ? 'aria-disabled="true"' : ''} href="${href}" ${quote || action === 'WHATSAPP' ? 'data-plan-whatsapp' : 'data-full-navigation'}>${escapeHtml(buttonText)}</a>
        </article>`;
      }).join('');
      host.querySelectorAll('[data-plan-whatsapp]').forEach((button) => button.addEventListener('click', async (event) => {
        event.preventDefault();
        const planName = button.closest('[data-plan-code]')?.querySelector('h2')?.textContent?.trim() || 'BarLytics';
        const config = await siteConfig();
        const number = digits(config.whatsapp);
        if (!number) return showInlineStatus(host, 'WhatsApp no está configurado actualmente.');
        location.href = `https://wa.me/${number}?text=${encodeURIComponent(`Hola, quiero información sobre el plan ${planName} de BarLytics.`)}`;
      }));
    } catch (error) {
      host.innerHTML = `<div class="status-box">No fue posible consultar los planes. <button class="tab-button" type="button" data-retry-plans>Reintentar</button></div>`;
      host.querySelector('[data-retry-plans]')?.addEventListener('click', renderPlans, {once: true});
    }
  };

  const periodLabel = (plan) => {
    const frequency = Number(plan.frequency || 1);
    const type = String(plan.frequencyType || 'months').toLowerCase();
    if (type.includes('month')) return frequency === 1 ? 'Mensual' : `Cada ${frequency} meses`;
    if (type.includes('year')) return frequency === 1 ? 'Anual' : `Cada ${frequency} años`;
    return 'Suscripción';
  };

  const renderContact = async () => {
    const phone = document.querySelector('[data-contact-phone]');
    const whatsapp = document.querySelector('[data-contact-whatsapp]');
    if (!phone && !whatsapp) return;
    const config = await siteConfig();
    const configuredPhone = String(config.phone || config.contactPhone || '').trim();
    const configuredWhatsapp = String(config.whatsapp || '').trim();
    setContact(phone, configuredPhone, 'tel:');
    setContact(whatsapp, configuredWhatsapp, configuredWhatsapp ? `https://wa.me/${digits(configuredWhatsapp)}?text=${encodeURIComponent('Hola, quiero conocer más sobre BarLytics para mi negocio.')}` : '');
  };

  const setContact = (node, value, hrefPrefix) => {
    if (!node) return;
    if (!value) {
      node.textContent = 'No configurado';
      node.classList.add('is-unconfigured');
      node.removeAttribute('href');
      return;
    }
    node.textContent = value;
    node.classList.remove('is-unconfigured');
    node.href = hrefPrefix.startsWith('http') ? hrefPrefix : `${hrefPrefix}${digits(value)}`;
  };

  const initMobileAppPrompt = async () => {
    if (document.querySelector('[data-mobile-app-prompt]')) return;
    const ua = navigator.userAgent || '';
    const isAndroid = /Android/i.test(ua);
    const isIOS = /iPhone|iPad|iPod/i.test(ua) ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    if (!isAndroid && !isIOS) return;
    if (window.matchMedia?.('(display-mode: standalone)').matches || navigator.standalone === true) return;
    if (sessionStorage.getItem('barlytics-mobile-app-prompt-dismissed') === '1') return;

    const config = await siteConfig();
    const storeUrl = String(isIOS ? config.iosDownloadUrl : config.androidDownloadUrl).trim();
    if (!isHttpUrl(storeUrl)) return;

    const banner = document.createElement('aside');
    banner.dataset.mobileAppPrompt = 'true';
    banner.setAttribute('role', 'region');
    banner.setAttribute('aria-label', 'Abrir BarLytics en la aplicación');
    banner.style.cssText = 'position:fixed;left:12px;right:12px;bottom:calc(12px + env(safe-area-inset-bottom));z-index:100000;display:flex;align-items:center;gap:12px;padding:12px 14px;border:1px solid rgba(46,226,211,.32);border-radius:18px;background:rgba(6,23,35,.96);box-shadow:0 16px 44px rgba(0,0,0,.38);backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px);color:#fff;font-family:Roboto,system-ui,sans-serif';
    banner.innerHTML = `
      <img src="/favicon.png" alt="" width="44" height="44" style="border-radius:11px;flex:0 0 auto">
      <div style="min-width:0;flex:1"><strong style="display:block;font-size:14px">BarLytics funciona mejor en la app</strong><span style="display:block;margin-top:2px;color:#b9cbd3;font-size:12px">${isIOS ? 'iPhone / iPad' : 'Android'} · acceso directo y pantalla completa</span></div>
      <a data-open-store href="${escapeHtml(storeUrl)}" style="flex:0 0 auto;padding:10px 13px;border-radius:999px;background:#22d9d7;color:#061723;text-decoration:none;font-weight:900;font-size:13px">Abrir app</a>
      <button data-close-app-prompt type="button" aria-label="Cerrar" style="flex:0 0 auto;border:0;background:transparent;color:#b9cbd3;font-size:24px;line-height:1;cursor:pointer;padding:4px">×</button>`;
    document.body.appendChild(banner);
    banner.querySelector('[data-close-app-prompt]')?.addEventListener('click', () => {
      sessionStorage.setItem('barlytics-mobile-app-prompt-dismissed', '1');
      banner.remove();
    });
  };

  const DOWNLOAD_PLATFORMS = new Set(['windows','macos','android','ios','linux']);

  const renderDownloads = async () => {
    const nodes = document.querySelectorAll('[data-download-platform]');
    if (!nodes.length) return;

    const config = await siteConfig();
    const storeUrls = {
      android: String(config.androidDownloadUrl || '').trim(),
      ios: String(config.iosDownloadUrl || '').trim(),
    };

    nodes.forEach((node) => {
      const platform = String(node.dataset.downloadPlatform || '').toLowerCase();
      const button = node.querySelector('[data-download-button]');
      if (!button || !DOWNLOAD_PLATFORMS.has(platform)) return;

      if (platform === 'android' || platform === 'ios') {
        const url = storeUrls[platform];
        if (!url) {
          button.textContent = 'Próximamente';
          button.setAttribute('aria-disabled', 'true');
          button.removeAttribute('href');
          return;
        }
        button.href = url;
        button.textContent = platform === 'android' ? 'Abrir Play Store' : 'Abrir App Store';
        button.removeAttribute('aria-disabled');
        button.setAttribute('target', '_blank');
        button.setAttribute('rel', 'noopener noreferrer');
        button.removeAttribute('data-full-navigation');
        return;
      }

      button.href = `/descargas/${platform}/`;
      button.textContent = 'Continuar';
      button.removeAttribute('aria-disabled');
      button.removeAttribute('target');
      button.removeAttribute('rel');
      button.setAttribute('data-full-navigation', '');
    });
  };

  const renderProtectedDownload = async () => {
    const host = document.querySelector('[data-protected-download]');
    if (!host) return;
    const platform = String(host.dataset.protectedDownload || '').toLowerCase();
    if (!DOWNLOAD_PLATFORMS.has(platform)) return;

    const button = host.querySelector('[data-request-download]');
    const status = host.querySelector('[data-download-status]');
    const captcha = host.querySelector('[data-turnstile]');
    if (!button || !status || !captcha) return;

    let challengeToken = '';
    const config = await siteConfig();
    const siteKey = String(config.turnstileSiteKey || '').trim();

    if (!siteKey) {
      status.textContent = 'La verificación de seguridad todavía no está configurada.';
      button.disabled = true;
      return;
    }

    const renderCaptcha = () => {
      if (!window.turnstile) return setTimeout(renderCaptcha, 100);
      window.turnstile.render(captcha, {
        sitekey: siteKey,
        theme: 'dark',
        callback: (token) => {
          challengeToken = token;
          button.disabled = false;
          status.textContent = 'Verificación completada. Ya puedes solicitar la descarga.';
        },
        'expired-callback': () => {
          challengeToken = '';
          button.disabled = true;
          status.textContent = 'La verificación expiró. Complétala nuevamente.';
        },
        'error-callback': () => {
          challengeToken = '';
          button.disabled = true;
          status.textContent = 'No fue posible completar la verificación.';
        }
      });
    };
    renderCaptcha();

    button.addEventListener('click', async () => {
      if (!challengeToken || button.disabled) return;
      button.disabled = true;
      status.textContent = 'Generando enlace seguro…';
      try {
        const response = await fetch('/api/v1/downloads/ticket', {
          method: 'POST',
          headers: {'Accept':'application/json','Content-Type':'application/json'},
          body: JSON.stringify({platform, turnstileToken: challengeToken})
        });
        if (response.status === 429) throw new Error('Demasiadas solicitudes. Espera unos minutos e inténtalo nuevamente.');
        if (!response.ok) throw new Error('No fue posible autorizar la descarga.');
        const payload = await response.json();
        const data = payload && Object.prototype.hasOwnProperty.call(payload, 'data') ? payload.data : payload;
        const downloadUrl = String(data?.downloadUrl || '').trim();
        if (!downloadUrl || !downloadUrl.startsWith('/api/v1/downloads/file/')) throw new Error('El servidor no devolvió un enlace de descarga válido.');
        status.textContent = 'Descarga autorizada. El enlace es temporal y de un solo uso.';
        location.assign(downloadUrl);
      } catch (error) {
        status.textContent = error?.message || 'No fue posible iniciar la descarga.';
        challengeToken = '';
        if (window.turnstile) window.turnstile.reset(captcha);
      }
    });
  };

  const renderFeatureExplorer = () => {
    const host = document.querySelector('[data-feature-explorer]');
    if (!host) return;
    let featureIndex = 0;
    let deviceKey = 'desktop';

    const deviceChrome = (key) => {
      if (key === 'phone') return `<div class="phone-status"><span>9:41</span><span class="dynamic-island" aria-hidden="true"></span><span>▮ Wi‑Fi ▰</span></div>`;
      if (key === 'tablet') return `<div class="tablet-status"><span class="status-dot"></span><strong>BarLytics</strong><span>Wi‑Fi ▰</span></div>`;
      return `<div class="desktop-status"><span class="window-dots"><i></i><i></i><i></i></span><span class="browser-address">BarLytics · Gestión inteligente para tu negocio</span></div>`;
    };

    const draw = () => {
      const feature = FEATURES[featureIndex];
      const device = DEVICES[deviceKey];
      const path = demoMediaPath(deviceKey, feature.slug);
      const isVideo = Boolean(path);
      host.innerHTML = `<div class="feature-explorer__header">
          <div class="explorer-intro"><span class="explorer-live"><i></i> DEMOSTRACIÓN REAL</span><strong>Mira BarLytics como lo usaría tu equipo</strong></div>
          <div class="device-selector" aria-label="Selecciona dispositivo">${Object.entries(DEVICES).map(([key,value]) => `<button class="device-option ${key === deviceKey ? 'is-active' : ''}" type="button" data-device="${key}"><span class="device-option__icon" aria-hidden="true">${value.icon}</span><span>${value.label}</span></button>`).join('')}</div>
        </div>
        <div class="feature-rail-shell">
          <button class="feature-rail-arrow feature-rail-arrow--prev" type="button" data-feature-prev aria-label="Funciones anteriores">‹</button>
          <div class="feature-tabs" data-feature-tabs aria-label="Funciones">${FEATURES.map((item,index) => `<button class="feature-tab-card ${index === featureIndex ? 'is-active' : ''}" type="button" data-feature="${index}"><span class="feature-tab-card__icon" aria-hidden="true">${item.icon}</span><span>${escapeHtml(item.name)}</span></button>`).join('')}</div>
          <button class="feature-rail-arrow feature-rail-arrow--next" type="button" data-feature-next aria-label="Más funciones">›</button>
        </div>
        <div class="feature-stage">
          <div class="device-frame-wrap"><div class="device-frame ${device.cls}" data-device-frame>
            ${deviceChrome(deviceKey)}
            <div class="device-screen"><div class="demo-placeholder"><span class="demo-placeholder__icon" aria-hidden="true">${feature.icon}</span><strong>${escapeHtml(feature.name)}</strong><span>Demostración en ${escapeHtml(device.label)} en preparación.</span></div>${path ? (isVideo ? `<video src="${path}" muted autoplay loop playsinline preload="auto" aria-label="Demo de ${escapeHtml(feature.name)} en ${escapeHtml(device.label)}" data-demo-video hidden></video>` : `<img src="${path}" alt="Demo de ${escapeHtml(feature.name)} en ${escapeHtml(device.label)}" loading="eager" data-demo-image hidden>`) : ''}</div>
            ${deviceKey === 'phone' ? '<div class="phone-home" aria-hidden="true"><span></span></div>' : ''}
          </div></div>
          <section class="feature-detail">
            <div class="feature-detail__title"><span class="feature-detail__icon" aria-hidden="true">${feature.icon}</span><div><span class="feature-detail__eyebrow">${escapeHtml(device.label)} · ${String(featureIndex + 1).padStart(2,'0')}</span><h3>${escapeHtml(feature.name)}</h3></div></div>
            <p>${escapeHtml(feature.description)}</p>
            <div class="feature-benefits">${feature.benefits.map((item) => `<span>✓ ${escapeHtml(item)}</span>`).join('')}</div>
            <div class="feature-outcome"><small>PARA TU NEGOCIO</small><strong>${escapeHtml(feature.outcome)}</strong></div>
            <button class="button button--ghost replay-button" type="button" data-replay>↻ Repetir demostración</button>
          </section>
        </div>`;

      const rail = host.querySelector('[data-feature-tabs]');
      host.querySelectorAll('[data-feature]').forEach((button) => button.addEventListener('click', () => {
        featureIndex = Number(button.dataset.feature);
        draw();
      }));
      host.querySelectorAll('[data-device]').forEach((button) => button.addEventListener('click', () => {
        deviceKey = button.dataset.device;
        draw();
      }));
      host.querySelector('[data-feature-prev]')?.addEventListener('click', () => rail?.scrollBy({left:-380, behavior:'smooth'}));
      host.querySelector('[data-feature-next]')?.addEventListener('click', () => rail?.scrollBy({left:380, behavior:'smooth'}));

      const img = host.querySelector('[data-demo-image]');
      const video = host.querySelector('[data-demo-video]');
      const media = video || img;
      const placeholder = host.querySelector('.demo-placeholder');
      const replayButton = host.querySelector('[data-replay]');
      if (video) {
        video.addEventListener('canplay', () => {
          video.hidden = false;
          if (placeholder) placeholder.hidden = true;
          if (replayButton) { replayButton.disabled = false; replayButton.textContent = '↻ Repetir demostración'; }
          video.play().catch(() => {});
        }, {once:true});
        video.addEventListener('error', () => {
          video.hidden = true;
          if (placeholder) placeholder.hidden = false;
          if (replayButton) { replayButton.disabled = true; replayButton.textContent = 'Demostración en preparación'; }
        }, {once:true});
      }
      if (img) {
        img.addEventListener('load', () => {
          img.hidden = false;
          if (placeholder) placeholder.hidden = true;
          if (replayButton) { replayButton.disabled = false; replayButton.textContent = '↻ Repetir demostración'; }
        }, {once:true});
        img.addEventListener('error', () => {
          img.hidden = true;
          if (placeholder) placeholder.hidden = false;
          if (replayButton) { replayButton.disabled = true; replayButton.textContent = 'Demostración en preparación'; }
          console.info(`BarLytics: GIF pendiente ${path}`);
        }, {once:true});
      }
      replayButton?.addEventListener('click', () => {
        if (!media || media.hidden) return;
        if (video) {
          video.currentTime = 0;
          video.play().catch(() => {});
          return;
        }
        const clean = img.src.split('?')[0];
        img.src = `${clean}?replay=${Date.now()}`;
      });
    };
    draw();
  };

  const initFaq = () => {
    const search = document.querySelector('[data-faq-search]');
    if (!search || search.dataset.bound === 'true') return;
    search.dataset.bound = 'true';
    search.addEventListener('input', () => {
      const term = search.value.trim().toLocaleLowerCase('es-CO');
      document.querySelectorAll('details[data-faq-item]').forEach((detail) => {
        const match = !term || detail.textContent.toLocaleLowerCase('es-CO').includes(term);
        detail.hidden = !match;
      });
      document.querySelectorAll('[data-faq-category]').forEach((section) => {
        section.hidden = !section.querySelector('details[data-faq-item]:not([hidden])');
      });
    });
  };
  const initDocsSearch = () => {
    const search = document.querySelector('[data-doc-search]');
    if (!search || search.dataset.bound === 'true') return;
    search.dataset.bound = 'true';
    search.addEventListener('input', () => {
      const term = search.value.trim().toLocaleLowerCase('es-CO');
      document.querySelectorAll('[data-doc-section]').forEach((section) => {
        section.hidden = Boolean(term) && !section.textContent.toLocaleLowerCase('es-CO').includes(term);
      });
    });
  };


  const initPage = async () => {
    setTheme();
    await ensureSharedLayout();
    activeRoute();
    initMenu();
    renderPlans();
    renderContact();
    renderDownloads();
    initMobileAppPrompt();
    renderProtectedDownload();
    renderFeatureExplorer();
    // Sin precargas masivas: el video activo inicia al ser visible.
    initFaq();
    initDocsSearch();
  };

  const digits = (value) => String(value || '').replace(/\D/g, '');
  const isHttpUrl = (value) => { try { const u = new URL(value); return u.protocol === 'http:' || u.protocol === 'https:'; } catch (_) { return false; } };
  const escapeHtml = (value) => String(value ?? '').replace(/[&<>'"]/g, (ch) => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[ch]));
  const showInlineStatus = (host, text) => { const box = document.createElement('div'); box.className = 'status-box'; box.textContent = text; host.prepend(box); setTimeout(() => box.remove(), 5000); };

  preventZoom();
  initPartialNavigation();
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initPage, {once: true});
  else initPage();
})();
