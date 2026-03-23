import 'package:flutter/material.dart';

enum Role {
  sheriff(sheetValues: ['Шериф'], isBlack: false, chanceToDraw: 0.1,
      color: Color(0xFF00BCD4), lightColor: Color(0xFFE0F7FA)),
  don(sheetValues: ['Дон'], isBlack: true, chanceToDraw: 0.1,
      color: Color(0xFF212121), lightColor: Color(0xFFEEEEEE)),
  civilian(sheetValues: ['Мирный', 'Мирний'], isBlack: false, chanceToDraw: 0.6,
      color: Color(0xFFE53935), lightColor: Color(0xFFFFEBEE)),
  mafia(sheetValues: ['Мафия', 'Мафія'], isBlack: true, chanceToDraw: 0.2,
      color: Color(0xFF616161), lightColor: Color(0xFFF5F5F5));

  const Role({
    required this.sheetValues,
    required this.isBlack,
    required this.chanceToDraw,
    required this.color,
    required this.lightColor,
  });

  final List<String> sheetValues;
  final bool isBlack;
  final double chanceToDraw;
  final Color color;
  final Color lightColor;

  // The canonical single value (last in list) used as map key
  String get sheetValue => sheetValues.last;

  static Role? findByValue(String value) {
    for (final role in values) {
      if (role.sheetValues.contains(value)) return role;
    }
    return null;
  }
}
