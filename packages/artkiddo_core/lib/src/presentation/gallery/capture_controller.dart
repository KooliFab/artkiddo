import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../async_action.dart';
import '../../local/audio/audio_recorder_service.dart';
import '../../local/logging/log.dart';
import '../providers/core_providers.dart';
import '../../domain/action_result.dart';
import '../children/children_providers.dart';
import 'gallery_providers.dart';

enum CaptureOrigin { galleryFab, galleryEmpty, galleryEmptyFiltered }

enum CaptureStep { sourceChoice, review, details }

class CaptureEntry {
  final String? preselectedChildId; // from a filtered empty state
  final CaptureOrigin origin;

  const CaptureEntry({this.preselectedChildId, required this.origin});
}

enum PermissionStatus { granted, denied, limited, unavailable }

class PermissionStatusPair {
  final PermissionStatus camera;
  final PermissionStatus photos;
  const PermissionStatusPair({
    this.camera = PermissionStatus.granted,
    this.photos = PermissionStatus.granted,
  });

  PermissionStatusPair copyWith({
    PermissionStatus? camera,
    PermissionStatus? photos,
  }) {
    return PermissionStatusPair(
      camera: camera ?? this.camera,
      photos: photos ?? this.photos,
    );
  }
}

class CaptureDraft {
  final String temporaryImagePath;
  final String? temporaryAudioPath;
  final int? audioDurationMs;
  final String story; // '' = no anecdote
  final DateTime startedAt;
  final bool cropped;

  const CaptureDraft({
    required this.temporaryImagePath,
    this.temporaryAudioPath,
    this.audioDurationMs,
    this.story = '',
    required this.startedAt,
    this.cropped = false,
  });

  CaptureDraft copyWith({
    String? temporaryImagePath,
    String? temporaryAudioPath,
    bool clearAudio = false,
    int? audioDurationMs,
    String? story,
    bool? cropped,
  }) => CaptureDraft(
    temporaryImagePath: temporaryImagePath ?? this.temporaryImagePath,
    temporaryAudioPath: clearAudio
        ? null
        : (temporaryAudioPath ?? this.temporaryAudioPath),
    audioDurationMs: clearAudio
        ? null
        : (audioDurationMs ?? this.audioDurationMs),
    story: story ?? this.story,
    startedAt: startedAt,
    cropped: cropped ?? this.cropped,
  );
}

class CaptureState {
  final CaptureStep step;
  final CaptureDraft? draft;
  final String? selectedChildId; // null = no choice; never filled implicitly
  final bool childSelectedManually;
  final bool artistErrorShown;
  final AsyncAction save;
  final PermissionStatusPair permissions;
  final PermissionStatus micPermission;
  final String? childCreatedBanner;
  final bool reviewUnreadable;
  final bool reviewTooLarge;
  final bool reviewLoading;
  final ImageSource?
  lastSource; // for "Reprendre" relaunching the same source (screens.md §4.2)
  final bool isRecording;
  final int recordingDurationMs;
  final double soundLevel;
  final bool isPlayingAudio;
  final int playbackPositionMs;

  const CaptureState({
    this.step = CaptureStep.sourceChoice,
    this.draft,
    this.selectedChildId,
    this.childSelectedManually = false,
    this.artistErrorShown = false,
    this.save = const ActionIdle(),
    this.permissions = const PermissionStatusPair(),
    this.micPermission = PermissionStatus.granted,
    this.childCreatedBanner,
    this.reviewUnreadable = false,
    this.reviewTooLarge = false,
    this.reviewLoading = false,
    this.lastSource,
    this.isRecording = false,
    this.recordingDurationMs = 0,
    this.soundLevel = 0.0,
    this.isPlayingAudio = false,
    this.playbackPositionMs = 0,
  });

  bool get isDirty =>
      draft != null &&
      (draft!.story.trim().isNotEmpty ||
          draft!.temporaryAudioPath != null ||
          childSelectedManually);

