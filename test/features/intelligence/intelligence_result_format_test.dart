import 'package:flutter_test/flutter_test.dart';
import '../../../lib/features/intelligence/domain/intelligence_result_format.dart';

void main(){
  test('formats Colombian money, labels, percentages and exact IDs',(){
    expect(IntelligenceResultFormat.cell('ganancia_neta_estimada_periodo',625306.76,'ganancias'),r'$625.306,76');
    expect(IntelligenceResultFormat.cell('margen_neto_porcentaje',14.72,'ganancias'),'14,72 %');
    expect(IntelligenceResultFormat.cell('prod_id','123456789012345678','productos'),'123456789012345678');
    expect(IntelligenceResultFormat.cell('invt_cantidad',1.125,'inventario'),'1,125');
    expect(IntelligenceResultFormat.label('ganancia_neta_estimada_periodo'),'Ganancia neta estimada');
    expect(IntelligenceResultFormat.measure('prod_id',123,'productos'),isNull);
    expect(IntelligenceResultFormat.measure('total','123.50','reporte_ventas_fecha'),123.5);
  });
}
