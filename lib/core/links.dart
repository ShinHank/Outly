import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a place's website in an in-app browser. When the place has no known
/// website it opens a web search for it instead.
Future<void> openPlacePage(
  BuildContext context, {
  required String name,
  String website = '',
  String hint = '',
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = website.isNotEmpty
      ? Uri.tryParse(website)
      : Uri.https('www.google.com', '/search', {
          'q': [name, hint].where((part) => part.isNotEmpty).join(' '),
        });
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
