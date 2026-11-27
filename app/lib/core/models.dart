import 'package:flutter/material.dart';

/// Three-color station state used across the Side Menu and Mustafa's Map API:
/// - [unvisited] -> Blue (locked in menu until scanned at least once)
/// - [current]   -> Red (the user's current / most recently reached station)
/// - [visited]   -> Green (previously reached & unlocked stations)
enum StationVisitStatus { unvisited, current, visited }

enum StationOwner { andrea, yunpeng, juhani, nico }

enum SecondaryActionKind {
  openScanner,
  greenhouseMinigame,
  retroPcExhibit,
  portraitArScanner,
  canteenMenuAndReviews,
}

class StationCallout {
  const StationCallout({
    required this.icon,
    required this.title,
    required this.body,
  });

  final String icon;
  final String title;
  final String body;

  factory StationCallout.fromJson(Map<String, dynamic> json) => StationCallout(
    icon: json['icon'] as String? ?? 'info',
    title: json['title'] as String,
    body: json['body'] as String,
  );
}

class GuildExternalLink {
  const GuildExternalLink({
    required this.label,
    required this.url,
    required this.kind,
  });

  final String label;
  final String url;
  final String kind; // 'website' | 'telegram' | 'instagram' | 'linktree'

  factory GuildExternalLink.fromJson(Map<String, dynamic> json) =>
      GuildExternalLink(
        label: json['label'] as String,
        url: json['url'] as String,
        kind: json['kind'] as String? ?? 'website',
      );
}

class GuildProfile {
  const GuildProfile({
    required this.id,
    required this.name,
    required this.shortTag,
    required this.description,
    required this.accentHex,
    required this.links,
  });

  final String id;
  final String name;
  final String shortTag;
  final String description;
  final int accentHex;
  final List<GuildExternalLink> links;

