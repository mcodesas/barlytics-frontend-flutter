import 'package:flutter/services.dart';

/// Límites de entrada compartidos entre los formularios de BarLytics.
///
/// Los tamaños de los campos persistidos reflejan las restricciones actuales
/// del backend/JPA y de PostgreSQL. Mantener estas reglas centralizadas evita
/// que Flutter permita valores que luego fallen al persistirse.
class InputConstraints {
  InputConstraints._();

  static const int search = 120;
  static const int password = 72;
  static const int googleIdToken = 8192;
  static const int supportReason = 500;
  /// Límite de texto base64 aceptado por el backend.
  static const int imageBase64 = 3000000;

  /// 2 MiB de archivo binario mantienen el data URI/base64 por debajo de
  /// los 3.000.000 caracteres admitidos por el backend (base64 agrega ~33%).
  static const int imageMaxBytes = 2 * 1024 * 1024;

  static const Map<String, int> _maxLengths = <String, int>{
    // Autenticación.
    'identificador': 255,
    'password': password,
    'currentPassword': password,
    'newPassword': password,
    'confirmPassword': password,
    'code': 128,
    'idToken': googleIdToken,
    'logiTipo': 30,

    // Empresa y sucursal.
    'empreNombreComercial': 100,
    'emprRazonSocial': 300,
    'emprIdentificacion': 20,
    'emprDireccion': 100,
    'emprCodigoPostal': 30,
    'emprTelefono': 15,
    'emprCorreoElectronico': 200,
    'emprSitioWeb': 300,
    'emprLogo': imageBase64,
    'sucuNombre': 100,
    'sucuCodigoInterno': 50,
    'sucuDireccion': 100,
    'sucuTelefono': 20,

    // Usuarios y perfil.
    'usuaPrimerNombre': 20,
    'usuaSegundoNombre': 20,
    'usuaPrimerApellido': 20,
    'usuaSegundoApellido': 20,
    'usuaEmail': 100,
    'usuaDireccion': 200,
    'usuaTelefonoPrincipal': 13,
    'usuaTelefonoSecundario': 13,
    'primerNombre': 20,
    'segundoNombre': 20,
    'primerApellido': 20,
    'segundoApellido': 20,
    'email': 100,
    'direccion': 200,
    'telefonoPrincipal': 13,
    'telefonoSecundario': 13,

    // Catálogos.
    'ciudNombre': 300,
    'ciudCodigoDane': 10,
    'ciudCodigoPostal': 10,
    'mrcaNombre': 30,
    'mrcaIdentificacion': 50,
    'mepaNombre': 20,
    'mepaDescripcion': 50,
    'menuNombre': 50,
    'menuDescripcion': 100,
    'menuParametro': 50,
    'moneCodigoiso': 10,
    'moneNombre': 50,
    'moneSimbolo': 1,
    'opmeNombre': 50,
    'opmeDescripcion': 100,
    'opmeCodigotraduccion': 10,
    'paisNombre': 200,
    'paisCodigo': 20,
    'regiNombre': 30,
    'regiCodigo': 10,
    'roleNombre': 50,
    'roleDescripcion': 100,
    'tiauNombre': 30,
    'tiaudToken': 300,
    'tiauDescripcion': 50,
    'tiidNombre': 50,
    'tiidDescripcion': 100,
    'timoNombre': 50,
    'timoDescripcion': 100,
    'timoOperacion': 10,
    'tpprNombre': 30,
    'tpprDescripcion': 300,
    'tiusNombre': 50,
    'tiusDescripcion': 100,
    'zohoNombre': 50,
    'zohoDescripcion': 100,
    'zohoAbreviatura': 10,
    'zohoOffsetOut': 10,

    // Operación.
    'cuevDescripcion': 300,
    'mesaEstado': 20,
    'mesaDescripcion': 300,
    'moviMotivo': 100,
    'moviReferencia': 300,
    'moviOperacion': 10,
    'moviUnidad': 30,
    'prodNombre': 120,
    'prodDescripcion': 400,
    'prodPresentacionCompra': 60,
    'ventEstado': 20,
    'tipoVenta': 20,

    // Parámetros.
    'paraCodigo': 80,
    'paraNombre': 100,
    'paraDescripcion': 500,
    'paraTipoDato': 30,
    'paraValor': 1000,
    'paraValorDefecto': 1000,
    'paraGrupo': 50,

    // Suscripciones / planes.
    'planCode': 60,
    'codePlan': 60,
    'planName': 100,
    'planDescription': 500,
    'currency': 3,
    'frequencyType': 20,
    'badge': 50,
    'buttonText': 80,
    'buttonAction': 20,
    'promotionText': 200,
    'planItemText': 220,

    // Pago PSE / proveedor.
    'financialInstitution': 50,
    'entityType': 20,
    'identificationType': 20,
    'identificationNumber': 30,
    'firstName': 100,
    'lastName': 100,
    'phone': 30,
    'zipCode': 20,
    'streetName': 150,
    'streetNumber': 30,
    'neighborhood': 100,
    'city': 100,
    'token': 4096,
    'paymentMethodId': 50,
    'paymentTypeId': 50,
    'selectedPaymentMethod': 50,
    'issuerId': 50,
  };

  // Máximos efectivos para campos enteros editables. Cuando PostgreSQL no
  // define precisión, el límite real lo impone el tipo Integer del backend.
  static const Map<String, int> _integerMaxValues = <String, int>{
    'moneDecimales': 99, // NUMERIC(2,0)
    'precAplicaImpuesto': 1, // contrato funcional 0/1
    'precEstado': 1, // contrato funcional 0/1
    'sucuEstado': 1, // contrato backend 0/1
  };

