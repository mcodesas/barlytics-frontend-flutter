import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'event_visual_kit.dart';

/// Entrada y comprobante de reserva con diseño adaptable a móvil y escritorio.
/// Respeta los colores del evento, sin cambiar el token ni el estado del pago.
class EventDigitalTicketView extends StatelessWidget {
  const EventDigitalTicketView({
    super.key,
    required this.token,
    required this.value,
    required this.error,
    required this.palette,
    required this.qrUrl,
    required this.onRefresh,
    required this.onFinish,
    required this.onPay,
  });

  final String token;
  final Map<String, dynamic>? value;
  final String? error;
  final EventPagePalette palette;
  final String Function(String token) qrUrl;
  final VoidCallback onRefresh;
  final VoidCallback onFinish;
  final Future<void> Function(String url) onPay;

  String _str(Object? raw, [String fallback = '']) {
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _date(Object? raw) {
    final date = DateTime.tryParse(_str(raw));
    if (date == null) return 'Por confirmar';
    return DateFormat("EEE d MMM yyyy · h:mm a", 'es_CO').format(date);
  }

  String get _status => _str(value?['estado']);
  bool get _confirmed => _status == 'CONFIRMADA';

  String get _statusTitle {
    switch (_status) {
      case 'CONFIRMADA':
        return 'Reserva confirmada';
      case 'PENDIENTE_PAGO':
        return 'Pendiente de pago';
      case 'PENDIENTE_REVISION':
        return 'Pendiente de aprobación';
      case 'EXPIRADA':
        return 'Reserva vencida';
      case 'REEMBOLSO_PENDIENTE':
        return 'Devolución en revisión';
      case 'REEMBOLSADA':
        return 'Reserva reembolsada';
      case 'CANCELADA':
        return 'Reserva cancelada';
      default:
        return error != null ? 'No se pudo cargar la entrada' : 'Consultando reserva';
    }
  }

  IconData get _statusIcon {
    switch (_status) {
      case 'CONFIRMADA':
        return Icons.verified_rounded;
      case 'PENDIENTE_PAGO':
      case 'PENDIENTE_REVISION':
        return Icons.schedule_rounded;
      case 'REEMBOLSO_PENDIENTE':
        return Icons.support_agent_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color get _statusColor {
    if (_confirmed) return const Color(0xFF38CFA1);
    if (_status == 'PENDIENTE_PAGO' || _status == 'PENDIENTE_REVISION') {
      return const Color(0xFFFFC678);
    }
    return const Color(0xFFFF9F9F);
  }

  Widget _panel({required Widget child, EdgeInsets padding = const EdgeInsets.all(20)}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border.withOpacity(.68)),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, String subtitle, IconData icon) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 43,
        height: 43,
        decoration: BoxDecoration(
          color: palette.accentOnSurface.withOpacity(.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: palette.accentOnSurface, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w900,
            color: palette.onSurface,
          )),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(
            height: 1.45, fontSize: 13, color: palette.muted,
          )),
        ],
      )),
    ]);
  }

  Widget _hero() {
    final photo = eventPhoto(value?['imagen']);
    final ink = photo == null ? palette.onSurface : Colors.white;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 236),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.border.withOpacity(.72)),
      ),
      child: Stack(children: [
        Positioned.fill(child: photo == null
          ? DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [palette.surfaceSoft, palette.surface, palette.canvas],
              ),
            ))
          : Image(image: photo, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                ColoredBox(color: palette.surface))),
        Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: photo == null
              ? [Colors.transparent, palette.canvas.withOpacity(.65)]
              : [Colors.black.withOpacity(.48), Colors.black.withOpacity(.85)],
          ),
        ))),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 25),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.confirmation_number_outlined, size: 18, color: ink),
              const SizedBox(width: 8),
              Expanded(child: Text('ENTRADA DIGITAL',
                style: TextStyle(
                  color: ink, fontSize: 11,
                  letterSpacing: 2, fontWeight: FontWeight.w800,
                ),
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(photo == null ? .13 : .42),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: ink.withOpacity(.32)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_statusIcon, color: _confirmed
                    ? const Color(0xFF83F5CE) : ink, size: 15),
                  const SizedBox(width: 5),
                  Text(_confirmed ? 'Confirmada' : 'En seguimiento',
                    style: TextStyle(color: ink,
                      fontSize: 11, fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
            const SizedBox(height: 41),
            Text(_str(value?['sucursal'], 'Organizador del evento'),
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: ink.withOpacity(.85),
                fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_str(value?['evento'], 'Tu próximo evento'),
              maxLines: 3, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: ink, fontSize: 31,
                height: 1.12, fontWeight: FontWeight.w900)),
            const SizedBox(height: 13),
            Container(width: 58, height: 4, decoration: BoxDecoration(
              color: photo == null ? palette.accentOnSurface : Colors.white,
              borderRadius: BorderRadius.circular(4))),
          ]),
        ),
      ]),
    );
  }

  Widget _dateTile(IconData icon, String label, Object? date) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: palette.border.withOpacity(.5)),
      ),
      child: Row(children: [
        Icon(icon, color: palette.accentOnSoft, size: 22),
        const SizedBox(width: 11),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: TextStyle(
              color: palette.onSurfaceSoft.withOpacity(.8),
              fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(_date(date), style: TextStyle(
              color: palette.onSurfaceSoft, fontWeight: FontWeight.w800,
              fontSize: 13)),
          ],
        )),
      ]),
    );
  }

  Widget _summary() {
    final rawTables = value?['mesas'];
    final tables = rawTables is List ? rawTables : const <dynamic>[];
    final individual = value?['entradaIndividual'] == true;
    final places = _str(value?['puestos'], '1');
    return _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Detalles de la reserva',
        'Tu ubicación y horario para disfrutar el evento.',
        Icons.event_seat_outlined),
      const SizedBox(height: 18),
      Wrap(spacing: 9, runSpacing: 9, children: [
        _detailChip(Icons.event_seat_rounded,
          tables.length > 1 ? 'Varias mesas' :
            'Mesa ' + _str(value?['mesa'], '—')),
        _detailChip(Icons.groups_2_outlined,
          places + (places == '1' ? ' puesto' : ' puestos')),
        if (individual && value?['sillaEntrada'] != null)
          _detailChip(Icons.chair_alt_outlined,
            'Puesto ' + _str(value?['sillaEntrada'])),
      ]),
      if (tables.length > 1) ...[
        const SizedBox(height: 12),
        for (final row in tables)
          if (row is Map) Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              'Mesa ' + _str(row['numero']) + ' · ' +
                _str(row['puestos']) + ' puestos',
              style: TextStyle(color: palette.onSurface, fontSize: 13)),
          ),
      ],
      const SizedBox(height: 18),
      LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 470) {
          return Column(children: [
            _dateTile(Icons.login_rounded, 'Inicio', value?['inicio']),
            const SizedBox(height: 9),
            _dateTile(Icons.logout_rounded, 'Fin', value?['fin']),
          ]);
        }
        return Row(children: [
          Expanded(child: _dateTile(
            Icons.login_rounded, 'Inicio', value?['inicio'])),
          const SizedBox(width: 10),
          Expanded(child: _dateTile(
            Icons.logout_rounded, 'Fin', value?['fin'])),
        ]);
      }),
    ]));
  }

  Widget _detailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: palette.border.withOpacity(.7)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: palette.accentOnSoft, size: 17),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: palette.onSurfaceSoft,
          fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _qr(String ticketToken, double size) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x18000000),
            blurRadius: 15, offset: Offset(0, 7)),
        ],
      ),
      child: Image.network(
        qrUrl(ticketToken),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => SizedBox(
          width: size, height: size,
          child: const Center(child: Text(
            'No se pudo cargar el código QR.\nUsa el botón de descarga.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black87, fontSize: 13),
          )),
        ),
      ),
    );
  }

  Future<void> _openSafe(String raw) async {
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _ticketCard({
    required String ticketToken,
    required String number,
    required String seat,
    String? digitalUrl,
  }) {
    return _panel(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 510;
        final qr = _qr(ticketToken, wide ? 184 : 210);
        final details = Column(
          crossAxisAlignment: wide
            ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Text('ACCESO PERSONAL', style: TextStyle(
              color: palette.accentOnSurface, fontSize: 10,
              fontWeight: FontWeight.w900, letterSpacing: 1.6)),
            const SizedBox(height: 9),
            Text('Entrada ' + number,
              textAlign: wide ? TextAlign.start : TextAlign.center,
              style: TextStyle(color: palette.onSurface,
                fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(seat, textAlign: wide ? TextAlign.start : TextAlign.center,
              style: TextStyle(color: palette.muted, fontSize: 14)),
            const SizedBox(height: 17),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.verified_outlined,
                color: EventPagePalette.readable(
                  _statusColor, palette.surface), size: 16),
              const SizedBox(width: 7),
              Text('Lista para presentar',
                style: TextStyle(color: palette.onSurface,
                  fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 18),
            if (digitalUrl != null && digitalUrl.isNotEmpty) ...[
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: () => _openSafe(digitalUrl),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Ver entrada digital'),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: palette.onAccent,
                  padding: const EdgeInsets.symmetric(vertical: 13)),
              )),
              const SizedBox(height: 9),
            ],
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () => _openSafe(qrUrl(ticketToken)),
              icon: const Icon(Icons.download_rounded, size: 19),
              label: const Text('Descargar QR'),
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.onSurface,
                side: BorderSide(color: palette.border),
                padding: const EdgeInsets.symmetric(vertical: 13)),
            )),
          ],
        );

        if (!wide) {
          return Column(children: [
            details,
            const SizedBox(height: 18),
            qr,
            const SizedBox(height: 8),
            Text('Presenta este QR al ingresar.',
              style: TextStyle(color: palette.muted, fontSize: 12)),
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          qr,
          const SizedBox(width: 24),
          Expanded(child: details),
        ]);
      }),
    );
  }

  Widget _tickets() {
    final individual = value?['entradaIndividual'] == true;
    final raw = value?['entradas'];
    final tickets = raw is List ? raw : const <dynamic>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(individual ? 'Tu entrada' : 'Tus entradas individuales',
        individual ? 'Tu código de acceso es personal.' :
          'Cada asistente tiene su propio código QR. Puedes descargarlo o abrirlo.',
        Icons.qr_code_2_rounded),
      const SizedBox(height: 16),
      if (individual || tickets.isEmpty)
        _ticketCard(
          ticketToken: token,
          number: individual
            ? _str(value?['numeroEntrada'], '1') +
                ' de ' + _str(value?['totalEntradas'], '1')
            : 'principal',
          seat: 'Mesa ' + _str(value?['mesa'], '—') +
            (value?['sillaEntrada'] == null ? '' :
              ' · Puesto ' + _str(value?['sillaEntrada'])),
        )
      else
        for (var i = 0; i < tickets.length; i++)
          if (tickets[i] is Map) ...[
            _ticketCard(
              ticketToken: _str((tickets[i] as Map)['token']),
              number: _str((tickets[i] as Map)['numero'],
                (i + 1).toString()) + ' de ' + tickets.length.toString(),
              seat: 'Mesa ' + _str((tickets[i] as Map)['mesa'], '—') +
                ((tickets[i] as Map)['silla'] == null ? '' :
                 ' · Puesto ' + _str((tickets[i] as Map)['silla'])),
              digitalUrl: _str((tickets[i] as Map)['url']),
            ),
            if (i < tickets.length - 1) const SizedBox(height: 12),
          ],
    ]);
  }

  Widget _pending() {
    final message = _str(value?['mensajeEstado'],
      error ?? 'Estamos consultando el estado de tu reserva.');
    final payment = _str(value?['checkoutUrl']);
    return _panel(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(_statusIcon, size: 27,
            color: EventPagePalette.readable(_statusColor, palette.surface)),
          const SizedBox(width: 10),
          Expanded(child: Text(_statusTitle,
            style: TextStyle(color: palette.onSurface,
              fontSize: 19, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 12),
        Text(message, style: TextStyle(
          color: palette.muted, height: 1.5, fontSize: 14)),
        if (_status == 'PENDIENTE_PAGO' &&
            value?['vencePago'] != null) ...[
          const SizedBox(height: 12),
          Text('Plazo de pago: ' + _date(value?['vencePago']),
            style: TextStyle(color: palette.onSurface,
              fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 5),
          Text('Actualización automática cada 15 segundos.',
            style: TextStyle(color: palette.muted, fontSize: 12)),
        ],
        if (_status == 'PENDIENTE_PAGO' && payment.isNotEmpty) ...[
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: () => onPay(payment),
            icon: const Icon(Icons.payment_rounded),
            label: const Text('Pagar con Mercado Pago'),
            style: FilledButton.styleFrom(
              foregroundColor: palette.onAccent,
              backgroundColor: palette.accent,
              padding: const EdgeInsets.symmetric(vertical: 15)),
          )),
        ],
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final loading = value == null && error == null;
    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 500 ? 12 : 24,
          vertical: 22,
        ),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 790),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Icons.local_activity_outlined,
                color: EventPagePalette.readable(
                  palette.accent, palette.canvas), size: 19),
              const SizedBox(width: 9),
              Expanded(child: Text('TU EXPERIENCIA · BARLYTICS',
                style: TextStyle(
                  color: EventPagePalette.readable(
                    palette.text, palette.canvas),
                  fontSize: 11, letterSpacing: 1.1,
                  fontWeight: FontWeight.w800),
              )),
            ]),
            const SizedBox(height: 17),
            _hero(),
            const SizedBox(height: 16),
            if (!loading && value != null) ...[
              _panel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 16),
                child: Row(children: [
                  Icon(_statusIcon,
                    color: EventPagePalette.readable(
                      _statusColor, palette.surface), size: 28),
                  const SizedBox(width: 13),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_statusTitle, style: TextStyle(
                        color: palette.onSurface, fontSize: 17,
                        fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(_str(value?['mensajeEstado'],
                        'Consulta los detalles de tu reserva.'),
                        style: TextStyle(
                          color: palette.muted, fontSize: 12, height: 1.4)),
                    ],
                  )),
                ]),
              ),
              const SizedBox(height: 16),
              _summary(),
              const SizedBox(height: 25),
              if (_confirmed) _tickets() else _pending(),
            ] else if (loading)
              _panel(child: const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              ))
            else
              _pending(),
            const SizedBox(height: 26),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              key: const Key('event-ticket-finish'),
              onPressed: onFinish,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Finalizar · Volver al evento'),
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: palette.onAccent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17))),
            )),
            const SizedBox(height: 8),
            Center(child: TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 19),
              label: const Text('Actualizar estado'),
              style: TextButton.styleFrom(
                foregroundColor: EventPagePalette.readable(
                  palette.text, palette.canvas)),
            )),
            const SizedBox(height: 24),
          ]),
        )),
      )),
    );
  }
}
