import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class CanteenMenuException implements Exception {
  const CanteenMenuException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CanteenMenuService {
  CanteenMenuService({this.client});

  static final Uri _menuUri = Uri.parse(
    'https://folio.kanttiinit.fi/en/area/1',
  );
  static const String _restaurantId = 'computer-science-building';

  final http.Client? client;

  Future<List<String>> fetchMenu() async {
    if (kIsWeb) {
      throw const CanteenMenuException(
        'Live menu refresh is unavailable in the web build because the source '
        'does not allow cross-origin browser requests. Open Kanttiinit to view '
        'the current menu.',
      );
    }

    late final http.Response response;
    try {
      response = await (client?.get(_menuUri) ?? http.get(_menuUri)).timeout(
        const Duration(seconds: 15),
      );
    } on http.ClientException catch (error) {
      throw CanteenMenuException(
        'Could not load the canteen menu: ${error.message}',
      );
    } on TimeoutException {
      throw const CanteenMenuException('Loading the canteen menu timed out.');
    }

    if (response.statusCode != 200) {
      throw CanteenMenuException(
        'Could not load the canteen menu (HTTP ${response.statusCode}).',
      );
    }

    return parseMenu(response.body);
  }

  static List<String> parseMenu(String source) {
    final document = html_parser.parse(source);
    final restaurant = document.getElementById(_restaurantId);
    if (restaurant == null) {
      throw const CanteenMenuException(
        'The canteen restaurant was not found on the menu page.',
      );
    }

    final menuList = restaurant.querySelector('ul');
    if (menuList == null) {
      throw const CanteenMenuException(
        'The canteen menu page did not contain a dish list.',
      );
    }

    final dishes = <String>[];
    for (final item in menuList.children) {
      if (item.localName != 'li') continue;

      final dietaryLabels = item
          .querySelectorAll('abbr')
          .map((abbr) => abbr.attributes['title']?.trim() ?? '')
          .where((label) => label.isNotEmpty)
          .toSet()
          .toList();
      item.querySelectorAll('abbr').forEach((abbr) => abbr.remove());
      final name = item.text
          .replaceAll(RegExp(r'\(\s*(?:,\s*)*\)'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (name.isEmpty) continue;

      dishes.add(
        dietaryLabels.isEmpty ? name : '$name (${dietaryLabels.join(', ')})',
      );
    }

    if (dishes.isEmpty) {
      throw const CanteenMenuException(
        'The canteen menu page did not contain any dishes.',
      );
    }
    return dishes;
  }
}

class CanteenMenuRepository extends ChangeNotifier {
  CanteenMenuRepository({CanteenMenuService? service})
    : _service = service ?? CanteenMenuService();

  final CanteenMenuService _service;

  List<String> dishes = const [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> refresh() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      dishes = await _service.fetchMenu();
    } on CanteenMenuException catch (error) {
      errorMessage = error.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
