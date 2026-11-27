import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zenify/zenify.dart';

import '../../core/controllers.dart';
import '../../core/device_capabilities.dart';
import '../../core/models.dart';
import '../../core/translation_service.dart';
import 'canteen_menu_service.dart';

/// Demonstrable default implementation of [CanteenFeatureSlot] for **Juhani**.
///
/// Juhani can replace [DefaultCanteenFeatureSlot] with his full daily canteen
/// menu scraper & review module while reusing:
/// - [translator] (`TranslationService`) or [TrText] to translate scraped
///   Finnish/English dish names and dietary labels into any of the 17 languages.
/// - [settings] (`AppSettingsController.languageCode`) to observe language switches.
/// - [onCatchPuzzlePiece] to launch the Canteen station's floating AR puzzle hunt.
class DefaultCanteenFeatureSlot implements CanteenFeatureSlot {
  const DefaultCanteenFeatureSlot({required this.menuRepository});

  final CanteenMenuRepository menuRepository;

  @override
  Widget buildCanteenScreen(
    BuildContext context, {
    required TranslationService translator,
    required AppSettingsController settings,
    required VoidCallback onBackToLobby,
    required VoidCallback onCatchPuzzlePiece,
  }) {
    return _DefaultCanteenView(
      translator: translator,
      settings: settings,
      menuRepository: menuRepository,
      onBackToLobby: onBackToLobby,
      onCatchPuzzlePiece: onCatchPuzzlePiece,
    );
  }
}

class _DefaultCanteenView extends StatefulWidget {
  const _DefaultCanteenView({
    required this.translator,
    required this.settings,
    required this.menuRepository,
    required this.onBackToLobby,
    required this.onCatchPuzzlePiece,
  });

  final TranslationService translator;
  final AppSettingsController settings;
  final CanteenMenuRepository menuRepository;
  final VoidCallback onBackToLobby;
  final VoidCallback onCatchPuzzlePiece;

  @override
  State<_DefaultCanteenView> createState() => _DefaultCanteenViewState();
}

class _DefaultCanteenViewState extends State<_DefaultCanteenView> {
  static const Color _forestAccent = Color(0xFF262523);
  static const Color _canteenAccent = Color(0xFF7A5C3E);
  static const String _subwayMenuUrl = 'https://www.subway.fi/en/menu';
  static const String _canteenMenuUrl = 'https://folio.kanttiinit.fi/en/area/1';

  static const String _kitchenLiveBannerEn =
      'Sodexo Tietotekniikantalo (~€3.10 Kela student lunch with Frank/Slice card) · Campus Subway also offers Kela-subsidized Päivän Subi · Compare all Otaniemi menus on kanttiinit.fi.';

  final TextEditingController _reviewNoteController = TextEditingController();
  int _selectedDishIndex = 0;
  int _selectedStars = 5;
  bool _reviewSubmitted = false;

  int _bannerTranslationEpoch = 0;
  String? _bannerLang;
  String _translatedKitchenBanner = _kitchenLiveBannerEn;

  @override
  void initState() {
    super.initState();
    widget.menuRepository.addListener(_handleMenuChanged);
  }

