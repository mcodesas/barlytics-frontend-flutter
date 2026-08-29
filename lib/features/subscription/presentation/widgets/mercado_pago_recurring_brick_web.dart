// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Payment Brick oficial para suscripción recurrente de Mercado Pago montado directamente en el DOM.
///
/// No usa iframe ni reconstruye los campos de pago. Mercado Pago controla la
/// interfaz, validación y tokenización; BarLytics solo envía `formData` al
/// backend autenticado y reacciona al resultado.
class MercadoPagoRecurringBrick extends StatefulWidget {
  const MercadoPagoRecurringBrick({
    super.key,
    required this.publicKey,
    required this.amount,
    required this.payerEmail,
    required this.apiBaseUrl,
    required this.authToken,
    required this.returnUrl,
  });

  final String publicKey;
  final double amount;
  final String payerEmail;
  final String apiBaseUrl;
  final String authToken;
  final String returnUrl;

  @override
  State<MercadoPagoRecurringBrick> createState() => _MercadoPagoRecurringBrickState();
}

class _MercadoPagoRecurringBrickState extends State<MercadoPagoRecurringBrick> {
  late final String _viewType;
  late final String _instanceId;
  late final String _containerId;
  late final String _statusId;
  late final String _scriptId;
  late final html.DivElement _root;

  StreamSubscription<html.MessageEvent>? _messageSubscription;
  double _height = 610;

  @override
  void initState() {
    super.initState();

    final stamp = DateTime.now().microsecondsSinceEpoch;
    _viewType = 'barlytics-mp-brick-$stamp';
    _instanceId = 'barlytics-mp-$stamp';
    _containerId = 'barlytics-mp-container-$stamp';
    _statusId = 'barlytics-mp-status-$stamp';
    _scriptId = 'barlytics-mp-init-$stamp';

    _root = html.DivElement()
      ..id = 'barlytics-mp-root-$stamp'
      ..style.width = '100%'
      ..style.minWidth = '0'
      ..style.margin = '0'
      ..style.padding = '0'
      // El contenedor Flutter ya dibuja la tarjeta de pago con la paleta de
      // BarLytics. Dejamos la raíz del HtmlElementView transparente para evitar
      // el efecto de una tarjeta dentro de otra.
      ..style.backgroundColor = 'transparent'
      ..style.borderRadius = '0'
      ..style.boxSizing = 'border-box'
      ..style.padding = '0'
      ..append(html.DivElement()
        ..id = _containerId
        ..style.width = '100%'
        ..style.minWidth = '280px'
        ..style.display = 'block'
        ..style.boxSizing = 'border-box')
      ..append(html.DivElement()
        ..id = _statusId
        ..style.display = 'none'
        ..style.marginTop = '8px'
        ..style.padding = '10px 12px'
        ..style.borderRadius = '10px'
        ..style.fontFamily = 'Arial, sans-serif'
        ..style.fontSize = '12px'
        ..style.lineHeight = '1.4');

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _root);
    _listenForHeight();

