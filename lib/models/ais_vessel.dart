class AisVessel {
  final int mmsi;
  final String name;
  final double lat;
  final double lon;
  final double sog;
  final double cog;
  final int shipType;
  final DateTime timestamp;

  AisVessel({
    required this.mmsi,
    required this.name,
    required this.lat,
    required this.lon,
    required this.sog,
    required this.cog,
    required this.shipType,
    required this.timestamp,
  });

  factory AisVessel.fromJson(Map<String, dynamic> json) {
    return AisVessel(
      mmsi: json['mmsi'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      sog: (json['sog'] as num?)?.toDouble() ?? 0.0,
      cog: (json['cog'] as num?)?.toDouble() ?? 0.0,
      shipType: json['shipType'] as int? ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : DateTime.now(),
    );
  }
}
