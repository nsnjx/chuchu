// Web: detect if page was loaded over HTTPS (for Mixed Content: ws:// blocked only on HTTPS)
import 'dart:html' as html;

bool get isWebPageHttps => html.window.location.protocol == 'https:';
