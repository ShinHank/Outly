import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';

/// Opens a place's website in an in-app browser. When the place has no known
/// website it opens a web search for "name + city" instead, so a branch in
/// another city is not shown.
Future<void> openPlacePage(
  BuildContext context, {
  required ApiService api,
  required String name,
  required double latitude,
  required double longitude,
  String website = '',
}) async {
  final messenger = ScaffoldMessenger.of(context);
  Uri? uri;
  if (website.isNotEmpty) {
    uri = Uri.tryParse(website);
  } else {
    final city = (latitude == 0 && longitude == 0)
        ? ''
        : await api.cityOf(latitude, longitude);
    uri = Uri.https('www.google.com', '/search', {
      'q': [name, city].where((part) => part.isNotEmpty).join(' '),
    });
  }
  if (uri == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Invalid web address.')));
    return;
  }
  try {
    var opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!opened) {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the page.')),
      );
    }
  } catch (e) {
    debugPrint('[Outly] could not open $uri: $e');
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not open the page.')),
    );
  }
}
