/// Invite-code parsing shared by every entry point that receives a code:
/// manual input, clipboard, QR scan, and incoming links.
///
/// Pure Dart on purpose: no Flutter, no provider, no host name. The link
/// *builder* belongs to the composition (`CompositionActions.inviteLinkFor`);
/// this file only recognises the shapes a code can arrive in.
library;

/// Code alphabet shared with the issuer: no `0/O`, `1/I`, which are
/// ambiguous when read aloud or typed.
const String _alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

/// Accepted code shapes by kind; [normalizeInviteCode] checks them all.
/// `family` joins the household (and may leave the current one); `circle`
/// only follows a household, read-only.
final Map<String, RegExp> kInviteCodePatterns = {
  'family': RegExp('^[$_alphabet]{8}\$'),
  'circle': RegExp('^[$_alphabet]{10}\$'),
};

/// Longest accepted code, for input fields.
const int kInviteCodeMaxLength = 10;

/// The kind of a normalized [code] (`family`, `circle`), or null when it
/// matches no pattern.
String? inviteCodeKind(String code) {
  final normalized = code.trim().toUpperCase();
  for (final entry in kInviteCodePatterns.entries) {
    if (entry.value.hasMatch(normalized)) return entry.key;
  }
  return null;
}

/// Custom scheme used by the web join page to open the app.
const String kInviteAppScheme = 'artkiddo';

/// Returns the normalized (trimmed, uppercase) invite code found in [raw], or
/// null when nothing valid is there.
///
/// [raw] may be a bare code, an `http(s)` URL whose path ends in `/join` or
/// `/join/` with a `code` query parameter, or `artkiddo://join?code=`.
String? normalizeInviteCode(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  final urlToken = RegExp(r'\S+://\S+').firstMatch(text)?.group(0);
  if (urlToken != null) {
    final stripped = urlToken.replaceFirst(RegExp(r'[)\]}>,.;:!?"\x27]+$'), '');
    final extracted = _codeFromUri(Uri.tryParse(stripped));
    return extracted == null ? null : _matchCode(extracted);
  }

  final whole = _matchCode(text);
  if (whole != null) return whole;

  // Free text such as "... (code ABCD2345)": a standalone token.
  for (final token in text.split(RegExp(r'[^A-Za-z0-9]+'))) {
    final code = _matchCode(token);
    if (code != null) return code;
  }
  return null;
}

String? _matchCode(String candidate) {
  final code = candidate.trim().toUpperCase();
  for (final pattern in kInviteCodePatterns.values) {
    if (pattern.hasMatch(code)) return code;
  }
  return null;
}

String? _codeFromUri(Uri? uri) {
  if (uri == null) return null;
  final scheme = uri.scheme.toLowerCase();
  final bool isJoinTarget;
  if (scheme == 'http' || scheme == 'https') {
    if (uri.host.isEmpty) return null;
    final path = uri.path;
    isJoinTarget = path.endsWith('/join') || path.endsWith('/join/');
  } else if (scheme == kInviteAppScheme) {
    isJoinTarget =
        uri.host.toLowerCase() == 'join' &&
        (uri.path.isEmpty || uri.path == '/');
  } else {
    isJoinTarget = false;
  }
  if (!isJoinTarget) return null;
  return uri.queryParametersAll['code']?.first;
}