    // El script se monta después del primer frame para asegurar que el
    // HtmlElementView ya tenga un nodo real en el DOM.
    WidgetsBinding.instance.addPostFrameCallback((_) => _mountBrick());
  }

  void _listenForHeight() {
    _messageSubscription = html.window.onMessage.listen((event) {
      final raw = event.data;
      if (raw is! String) return;
      try {
        final data = jsonDecode(raw);
        if (data is! Map<String, dynamic>) return;
        if (data['source'] != 'barlytics-mp-brick-height') return;
        if (data['instanceId'] != _instanceId) return;
        final rawHeight = data['height'];
        if (rawHeight is! num) return;
        final next = rawHeight.toDouble().clamp(460.0, 1800.0).toDouble();
        if (!mounted || (next - _height).abs() < 3) return;
        setState(() => _height = next);
      } catch (_) {
        // Ignora mensajes ajenos al Brick.
      }
    });
  }

  void _mountBrick() {
    _ensureSdkScript();

    final config = base64Encode(
      utf8.encode(
        jsonEncode(<String, dynamic>{
          'instanceId': _instanceId,
          'containerId': _containerId,
          'statusId': _statusId,
          'publicKey': widget.publicKey,
          'amount': widget.amount,
          'payerEmail': widget.payerEmail,
          'apiBaseUrl': widget.apiBaseUrl,
          'authToken': widget.authToken,
          'returnUrl': widget.returnUrl,
        }),
      ),
    );

    html.document.getElementById(_scriptId)?.remove();
    final script = html.ScriptElement()
      ..id = _scriptId
      ..type = 'text/javascript'
      ..text = _brickScript(config);
    html.document.body?.append(script);
  }

  void _ensureSdkScript() {
    if (html.document.querySelector('script[data-barlytics-mp-sdk="true"]') != null) return;

    final sdk = html.ScriptElement()
      ..src = 'https://sdk.mercadopago.com/js/v2'
      ..async = true
      ..setAttribute('data-barlytics-mp-sdk', 'true');
    html.document.head?.append(sdk);
  }

  String _brickScript(String config) => '''
(() => {
  const cfg = JSON.parse(new TextDecoder().decode(Uint8Array.from(atob('$config'), c => c.charCodeAt(0))));
  window.__barlyticsMpControllers = window.__barlyticsMpControllers || {};

  const getContainer = () => document.getElementById(cfg.containerId);
  const getStatus = () => document.getElementById(cfg.statusId);

  const reportHeight = () => window.requestAnimationFrame(() => {
    const container = getContainer();
    const status = getStatus();
    if (!container) return;
    const statusHeight = status && status.style.display !== 'none' ? status.scrollHeight + 8 : 0;
    const height = Math.max(460, Math.ceil(container.scrollHeight + statusHeight + 8));
    window.postMessage(JSON.stringify({
      source: 'barlytics-mp-brick-height',
      instanceId: cfg.instanceId,
      height
    }), '*');
  });

  const setStatus = (message, type = 'error') => {
    const status = getStatus();
    if (!status) return;
    if (!message) {
      status.textContent = '';
      status.style.display = 'none';
      reportHeight();
      return;
    }
    status.textContent = message;
    status.style.display = 'block';
    if (type === 'success') {
      status.style.color = '#D1FAE5';
      status.style.background = '#073B35';
      status.style.border = '1px solid #0FBF9E';
    } else {
      status.style.color = '#FFE4E6';
      status.style.background = '#3A1118';
      status.style.border = '1px solid #FF6B6B';
    }
    reportHeight();
  };

  // Payment Brick exige el e-mail del pagador, pero BarLytics ya lo conoce
  // antes de abrir el formulario. Mercado Pago permite precargarlo mediante
  // initialization.payer.email; visualmente ocultamos solo la sección redundante
  // "Completa tu información" sin eliminar el input ni alterar formData.
  const hidePrefilledPayerEmailSection = () => {
    if (!cfg.payerEmail) return;
    const container = getContainer();
    if (!container) return;

    const normalize = value => (value || '')
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .trim()
      .toLowerCase();

    const emailInput = container.querySelector('input[type="email"]');
    if (!emailInput) return;

    // El valor permanece en el DOM para que Mercado Pago lo incluya en formData.
    if (!emailInput.value && cfg.payerEmail) {
      emailInput.value = cfg.payerEmail;
      emailInput.dispatchEvent(new Event('input', { bubbles: true }));
      emailInput.dispatchEvent(new Event('change', { bubbles: true }));
    }

    const title = Array.from(container.querySelectorAll('h1,h2,h3,h4,h5,h6,div,p,span'))
      .find(element => normalize(element.textContent) === 'completa tu informacion');

    if (!title) return;

    // Busca el ancestro más pequeño que contiene simultáneamente el título y
    // el input de e-mail. De esta forma no ocultamos campos de tarjeta ni otros
    // medios de pago.
    let section = title.parentElement;
    while (section && section !== container && !section.contains(emailInput)) {
      section = section.parentElement;
    }

    if (section && section !== container && section.style.display !== 'none') {
      section.style.display = 'none';
      section.setAttribute('data-barlytics-hidden-payer-email', 'true');
      reportHeight();
    }
  };

  const apiMessage = payload => {
    if (Array.isArray(payload?.errors) && payload.errors.length && payload.errors[0]?.message) {
      return payload.errors[0].message;
    }
    return payload?.message || 'No fue posible procesar el pago.';
  };

  const addQuery = (url, key, value) => {
    const separator = url.includes('?') ? '&' : '?';
    return url + separator + encodeURIComponent(key) + '=' + encodeURIComponent(value);
  };

  const returnToBarLytics = data => {
    let target = cfg.returnUrl;
    if (data.preapprovalId) target = addQuery(target, 'preapproval_id', data.preapprovalId);
    if (data.paymentId) target = addQuery(target, 'payment_id', data.paymentId);
    window.location.assign(target);
  };

  const submitToBarLytics = async (selectedPaymentMethod, formData) => {
    // selectedPaymentMethod es parte oficial del callback de Payment Brick y
    // viene separado de formData. Lo agregamos como metadato de enrutamiento;
    // token, payer, issuer, installments, etc. permanecen exactamente como los
    // entrega Mercado Pago.
    const normalizedSelectedPaymentMethod =
      selectedPaymentMethod === 'credit_card' || selectedPaymentMethod === 'debit_card'
        ? selectedPaymentMethod
        : null;

    // Mercado Pago documenta selectedPaymentMethod separado de formData. En
    // algunos flujos de débito formData trae payment_method_id (ej. debmaster)
    // pero no payment_type_id. Enviamos ambos para que el backend pueda resolver
    // el tipo sin rechazar una tarjeta que el propio Brick ya tokenizó.
    const payloadToSend = {
      ...(formData || {}),
      payment_type_id: formData?.payment_type_id || normalizedSelectedPaymentMethod,
      selected_payment_method: selectedPaymentMethod || null
    };

    console.info('[BarLytics / Mercado Pago] submit', {
      selectedPaymentMethod,
      paymentMethodId: formData?.payment_method_id || null,
      paymentTypeId: payloadToSend.payment_type_id || null,
      hasToken: Boolean(formData?.token)
    });

    const response = await fetch(cfg.apiBaseUrl + '/api/v1/subscriptions/checkout/recurring/authorize', {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + cfg.authToken,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payloadToSend)
    });

    let payload = null;
    try { payload = await response.json(); } catch (_) {}
    if (!response.ok || !payload || payload.success === false) {
      throw new Error(apiMessage(payload));
    }
    return payload.data || {};
  };

  const createBrick = async () => {
    const container = getContainer();
    if (!container) {
      window.setTimeout(createBrick, 40);
      return;
    }
    if (!window.MercadoPago) {
      window.setTimeout(createBrick, 80);
      return;
    }

    // HtmlElementView puede insertar el nodo antes de que Flutter termine su
    // layout. Payment Brick calcula dimensiones de varios SVG al inicializarse;
    // si el contenedor todavía mide 0 px Mercado Pago puede terminar generando
    // width="" / height="" en sus iconos internos.
    const rect = container.getBoundingClientRect();
    if (!Number.isFinite(rect.width) || rect.width < 280) {
      window.setTimeout(createBrick, 60);
      return;
    }

    if (!cfg.publicKey || !cfg.authToken || !cfg.apiBaseUrl) {
      setStatus('Mercado Pago no está configurado completamente.');
      return;
    }

    try {
      if (window.__barlyticsMpControllers[cfg.instanceId]) {
        try { window.__barlyticsMpControllers[cfg.instanceId].unmount(); } catch (_) {}
      }
      container.innerHTML = '';

      const mp = new MercadoPago(cfg.publicKey, { locale: 'es-CO' });
      const bricksBuilder = mp.bricks();
      const settings = {
        initialization: {
          amount: Number(cfg.amount || 0),
          payer: { email: cfg.payerEmail || '' }
        },
        customization: {
          paymentMethods: {
            // BarLytics es una suscripción mensual. Cada renovación se cobra
            // como una única transacción mensual, no como una compra financiada
            // en varias cuotas.
            minInstallments: 1,
            maxInstallments: 1,
            creditCard: 'all',
            // El mismo Payment Brick tokeniza tarjetas débito disponibles para
            // la cuenta/país. El backend valida el payment_type_id antes de
            // crear la preapproval recurrente.
            debitCard: 'all'
          },
          visual: {
            // Abrimos el formulario de tarjeta por defecto. El usuario puede
            // ingresar crédito o débito y Mercado Pago identifica el tipo.
            defaultPaymentOption: {
              creditCardForm: true
            },
            style: {
              // Conservamos el motor de estados del tema oscuro oficial y solo
              // sustituimos variables CSS soportadas por Mercado Pago. Esto
              // mantiene contraste/validaciones y alinea el Brick con BarLytics.
              theme: 'dark',
              customVariables: {
                formBackgroundColor: '#0B2634',
                inputBackgroundColor: '#123D4F',
                textPrimaryColor: '#F8FAFC',
                textSecondaryColor: '#CBD5E1',
                baseColor: '#21E6BE',
                baseColorFirstVariant: '#0FBF9E',
                baseColorSecondVariant: '#38BDF8',
                // Superficies secundarias y opción de pago seleccionada.
                // Evita el violeta del tema dark y mantiene la paleta BarLytics.
                secondaryColor: '#123D4F',
                secondaryColorListItem: '#164E63',
                outlinePrimaryColor: '#245264',
                outlineSecondaryColor: '#173F50',
                buttonTextColor: '#04131E',
                errorColor: '#FF6B6B',
                successColor: '#34D399',
                successSecondaryColor: '#0FBF9E',
                borderRadiusSmall: '8px',
                borderRadiusMedium: '12px',
                borderRadiusLarge: '16px',
                formPadding: '12px'
              }
            }
          }
        },
        callbacks: {
          onReady: () => {
            setStatus('');
            hidePrefilledPayerEmailSection();
            reportHeight();
            window.setTimeout(() => {
              hidePrefilledPayerEmailSection();
              reportHeight();
            }, 250);
            window.setTimeout(() => {
              hidePrefilledPayerEmailSection();
              reportHeight();
            }, 900);
          },
          onSubmit: ({ selectedPaymentMethod, formData }) => new Promise(async (resolve, reject) => {
            try {
              setStatus('');
              const data = await submitToBarLytics(selectedPaymentMethod, formData);
              resolve();

              if (data.redirectUrl) {
                window.setTimeout(() => window.location.assign(data.redirectUrl), 100);
                return;
              }

              setStatus('Pago recibido. Confirmando tu suscripción…', 'success');
              window.setTimeout(() => returnToBarLytics(data), 260);
            } catch (error) {
              console.error('[BarLytics / Mercado Pago]', error);
              setStatus(error?.message || 'No fue posible procesar el pago.');
              reject(error);
            }
          }),
          onError: error => {
            // Las validaciones de campos son responsabilidad visual del Brick.
            console.error('[MercadoPago Payment Brick]', error);
            reportHeight();
          }
        }
      };

      const controller = await bricksBuilder.create('payment', cfg.containerId, settings);
      window.__barlyticsMpControllers[cfg.instanceId] = controller;
      reportHeight();
    } catch (error) {
      console.error('[MercadoPago Payment Brick init]', error);
      setStatus('No fue posible cargar el formulario de Mercado Pago.');
    }
  };

  const observe = () => {
    const container = getContainer();
    if (!container) return;
    if (window.ResizeObserver) new ResizeObserver(reportHeight).observe(container);
    if (window.MutationObserver) {
      new MutationObserver(() => {
        hidePrefilledPayerEmailSection();
        reportHeight();
      }).observe(container, {
        childList: true,
        subtree: true,
        attributes: true
      });
    }
  };

  createBrick();
  window.setTimeout(observe, 120);
})();
''';

  @override
  void dispose() {
    _messageSubscription?.cancel();
    html.document.getElementById(_scriptId)?.remove();

    final cleanup = html.ScriptElement()
      ..text = '''
(() => {
  const controllers = window.__barlyticsMpControllers || {};
  const controller = controllers['$_instanceId'];
  if (controller) {
    try { controller.unmount(); } catch (_) {}
    delete controllers['$_instanceId'];
  }
})();
''';
    html.document.body?.append(cleanup);
    Future<void>.delayed(const Duration(milliseconds: 50), cleanup.remove);
    _root.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: double.infinity,
        height: _height,
        child: HtmlElementView(viewType: _viewType),
      ),
    );
  }
}
