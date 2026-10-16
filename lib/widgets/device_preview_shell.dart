import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DevicePreset {
  final String id;
  final String name;
  final double width;
  final double height;
  final double borderRadius;
  final String icon;
  final bool hasDynamicIsland;

  const DevicePreset({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    this.borderRadius = 40,
    this.icon = '📱',
    this.hasDynamicIsland = true,
  });
}

class DevicePreviewShell extends StatefulWidget {
  final Widget child;

  const DevicePreviewShell({super.key, required this.child});

  @override
  State<DevicePreviewShell> createState() => _DevicePreviewShellState();
}

class _DevicePreviewShellState extends State<DevicePreviewShell> {
  static const List<DevicePreset> presets = [
    DevicePreset(
      id: 'iphone_15_pro',
      name: 'iPhone 15 Pro',
      width: 393,
      height: 852,
      borderRadius: 44,
      hasDynamicIsland: true,
    ),
    DevicePreset(
      id: 'galaxy_s24',
      name: 'Galaxy S24 / Pixel 8',
      width: 412,
      height: 915,
      borderRadius: 36,
      hasDynamicIsland: false,
    ),
    DevicePreset(
      id: 'iphone_pro_max',
      name: 'iPhone 15 Pro Max',
      width: 430,
      height: 932,
      borderRadius: 48,
      hasDynamicIsland: true,
    ),
    DevicePreset(
      id: 'compact_android',
      name: 'Compact Android (360p)',
      width: 360,
      height: 780,
      borderRadius: 32,
      hasDynamicIsland: false,
    ),
    DevicePreset(
      id: 'iphone_se',
      name: 'iPhone SE (Classic)',
      width: 375,
      height: 667,
      borderRadius: 20,
      hasDynamicIsland: false,
    ),
    DevicePreset(
      id: 'responsive',
      name: 'Full Screen Mode',
      width: 0,
      height: 0,
      borderRadius: 0,
      icon: '💻',
      hasDynamicIsland: false,
    ),
  ];

  late DevicePreset _selectedPreset;
  bool _isLandscape = false;
  bool _showFrame = true;

  @override
  void initState() {
    super.initState();
    _selectedPreset = presets[0]; // Default: iPhone 15 Pro
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return widget.child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // If narrow mobile window (< 480px) or Full Screen mode selected
        if (constraints.maxWidth <= 480 || _selectedPreset.id == 'responsive') {
          return Scaffold(
            body: Stack(
              children: [
                widget.child,
                if (constraints.maxWidth > 480)
                  Positioned(
                    top: 14,
                    right: 14,
                    child: _buildFloatingPresetPicker(),
                  ),
              ],
            ),
          );
        }

        final double targetWidth =
            _isLandscape ? _selectedPreset.height : _selectedPreset.width;
        final double targetHeight =
            _isLandscape ? _selectedPreset.width : _selectedPreset.height;

        return Scaffold(
          backgroundColor: const Color(0xFF0B0F19),
          body: SafeArea(
            child: Column(
              children: [
                // Top Multi-Resolution Toolbar
                _buildTopToolbar(context),

                // Device Frame Viewport
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: _buildDeviceFrame(
                            context, targetWidth, targetHeight),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopToolbar(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF161E2E),
        border: Border(bottom: BorderSide(color: Color(0xFF2E3A52), width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // App Branding
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.build_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NearSlay Preview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Mobile Resolution Tester',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(width: 16),
            Container(width: 1, height: 26, color: const Color(0xFF2E3A52)),
            const SizedBox(width: 14),

            // Preset Dropdown Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF3B4861)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DevicePreset>(
                  dropdownColor: const Color(0xFF161E2E),
                  value: _selectedPreset,
                  icon:
                      const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  items: presets.map((preset) {
                    return DropdownMenuItem<DevicePreset>(
                      value: preset,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(preset.icon,
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            preset.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (preset.width > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${preset.width.toInt()}×${preset.height.toInt()})',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedPreset = val;
                      });
                    }
                  },
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Quick Resolution Presets
            ...presets.take(4).map((p) {
              final isPicked = _selectedPreset.id == p.id;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(
                    p.name.split(' ')[0],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isPicked ? FontWeight.w700 : FontWeight.w500,
                      color: isPicked ? Colors.white : const Color(0xFF94A3B8),
                    ),
                  ),
                  selected: isPicked,
                  selectedColor: AppColors.primary,
                  backgroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isPicked
                          ? AppColors.primary
                          : const Color(0xFF2E3A52),
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedPreset = p;
                      });
                    }
                  },
                ),
              );
            }),

            const SizedBox(width: 6),
            Container(width: 1, height: 26, color: const Color(0xFF2E3A52)),
            const SizedBox(width: 8),

            // Rotate Orientation
            IconButton(
              tooltip: _isLandscape
                  ? 'Switch to Portrait'
                  : 'Switch to Landscape',
              icon: Icon(
                Icons.screen_rotation_rounded,
                color: _isLandscape ? AppColors.secondary : Colors.white70,
                size: 19,
              ),
              onPressed: () {
                setState(() {
                  _isLandscape = !_isLandscape;
                });
              },
            ),

            // Toggle Phone Frame
            IconButton(
              tooltip:
                  _showFrame ? 'Hide Device Bezel' : 'Show Device Bezel',
              icon: Icon(
                _showFrame ? Icons.smartphone_rounded : Icons.crop_free_rounded,
                color: _showFrame ? AppColors.primary : Colors.white70,
                size: 19,
              ),
              onPressed: () {
                setState(() {
                  _showFrame = !_showFrame;
                });
              },
            ),

            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceFrame(
      BuildContext context, double targetWidth, double targetHeight) {
    final framePadding = _showFrame ? 12.0 : 0.0;
    final frameRadius = _showFrame ? _selectedPreset.borderRadius : 0.0;

    return Container(
      width: targetWidth + (framePadding * 2),
      height: targetHeight + (framePadding * 2),
      padding: EdgeInsets.all(framePadding),
      decoration: BoxDecoration(
        color: _showFrame ? const Color(0xFF1E1E24) : Colors.transparent,
        borderRadius: BorderRadius.circular(frameRadius + 8),
        border: _showFrame
            ? Border.all(
                color: const Color(0xFF4A4A5A),
                width: 3.5,
              )
            : null,
        boxShadow: _showFrame
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 36,
                  spreadRadius: 4,
                  offset: const Offset(0, 16),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(frameRadius),
        child: SizedBox(
          width: targetWidth,
          height: targetHeight,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: Size(targetWidth, targetHeight),
              padding: EdgeInsets.only(
                top: _selectedPreset.hasDynamicIsland ? 36.0 : 24.0,
                bottom: 16.0,
              ),
            ),
            child: Scaffold(
              body: Stack(
                children: [
                  // The Actual App Screen
                  Positioned.fill(
                    child: widget.child,
                  ),

                  // Dynamic Island (iPhone)
                  if (_showFrame &&
                      _selectedPreset.hasDynamicIsland &&
                      !_isLandscape)
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 105,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1A1A2E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Punch-Hole Camera (Android)
                  if (_showFrame &&
                      !_selectedPreset.hasDynamicIsland &&
                      _selectedPreset.id != 'iphone_se' &&
                      !_isLandscape)
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),

                  // Bottom Home Indicator Bar
                  if (_showFrame && !_isLandscape)
                    Positioned(
                      bottom: 4,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 110,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingPresetPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF475569)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📱', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Text(
            _selectedPreset.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