  CaptureState copyWith({
    CaptureStep? step,
    CaptureDraft? draft,
    bool clearDraft = false,
    String? selectedChildId,
    bool clearSelectedChildId = false,
    bool? childSelectedManually,
    bool? artistErrorShown,
    AsyncAction? save,
    PermissionStatusPair? permissions,
    PermissionStatus? micPermission,
    String? childCreatedBanner,
    bool clearBanner = false,
    bool? reviewUnreadable,
    bool? reviewTooLarge,
    bool? reviewLoading,
    ImageSource? lastSource,
    bool clearLastSource = false,
    bool? isRecording,
    int? recordingDurationMs,
    double? soundLevel,
    bool? isPlayingAudio,
    int? playbackPositionMs,
  }) {
    return CaptureState(
      step: step ?? this.step,
      draft: clearDraft ? null : (draft ?? this.draft),
      selectedChildId: clearSelectedChildId
          ? null
          : (selectedChildId ?? this.selectedChildId),
      childSelectedManually: clearDraft
          ? false
          : (childSelectedManually ?? this.childSelectedManually),
      artistErrorShown: artistErrorShown ?? this.artistErrorShown,
      save: save ?? this.save,
      permissions: permissions ?? this.permissions,
      micPermission: micPermission ?? this.micPermission,
      childCreatedBanner: clearBanner
          ? null
          : (childCreatedBanner ?? this.childCreatedBanner),
      reviewUnreadable: reviewUnreadable ?? this.reviewUnreadable,
      reviewTooLarge: reviewTooLarge ?? this.reviewTooLarge,
      reviewLoading: reviewLoading ?? this.reviewLoading,
      lastSource: clearLastSource || clearDraft
          ? null
          : (lastSource ?? this.lastSource),
      isRecording: isRecording ?? this.isRecording,
      recordingDurationMs: recordingDurationMs ?? this.recordingDurationMs,
      soundLevel: soundLevel ?? this.soundLevel,
      isPlayingAudio: isPlayingAudio ?? this.isPlayingAudio,
      playbackPositionMs: playbackPositionMs ?? this.playbackPositionMs,
    );
  }
}

class CaptureController extends Notifier<CaptureState> {
  CaptureController(this.entry);

  static const _maxAudioDurationMs = 120000;

  final CaptureEntry entry;
  final ImagePicker _picker = ImagePicker();
  StreamSubscription<double>? _ampSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<Duration>? _playerPosSub;
  StreamSubscription<bool>? _playerStateSub;
  String? _currentRecordingPath;

  @override
  CaptureState build() {
    final recorder = ref.read(audioRecorderServiceProvider);
    ref.onDispose(() {
      _ampSub?.cancel();
      _durSub?.cancel();
      _playerPosSub?.cancel();
      _playerStateSub?.cancel();
      final recordingPath = _currentRecordingPath;
      if (recordingPath != null) {
        unawaited(_cancelRecordingOnDispose(recorder, recordingPath));
      }
    });
    return const CaptureState();
  }

  Future<void> _cancelRecordingOnDispose(
    AudioRecorderService recorder,
    String? recordingPath,
  ) async {
    try {
      await recorder.cancelRecording();
      if (recordingPath != null) {
        final file = File(recordingPath);
        if (await file.exists()) await file.delete();
      }
    } catch (e, st) {
      Log.e(
        'Annulation de l’enregistrement à la fermeture impossible',
        e,
        st,
        'Capture',
      );
    }
  }

  Future<void> chooseSource(ImageSource source) async {
    try {
      Log.d('Ouverture du sélecteur ${source.name}', 'Capture');
      final picked = await _picker.pickImage(source: source);
      if (picked == null) {
        Log.d('Sélecteur annulé', 'Capture');
        pickerCancelled();
        return;
      }
      await photoPicked(picked.path, source: source);
    } on PlatformException catch (e) {
      Log.e(
        'Échec du sélecteur ${source.name}',
        e,
        StackTrace.current,
        'Capture',
      );
      final denialCodes = {'camera_access_denied', 'photo_access_denied'};
      if (denialCodes.contains(e.code)) {
        const kind = PermissionStatus.denied;
        state = state.copyWith(
          step: CaptureStep.sourceChoice,
          permissions: source == ImageSource.camera
              ? state.permissions.copyWith(camera: kind)
              : state.permissions.copyWith(photos: kind),
        );
      } else {
        state = state.copyWith(step: CaptureStep.sourceChoice);
      }
    }
  }

