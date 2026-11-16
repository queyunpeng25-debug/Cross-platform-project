import 'package:flutter/material.dart';

import '../core/controllers.dart';
import '../core/models.dart';
import '../core/translation_service.dart';

/// Displays the rounded *AMuse* language selection modal dialog used both on
/// first app launch and from the Settings screen.
Future<void> showLanguageSelectionDialog(
  BuildContext context, {
  required AppSettingsController settings,
  bool isFirstLaunch = false,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: !isFirstLaunch,
    builder: (dialogContext) => _LanguageSelectionDialog(
      settings: settings,
      isFirstLaunch: isFirstLaunch,
    ),
  );

  if (isFirstLaunch && !settings.hasCompletedLanguagePrompt.value) {
    settings.selectLanguage(settings.languageCode.value);
  }
}

class _LanguageSelectionDialog extends StatefulWidget {
  const _LanguageSelectionDialog({
    required this.settings,
    required this.isFirstLaunch,
  });

  final AppSettingsController settings;
  final bool isFirstLaunch;

  @override
  State<_LanguageSelectionDialog> createState() =>
      _LanguageSelectionDialogState();
}

class _LanguageSelectionDialogState extends State<_LanguageSelectionDialog> {
  late String _selectedCode;

  @override
  void initState() {
    super.initState();
    final initial = widget.settings.languageCode.value;
    _selectedCode = SupportedLanguage.byCode(initial).code;
  }

  void _confirmSelection() {
    widget.settings.selectLanguage(_selectedCode);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const languages = SupportedLanguage.orderedCatalog;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.translate_rounded,
                      color: scheme.onPrimaryContainer,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TrText(
                          widget.isFirstLaunch
                              ? 'Welcome to CS Explorer'
                              : 'Choose App Language',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        TrText(
                          'Select the language for building guides, menus, and navigation.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!widget.isFirstLaunch)
                    Semantics(
                      button: true,
                      label: 'Close language dialog',
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Close',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: languages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final lang = languages[index];
                    final isSelected = lang.code == _selectedCode;

                    return Semantics(
                      button: true,
                      selected: isSelected,
                      label: lang.hasDirectLanguageFile
                          ? lang.displayLabel
                          : '${lang.displayLabel}, ${lang.translationProviderNote}',
                      child: Material(
                        color: isSelected
                            ? scheme.primaryContainer.withValues(alpha: 0.55)
                            : scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            setState(() {
                              _selectedCode = lang.code;
                            });
                          },
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 54),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lang.displayLabel,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: scheme.onSurface,
                                          ),
                                        ),
                                        if (!lang.hasDirectLanguageFile) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            lang.translationProviderNote,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              fontSize: 11.5,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSelected
                                        ? scheme.primary
                                        : scheme.outline,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (!widget.isFirstLaunch) ...[
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Cancel language change',
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const TrText('Cancel'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: widget.isFirstLaunch ? 1 : 2,
                    child: Semantics(
                      button: true,
                      label: widget.isFirstLaunch
                          ? 'Continue with selected language'
                          : 'Apply selected language',
                      child: FilledButton(
                        onPressed: _confirmSelection,
                        child: TrText(
                          widget.isFirstLaunch ? 'Continue' : 'Done',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
