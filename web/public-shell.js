(function () {
  'use strict';

  const links = [
    { label: 'Demo', href: '/?section=demo', key: 'demo' },
    { label: 'Funciones', href: '/funcionalidades/', key: 'funcionalidades' },
    { label: 'Nosotros', href: '/nosotros/', key: 'nosotros' },
    { label: 'Planes', href: '/planes/', key: 'planes' },
    { label: 'Descargas', href: '/descargas/', key: 'descargas' },
    { label: 'Contacto', href: '/contacto/', key: 'contacto' },
  ];

  const keyForLocation = (url = new URL(window.location.href)) => {
    const path = url.pathname.replace(/\/+$/, '') || '/';
    if (path === '/funcionalidades') return 'funcionalidades';
    if (path === '/planes') return 'planes';
    if (path === '/descargas') return 'descargas';
    if (path === '/contacto') return 'contacto';
    if (path === '/nosotros') return 'nosotros';
    if (path === '/' && url.searchParams.get('section') === 'demo') return 'demo';
    return '';
  };

  class BarLyticsPublicHeader extends HTMLElement {
    connectedCallback() {
      if (this.dataset.ready === 'true') return;
      this.dataset.ready = 'true';
      this.innerHTML = `
        <header class="site-header">
          <div class="navigation-progress" aria-hidden="true"></div>
          <nav class="container nav" aria-label="Navegación principal">
            <a class="brand" href="/" aria-label="Ir al inicio de BarLytics Colombia">
              <img src="/branding/barlytics-logo-light.png" alt="BarLytics Colombia" width="220" height="69">
            </a>
            <button class="menu-toggle" type="button" aria-label="Abrir menú" aria-expanded="false">
              <span aria-hidden="true"></span><span aria-hidden="true"></span><span aria-hidden="true"></span>
            </button>
            <div class="nav-links" data-public-menu>
              ${links.map((link) => `<a href="${link.href}" data-nav-key="${link.key}">${link.label}</a>`).join('')}
              <span class="nav-divider" aria-hidden="true"></span>
              <a class="button nav-login" href="/#/login">Ingresar</a>
              <a class="button nav-register" href="/#/registro">Registrarse <span aria-hidden="true">→</span></a>
            </div>
          </nav>
        </header>`;

      const toggle = this.querySelector('.menu-toggle');
      const menu = this.querySelector('[data-public-menu]');
      toggle?.addEventListener('click', () => {
        const open = menu?.classList.toggle('open') === true;
        toggle.setAttribute('aria-expanded', String(open));
        toggle.setAttribute('aria-label', open ? 'Cerrar menú' : 'Abrir menú');
      });
      menu?.addEventListener('click', (event) => {
        if (!event.target.closest('a')) return;
        menu.classList.remove('open');
        toggle?.setAttribute('aria-expanded', 'false');
        toggle?.setAttribute('aria-label', 'Abrir menú');
      });
      this.syncActive();
    }

    syncActive(url = new URL(window.location.href)) {
      const key = keyForLocation(url);
      this.querySelectorAll('[data-nav-key]').forEach((link) => {
        if (link.dataset.navKey === key) link.setAttribute('aria-current', 'page');
        else link.removeAttribute('aria-current');
      });
    }
  }

  class BarLyticsPublicFooter extends HTMLElement {
    connectedCallback() {
      if (this.dataset.ready === 'true') return;
      this.dataset.ready = 'true';
      this.innerHTML = `
        <footer class="site-footer">
          <div class="container footer-row">
            <div class="footer-brand">
              <a href="/" aria-label="Inicio de BarLytics"><img src="/branding/barlytics-logo-light.png" alt="BarLytics Colombia" width="214" height="67"></a>
              <p>Gestión para bares · Ventas · Inventario · Caja · Reportes</p>
              <nav class="footer-links" aria-label="Enlaces del pie de página">
                <a href="/software-para-bares/">Software para bares</a>
                <a href="/funcionalidades/">Funciones</a>
                <a href="/nosotros/">Nosotros</a>
                <a href="/planes/">Planes</a>
                <a href="/descargas/">Descargas</a>
                <a href="/contacto/">Contacto</a>
                <a href="/preguntas-frecuentes/">Preguntas frecuentes</a>
                <a href="/documentacion/">Documentación</a>
              </nav>
            </div>
            <div class="footer-signature">
              <img src="/branding/mcode-m-icon.png" alt="" width="46" height="46">
              <span><strong>Desarrollado por MCode SAS</strong><small>Innovación en cada línea</small></span>
            </div>
          </div>
          <div class="container footer-legal">
            <span>© BarLytics · Colombia</span>
            <nav aria-label="Enlaces legales">
              <a href="/privacidad/">Política de privacidad</a>
              <a href="/opciones-de-privacidad/">Opciones de privacidad</a>
              <a href="/terminos/">Términos y condiciones</a>
            </nav>
          </div>
        </footer>`;
    }
  }

  if (!customElements.get('barlytics-public-header')) {
    customElements.define('barlytics-public-header', BarLyticsPublicHeader);
  }
  if (!customElements.get('barlytics-public-footer')) {
    customElements.define('barlytics-public-footer', BarLyticsPublicFooter);
  }

  window.BarLyticsPublicShell = {
    sync(url) {
      document.querySelector('barlytics-public-header')?.syncActive(url);
    },
  };
})();