  /// Cantidad de dígitos enteros y decimales permitidos por PostgreSQL.
  static const Map<String, ({int integer, int fraction})> _decimalLimits =
      <String, ({int integer, int fraction})>{
    'cuevTotal': (integer: 20, fraction: 0),
    'cuevPropina': (integer: 20, fraction: 0),
    'decvCantidad': (integer: 10, fraction: 0),
    'decvSubtotal': (integer: 20, fraction: 0),
    'invtCantidad': (integer: 30, fraction: 0),
    'moviCantidad': (integer: 13, fraction: 2),
    'moviCantidadCapturada': (integer: 13, fraction: 2),
    'moviFactorConversion': (integer: 13, fraction: 2),
    'pacvMonto': (integer: 20, fraction: 0),
    'pacvObservacion': (integer: 30, fraction: 0),
    'pacvValorRecibido': (integer: 18, fraction: 2),
    'pacvCambio': (integer: 18, fraction: 2),
    'precValorVenta': (integer: 15, fraction: 0),
    'precValorCompra': (integer: 15, fraction: 0),
    'precPorcentajeImpuesto': (integer: 3, fraction: 2),
    'precValorImpuesto': (integer: 13, fraction: 2),
    'prodCantidadCompra': (integer: 13, fraction: 2),
    'prodStockMinimo': (integer: 28, fraction: 2),
    'prodStockMaximo': (integer: 28, fraction: 2),
    'ventTotal': (integer: 15, fraction: 0),
    'ventPropina': (integer: 10, fraction: 0),
  };

  static int? maxLengthFor(String fieldName) => _maxLengths[fieldName];

  static ({int integer, int fraction})? decimalLimitFor(String fieldName) =>
      _decimalLimits[fieldName];

  static List<TextInputFormatter> phoneFormatters(int maxLength) =>
      <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\-\s]')),
        LengthLimitingTextInputFormatter(maxLength),
      ];

  static List<TextInputFormatter> digitsFormatters(int maxDigits) =>
      <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxDigits),
      ];

  static List<TextInputFormatter> integerFormatters({
    int minValue = 0,
    int maxValue = 2147483647,
  }) => <TextInputFormatter>[
        minValue < 0
            ? FilteringTextInputFormatter.allow(RegExp(r'[-0-9]'))
            : FilteringTextInputFormatter.digitsOnly,
        IntegerRangeInputFormatter(minValue: minValue, maxValue: maxValue),
      ];

  static List<TextInputFormatter> decimalFormatters({
    required int integerDigits,
    required int fractionDigits,
    bool allowNegative = false,
  }) => <TextInputFormatter>[
        DecimalLimitInputFormatter(
          integerDigits: integerDigits,
          fractionDigits: fractionDigits,
          allowNegative: allowNegative,
        ),
      ];

  static List<TextInputFormatter>? formattersForField(
    String fieldName, {
    bool numeric = false,
    bool decimal = false,
    bool allowNegative = false,
  }) {
    final lower = fieldName.toLowerCase();
    final maxLength = maxLengthFor(fieldName);
    if (lower.contains('telefono') || lower == 'phone') {
      return phoneFormatters(maxLength ?? 30);
    }
    final numericLimit = decimalLimitFor(fieldName);
    if (numericLimit != null) {
      return decimalFormatters(
        integerDigits: numericLimit.integer,
        fractionDigits: numericLimit.fraction,
        allowNegative: allowNegative,
      );
    }
    if (numeric) {
      return integerFormatters(maxValue: _integerMaxValues[fieldName] ?? 2147483647);
    }
    if (decimal) {
      return decimalFormatters(
        integerDigits: 20,
        fractionDigits: 2,
        allowNegative: allowNegative,
      );
    }
    if (maxLength != null) {
      return <TextInputFormatter>[LengthLimitingTextInputFormatter(maxLength)];
    }
    return null;
  }
}

/// Formatter que impide escribir un número que exceda la precisión disponible
/// en la base de datos. Acepta coma o punto como separador decimal.
class DecimalLimitInputFormatter extends TextInputFormatter {
  DecimalLimitInputFormatter({
    required this.integerDigits,
    required this.fractionDigits,
    this.allowNegative = false,
  }) : assert(integerDigits > 0),
       assert(fractionDigits >= 0);

  final int integerDigits;
  final int fractionDigits;
  final bool allowNegative;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final value = newValue.text;
    if (value.isEmpty) return newValue;

    final sign = allowNegative ? r'-?' : '';
    final decimal = fractionDigits == 0
        ? ''
        : r'(?:[\.,]\d{0,' + fractionDigits.toString() + r'})?';
    final regex = RegExp(
      '^$sign' r'\d{0,' + integerDigits.toString() + r'}' + decimal + r'$'
    );

    return regex.hasMatch(value) ? newValue : oldValue;
  }
}


/// Impide que un campo entero exceda el rango que puede recibir el backend
/// o la precisión NUMERIC de PostgreSQL.
class IntegerRangeInputFormatter extends TextInputFormatter {
  IntegerRangeInputFormatter({required this.minValue, required this.maxValue});

  final int minValue;
  final int maxValue;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    if (newValue.text == '-' && minValue < 0) return newValue;
    final value = int.tryParse(newValue.text);
    if (value == null || value < minValue || value > maxValue) return oldValue;
    return newValue;
  }
}