  factory GuildProfile.fromJson(Map<String, dynamic> json) => GuildProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    shortTag: json['shortTag'] as String,
    description: json['description'] as String,
    accentHex: int.parse((json['accentHex'] as String).replaceFirst('#', '0xff')),
    links: (json['links'] as List<dynamic>)
        .map((e) => GuildExternalLink.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class StationSpec {
  const StationSpec({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.floor,
    required this.floorLabel,
    required this.scanHintParenthetical,
    required this.triggerModeSummary,
    required this.heroAsset,
    required this.paragraphs,
    required this.callouts,
    required this.owner,
    required this.normalizedX,
    required this.normalizedY,
    this.unlockedByDefault = false,
    this.hasPuzzlePiece = true,
    this.puzzleCtaLabel = 'Catch AR Puzzle Piece',
    this.secondaryActionKind,
    this.secondaryActionLabel,
    this.guilds = const [],
  });

  final String id;
  final String title;
  final String subtitle;
  final int floor;
  final String floorLabel;
  final String scanHintParenthetical;
  final String triggerModeSummary;
  final String heroAsset;
  final List<String> paragraphs;
  final List<StationCallout> callouts;
  final StationOwner owner;

  /// Normalized floor-plan coordinates in [0.0, 1.0] (origin top-left, +x right, +y down).
  /// Provided as optional convenience data for Mustafa's Map module.
  final double normalizedX;
  final double normalizedY;

  final bool unlockedByDefault;
  final bool hasPuzzlePiece;
  final String puzzleCtaLabel;
  final SecondaryActionKind? secondaryActionKind;
  final String? secondaryActionLabel;
  final List<GuildProfile> guilds;

  factory StationSpec.fromJson(Map<String, dynamic> json) {
    final x = (json['normalizedX'] as num?)?.toDouble() ?? 0.5;
    final y = (json['normalizedY'] as num?)?.toDouble() ?? 0.5;
    if (!x.isFinite || !y.isFinite || x < 0 || x > 1 || y < 0 || y > 1) {
      throw FormatException('Invalid normalized map coordinates for ${json['id']}');
    }
    return StationSpec(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      floor: (json['floor'] as num).toInt(),
      floorLabel: json['floorLabel'] as String,
      scanHintParenthetical: json['scanHintParenthetical'] as String? ?? '',
      triggerModeSummary: json['triggerModeSummary'] as String? ?? '',
      heroAsset: json['heroAsset'] as String,
      paragraphs: (json['paragraphs'] as List<dynamic>).cast<String>(),
      callouts: (json['callouts'] as List<dynamic>? ?? const [])
          .map((e) => StationCallout.fromJson(e as Map<String, dynamic>))
          .toList(),
      owner: StationOwner.values.byName(json['owner'] as String? ?? 'andrea'),
      normalizedX: x,
      normalizedY: y,
      unlockedByDefault: json['unlockedByDefault'] == true,
      hasPuzzlePiece: json['hasPuzzlePiece'] != false,
      puzzleCtaLabel:
          json['puzzleCtaLabel'] as String? ??
          'Catch AR Puzzle Piece',
      secondaryActionKind: json['secondaryActionKind'] != null
          ? SecondaryActionKind.values.byName(
              json['secondaryActionKind'] as String,
            )
          : null,
      secondaryActionLabel: json['secondaryActionLabel'] as String?,
      guilds: (json['guilds'] as List<dynamic>? ?? const [])
          .map((e) => GuildProfile.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Language metadata ordered per project specification:
/// 1. English (default, native file -> no translation engine subtitle)
/// 2. Finnish (Suomi)
/// 3. Swedish (Svenska)
/// 4..N. Remaining languages in strict alphabetical order by English name.
class SupportedLanguage {
  const SupportedLanguage({
    required this.code,
    required this.englishName,
    required this.nativeName,
    required this.hasDirectLanguageFile,
    this.translationProviderNote = 'Translated automatically via Google Translate',
  });

  final String code;
  final String englishName;
  final String nativeName;

  /// When true, no auto-translation disclaimer is shown in the selector.
  final bool hasDirectLanguageFile;
  final String translationProviderNote;

  String get displayLabel =>
      englishName == nativeName ? englishName : '$englishName · $nativeName';

  static const List<SupportedLanguage> orderedCatalog = [
    // 1. Default base language (direct file, no translation note)
    SupportedLanguage(
      code: 'en',
      englishName: 'English',
      nativeName: 'English',
      hasDirectLanguageFile: true,
      translationProviderNote: '',
    ),
    // 2. First priority option: Finnish
    SupportedLanguage(
      code: 'fi',
      englishName: 'Finnish',
      nativeName: 'Suomi',
      hasDirectLanguageFile: false,
    ),
    // 3. Second priority option: Swedish
    SupportedLanguage(
      code: 'sv',
      englishName: 'Swedish',
      nativeName: 'Svenska',
      hasDirectLanguageFile: false,
    ),
    // 4+. Strictly alphabetical order (A -> Z)
    SupportedLanguage(
      code: 'ar',
      englishName: 'Arabic',
      nativeName: 'العربية',
      hasDirectLanguageFile: false,
    ),
    SupportedLanguage(
      code: 'zh-CN',
      englishName: 'Chinese (Simplified)',
      nativeName: '简体中文',
      hasDirectLanguageFile: false,
    ),
    SupportedLanguage(
      code: 'nl',
      englishName: 'Dutch',
      nativeName: 'Nederlands',
      hasDirectLanguageFile: false,
    ),
    SupportedLanguage(
      code: 'fr',
      englishName: 'French',
      nativeName: 'Français',
      hasDirectLanguageFile: false,
    ),
    SupportedLanguage(
      code: 'de',
      englishName: 'German',
      nativeName: 'Deutsch',
      hasDirectLanguageFile: false,
    ),
    SupportedLanguage(
      code: 'hi',
      englishName: 'Hindi',
      nativeName: 'हिन्दी',
      hasDirectLanguageFile: false,
    ),
    SupportedLanguage(
      code: 'it',
      englishName: 'Italian',
      nativeName: 'Italiano',
      hasDirectLanguageFile: false,
    ),
    SupportedLanguage(
      code: 'ja',
      englishName: 'Japanese',
      nativeName: '日本語',
      hasDirectLanguageFile: false,
    ),
    SupportedLanguage(
      code: 'ko',
      englishName: 'Korean',
      nativeName: '한국어',
      hasDirectLanguageFile: false,
    ),
    SupportedLanguage(
      code: 'pl',
      englishName: 'Polish',
      nativeName: 'Polski',
      hasDirectLanguageFile: false,
    ),
    SupportedLanguage(
      code: 'pt',
      englishName: 'Portuguese',
      nativeName: 'Português',
      hasDirectLanguageFile: false,
    ),
    SupportedLanguage(
      code: 'es',
      englishName: 'Spanish',
      nativeName: 'Español',
      hasDirectLanguageFile: false,
    ),
    SupportedLanguage(
      code: 'tr',
      englishName: 'Turkish',
      nativeName: 'Türkçe',
      hasDirectLanguageFile: false,
    ),
    SupportedLanguage(
      code: 'uk',
      englishName: 'Ukrainian',
      nativeName: 'Українська',
      hasDirectLanguageFile: false,
    ),
  ];

  static SupportedLanguage byCode(String code) => orderedCatalog.firstWhere(
    (lang) => lang.code == code,
    orElse: () => orderedCatalog.first,
  );
}

/// XCI Part 4: Sealed result hierarchy for deterministic scanner dispatch.
sealed class ScanOutcome {
  const ScanOutcome();
}

final class ScanMatchedStation extends ScanOutcome {
  const ScanMatchedStation({
    required this.stationId,
    required this.triggerMethod,
  });
  final String stationId;
  final String triggerMethod;
}

final class ScanCaughtPuzzlePiece extends ScanOutcome {
  const ScanCaughtPuzzlePiece({required this.stationId});
  final String stationId;
}

final class ScanExternalLink extends ScanOutcome {
  const ScanExternalLink({required this.title, required this.url});
  final String title;
  final String url;
}

final class ScanUnrecognized extends ScanOutcome {
  const ScanUnrecognized({required this.hint});
  final String hint;
}

final class TeamMemberProfile {
  const TeamMemberProfile({
    required this.name,
    required this.initials,
    required this.headline,
    required this.bio,
    required this.accentColor,
    required this.linkedinUrl,
    this.githubUrl,
  });

  final String name;
  final String initials;
  final String headline;
  final String bio;
  final Color accentColor;
  final String linkedinUrl;
  final String? githubUrl;

  bool get hasDirectLinkedinProfile =>
      linkedinUrl.contains('linkedin.com/in/');

  static const List<TeamMemberProfile> projectTeam = [
    TeamMemberProfile(
      name: 'Andrea Gollo',
      initials: 'AG',
      headline:
          'Applied AI & Human-Centered Systems MSc · EIT Digital (KTH & Aalto)',
      bio:
          'EIT Digital double-degree Master’s student in ICT Innovation at KTH Royal Institute of Technology and Aalto University, focusing on Edge AI, XR, user-centered design, and product prototyping. Former President of BEST Milan and EY Campus Ambassador.',
      accentColor: Color(0xFF2B2927),
      linkedinUrl: 'https://www.linkedin.com/in/gollo-andrea/',
      githubUrl: 'https://github.com/GolAndrea',
    ),
    TeamMemberProfile(
      name: 'Mustafa Alalawi',
      initials: 'MA',
      headline: 'Software Engineer @ Elisa · CS Student at Aalto University',
      bio:
          'Computer Science student at Aalto University and Software Engineer at Elisa in Helsinki, building AI governance and RAG platforms with Vertex AI and Next.js. Previously worked in software development and IT systems at SSAB and Tavastia.',
      accentColor: Color(0xFF56514A),
      linkedinUrl: 'https://www.linkedin.com/in/mustafa0alalawi/',
      githubUrl: 'https://github.com/Mustafa0Alalawi',
    ),
    TeamMemberProfile(
      name: 'Juhani',
      initials: 'JL',
      headline: 'Computer Science Student · Aalto University',
      bio:
          'Computer Science student at Aalto University interested in software engineering, interactive systems, and cross-platform application development.',
      accentColor: Color(0xFF7A6B58),
      linkedinUrl: 'https://www.linkedin.com/',
      githubUrl: 'https://github.com/juhalo',
    ),
    TeamMemberProfile(
      name: 'Yunpeng Que',
      initials: 'YQ',
      headline:
          'Human-Computer Interaction & Design MSc · Aalto University & KTH',
      bio:
          'EIT Digital double-degree Master’s student in Human-Computer Interaction and Design at Aalto University and KTH Royal Institute of Technology, with a Bachelor of Engineering in Digital Media Technology from Shanghai University.',
      accentColor: Color(0xFF45413C),
      linkedinUrl: 'https://www.linkedin.com/in/yunpeng-que-900b2a444/',
      githubUrl: 'https://github.com/queyunpeng25-debug',
    ),
    TeamMemberProfile(
      name: 'Niccolò Sobrero',
      initials: 'NS',
      headline:
          'Human-Computer Interaction & Design MSc · EIT Digital (PoliMi & Aalto)',
      bio:
          'EIT Digital double-degree Master’s student in Human-Computer Interaction and Design at Politecnico di Milano and Aalto University, with a minor in Innovation & Entrepreneurship. Experienced in backend and web development, virtual reality, and AI-driven interactive applications.',
      accentColor: Color(0xFF8A7B68),
      linkedinUrl: 'https://www.linkedin.com/in/niccol%C3%B2-sobrero/',
      githubUrl: 'https://github.com/NiccoloSobrero',
    ),
  ];
}
