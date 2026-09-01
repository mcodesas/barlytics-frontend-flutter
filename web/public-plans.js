(function () {
  'use strict';

  const endpoint = '/api/v1/subscriptions/public/plans';
  const localEndpoint = `${window.location.protocol}//${window.location.hostname}:8282${endpoint}`;
  const candidates = window.location.port && !['80', '443'].includes(window.location.port)
    ? [endpoint, localEndpoint]
    : [endpoint];

  const escapeHtml = (value) => String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');

  const money = (value, currency) => new Intl.NumberFormat('es-CO', {
    style: 'currency',
    currency: currency || 'COP',
    currencyDisplay: 'narrowSymbol',
    maximumFractionDigits: 0,
  }).format(Number(value || 0));

  const period = (plan) => {
    if (plan.quoteRequired) return 'según operación';
    const frequency = Math.max(1, Number(plan.frequency || 1));
    const type = String(plan.frequencyType || 'months').toLowerCase();
    let unit = frequency === 1 ? 'mes' : `${frequency} meses`;
    if (type.startsWith('day')) unit = frequency === 1 ? 'día' : `${frequency} días`;
    if (type.startsWith('week')) unit = frequency === 1 ? 'semana' : `${frequency} semanas`;
    if (type.startsWith('year')) unit = frequency === 1 ? 'año' : `${frequency} años`;
    return `${escapeHtml(plan.currency || 'COP')} / ${unit}`;
  };

  const planAction = (plan) => {
    const action = String(plan.buttonAction || 'REGISTER').toUpperCase();
    if (plan.quoteRequired || action === 'WHATSAPP') return '/contacto/';
    if (action === 'NONE') return '';
    return `/#/registro?plan=${encodeURIComponent(plan.code || '')}`;
  };

  const planIcon = (plan) => {
    if (plan.recommended) return '<span aria-hidden="true">✦</span>';
    if (plan.quoteRequired) return '<span aria-hidden="true">▦</span>';
    return '<span aria-hidden="true">↗</span>';
  };

  const renderPlan = (plan) => {
    const recommended = plan.recommended === true;
    const hasDiscount = plan.promotionActive === true
      && Number(plan.discountPercentage || 0) > 0
      && Number(plan.regularPrice || 0) > Number(plan.price || 0);
    const badge = String(plan.badge || '').trim() || (recommended ? 'RECOMENDADO' : '');
    const features = Array.isArray(plan.features) ? plan.features : [];
    const href = planAction(plan);
    const buttonText = String(plan.buttonText || '').trim()
      || (plan.quoteRequired ? 'Hablar con nosotros' : `Elegir ${plan.name || 'plan'}`);

    return `
      <article class="plan-card${recommended ? ' recommended' : ''}">
        <div class="plan-card__glow" aria-hidden="true"></div>
        <div class="plan-card__top">
          <span class="plan-card__icon">${planIcon(plan)}</span>
          ${badge ? `<span class="plan-card__badge">${escapeHtml(badge.toUpperCase())}</span>` : ''}
        </div>
        <h2>${escapeHtml(plan.name)}</h2>
        ${hasDiscount ? `<div class="plan-card__regular"><span>${money(plan.regularPrice, plan.currency)}</span><strong>-${escapeHtml(plan.discountPercentage)}%</strong></div>` : ''}
        <div class="plan-card__price-row">
          <div class="plan-card__price">${plan.quoteRequired ? 'Cotizar' : money(plan.price, plan.currency)}</div>
          <div class="plan-card__period">${period(plan)}</div>
        </div>
        ${plan.promotionActive && plan.promotionText ? `<p class="plan-card__promo"><span aria-hidden="true">◇</span>${escapeHtml(plan.promotionText)}</p>` : ''}
        <p class="plan-card__description">${escapeHtml(plan.description || 'Una opción de BarLytics para organizar y controlar tu negocio.')}</p>
        <ul>${features.map((feature) => `<li><span aria-hidden="true">✓</span><span>${escapeHtml(feature)}</span></li>`).join('')}</ul>
        ${href
          ? `<a class="button plan-card__button${recommended ? '' : ' secondary'}" href="${href}">${escapeHtml(buttonText)}</a>`
          : `<span class="button secondary plan-card__button disabled" aria-disabled="true">${escapeHtml(buttonText)}</span>`}
      </article>`;
  };

  const unpack = (payload) => {
    if (Array.isArray(payload)) return payload;
    if (Array.isArray(payload?.data)) return payload.data;
    if (Array.isArray(payload?.content)) return payload.content;
    if (Array.isArray(payload?.data?.content)) return payload.data.content;
    return [];
  };

  const fetchPlans = async () => {
    let lastError;
    for (const url of candidates) {
      try {
        const response = await fetch(url, { headers: { Accept: 'application/json' } });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return unpack(await response.json());
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError || new Error('No fue posible consultar los planes.');
  };

  const load = async (container) => {
    container.dataset.plansInitialized = 'true';
    container.innerHTML = '<div class="plans-status"><span class="spinner"></span><p>Consultando planes vigentes...</p></div>';
    try {
      const plans = (await fetchPlans())
        .filter((plan) => plan && plan.publicVisible !== false)
        .sort((a, b) => Number(a.displayOrder || 100) - Number(b.displayOrder || 100));
      if (!container.isConnected) return;
      if (!plans.length) {
        container.innerHTML = '<div class="plans-status"><p>No hay planes comerciales activos para mostrar en este momento.</p></div>';
        return;
      }
      container.innerHTML = plans.map(renderPlan).join('');
    } catch (_) {
      if (!container.isConnected) return;
      container.innerHTML = '<div class="plans-status"><p>No fue posible cargar los planes en este momento.</p><button class="button secondary" type="button" data-retry-plans>Volver a intentar</button></div>';
      container.querySelector('[data-retry-plans]')?.addEventListener('click', () => load(container));
    }
  };

  const init = (root = document) => {
    root.querySelectorAll('[data-public-plans]').forEach((container) => {
      if (container.dataset.plansInitialized === 'true') return;
      load(container);
    });
  };

  window.BarLyticsPublicPlans = { init };
  init();
})();
