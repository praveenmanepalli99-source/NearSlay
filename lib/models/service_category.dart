import 'package:flutter/material.dart';

enum ServiceType {
  all,
  catering,
  plumber,
  electrician,
  mechanic,
  doctor,
  hotel,
  restaurant,
  decoration,
  tentHouse,
  carpenter,
  applianceRepair,
  painter,
  djSound,
}

class ServiceCategory {
  final ServiceType type;
  final String title;
  final IconData icon;
  final Color color;
  final String description;
  final int averagePrice;

  const ServiceCategory({
    required this.type,
    required this.title,
    required this.icon,
    required this.color,
    required this.description,
    required this.averagePrice,
  });

  static List<ServiceCategory> get defaultCategories => [
        const ServiceCategory(
          type: ServiceType.all,
          title: 'All Services',
          icon: Icons.grid_view_rounded,
          color: Color(0xFF00875A),
          description: 'Browse all verified local services & technicians',
          averagePrice: 199,
        ),
        const ServiceCategory(
          type: ServiceType.catering,
          title: 'Catering',
          icon: Icons.restaurant_menu_rounded,
          color: Color(0xFFD97706),
          description: 'Event catering, party food orders, buffets & meal boxes',
          averagePrice: 499,
        ),
        const ServiceCategory(
          type: ServiceType.mechanic,
          title: 'Mechanic',
          icon: Icons.build_rounded,
          color: Color(0xFFEA580C),
          description: 'Bike & car repairs, puncture, oil change & tune-ups',
          averagePrice: 299,
        ),
        const ServiceCategory(
          type: ServiceType.doctor,
          title: 'Doctor',
          icon: Icons.medical_services_rounded,
          color: Color(0xFF059669),
          description: 'Home visits, general physicians & clinic consultations',
          averagePrice: 499,
        ),
        const ServiceCategory(
          type: ServiceType.hotel,
          title: 'Hotel',
          icon: Icons.hotel_rounded,
          color: Color(0xFF6366F1),
          description: 'Hotels, rooms, lodges & guest accommodations',
          averagePrice: 999,
        ),
        const ServiceCategory(
          type: ServiceType.restaurant,
          title: 'Restaurant',
          icon: Icons.restaurant_rounded,
          color: Color(0xFFF97316),
          description: 'Dining, family restaurants, catering & food takeaway',
          averagePrice: 299,
        ),
        const ServiceCategory(
          type: ServiceType.decoration,
          title: 'Decoration',
          icon: Icons.celebration_rounded,
          color: Color(0xFFEC4899),
          description: 'Event & stage decor, balloon & flower decoration',
          averagePrice: 1499,
        ),
        const ServiceCategory(
          type: ServiceType.tentHouse,
          title: 'Tent House',
          icon: Icons.holiday_village_rounded,
          color: Color(0xFF0891B2),
          description: 'Shamiana, tent, sound, stage & chairs rental for events',
          averagePrice: 1999,
        ),
        const ServiceCategory(
          type: ServiceType.plumber,
          title: 'Plumber',
          icon: Icons.plumbing_rounded,
          color: Color(0xFF0284C7),
          description: 'Tap leakages, pipe blockages & sanitary repairs',
          averagePrice: 199,
        ),
        const ServiceCategory(
          type: ServiceType.electrician,
          title: 'Electrician',
          icon: Icons.bolt_rounded,
          color: Color(0xFFF59E0B),
          description: 'Short circuit, fan fitting, MCB switch repairs',
          averagePrice: 249,
        ),
        const ServiceCategory(
          type: ServiceType.carpenter,
          title: 'Carpenter',
          icon: Icons.handyman_rounded,
          color: Color(0xFF854D0E),
          description: 'Door hinge fixes, furniture assembly, lock replacement',
          averagePrice: 249,
        ),
        const ServiceCategory(
          type: ServiceType.applianceRepair,
          title: 'Appliance Repair',
          icon: Icons.tv_rounded,
          color: Color(0xFF7C3AED),
          description: 'AC servicing, washing machine, fridge & microwave fix',
          averagePrice: 349,
        ),
        const ServiceCategory(
          type: ServiceType.painter,
          title: 'Painter',
          icon: Icons.format_paint_rounded,
          color: Color(0xFF0D9488),
          description: 'Wall touchups, waterproofing, door polish',
          averagePrice: 399,
        ),
        const ServiceCategory(
          type: ServiceType.djSound,
          title: 'DJ & Sound System',
          icon: Icons.speaker_group_rounded,
          color: Color(0xFF9333EA),
          description: 'DJ setup, party sound systems, speakers & event audio',
          averagePrice: 1499,
        ),
      ];
}
