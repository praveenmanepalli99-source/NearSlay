import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/colony_model.dart';

class LocationService {
  /// Known accurate coordinate mapping for popular colonies and cities in Telangana/AP/Karnataka
  static const Map<String, Map<String, dynamic>> knownColonies = {
    'kphb': {
      'lat': 17.4933,
      'lng': 78.3995,
      'city': 'Hyderabad',
      'landmark': 'Near KPHB Metro Station',
      'pin': '500072'
    },
    'kphb colony': {
      'lat': 17.4933,
      'lng': 78.3995,
      'city': 'Hyderabad',
      'landmark': 'Phase 1 to 9, KPHB',
      'pin': '500072'
    },
    'kukatpally': {
      'lat': 17.4849,
      'lng': 78.4138,
      'city': 'Hyderabad',
      'landmark': 'Near Kukatpally Metro Station',
      'pin': '500072'
    },
    'ktps': {
      'lat': 17.5980,
      'lng': 80.6970,
      'city': 'Palvancha',
      'landmark': 'Near KTPS Power Station',
      'pin': '507115'
    },
    'palvancha': {
      'lat': 17.5980,
      'lng': 80.6970,
      'city': 'Palvancha',
      'landmark': 'Palvancha Town',
      'pin': '507115'
    },
    'kothagudem': {
      'lat': 17.5524,
      'lng': 80.6174,
      'city': 'Kothagudem',
      'landmark': 'Kothagudem Town',
      'pin': '507101'
    },
    'banjara hills': {
      'lat': 17.4156,
      'lng': 78.4350,
      'city': 'Hyderabad',
      'landmark': 'Road No 12',
      'pin': '500034'
    },
    'jubilee hills': {
      'lat': 17.4319,
      'lng': 78.4073,
      'city': 'Hyderabad',
      'landmark': 'Road No 36',
      'pin': '500033'
    },
    'madhapur': {
      'lat': 17.4483,
      'lng': 78.3915,
      'city': 'Hyderabad',
      'landmark': 'Cyber Towers Area',
      'pin': '500081'
    },
    'hitec city': {
      'lat': 17.4435,
      'lng': 78.3772,
      'city': 'Hyderabad',
      'landmark': 'HITEC City Metro',
      'pin': '500081'
    },
    'gachibowli': {
      'lat': 17.4401,
      'lng': 78.3489,
      'city': 'Hyderabad',
      'landmark': 'Gachibowli Stadium Road',
      'pin': '500032'
    },
    'ameerpet': {
      'lat': 17.4375,
      'lng': 78.4482,
      'city': 'Hyderabad',
      'landmark': 'Ameerpet Crossroads',
      'pin': '500016'
    },
    'green glen layout': {
      'lat': 12.9298,
      'lng': 77.6749,
      'city': 'Bengaluru',
      'landmark': 'Outer Ring Road, Bellandur',
      'pin': '560103'
    },
    'indiranagar': {
      'lat': 12.9784,
      'lng': 77.6408,
      'city': 'Bengaluru',
      'landmark': '100ft Road',
      'pin': '560038'
    },
    'koramangala': {
      'lat': 12.9352,
      'lng': 77.6245,
      'city': 'Bengaluru',
      'landmark': 'Sony World Signal',
      'pin': '560034'
    },
  };

