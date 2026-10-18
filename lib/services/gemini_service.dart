import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/service_category.dart';

class GeminiDiagnosticResult {
  final String issueSummary;
  final String diagnosis;
  final ServiceType recommendedCategory;
  final String categoryTitle;
  final String estimatedRate;
  final List<String> safetyTips;
  final String urgency; // 'Immediate', 'High', 'Normal'

  const GeminiDiagnosticResult({
    required this.issueSummary,
    required this.diagnosis,
    required this.recommendedCategory,
    required this.categoryTitle,
    required this.estimatedRate,
    required this.safetyTips,
    this.urgency = 'Normal',
  });
}

class GeminiService {
  // Can be configured via environment or user settings
  static String apiKey = 'DEMO_KEY';

  static void setApiKey(String key) {
    apiKey = key;
  }

  /// Analyze a resident's issue description using Gemini 1.5 Flash
  static Future<GeminiDiagnosticResult> diagnoseIssue(String userQuery) async {
    if (apiKey.isNotEmpty && apiKey != 'DEMO_KEY') {
      try {
        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: apiKey,
          systemInstruction: Content.system(
            'You are NearSlay Local AI Assistant. Given a service, booking, or repair inquiry, '
            'diagnose the cause, suggest the best repair or local service category from [plumber, electrician, mechanic, carpenter, applianceRepair, painter, catering, djSound, hotel, restaurant, decoration, tentHouse], '
            'estimate standard labor or booking rate in INR, provide 2 quick safety tips, and determine urgency (Immediate, High, Normal). '
            'Respond ONLY with valid JSON in the format: '
            '{"summary": "...", "diagnosis": "...", "category": "plumber/electrician/mechanic/carpenter/applianceRepair/painter/catering/djSound/hotel/restaurant/decoration/tentHouse", "estimated_rate": "₹200 - ₹500 / hr", "urgency": "Immediate/High/Normal", "safety_tips": ["...", "..."]}',
          ),
        );

        final response = await model.generateContent([
          Content.text(userQuery),
        ]);

        final text = response.text;
        if (text != null && text.isNotEmpty) {
          final cleaned = text
              .replaceAll('```json', '')
              .replaceAll('```', '')
              .trim();
          final data = jsonDecode(cleaned) as Map<String, dynamic>;

          final catStr = (data['category'] as String? ?? 'plumber').toLowerCase();
          final category = _parseServiceType(catStr);

          return GeminiDiagnosticResult(
            issueSummary: data['summary'] ?? userQuery,
            diagnosis: data['diagnosis'] ?? 'Service provider inspection recommended.',
            recommendedCategory: category,
            categoryTitle: _getCategoryTitle(category),
            estimatedRate: data['estimated_rate'] ?? 'Starts from ₹250',
            urgency: data['urgency'] ?? 'Normal',
            safetyTips: (data['safety_tips'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                ['Confirm service details and requirements before booking.'],
          );
        }
      } catch (_) {
        // Fallback to offline rule-based diagnosis if network / key error occurs
      }
    }

    // High-accuracy fallback smart rule engine for local execution
    return _generateSmartFallback(userQuery);
  }

  static ServiceType _parseServiceType(String catStr) {
    if (catStr.contains('cater') || catStr.contains('chef') || catStr.contains('cook') || catStr.contains('baking') || catStr.contains('culinary') || catStr.contains('meal') || catStr.contains('buffet')) {
      return ServiceType.catering;
    }
    if (catStr.contains('dj') || catStr.contains('sound') || catStr.contains('audio') || catStr.contains('speaker') || catStr.contains('music') || catStr.contains('amplifier') || catStr.contains('pest')) {
      return ServiceType.djSound;
    }
    if (catStr.contains('doctor') || catStr.contains('clinic') || catStr.contains('medic') || catStr.contains('health') || catStr.contains('fever') || catStr.contains('hospital')) {
      return ServiceType.doctor;
    }
    if (catStr.contains('hotel') || catStr.contains('lodge') || catStr.contains('stay') || catStr.contains('room') || catStr.contains('resort')) {
      return ServiceType.hotel;
    }
    if (catStr.contains('restaurant') || catStr.contains('restaurent') || catStr.contains('food') || catStr.contains('dining') || catStr.contains('cafe') || catStr.contains('lunch') || catStr.contains('dinner')) {
      return ServiceType.restaurant;
    }
    if (catStr.contains('decor') || catStr.contains('balloon') || catStr.contains('flower') || catStr.contains('stage') || catStr.contains('birthday')) {
      return ServiceType.decoration;
    }
    if (catStr.contains('tent') || catStr.contains('shamiana') || catStr.contains('mandap') || catStr.contains('chair')) {
      return ServiceType.tentHouse;
    }
    if (catStr.contains('mech') || catStr.contains('car') || catStr.contains('bike') || catStr.contains('scooter') || catStr.contains('tyre') || catStr.contains('puncture') || catStr.contains('brake') || catStr.contains('engine')) {
      return ServiceType.mechanic;
    }
    if (catStr.contains('plumb') || catStr.contains('water') || catStr.contains('pipe') || catStr.contains('tap') || catStr.contains('drain') || catStr.contains('leak')) {
      return ServiceType.plumber;
    }
    if (catStr.contains('elect') || catStr.contains('power') || catStr.contains('wire') || catStr.contains('switch') || catStr.contains('fan') || catStr.contains('mcb') || catStr.contains('fuse')) {
      return ServiceType.electrician;
    }
    if (catStr.contains('appliance') || catStr.contains('fridge') || catStr.contains('washing') || catStr.contains('ac') || catStr.contains('microwave') || catStr.contains('geyser')) {
      return ServiceType.applianceRepair;
    }
    if (catStr.contains('carpenter') || catStr.contains('wood') || catStr.contains('door') || catStr.contains('lock') || catStr.contains('furniture') || catStr.contains('cupboard')) {
      return ServiceType.carpenter;
    }
    if (catStr.contains('paint') || catStr.contains('wall') || catStr.contains('crack')) {
      return ServiceType.painter;
    }
    return ServiceType.all;
  }

  static String _getCategoryTitle(ServiceType type) {
    switch (type) {
      case ServiceType.catering:
        return 'Catering';
      case ServiceType.djSound:
        return 'DJ & Sound System';
      case ServiceType.mechanic:
        return 'Mechanic';
      case ServiceType.doctor:
        return 'Doctor';
      case ServiceType.hotel:
        return 'Hotel';
      case ServiceType.restaurant:
        return 'Restaurant';
      case ServiceType.decoration:
        return 'Decoration';
      case ServiceType.tentHouse:
        return 'Tent House';
      case ServiceType.plumber:
        return 'Plumber';
      case ServiceType.electrician:
        return 'Electrician';
      case ServiceType.carpenter:
        return 'Carpenter';
      case ServiceType.applianceRepair:
        return 'Appliance Repair';
      case ServiceType.painter:
        return 'Painter';
      default:
        return 'All Services';
    }
  }

  static GeminiDiagnosticResult _generateSmartFallback(String query) {
    final lower = query.toLowerCase();

    if (lower.contains('doctor') || lower.contains('fever') || lower.contains('clinic') || lower.contains('health') || lower.contains('pain') || lower.contains('sick') || lower.contains('cough')) {
      return const GeminiDiagnosticResult(
        issueSummary: 'Health & Medical Consultation Inquiry',
        diagnosis: 'For medical symptoms or illness, please consult your nearest hospital, clinic, or verified healthcare center directly.',
        recommendedCategory: ServiceType.all,
        categoryTitle: 'All Services',
        estimatedRate: 'Contact clinic directly',
        urgency: 'High',
        safetyTips: [
          'Stay hydrated and keep notes of symptoms or current body temperature.',
          'In case of emergency, contact the nearest emergency trauma center immediately.',
        ],
      );
    }

    if (lower.contains('hotel') || lower.contains('lodge') || lower.contains('room') || lower.contains('stay') || lower.contains('ac room') || lower.contains('guest house')) {
      return const GeminiDiagnosticResult(
        issueSummary: 'Hotel Room & Lodging Booking Request',
        diagnosis: 'Local accommodation options available nearby for comfortable stays.',
        recommendedCategory: ServiceType.hotel,
        categoryTitle: 'Hotel',
        estimatedRate: 'Starts from ₹800',
        urgency: 'Normal',
        safetyTips: [
          'Verify check-in and check-out timings before booking.',
          'Keep valid government ID handy during hotel check-in.',
        ],
      );
    }

    if (lower.contains('cater') || lower.contains('food order') || lower.contains('buffet') || lower.contains('meal box') || lower.contains('party food') || lower.contains('chef') || lower.contains('cook') || lower.contains('cooking') || lower.contains('baking') || lower.contains('party meal')) {
      return const GeminiDiagnosticResult(
        issueSummary: 'Catering & Event Food Order Service',
        diagnosis: 'Professional caterer or food service provider needed for event catering, party food orders, buffet preparation, or meal packages.',
        recommendedCategory: ServiceType.catering,
        categoryTitle: 'Catering',
        estimatedRate: 'Starts from ₹350',
        urgency: 'Normal',
        safetyTips: [
          'Discuss guest count, vegetarian / non-vegetarian menu, and dietary preferences in advance.',
          'Confirm delivery schedule and buffet setup timing before the event.',
        ],
      );
    }

    if (lower.contains('dj') || lower.contains('sound system') || lower.contains('speaker') || lower.contains('mic') || lower.contains('audio setup') || lower.contains('party sound') || lower.contains('amplifier')) {
      return const GeminiDiagnosticResult(
        issueSummary: 'DJ & Sound System Setup Request',
        diagnosis: 'Professional DJ, stage audio, party sound systems, speakers, and microphone setup for events or parties.',
        recommendedCategory: ServiceType.djSound,
        categoryTitle: 'DJ & Sound System',
        estimatedRate: 'Starts from ₹1,500',
        urgency: 'Normal',
        safetyTips: [
          'Verify venue sound permissions and power socket availability.',
          'Share playlist genre and event schedule with the DJ ahead of time.',
        ],
      );
    }

    if (lower.contains('food') || lower.contains('restaurant') || lower.contains('restaurent') || lower.contains('dining') || lower.contains('lunch') || lower.contains('dinner') || lower.contains('biryani') || lower.contains('hotel food')) {
      return const GeminiDiagnosticResult(
        issueSummary: 'Restaurant & Dining Discovery Request',
        diagnosis: 'Verified local family restaurants, takeaway dining, and catering providers.',
        recommendedCategory: ServiceType.restaurant,
        categoryTitle: 'Restaurant',
        estimatedRate: 'Starts from ₹150',
        urgency: 'Normal',
        safetyTips: [
          'Check vegetarian / non-vegetarian food preferences before ordering.',
          'Directly contact restaurant staff for special catering orders.',
        ],
      );
    }

    if (lower.contains('decor') || lower.contains('flower') || lower.contains('balloon') || lower.contains('stage') || lower.contains('birthday') || lower.contains('anniversary')) {
      return const GeminiDiagnosticResult(
        issueSummary: 'Event & Celebration Decoration Service',
        diagnosis: 'Custom stage styling, floral arrangements, and balloon backdrop setup.',
        recommendedCategory: ServiceType.decoration,
        categoryTitle: 'Decoration',
        estimatedRate: 'Starts from ₹1,000',
        urgency: 'Normal',
        safetyTips: [
          'Share venue dimensions and theme colors with the decorator in advance.',
          'Book at least 24-48 hours before the event date for custom backdrops.',
        ],
      );
    }

    if (lower.contains('tent') || lower.contains('shamiana') || lower.contains('chairs') || lower.contains('mandap') || lower.contains('lighting')) {
      return const GeminiDiagnosticResult(
        issueSummary: 'Tent House, Shamiana & Function Setup',
        diagnosis: 'Event infrastructure including waterproof shamianas, banquet chairs, and event setup.',
        recommendedCategory: ServiceType.tentHouse,
        categoryTitle: 'Tent House',
        estimatedRate: 'Starts from ₹1,500',
        urgency: 'Normal',
        safetyTips: [
          'Confirm electrical supply points for high-power event lighting.',
          'Ensure ground space is cleared for shamiana pole pitching.',
        ],
      );
    }

    if (lower.contains('car') || lower.contains('bike') || lower.contains('brake') || lower.contains('puncture') || lower.contains('tyre') || lower.contains('engine') || lower.contains('battery') || lower.contains('start') || lower.contains('scooter') || lower.contains('mechanic')) {
      return const GeminiDiagnosticResult(
        issueSummary: 'Vehicle & Automobile Repair Issue Detected',
        diagnosis: 'Potential battery discharge, puncture, brake wear, or ignition breakdown.',
        recommendedCategory: ServiceType.mechanic,
        categoryTitle: 'Mechanic',
        estimatedRate: 'Starts from ₹250',
        urgency: 'High',
        safetyTips: [
          'Park vehicle safely with hazard lights if on roadside.',
          'Do not continuously crank weak batteries to prevent starter burnout.',
        ],
      );
    }

    if (lower.contains('water') || lower.contains('tap') || lower.contains('leak') || lower.contains('pipe') || lower.contains('sink') || lower.contains('toilet') || lower.contains('drain')) {
      return const GeminiDiagnosticResult(
        issueSummary: 'Plumbing & Water Line Issue Detected',
        diagnosis: 'Possible valve washer degradation, pipe coupling looseness, or drain obstruction.',
        recommendedCategory: ServiceType.plumber,
        categoryTitle: 'Plumber',
        estimatedRate: 'Starts from ₹200',
        urgency: 'High',
        safetyTips: [
          'Turn off the local stopcock or main water inlet immediately.',
          'Place a bucket under the leak to prevent floor dampness.',
        ],
      );
    }

    if (lower.contains('power') || lower.contains('light') || lower.contains('spark') || lower.contains('switch') || lower.contains('mcb') || lower.contains('trip') || lower.contains('fuse') || lower.contains('electric') || lower.contains('fan')) {
      return const GeminiDiagnosticResult(
        issueSummary: 'Electrical Circuit & Power Issue Detected',
        diagnosis: 'Possible short-circuit, overload on breaker, or faulty switchboard wiring.',
        recommendedCategory: ServiceType.electrician,
        categoryTitle: 'Electrician',
        estimatedRate: 'Starts from ₹250',
        urgency: 'Immediate',
        safetyTips: [
          'Do NOT touch wet switchboards or spark sources.',
          'Turn off the main distribution MCB switch on your colony meter panel.',
        ],
      );
    }

    if (lower.contains('fridge') || lower.contains('washing') || lower.contains('ac') || lower.contains('geyser') || lower.contains('microwave') || lower.contains('cooling') || lower.contains('appliance')) {
      return const GeminiDiagnosticResult(
        issueSummary: 'Home Appliance Component Breakdown',
        diagnosis: 'Thermostat, capacitor, heating element, or drain pump malfunction.',
        recommendedCategory: ServiceType.applianceRepair,
        categoryTitle: 'Appliance Repair',
        estimatedRate: 'Starts from ₹300',
        urgency: 'Normal',
        safetyTips: [
          'Unplug appliance power cord from socket before opening any panel.',
          'Check if warranty or service plan applies before disassembling.',
        ],
      );
    }

    if (lower.contains('door') || lower.contains('lock') || lower.contains('wood') || lower.contains('hinge') || lower.contains('cabinet') || lower.contains('handle') || lower.contains('table') || lower.contains('chair')) {
      return const GeminiDiagnosticResult(
        issueSummary: 'Carpentry & Woodwork Hardware Repair',
        diagnosis: 'Misaligned hinges, swollen wood frame, or lock cylinder jamming.',
        recommendedCategory: ServiceType.carpenter,
        categoryTitle: 'Carpenter',
        estimatedRate: 'Starts from ₹200',
        urgency: 'Normal',
        safetyTips: [
          'Avoid forcing jammed locks to avoid key breakage.',
          'Keep wooden doors dry and oiled around pivot points.',
        ],
      );
    }

    // Default general diagnostic
    return const GeminiDiagnosticResult(
      issueSummary: 'General Local Service & Repair Request',
      diagnosis: 'Nearby verified technician or service provider can assist at your doorstep.',
      recommendedCategory: ServiceType.all,
      categoryTitle: 'All Services',
      estimatedRate: 'Starts from ₹250',
      urgency: 'Normal',
      safetyTips: [
        'Take a quick photo or description of the issue to show the provider upon arrival.',
        'Keep the work area accessible.',
      ],
    );
  }
}
