import 'dart:convert';

import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../contracts/following.dart';
import '../../local/logging/log.dart';
import 'followed_feed_providers.dart';

/// The names a followed artist goes by, before any nickname.
abstract final class FollowedArtistNames {
  /// "Tom Martin": the first name and the household's name.
  static String full(String name, String? familyName) {
    final family = familyName?.trim() ?? '';
    return family.isEmpty ? name : '$name $family';
  }

  /// "Tom M.": the first name and the household's initial; the first name
  /// alone while the household has no name.
  static String short(String name, String? familyName) {
    final family = familyName?.trim() ?? '';
    if (family.isEmpty) return name;
    return '$name ${family.characters.first.toUpperCase()}.';
  }
}

/// Nicknames the user gives to followed artists, keyed by child id. They
/// stay on this device: never synced, never sent, never seen by the
/// household.
class FollowedNicknamesNotifier extends Notifier<Map<String, String>> {
  static const prefsKey = 'followed_artist_nicknames';

  late Future<void> _loaded;

  @override
  Map<String, String> build() {
    _loaded = _load();
    return const {};
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      state = {
        for (final MapEntry(:key, :value) in decoded.entries)
          if (key is String && value is String && value.trim().isNotEmpty)
            key: value.trim(),
      };
    } catch (error, stack) {
      Log.e('Lecture des surnoms impossible', error, stack, 'Following');
    }
  }

  /// Gives [childId] a nickname; a blank one removes it.
  Future<void> setNickname(String childId, String? nickname) async {
    await _loaded;
    final value = nickname?.trim() ?? '';
    final next = {...state};
    if (value.isEmpty) {
      next.remove(childId);
    } else {
      next[childId] = value;
    }
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(next));
  }
}

final followedNicknamesProvider =
    NotifierProvider<FollowedNicknamesNotifier, Map<String, String>>(
      FollowedNicknamesNotifier.new,
    );

/// What the gallery calls a followed artist: the user's nickname, else
/// "Prénom N." ([FollowedArtistNames.short]).
class FollowedArtistLabels {
  final Map<String, String> nicknames;

  const FollowedArtistLabels(this.nicknames);

  String of({
    required String childId,
    required String name,
    required String? familyName,
  }) => nicknames[childId] ?? FollowedArtistNames.short(name, familyName);

  String ofChild(FollowedChildInfo info) => of(
    childId: info.child.id,
    name: info.child.name,
    familyName: info.family.familyName,
  );

  String ofArtwork(FollowedArtwork artwork) => of(
    childId: artwork.childId,
    name: artwork.childName,
    familyName: artwork.familyName,
  );
}

/// The labels with the current nicknames: a nickname edit relabels the
/// gallery at once.
final followedArtistLabelsProvider = Provider<FollowedArtistLabels>(
  (ref) => FollowedArtistLabels(ref.watch(followedNicknamesProvider)),
);