  /// Proactively requests location permission on all devices (including Vivo/OEMs)
  static Future<bool> requestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    } catch (e) {
      if (kDebugMode) {
        print('Location permission request error: $e');
      }
      return false;
    }
  }

  /// Request GPS permission and fetch live current colony/city
  static Future<ColonyModel?> getLiveLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current GPS position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      String colonyName = 'My Live Location';
      String cityName = 'Current Location';
      String landmark = 'Near Current GPS Area';
      String pincode = '';

      // Reverse geocode to get real human-readable colony and city
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;

          // Extract best colony/neighborhood representation
          final subLocality = place.subLocality?.trim() ?? '';
          final thoroughfare = place.thoroughfare?.trim() ?? '';
          final name = place.name?.trim() ?? '';
          final locality = place.locality?.trim() ?? '';
          final subAdmin = place.subAdministrativeArea?.trim() ?? '';
          final admin = place.administrativeArea?.trim() ?? '';

          if (subLocality.isNotEmpty && subLocality != locality) {
            colonyName = subLocality;
          } else if (thoroughfare.isNotEmpty) {
            colonyName = thoroughfare;
          } else if (name.isNotEmpty && !name.contains('+') && !name.contains(locality)) {
            colonyName = name;
          } else if (locality.isNotEmpty) {
            colonyName = locality;
          }

          if (locality.isNotEmpty) {
            cityName = locality;
          } else if (subAdmin.isNotEmpty) {
            cityName = subAdmin;
          } else if (admin.isNotEmpty) {
            cityName = admin;
          }

          if (place.postalCode != null && place.postalCode!.isNotEmpty) {
            pincode = place.postalCode!;
          }

          if (place.street != null && place.street!.isNotEmpty) {
            landmark = place.street!;
          } else {
            landmark = '$colonyName, $cityName';
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Reverse geocoding error: $e');
        }
      }

      return ColonyModel(
        id: 'gps_${position.latitude.toStringAsFixed(3)}_${position.longitude.toStringAsFixed(3)}',
        name: colonyName,
        landmark: landmark,
        city: cityName,
        pincode: pincode,
        latitude: position.latitude,
        longitude: position.longitude,
        activeProvidersCount: 0,
      );
    } catch (e) {
      if (kDebugMode) {
        print('GPS location retrieval error: $e');
      }
      return null;
    }
  }

  /// Resolve coordinates for any colony by checking known list first, then online geocoding
  static Future<ColonyModel> resolveColonyCoordinates(ColonyModel colony) async {
    // If coordinates are already non-zero and valid
    if (colony.latitude != 0.0 &&
        colony.longitude != 0.0 &&
        !(colony.latitude == 12.9298 && colony.longitude == 77.6749 && !colony.name.toLowerCase().contains('green glen'))) {
      return colony;
    }

    final key = colony.name.toLowerCase().trim();
    for (final entry in knownColonies.entries) {
      if (key == entry.key || key.contains(entry.key) || entry.key.contains(key)) {
        final data = entry.value;
        return colony.copyWith(
          latitude: data['lat'] as double,
          longitude: data['lng'] as double,
          city: (colony.city.isNotEmpty && colony.city != 'Current Location' && colony.city != 'India')
              ? colony.city
              : data['city'] as String,
          pincode: (colony.pincode.isNotEmpty && colony.pincode != '500001')
              ? colony.pincode
              : (data['pin'] as String? ?? '500072'),
        );
      }
    }

    // Try online geocoding if network is available
    try {
      final query = colony.city.isNotEmpty && colony.city != 'Current Location'
          ? '${colony.name}, ${colony.city}'
          : colony.name;
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        return colony.copyWith(
          latitude: locations.first.latitude,
          longitude: locations.first.longitude,
        );
      }
    } catch (_) {}

    return colony;
  }

  /// Search locations globally/in India using OpenStreetMap Nominatim with Geocoding fallback
  static Future<List<ColonyModel>> searchLocations(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    final List<ColonyModel> results = [];

    // Check known colonies first for fast offline matching
    final qLower = cleanQuery.toLowerCase();
    for (final entry in knownColonies.entries) {
      if (entry.key.contains(qLower) || qLower.contains(entry.key)) {
        final data = entry.value;
        results.add(
          ColonyModel(
            id: 'known_${entry.key.replaceAll(' ', '_')}',
            name: entry.key.split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
            landmark: data['landmark'] as String,
            city: data['city'] as String,
            pincode: data['pin'] as String,
            latitude: data['lat'] as double,
            longitude: data['lng'] as double,
            activeProvidersCount: 0,
          ),
        );
      }
    }

    // 1. Try OpenStreetMap Nominatim Search
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=json&addressdetails=1&countrycodes=in&limit=8',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'NearFix-LocalApp/1.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        for (final item in data) {
          final address = item['address'] as Map<String, dynamic>? ?? {};
          final displayName = (item['display_name'] as String? ?? '').trim();
          final lat = double.tryParse(item['lat']?.toString() ?? '0') ?? 0.0;
          final lon = double.tryParse(item['lon']?.toString() ?? '0') ?? 0.0;

          // Extract best area/colony name
          String name = address['suburb'] ??
              address['neighbourhood'] ??
              address['quarter'] ??
              address['residential'] ??
              address['village'] ??
              address['road'] ??
              address['city_district'] ??
              address['town'] ??
              '';

          if (name.isEmpty) {
            final parts = displayName.split(',');
            name = parts.isNotEmpty ? parts.first.trim() : cleanQuery;
          }

          // Extract best city name
          String city = address['city'] ??
              address['town'] ??
              address['city_district'] ??
              address['state_district'] ??
              address['county'] ??
              address['state'] ??
              'India';

          String pincode = address['postcode'] ?? '500001';
          String landmark = address['road'] ??
              address['suburb'] ??
              (displayName.isNotEmpty ? displayName : '$name, $city');

          // Avoid duplicate IDs
          final osmId = 'osm_${item['place_id'] ?? '${lat}_$lon'}';
          if (!results.any((r) => r.id == osmId || (r.name.toLowerCase() == name.toLowerCase() && r.city.toLowerCase() == city.toLowerCase()))) {
            results.add(
              ColonyModel(
                id: osmId,
                name: name,
                landmark: landmark,
                city: city,
                pincode: pincode,
                latitude: lat,
                longitude: lon,
                activeProvidersCount: 0,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Nominatim search error: $e');
      }
    }

    // 2. Fallback to geocoding if online search returned 0 results
    if (results.isEmpty) {
      try {
        final locations = await locationFromAddress(cleanQuery);
        for (int i = 0; i < locations.length && i < 4; i++) {
          final loc = locations[i];
          final placemarks = await placemarkFromCoordinates(loc.latitude, loc.longitude);
          String cityName = 'India';
          String pin = '500001';
          String landmark = cleanQuery;
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            cityName = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? 'India';
            pin = p.postalCode ?? '500001';
            landmark = p.street ?? '$cleanQuery, $cityName';
          }

          results.add(
            ColonyModel(
              id: 'geo_${loc.latitude}_${loc.longitude}_$i',
              name: cleanQuery,
              landmark: landmark,
              city: cityName,
              pincode: pin,
              latitude: loc.latitude,
              longitude: loc.longitude,
              activeProvidersCount: 0,
            ),
          );
        }
      } catch (_) {}
    }

    return results;
  }

  /// Calculate distance in meters between two GPS coordinates using high-precision Haversine formula
  static double calculateDistanceMeters({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    if (startLat == endLat && startLng == endLng) return 0.0;
    // Missing or invalid coordinates must be treated as distant / unknown (never 0m!)
    if (startLat == 0.0 || startLng == 0.0 || endLat == 0.0 || endLng == 0.0) {
      return 9999999.0;
    }

    const double earthRadiusMeters = 6371000.0;
    final double dLat = _degreesToRadians(endLat - startLat);
    final double dLng = _degreesToRadians(endLng - startLng);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(startLat)) *
            math.cos(_degreesToRadians(endLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }
}