  Future<void> photoPicked(String path, {ImageSource? source}) async {
    final file = File(path);
    state = state.copyWith(
      step: CaptureStep.review,
      reviewLoading: true,
      reviewUnreadable: false,
      reviewTooLarge: false,
      lastSource: source,
    );
    try {
      final exists = await file.exists();
      final bytes = exists ? await file.length() : 0;
      if (!exists) {
        Log.w('Fichier sélectionné introuvable', 'Capture');
        state = state.copyWith(reviewLoading: false, reviewUnreadable: true);
        return;
      }
      final tooLarge = bytes > 40 * 1024 * 1024;
      Log.i(
        'Image sélectionnée (${bytes ~/ 1024} Ko${tooLarge ? ', volumineuse' : ''})',
        'Capture',
      );
      state = state.copyWith(
        draft: CaptureDraft(
          temporaryImagePath: path,
          startedAt: DateTime.now(),
        ),
        reviewLoading: false,
        reviewTooLarge: tooLarge,
      );
    } catch (e, st) {
      Log.e('Lecture de l’image sélectionnée impossible', e, st, 'Capture');
      state = state.copyWith(reviewLoading: false, reviewUnreadable: true);
    }
  }

  void pickerCancelled() {
    state = state.copyWith(step: CaptureStep.sourceChoice);
  }

  void reportCameraDenied() {
    state = state.copyWith(
      step: CaptureStep.sourceChoice,
      permissions: state.permissions.copyWith(camera: PermissionStatus.denied),
    );
  }

  Future<void> cropDraft({required String cropTitle}) async {
    final draft = state.draft;
    if (draft == null || draft.cropped) return;
    final croppedPath = await _crop(
      draft.temporaryImagePath,
      cropTitle: cropTitle,
    );
    if (croppedPath == null) {
      await _deleteDraftFile();
      state = state.copyWith(step: CaptureStep.sourceChoice, clearDraft: true);
      return;
    }
    if (croppedPath != draft.temporaryImagePath) {
      try {
        final original = File(draft.temporaryImagePath);
        if (await original.exists()) await original.delete();
      } catch (e, st) {
        Log.e(
          'Suppression de l’original non recadré impossible',
          e,
          st,
          'Capture',
        );
      }
    }
    state = state.copyWith(
      draft: draft.copyWith(temporaryImagePath: croppedPath, cropped: true),
    );
    confirmPhoto();
  }

