import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import '../../core/controllers.dart';
import '../../core/models.dart';
import '../../core/translation_service.dart';
import '../../ui/language_dialog.dart';
import '../../ui/theme.dart';

/// Application Settings screen providing theme mode switching, full-app
/// language selection, live Demo Mode unlock toggle, team credits link, and
/// tour progress reset.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.onBackToLobby,
    required this.onOpenTeam,
  });

  final VoidCallback onBackToLobby;
  final VoidCallback onOpenTeam;

  Future<void> _confirmResetProgress(
    BuildContext context,
    TourProgressController progress,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('Reset Tour Progress?'),
        content: const TrText(
          'This will lock unvisited building stations again, clear all collected floating AR puzzle pieces, and return your current position to the Lobby.',
        ),
        actions: [
          Semantics(
            button: true,
            label: 'Cancel reset',
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const TrText('Cancel'),
            ),
          ),
          Semantics(
            button: true,
            label: 'Confirm reset tour progress',
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: CsStatusColors.currentRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const TrText('Reset'),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await progress.resetTourProgress();
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: TrText(
            'Tour progress has been reset to the Main Entrance & Lobby.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Zen.find<AppSettingsController>();
    final progress = Zen.find<TourProgressController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: Semantics(
          button: true,
          label: 'Back to Lobby',
          child: IconButton(
            onPressed: onBackToLobby,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            tooltip: 'Back',
          ),
        ),
        title: const TrText('Settings'),
      ),
      body: ZenObserver(() {
        final activeThemeMode = settings.themeMode.value == ThemeMode.dark
            ? ThemeMode.dark
            : ThemeMode.light;
        final activeLanguage = SupportedLanguage.byCode(
          settings.languageCode.value,
        );
        final demoUnlock = settings.demoUnlockAll.value;

        final visitedIds = progress.visitedStationIds.value;
        final collectedIds = progress.collectedPuzzleIds.value;
        final totalStations = progress.catalog.stations.length;
        final visitedCount = progress.catalog.stations
            .where((s) => s.unlockedByDefault || visitedIds.contains(s.id))
            .length;
        final collectedCount = progress.catalog.stations
            .where((s) => s.hasPuzzlePiece && collectedIds.contains(s.id))
            .length;
        final totalPuzzles = progress.totalPuzzleStations;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                // 1. Appearance — Dark Mode / Light Mode
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                activeThemeMode == ThemeMode.dark
                                    ? Icons.dark_mode_rounded
                                    : Icons.light_mode_rounded,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TrText(
                                    'Appearance',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  TrText(
                                    'Switch between AMuse Warm Ivory and Museum Night.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: Semantics(
                            label: 'Theme mode selector',
                            child: SegmentedButton<ThemeMode>(
                              style: const ButtonStyle(
                                minimumSize: WidgetStatePropertyAll(
                                  Size(48, 48),
                                ),
                              ),
                              segments: const [
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.light,
                                  icon: Icon(Icons.light_mode_rounded),
                                  label: TrText('Light Mode'),
                                ),
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.dark,
                                  icon: Icon(Icons.dark_mode_rounded),
                                  label: TrText('Dark Mode'),
                                ),
                              ],
                              selected: <ThemeMode>{activeThemeMode},
                              onSelectionChanged: (selection) {
                                if (selection.isNotEmpty) {
                                  settings.setThemeMode(selection.first);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. App & Menu Language
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.translate_rounded,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TrText(
                                    'App & Menu Language',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    activeLanguage.displayLabel,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: scheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  if (activeLanguage.hasDirectLanguageFile)
                                    TrText(
                                      'Direct bundled English language file',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    )
                                  else
                                    Text(
                                      activeLanguage.translationProviderNote,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: Semantics(
                            button: true,
                            label: 'Open language selector dialog',
                            child: OutlinedButton.icon(
                              onPressed: () => showLanguageSelectionDialog(
                                context,
                                settings: settings,
                              ),
                              icon: const Icon(Icons.language_rounded),
                              label: const TrText('Change Language'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Demo Mode (Unlock All Stations & Final Puzzle)
                Card(
                  child: Semantics(
                    toggled: demoUnlock,
                    label: 'Demo Mode, unlock all stations and final puzzle',
                    child: SwitchListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      secondary: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: demoUnlock
                              ? CsStatusColors.visitedGreen.withValues(
                                  alpha: 0.18,
                                )
                              : scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.science_rounded,
                          color: demoUnlock
                              ? CsStatusColors.visitedGreen
                              : scheme.onTertiaryContainer,
                        ),
                      ),
                      title: TrText(
                        'Demo Mode (Unlock All Stations & Final Puzzle)',
                        style: theme.textTheme.titleMedium,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TrText(
                          'Bypasses physical scan-to-unlock gates so evaluators and teammates can inspect any station or the Final Puzzle immediately.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      value: demoUnlock,
                      onChanged: settings.setDemoUnlockAll,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Meet the Team & Contributions
                Card(
                  child: Semantics(
                    button: true,
                    label: 'Meet the Team and Contributions',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: onOpenTeam,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 76),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.groups_rounded,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TrText(
                                      'Meet the Team & Contributions',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    TrText(
                                      'Explore the five-member engineering collective behind CS Explorer.',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Reset Tour Progress
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: CsStatusColors.currentRed.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.restart_alt_rounded,
                                color: CsStatusColors.currentRed,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TrText(
                                    'Tour Progress',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  TrText(
                                    'Visited $visitedCount/$totalStations stations · Collected $collectedCount/$totalPuzzles puzzle pieces',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: Semantics(
                            button: true,
                            label: 'Reset Tour Progress',
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: CsStatusColors.currentRed,
                                side: BorderSide(
                                  color: CsStatusColors.currentRed.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                              onPressed: () =>
                                  _confirmResetProgress(context, progress),
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const TrText('Reset Tour Progress'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
