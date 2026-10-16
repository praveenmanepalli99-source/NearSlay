import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/gemini_service.dart';
import '../state/nearfix_state.dart';
import '../theme/app_colors.dart';

class GeminiAssistantSheet extends StatefulWidget {
  const GeminiAssistantSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GeminiAssistantSheet(),
    );
  }

  @override
  State<GeminiAssistantSheet> createState() => _GeminiAssistantSheetState();
}

class _GeminiAssistantSheetState extends State<GeminiAssistantSheet> {
  final TextEditingController _queryController = TextEditingController();
  bool _isLoading = false;
  GeminiDiagnosticResult? _result;

  final List<String> _quickSuggestions = [
    'Kitchen tap leaking water from pipe',
    'Main power tripped and spark in switch',
    'Car battery dead, not starting',
    'AC is not cooling the room',
    'Door lock jammed and won\'t turn',
  ];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _diagnose(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _result = null;
    });

    final res = await GeminiService.diagnoseIssue(text.trim());

    if (mounted) {
      setState(() {
        _isLoading = false;
        _result = res;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<NearFixState>(context, listen: false);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header with Gemini Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4285F4), Color(0xFF9B51E0), Color(0xFFFF6B35)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gemini Colony Repair AI',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Describe your problem for instant diagnosis & category match',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Input Field
            TextField(
              controller: _queryController,
              decoration: InputDecoration(
                hintText: 'e.g. Water dripping from bathroom ceiling pipe...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                  onPressed: () => _diagnose(_queryController.text),
                ),
              ),
              onSubmitted: _diagnose,
            ),
            const SizedBox(height: 12),

            // Quick Suggestion Chips
            if (_result == null && !_isLoading) ...[
              const Text(
                'Quick examples:',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _quickSuggestions.map((s) {
                  return InkWell(
                    onTap: () {
                      _queryController.text = s;
                      _diagnose(s);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Loading Indicator
            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                    SizedBox(height: 12),
                    Text(
                      'Gemini is analyzing your issue...',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],

            // Diagnostic Results Card
            if (_result != null && !_isLoading) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Result Header & Urgency
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _result!.issueSummary,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _result!.urgency == 'Immediate'
                                ? AppColors.errorRed.withOpacity(0.15)
                                : AppColors.secondaryLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Urgency: ${_result!.urgency}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: _result!.urgency == 'Immediate'
                                  ? AppColors.errorRed
                                  : AppColors.secondaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Diagnosis Explanation
                    Text(
                      _result!.diagnosis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.35),
                    ),
                    const SizedBox(height: 12),

                    // Category & Estimated Rate
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Match: ${_result!.categoryTitle}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _result!.estimatedRate,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Safety Tips
                    const Text(
                      'Safety & Immediate Action Tips:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    ..._result!.safetyTips.map((tip) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Text(tip, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ),
                            ],
                          ),
                        )),

                    const SizedBox(height: 16),

                    // Action Button: View Colony Providers
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          state.selectCategory(_result!.recommendedCategory);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.search_rounded, size: 16),
                        label: Text('View Nearby ${_result!.categoryTitle}s in Colony'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
