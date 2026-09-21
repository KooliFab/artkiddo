import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:artkiddo_core/artkiddo_core.dart';

void main() {
  late Directory tempRoot;
  late Directory docsDir;
  late AppDatabase db;
  late LocalVault vault;
  late FakeAudioRecorderService fakeRecorder;
  late FakeAudioPlayerService fakePlayer;
  late ProviderContainer container;

  const entry = CaptureEntry(origin: CaptureOrigin.galleryFab);

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp(
      'artkiddo_capture_audio_test_',
    );
    docsDir = Directory(p.join(tempRoot.path, 'docs'));
    await docsDir.create(recursive: true);
    db = AppDatabase.forTesting(
      NativeDatabase(File(p.join(tempRoot.path, 'test.sqlite'))),
    );
    vault = LocalVault(documentsDirProvider: () async => docsDir);
    fakeRecorder = FakeAudioRecorderService();
    fakePlayer = FakeAudioPlayerService();

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) => db),
        localVaultProvider.overrideWith((ref) => vault),
        audioRecorderServiceProvider.overrideWith((ref) => fakeRecorder),
        audioPlayerServiceProvider.overrideWith((ref) => fakePlayer),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  Future<File> makeSourceImage(String name) async {
    final file = File(p.join(tempRoot.path, name));
    await file.writeAsString('fake-image-bytes');
    return file;
  }

  test(
    'recording lifecycle: start, amplitude/duration updates, auto-stop and manual stop',
    () async {
      final controller = container.read(
        captureControllerProvider(entry).notifier,
      );
      final file = await makeSourceImage('drawing.jpg');
      await controller.photoPicked(file.path);
      controller.confirmPhoto();

      expect(container.read(captureControllerProvider(entry)).isDirty, isFalse);

      // Start recording
      await controller.startRecording();
      var state = container.read(captureControllerProvider(entry));
      expect(state.isRecording, isTrue);

      // Amplitude & duration streams
      fakeRecorder.emitAmplitude(0.75);
      await pumpEventQueue();
      state = container.read(captureControllerProvider(entry));
      expect(state.soundLevel, 0.75);

      fakeRecorder.emitDuration(const Duration(seconds: 10));
      await pumpEventQueue();
      state = container.read(captureControllerProvider(entry));
      expect(state.recordingDurationMs, 10000);

      // Stop recording
      fakeRecorder.fakeRecordedDurationMs = 15000;
      await controller.stopRecording();

      state = container.read(captureControllerProvider(entry));
      expect(state.isRecording, isFalse);
      expect(state.draft?.temporaryAudioPath, isNotNull);
      expect(state.draft?.audioDurationMs, 15000);
      expect(
        state.isDirty,
        isTrue,
        reason: 'Having audio makes the draft dirty',
      );

      // Delete audio
      await controller.deleteAudio();
      state = container.read(captureControllerProvider(entry));
      expect(state.draft?.temporaryAudioPath, isNull);
      expect(state.draft?.audioDurationMs, isNull);
      expect(state.isDirty, isFalse);
    },
  );

  test('save is blocked while recording is in progress', () async {
    final controller = container.read(
      captureControllerProvider(entry).notifier,
    );
    final file = await makeSourceImage('drawing.jpg');
    await controller.photoPicked(file.path);
    controller.confirmPhoto();

    await controller.startRecording();
    expect(
      container.read(captureControllerProvider(entry)).isRecording,
      isTrue,
    );

    final saveResult = await controller.save();
    expect(saveResult, isA<ActionCancelled>());
  });

  test(
    'recording duration is capped at two minutes before it is persisted',
    () async {
      final controller = container.read(
        captureControllerProvider(entry).notifier,
      );
      final file = await makeSourceImage('drawing.jpg');
      await controller.photoPicked(file.path);
      controller.confirmPhoto();

      await controller.startRecording();
      fakeRecorder.fakeRecordedDurationMs = 120100;
      await controller.stopRecording();

      final state = container.read(captureControllerProvider(entry));
      expect(state.draft?.audioDurationMs, 120000);
    },
  );

  test(
    'durable save creates artwork with audio and cleans up temporary audio file',
    () async {
      final childrenRepo = container.read(childrenRepositoryProvider);
      final childResult = await childrenRepo.create(
        name: 'Emma',
        birthDate: DateTime(2020, 1, 1),
      );
      final childId = (childResult as ActionSuccess<String>).value;

      final controller = container.read(
        captureControllerProvider(entry).notifier,
      );
      final file = await makeSourceImage('drawing.jpg');
      await controller.photoPicked(file.path);
      controller.confirmPhoto();
      controller.selectChild(childId);

      // Simulate audio recording
      final dummyAudio = File(p.join(tempRoot.path, 'dummy_rec.m4a'));
      await dummyAudio.writeAsString('audio-bytes');

      await controller.startRecording();
      await controller.stopRecording();

      // Directly set temporaryAudioPath to dummyAudio
      final controllerState = container.read(captureControllerProvider(entry));
      container
          .read(captureControllerProvider(entry).notifier)
          .state = controllerState.copyWith(
        draft: controllerState.draft?.copyWith(
          temporaryAudioPath: dummyAudio.path,
          audioDurationMs: 5000,
        ),
      );

      final saveResult = await controller.save();
      expect(saveResult, isA<ActionSuccess<String>>());
      final mpId = (saveResult as ActionSuccess<String>).value;

      final mpRepo = container.read(artworksRepositoryProvider);
      final savedMp = await mpRepo.getById(mpId);
      expect(savedMp, isNotNull);
      expect(savedMp!.hasAudio, isTrue);
      expect(savedMp.audioDurationMs, 5000);
      expect(savedMp.isAudioLocal, isTrue);

      // Temporary audio file was cleaned up
      expect(await dummyAudio.exists(), isFalse);
    },
  );
}
