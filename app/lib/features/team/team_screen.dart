import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models.dart';
import '../../core/translation_service.dart';

/// Museum-curator style credits screen showcasing [TeamMemberProfile.projectTeam]
/// (Andrea, Mustafa, Juhani, Yunpeng, and Nico) and their individual modules.
class TeamScreen extends StatelessWidget {
  const TeamScreen({
    super.key,
    required this.onBackToLobby,
  });

  final VoidCallback onBackToLobby;

  Future<void> _openGithubProfile(BuildContext context, String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: TrText('Could not open external link: $rawUrl'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const members = TeamMemberProfile.projectTeam;

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
        title: const TrText('Meet the Team'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            children: [
              // Curatorial header placard
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TrText(
                        'EXHIBITION CREDITS · AALTO UNIVERSITY',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TrText(
                      'CS Explorer Collective',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TrText(
                      'Designed and engineered collaboratively as an interactive cross-platform guide to the Computer Science building — uniting architecture, positioning, AR recognition, campus dining, and playful discovery.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              for (final member in members) ...[
                _CuratorMemberCard(
                  member: member,
                  onOpenGithub: member.githubUrl == null
                      ? null
                      : () => _openGithubProfile(context, member.githubUrl!),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CuratorMemberCard extends StatelessWidget {
  const _CuratorMemberCard({
    required this.member,
    this.onOpenGithub,
  });

  final TeamMemberProfile member;
  final VoidCallback? onOpenGithub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final badgeBg = member.accentColor.withValues(alpha: isDark ? 0.28 : 0.12);
    final badgeText = isDark
        ? Color.lerp(member.accentColor, Colors.white, 0.58)!
        : member.accentColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar circle with initials & member accentColor
                Semantics(
                  label: '${member.name} avatar',
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: member.accentColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: member.accentColor.withValues(
                            alpha: isDark ? 0.36 : 0.24,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        member.initials,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFFFAF9F6),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: member.accentColor.withValues(alpha: 0.32),
                          ),
                        ),
                        child: TrText(
                          member.roleTitle,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: badgeText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TrText(
              member.contributionSummary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.88),
                height: 1.48,
              ),
            ),
            if (onOpenGithub != null) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label: 'Open ${member.name} GitHub profile',
                  child: OutlinedButton.icon(
                    onPressed: onOpenGithub,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const TrText('GitHub Profile'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
