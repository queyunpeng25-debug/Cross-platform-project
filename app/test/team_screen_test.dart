import 'package:cs_building_guide/core/models.dart';
import 'package:cs_building_guide/features/team/team_screen.dart';
import 'package:cs_building_guide/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Project team profiles use LinkedIn descriptions and valid LinkedIn links', () {
    const team = TeamMemberProfile.projectTeam;
    expect(team, hasLength(5));

    for (final member in team) {
      expect(member.headline.trim(), isNotEmpty);
      expect(member.bio.trim(), isNotEmpty);
      final uri = Uri.tryParse(member.linkedinUrl);
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'www.linkedin.com');
    }

    final byName = {for (final m in team) m.name: m};
    expect(
      byName['Andrea Gollo']?.linkedinUrl,
      'https://www.linkedin.com/in/gollo-andrea/',
    );
    expect(
      byName['Mustafa Alalawi']?.linkedinUrl,
      'https://www.linkedin.com/in/mustafa0alalawi/',
    );
    expect(byName['Juhani']?.linkedinUrl, 'https://www.linkedin.com/');
    expect(byName['Juhani']?.hasDirectLinkedinProfile, isFalse);
    expect(
      byName['Yunpeng Que']?.linkedinUrl,
      'https://www.linkedin.com/in/yunpeng-que-900b2a444/',
    );
    expect(
      byName['Niccolò Sobrero']?.linkedinUrl,
      'https://www.linkedin.com/in/niccol%C3%B2-sobrero/',
    );
  });

  testWidgets('TeamScreen displays all members with LinkedIn and GitHub actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var backPressed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: CsAppTheme.light(),
        home: TeamScreen(onBackToLobby: () => backPressed = true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meet the Team'), findsOneWidget);
    expect(find.text('Andrea Gollo'), findsOneWidget);
    expect(find.text('LinkedIn'), findsWidgets);
    expect(find.text('GitHub'), findsWidgets);

    // Scroll through the list to verify all 5 cards render without overflow.
    for (final member in TeamMemberProfile.projectTeam) {
      await tester.scrollUntilVisible(
        find.text(member.name),
        240,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text(member.name), findsOneWidget);
      expect(find.text(member.headline), findsOneWidget);
      expect(find.text(member.bio), findsOneWidget);
    }

    await tester.tap(find.byTooltip('Back'));
    expect(backPressed, isTrue);
  });
}
