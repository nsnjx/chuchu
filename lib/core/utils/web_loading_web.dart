// Web: hide the #loading placeholder after Flutter has painted.

import 'dart:async';
import 'dart:html' as html;

void hideWebLoading() {
  try {
    final el = html.document.getElementById('loading');
    if (el != null) {
      el.className = 'hidden';
      Future.delayed(const Duration(milliseconds: 250), () {
        el.remove();
      });
    }
  } catch (_) {}
}