  Future<String?> _crop(String sourcePath, {required String cropTitle}) async {
    try {
      final result = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 100,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: cropTitle,
            lockAspectRatio: false,
            hideBottomControls: false,
          ),
          IOSUiSettings(title: cropTitle),
        ],
      );
      return result?.path;
    } catch (e, st) {
      Log.e('Recadrage de la photo impossible', e, st, 'Capture');
      return null;
    }
  }

  void confirmPhoto() {
    if (state.draft == null) return;
    final preselected = _applyPreselectionRule();
    state = state.copyWith(
      step: CaptureStep.details,
      selectedChildId: preselected,
      clearSelectedChildId: preselected == null,
    );
  }

  String? _applyPreselectionRule() {
    if (entry.preselectedChildId != null) return entry.preselectedChildId;

    final filter = ref.read(galleryFilterProvider);
    if (filter is OneChild) return filter.childId;

    final children = ref.read(allChildrenStreamProvider).value ?? const [];
    if (filter is AllChildren && children.length == 1) {
      return children.single.id;
    }

    return null; // >=2 children + "all" filter, or 0 children: no selection.
  }

  Future<void> discardDraftForRetake() async {
    await _deleteDraftFile();
    state = state.copyWith(
      clearDraft: true,
      reviewUnreadable: false,
      reviewTooLarge: false,
    );
  }

  Future<void> retakeSameSource() async {
    final source = state.lastSource;
    await discardDraftForRetake();
    if (source == null) {
      state = state.copyWith(step: CaptureStep.sourceChoice);
      return;
    }
    await chooseSource(source);
  }

  Future<void> backToSourceChoice() async {
    await _deleteDraftFile();
    state = state.copyWith(
      step: CaptureStep.sourceChoice,
      clearDraft: true,
      reviewUnreadable: false,
      reviewTooLarge: false,
    );
  }

  Future<void> backToReviewFromDetails() async {
    if (state.isRecording) await cancelRecording();
    state = state.copyWith(step: CaptureStep.review);
  }

  Future<void> discardDraft() => _deleteDraftFile();

  Future<void> _deleteDraftFile() async {
    if (state.isRecording) {
      await cancelRecording();
    }
    await stopAudio();
    final path = state.draft?.temporaryImagePath;
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (e, st) {
        Log.e(
          'Suppression du brouillon temporaire impossible',
          e,
          st,
          'Capture',
        );
      }
    }
    final audioPath = state.draft?.temporaryAudioPath;
    if (audioPath != null) {
      try {
        final file = File(audioPath);
        if (await file.exists()) await file.delete();
      } catch (e, st) {
        Log.e(
          'Suppression du brouillon audio temporaire impossible',
          e,
          st,
          'Capture',
        );
      }
    }
  }

  void selectChild(String? childId) {
    state = state.copyWith(
      selectedChildId: childId,
      clearSelectedChildId: childId == null,
      childSelectedManually: true,
      artistErrorShown: false,
    );
  }

  void updateStory(String text) {
    if (state.draft == null) return;
    final trimmed = text.length > 500 ? text.substring(0, 500) : text;
    state = state.copyWith(draft: state.draft!.copyWith(story: trimmed));
  }

  void childCreated(String childId, String childName) {
    if (state.step != CaptureStep.details) return;
    selectChild(childId);
    state = state.copyWith(childCreatedBanner: childName);
  }

  void consumeChildCreatedBanner() {
    state = state.copyWith(clearBanner: true);
  }

  Future<ActionResult<String>> save() async {
    if (state.save.isBusy || state.isRecording) return const ActionCancelled();
    final draft = state.draft;
    if (draft == null) return const ActionCancelled();

    if (state.selectedChildId == null) {
      Log.w('Enregistrement bloqué : artiste non sélectionné', 'Capture');
      state = state.copyWith(artistErrorShown: true);
      return const ActionCancelled();
    }

    state = state.copyWith(save: const ActionBusy());
    final repository = ref.read(masterpiecesRepositoryProvider);
    final story = draft.story.trim().isEmpty ? null : draft.story.trim();

    final result = await repository.create(
      childId: state.selectedChildId!,
      sourceImageFile: File(draft.temporaryImagePath),
      sourceAudioFile: draft.temporaryAudioPath != null
          ? File(draft.temporaryAudioPath!)
          : null,
      audioDurationMs: draft.audioDurationMs,
      addedAt: DateTime.now(),
      story: story,
    );

    switch (result) {
      case ActionSuccess(value: final id):
        Log.i('Œuvre enregistrée ($id)', 'Capture');
        try {
          final tmp = File(draft.temporaryImagePath);
          if (await tmp.exists()) await tmp.delete();
        } catch (e, st) {
          Log.w(
            'Suppression du fichier temporaire après enregistrement impossible : $e',
            'Capture',
          );
          Log.d(st.toString(), 'Capture');
        }
        if (draft.temporaryAudioPath != null) {
          try {
            final tmpA = File(draft.temporaryAudioPath!);
            if (await tmpA.exists()) await tmpA.delete();
          } catch (e, st) {
            Log.e(
              'Suppression du fichier audio temporaire après enregistrement impossible',
              e,
              st,
              'Capture',
            );
          }
        }
        state = state.copyWith(
          save: const ActionDone(),
          clearDraft: true,
          clearSelectedChildId: true,
        );
        ref.read(highlightedArtworkProvider.notifier).highlight(id);
        try {
          await HapticFeedback.lightImpact();
        } catch (e, st) {
          Log.w('Retour haptique indisponible : $e', 'Capture');
          Log.d(st.toString(), 'Capture');
        }
      case ActionFailed(failure: final f):
        Log.w('Enregistrement de l’œuvre refusé : ${f.runtimeType}', 'Capture');
        state = state.copyWith(save: ActionError(f));
      case ActionCancelled():
        state = state.copyWith(save: const ActionIdle());
    }
    return result;
  }

  Future<void> startRecording() async {
    if (state.isRecording) return;
    await stopAudio();
    final recorder = ref.read(audioRecorderServiceProvider);

    try {
      final hasPerm = await recorder.hasPermission();
      if (!hasPerm) {
        final granted = await recorder.requestPermission();
        if (!granted) {
          state = state.copyWith(micPermission: PermissionStatus.denied);
          return;
        }
      }
    } catch (e, st) {
      Log.e('Erreur permission microphone', e, st, 'Capture');
      state = state.copyWith(micPermission: PermissionStatus.denied);
      return;
    }

    state = state.copyWith(
      micPermission: PermissionStatus.granted,
      isRecording: true,
      recordingDurationMs: 0,
      soundLevel: 0.0,
    );
    final tempPath =
        '${Directory.systemTemp.path}/artkiddo_rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _currentRecordingPath = tempPath;

    _ampSub?.cancel();
    _ampSub = recorder.amplitudeStream.listen((amp) {
      state = state.copyWith(soundLevel: amp);
    });

    _durSub?.cancel();
    _durSub = recorder.durationStream.listen((dur) {
      final ms = dur.inMilliseconds;
      if (ms >= _maxAudioDurationMs) {
        stopRecording();
      } else {
        state = state.copyWith(recordingDurationMs: ms);
      }
    });

    try {
      await recorder.startRecording(targetPath: tempPath);
    } catch (e, st) {
      Log.e('Erreur au démarrage de l’enregistrement', e, st, 'Capture');
      _ampSub?.cancel();
      _durSub?.cancel();
      _currentRecordingPath = null;
      try {
        final file = File(tempPath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
      state = state.copyWith(isRecording: false);
    }
  }

  Future<void> stopRecording() async {
    if (!state.isRecording) return;
    final recorder = ref.read(audioRecorderServiceProvider);
    final durMs = await recorder.stopRecording();
    _ampSub?.cancel();
    _durSub?.cancel();

    final path = _currentRecordingPath;
    _currentRecordingPath = null;

    state = state.copyWith(
      isRecording: false,
      soundLevel: 0.0,
      draft: state.draft?.copyWith(
        temporaryAudioPath: path,
        audioDurationMs: (durMs ?? state.recordingDurationMs)
            .clamp(1, _maxAudioDurationMs)
            .toInt(),
      ),
    );
  }

  Future<void> cancelRecording() async {
    if (!state.isRecording) return;
    final recorder = ref.read(audioRecorderServiceProvider);
    await recorder.cancelRecording();
    _ampSub?.cancel();
    _durSub?.cancel();
    _currentRecordingPath = null;
    state = state.copyWith(
      isRecording: false,
      recordingDurationMs: 0,
      soundLevel: 0.0,
    );
  }

  Future<void> deleteAudio() async {
    if (state.isRecording) {
      await cancelRecording();
    }
    await stopAudio();
    final path = state.draft?.temporaryAudioPath;
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (e, st) {
        Log.e('Erreur suppression audio draft', e, st, 'Capture');
      }
    }
    state = state.copyWith(
      draft: state.draft?.copyWith(clearAudio: true),
      playbackPositionMs: 0,
      isPlayingAudio: false,
    );
  }

  Future<void> playAudio() async {
    final path = state.draft?.temporaryAudioPath;
    if (path == null) return;
    final player = ref.read(audioPlayerServiceProvider);
    await player.setFilePath(path);
    _playerPosSub?.cancel();
    _playerPosSub = player.positionStream.listen((pos) {
      state = state.copyWith(playbackPositionMs: pos.inMilliseconds);
    });
    _playerStateSub?.cancel();
    _playerStateSub = player.isPlayingStream.listen((playing) {
      state = state.copyWith(isPlayingAudio: playing);
    });
    await player.play();
  }

  Future<void> pauseAudio() async {
    final player = ref.read(audioPlayerServiceProvider);
    await player.pause();
    state = state.copyWith(isPlayingAudio: false);
  }

  Future<void> stopAudio() async {
    final player = ref.read(audioPlayerServiceProvider);
    await player.stop();
    state = state.copyWith(isPlayingAudio: false, playbackPositionMs: 0);
  }

  Future<void> togglePlayback() async {
    if (state.isPlayingAudio) {
      await pauseAudio();
    } else {
      await playAudio();
    }
  }

  bool get hasNoChildren =>
      (ref.read(allChildrenStreamProvider).value ?? const []).isEmpty;

  bool get artistRequiredWithoutSelection {
    final filter = ref.read(galleryFilterProvider);
    final children = ref.read(allChildrenStreamProvider).value ?? const [];
    return filter is AllChildren &&
        children.length >= 2 &&
        state.selectedChildId == null;
  }
}

final captureControllerProvider =
    NotifierProvider.family<CaptureController, CaptureState, CaptureEntry>(
      CaptureController.new,
    );
