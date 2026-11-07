import 'package:flutter/material.dart';

import '../l10n/strings.dart';

/// Hassasiyet ölçeğinin anlamlı bölgeleri: kullanıcı "ne kadar hassas" yerine "nerede" sorusunu yanıtlar.
///
/// Kapalı alanda fan, klima, buzdolabı gibi tonal cihazlar çoktur ve drone ancak yakındayken
/// içeriden duyulur: eşik yüksek tutulur. Açık ve sessiz alanda drone uzaktan ve zayıf gelir:
/// eşik düşürülür, karşılığında yanlış alarm biraz artar.
class EnvZone {
  const EnvZone({required this.id, required this.value, required this.icon});

  final String id;

  /// Bölgeye dokununca seçilen hassasiyet değeri.
  final double value;
  final IconData icon;

  String title(S t) => switch (id) { 'indoor' => t.zoneIndoorTitle, 'city' => t.zoneCityTitle, _ => t.zoneOpenTitle };

  String places(S t) => switch (id) { 'indoor' => t.zoneIndoorPlaces, 'city' => t.zoneCityPlaces, _ => t.zoneOpenPlaces };

  String description(S t) => switch (id) { 'indoor' => t.zoneIndoorText, 'city' => t.zoneCityText, _ => t.zoneOpenText };
}

const kZones = <EnvZone>[
  EnvZone(id: 'indoor', value: 0.2, icon: Icons.house_outlined),
  EnvZone(id: 'city', value: 0.5, icon: Icons.location_city_outlined),
  EnvZone(id: 'open', value: 0.8, icon: Icons.landscape_outlined),
];

EnvZone zoneFor(double sensitivity) {
  if (sensitivity < 0.34) return kZones[0];
  if (sensitivity < 0.67) return kZones[1];
  return kZones[2];
}