  void _handleMenuChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.menuRepository.removeListener(_handleMenuChanged);
    _reviewNoteController.dispose();
    super.dispose();
  }

  void _syncDynamicBannerTranslation(String langCode) {
    if (_bannerLang == langCode) return;
    _bannerLang = langCode;
    final token = ++_bannerTranslationEpoch;

    final cached = widget.translator.cachedOrImmediate(
      _kitchenLiveBannerEn,
      targetLang: langCode,
    );
    if (cached != null) {
      _translatedKitchenBanner = cached;
      return;
    }

    _translatedKitchenBanner = _kitchenLiveBannerEn;
    unawaited(
      widget.translator
          .translate(_kitchenLiveBannerEn, targetLang: langCode)
          .then((result) {
            if (mounted &&
                token == _bannerTranslationEpoch &&
                result != _translatedKitchenBanner) {
              setState(() {
                _translatedKitchenBanner = result;
              });
            }
          }),
    );
  }

  Future<void> _openSubwayMenu() async {
    final uri = Uri.tryParse(_subwayMenuUrl);
    if (uri == null) return;
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: TrText('Could not open external link: $_subwayMenuUrl'),
          ),
        );
    }
  }

  Future<void> _openCanteenMenu() async {
    await launchUrl(
      Uri.parse(_canteenMenuUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  void _submitDemoReview() {
    FocusScope.of(context).unfocus();
    setState(() {
      _reviewSubmitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? theme.scaffoldBackgroundColor
        : const Color(0xFFF6F4EE);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ZenObserver(() {
          final langCode = widget.settings.languageCode.value;
          final activeLanguage = SupportedLanguage.byCode(langCode);
          _syncDynamicBannerTranslation(langCode);

          final menu = widget.menuRepository;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
            children: [
              // Top bar with >= 48x48 `<` Back button
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Back to Lobby',
                    child: Material(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: widget.onBackToLobby,
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.chevron_left_rounded, size: 28),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TrText(
                      'Tietotekniikantalo Canteen & Subway',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Daily menu header
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _canteenAccent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.restaurant_menu_rounded,
                              color: _canteenAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TrText(
                              "Today's Campus Lunch Menu",
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _translatedKitchenBanner,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.78,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _forestAccent.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.translate_rounded,
                              size: 16,
                              color: _forestAccent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TrText(
                                'Live menu translation active (${activeLanguage.displayLabel})',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: _forestAccent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              if (menu.isLoading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
              ],
              if (menu.errorMessage != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(menu.errorMessage!),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: menu.isLoading
                                  ? null
                                  : widget.menuRepository.refresh,
                              child: const Text('Retry'),
                            ),
                            TextButton(
                              onPressed: _openCanteenMenu,
                              child: const Text('Open Kanttiinit'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (menu.dishes.isEmpty &&
                  !menu.isLoading &&
                  menu.errorMessage == null)
                const Text('No lunch dishes are currently listed.'),
              for (final dish in menu.dishes) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: TrText(
                      dish,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              const SizedBox(height: 6),

              // Subway Campus Menu Quick Action Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.55,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.lunch_dining_rounded,
                            color: Color(0xFF1F6E3D),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TrText(
                              'Ground-Floor Subway Counter',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TrText(
                        DeviceCapabilities.supportsCameraScan
                            ? 'Scanning the Subway sign in Smart Scan or tapping below opens the full Subway Finland menu.'
                            : 'Tap below to open the full Subway Finland menu.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.35,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.74,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _openSubwayMenu,
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const TrText('Open Subway Menu'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Safe Demo Student Review Box
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TrText(
                        'Student Dish Review (Safe Demo Mode)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TrText(
                        'Pick a dish and rating below — submitting displays a clearly labeled demo review for safe classroom demonstrations.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.35,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < menu.dishes.length; i++)
                            ChoiceChip(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              label: TrText(menu.dishes[i]),
                              selected: _selectedDishIndex == i,
                              onSelected: (_) => setState(() {
                                _selectedDishIndex = i;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const TrText(
                            'Rating:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          for (var star = 1; star <= 5; star++)
                            Semantics(
                              button: true,
                              label: 'Rate $star stars',
                              child: IconButton(
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                onPressed: () => setState(() {
                                  _selectedStars = star;
                                }),
                                icon: Icon(
                                  star <= _selectedStars
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: const Color(0xFFD99B26),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _reviewNoteController,
                        decoration: InputDecoration(
                          hintText: 'Optional tasting note (demo preview)...',
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: menu.dishes.isEmpty
                            ? null
                            : _submitDemoReview,
                        icon: const Icon(Icons.rate_review_outlined, size: 18),
                        label: const TrText('Submit Demo Review'),
                      ),
                      if (_reviewSubmitted && menu.dishes.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _forestAccent.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _forestAccent.withValues(alpha: 0.25),
                            ),
                          ),
                          child: TrText(
                            '${'★' * _selectedStars} · Verified Student Demo Review: '
                            '"${menu.dishes[_selectedDishIndex.clamp(0, menu.dishes.length - 1)]} '
                            'is a satisfying campus lunch option."',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
