/// Valida el correo que recibirá las entradas de una reserva del bar o llamada.
String? validateInternalBookingEmail(String? raw) {
  final value=(raw??'').trim();
  if(value.isEmpty||value.length>220||
      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)){
    return 'Ingresa un correo válido para recibir las entradas';
  }
  return null;
}
