import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_public_landing.dart';

void main(){
  test('Reserva automática permite cupo sumado en varias mesas',(){
    expect(eventAvailableSeats([
      {'id':1,'capacidad':4,'disponibles':4},
      {'id':2,'capacidad':6,'disponibles':6},
      {'id':3,'capacidad':8,'disponibles':0}
    ]),10);
  });
  test('Mesas reservadas y valores negativos no suman disponibilidad',(){
    expect(eventAvailableSeats([
      {'disponibles':0},
      {'disponibles':-2},
      {'disponibles':'5'},
      {'disponibles':null}
    ]),5);
  });
}
