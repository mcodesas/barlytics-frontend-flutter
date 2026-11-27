import 'package:intl/intl.dart';

/// Display only: the original dataset remains unchanged for exports.
class IntelligenceResultFormat {
  static const labels=<String,String>{
    'ganancia_neta_estimada_periodo':'Ganancia neta estimada','ingresos_periodo':'Ingresos',
    'costo_ventas_periodo':'Costo de ventas','ganancia_bruta_periodo':'Ganancia bruta',
    'gastos_operativos_periodo':'Gastos operativos','gastos_fijos_periodo':'Gastos fijos',
    'gastos_turno_periodo':'Gastos de turno','mano_obra_periodo':'Mano de obra',
    'margen_neto_porcentaje':'Margen neto','margen_bruto_porcentaje':'Margen bruto',
    'subtotal_productos':'Ventas de productos','ticket_promedio':'Ticket promedio',
    'propinas':'Propinas','ventas':'Ventas finalizadas','prod_nombre':'Producto',
    'prod_descripcion':'Descripción','prec_valorventa':'Precio de venta',
    'prec_valorcompra':'Precio de compra','invt_cantidad':'Cantidad en inventario',
    'prod_catalogo_activo':'Activo en catálogo','prod_stock_minimo':'Stock mínimo',
    'prod_stock_maximo':'Stock máximo','prod_id':'ID de producto','sucu_id':'ID de sucursal',
    'vent_id':'ID de venta','mepa_id':'ID de medio de pago','medio_pago':'Medio de pago',
  };
  static const monetary=<String>{
    'ingresos_periodo','costo_ventas_periodo','ganancia_bruta_periodo','gastos_operativos_periodo',
    'gastos_fijos_periodo','gastos_turno_periodo','mano_obra_periodo','ganancia_neta_estimada_periodo',
    'salidas_caja_periodo','pagos_pedidos_periodo','pagos_gastos_configurados_periodo','gastos_variables_periodo',
    'subtotal_productos','propinas','ticket_promedio','prec_valorventa','prec_valorcompra',
    'vent_total','vent_propina','cuev_total','cuev_propina','decv_subtotal','pacv_monto','pacv_valorrecibido',
    'pacv_cambio','cica_totalsistema','cica_totalpropina','cica_totalentregado','cica_valorbase','cica_totalgastos',
    'cica_diferencia','ciga_valor','cimp_totalsistema','cimp_totalentregado','cimp_diferencia','saca_valor',
    'gafi_valor','gafd_valor','pedi_total_estimado','depe_subtotal','pepa_valor','saldo_inicial','importe',
  };
  static String key(String k)=>k.toLowerCase().replaceFirst(RegExp(r'^r[0-3]\.'),'');
  static bool identifier(String k)=>key(k)=='id'||key(k).endsWith('_id')||key(k).endsWith('_numero');
  static bool percent(String k)=>key(k)=='porcentaje'||key(k).endsWith('_porcentaje');
  static bool money(String k,String resource)=>monetary.contains(key(k))||
      (key(k)=='total'&&const {'reporte_ventas_fecha','reporte_ventas_medio_pago'}.contains(resource));
  static String label(String k){
    final name=key(k);
    if(labels.containsKey(name))return labels[name]!;
    if(name.isEmpty)return 'Dato';
    final words=name.replaceAll('_',' ');
    return words[0].toUpperCase()+words.substring(1);
  }
  static num? measure(String k,dynamic v,String resource){
    if(identifier(k))return null;
    if(v is num&&v.isFinite)return v;
    if(v is String&&(money(k,resource)||percent(k))){
      final n=num.tryParse(v);
      if(n!=null&&n.isFinite)return n;
    }
    return null;
  }
  static String cell(String k,dynamic v,String resource){
    if(v==null)return 'Sin dato';
    if(v is bool)return v?'Sí':'No';
    if(identifier(k))return v.toString();
    final n=measure(k,v,resource);
    if(n==null)return v.toString();
    if(money(k,resource)||percent(k)){
      final formatted=NumberFormat('#,##0.00','es_CO').format(n);
      return money(k,resource)?r'$'+formatted:formatted+' %';
    }
    // Non-monetary decimals retain their original digits.
    final raw=v.toString();
    final parts=raw.split('.');
    if(parts.length>2||!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(raw))return raw;
    final sign=parts.first.startsWith('-')?'-':'';
    final digits=sign.isEmpty?parts.first:parts.first.substring(1);
    final grouped=StringBuffer(sign);
    for(int i=0;i<digits.length;i++){
      if(i>0&&(digits.length-i)%3==0)grouped.write('.');
      grouped.write(digits[i]);
    }
    if(parts.length==2)grouped.write(','+parts[1]);
    return grouped.toString();
  }
}
