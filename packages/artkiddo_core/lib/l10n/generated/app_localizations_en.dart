// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonAppName => 'artkiddo';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSaving => 'Saving…';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonDeleting => 'Deleting…';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonCopied => 'Link copied.';

  @override
  String get commonSend => 'Send';

  @override
  String get commonOpenSettings => 'Open settings';

  @override
  String get commonUnderstood => 'Got it';

  @override
  String get commonContinueEditing => 'Continue';

  @override
  String get commonDiscard => 'Discard';

  @override
  String get commonExampleLabel => 'Example';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonOptional => 'optional';

  @override
  String get commonRequired => 'required';

  @override
  String get commonContactUs => 'Contact us';

  @override
  String get commonOpensBrowser => 'Opens your browser';

  @override
  String get commonDiscardTitle => 'Discard your changes?';

  @override
  String get commonDiscardBody => 'What you entered will not be kept.';

  @override
  String get commonDateFormat => 'yMMMMd';

  @override
  String get commonDateFormatShort => 'yMMMd';

  @override
  String get onboardingPage1Title =>
      'The drawing is put away, the memory stays.';

  @override
  String get onboardingPage1Body =>
      'Take a photo of the drawing before it gets damaged, and keep it without cluttering your home.';

  @override
  String get onboardingPage2Title => 'Everything stays on your device.';

  @override
  String get onboardingPage2Body =>
      'Photos are saved on this device. No account is needed to get started.';

  @override
  String get onboardingPage3Title => 'Ready to start.';

  @override
  String get onboardingPage3Body =>
      'Add a first drawing whenever you like. You\'ll be able to introduce the artist right after.';

  @override
  String get onboardingStart => 'Start my album';

  @override
  String a11yOnboardingPageIndicator(int n) {
    return 'Page $n of 3';
  }

  @override
  String get navGallery => 'Gallery';

  @override
  String get navChildren => 'Children';

  @override
  String get navSettings => 'Settings';

  @override
  String a11yNavSelected(String label) {
    return '$label, selected';
  }

  @override
  String get galleryTitle => 'Gallery';

  @override
  String galleryCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drawings',
      one: '1 drawing',
      zero: 'No drawings',
    );
    return '$_temp0';
  }

  @override
  String galleryCountForChild(num count, String childName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drawings from $childName',
      one: '1 drawing from $childName',
      zero: 'No drawings from $childName',
    );
    return '$_temp0';
  }

  @override
  String get galleryFilterAll => 'All';

  @override
  String get galleryFilterLabel => 'Filter by child';

  @override
  String get galleryAddArtwork => 'Add a drawing';

  @override
  String galleryAddArtworkFor(String childName) {
    return 'Add a drawing from $childName';
  }

  @override
  String get galleryEmptyNoChildTitle => 'Start by introducing the artist';

  @override
  String get galleryEmptyNoChildBody =>
      'Add a child: every drawing will be assigned to them and their age will show automatically.';

  @override
  String get galleryEmptyNoChildAction => 'Add a child';

  @override
  String get galleryEmptyNoArtworkTitle => 'Your gallery is ready';

  @override
  String get galleryEmptyNoArtworkBody =>
      'Add the first drawing. It will stay on this device.';

  @override
  String galleryEmptyFilteredTitle(String childName) {
    return 'No drawings from $childName yet';
  }

  @override
  String get galleryEmptyFilteredBody =>
      'Add one, or go back to the full gallery.';

  @override
  String get galleryEmptyFilteredShowAll => 'View all drawings';

  @override
  String get galleryErrorTitle => 'Your gallery couldn\'t be opened';

  @override
  String get galleryErrorBody => 'Your drawings are still on the device.';

  @override
  String galleryFilterReset(String childName) {
    return '$childName was deleted. The gallery now shows all drawings again.';
  }

  @override
  String get galleryImageMissing => 'Image not found';

  @override
  String get galleryArtworkAdded => 'Drawing added to the gallery.';

  @override
  String a11yGalleryCard(String childName, DateTime date, String age) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Drawing from $childName, added on $dateString, $age when added.';
  }

  @override
  String a11yGalleryCardWithStory(
    String childName,
    DateTime date,
    String age,
    String story,
  ) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Drawing from $childName, added on $dateString, $age when added. Story: $story';
  }

  @override
  String a11yGalleryFilterChanged(String label, int count) {
    return 'Filter: $label. $count drawings.';
  }

  @override
  String artworkAddedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Added on $dateString';
  }

  @override
  String artworkAgeAtAddition(String age) {
    return 'Age when added: $age';
  }

  @override
  String artworkDrawnOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Drawn on $dateString';
  }

  @override
  String artworkAgeAtDrawing(String age) {
    return 'Age when drawn: $age';
  }

  @override
  String get ageLessThanMonth => 'Less than 1 month';

  @override
  String ageMonths(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String ageYears(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String ageYearsMonths(num years, num months) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years years',
      one: '1 year',
    );
    String _temp1 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: '1 month',
    );
    return '$_temp0 and $_temp1';
  }

  @override
  String get ageBeforeBirth => 'Before birth';

  @override
  String get captureTitle => 'Add a drawing';

  @override
  String get captureSourceCameraTitle => 'Take a photo';

  @override
  String get captureSourceCameraBody => 'The drawing is in front of you.';

  @override
  String get captureSourceGalleryTitle => 'Choose from my photos';

  @override
  String get captureSourceGalleryBody => 'The drawing is already photographed.';

  @override
  String get captureReviewTitle => 'Is the drawing clearly visible?';

  @override
  String get captureReviewUse => 'Use this photo';

  @override
  String get captureReviewRetake => 'Retake';

  @override
  String get captureReviewUnreadable => 'This image couldn\'t be opened.';

  @override
  String get captureReviewTooLarge =>
      'This image is very large and could slow down the app.';

  @override
  String get captureDetailsTitle => 'Whose drawing is this?';

  @override
  String get captureDetailsViewLarge => 'View full size';

  @override
  String get captureArtistLabel => 'Artist';

  @override
  String get captureArtistChoose => 'Choose the artist';

  @override
  String get captureArtistRequired => 'Choose the artist before saving.';

  @override
  String get captureArtistAddChild => 'Add a child';

  @override
  String get captureNoChildTitle => 'This drawing needs an artist';

  @override
  String get captureNoChildBody =>
      'Add a child: your drawing is kept in the meantime.';

  @override
  String get captureStoryLabel => 'Story (optional)';

  @override
  String get captureStoryHint => 'What the child says about their drawing.';

  @override
  String get captureAudioCardTitle => 'Tell the story';

  @override
  String get captureAudioCardSubtitle =>
      'Record the child\'s voice telling their drawing\'s story (max 2 min).';

  @override
  String get captureAudioRecord => 'Record voice';

  @override
  String get captureAudioRecording => 'Recording…';

  @override
  String get captureAudioStop => 'Stop';

  @override
  String get captureAudioCancel => 'Cancel';

  @override
  String get captureAudioPlay => 'Listen';

  @override
  String get captureAudioPause => 'Pause';

  @override
  String get captureAudioReRecord => 'Re-record';

  @override
  String get captureAudioReRecordConfirmTitle => 'Replace recording?';

  @override
  String get captureAudioReRecordConfirmBody =>
      'The current recording will be replaced with a new one.';

  @override
  String get captureAudioDelete => 'Delete voice note';

  @override
  String get captureAudioDeleteConfirmTitle => 'Delete recording?';

  @override
  String get captureAudioDeleteConfirmBody =>
      'This will delete the voice recording.';

  @override
  String get captureAudioMicPermissionDeniedTitle =>
      'Microphone access required';

  @override
  String get captureAudioMicPermissionDeniedBody =>
      'To record your child\'s voice, please allow microphone access in settings.';

  @override
  String get artworkAudioCardTitle => 'Child\'s voice';

  @override
  String get artworkAudioDownloading => 'Loading voice note…';

  @override
  String get artworkAudioDownloadError => 'Unable to load voice note';

  @override
  String get artworkAudioRetry => 'Retry';

  @override
  String get sharingIncludeAudio => 'Include child voice notes';

  @override
  String get sharingIncludeAudioSubtitle =>
      'Family and friends with the link can listen to the voice notes.';

  @override
  String captureAddedToday(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Added on $dateString';
  }

  @override
  String get captureSave => 'Save the drawing';

  @override
  String captureChildCreated(String childName) {
    return '$childName was added.';
  }

  @override
  String get captureErrorWriteTitle => 'The drawing wasn\'t saved';

  @override
  String get captureErrorWriteBody => 'Nothing was lost. You can try again.';

  @override
  String get captureErrorStorageFullTitle =>
      'There isn\'t enough space left on the device';

  @override
  String get captureErrorStorageFullBody =>
      'Free up some space, then try again.';

  @override
  String get captureDiscardTitle => 'Discard this drawing?';

  @override
  String get captureDiscardBody => 'The photo and story will not be saved.';

  @override
  String get captureDiscardPhotoTitle => 'Discard this photo?';

  @override
  String get captureDiscardPhotoBody => 'You\'ll be able to take another one.';

  @override
  String get permissionCameraDeniedTitle => 'Camera access is denied';

  @override
  String get permissionCameraDeniedBody =>
      'You can still choose an existing photo.';

  @override
  String get permissionPhotosDeniedTitle => 'Photo access is denied';

  @override
  String get permissionPhotosDeniedBody => 'You can still take a new photo.';

  @override
  String get permissionBothDeniedTitle =>
      'artkiddo doesn\'t have access to your photos';

  @override
  String get permissionBothDeniedBody =>
      'Allow the camera or photos in settings to add a drawing.';

  @override
  String get permissionCameraReason => 'Permission needed to take a photo.';

  @override
  String get permissionPhotosReason => 'Permission needed to choose a photo.';

  @override
  String artworkTitle(String childName) {
    return 'Drawing from $childName';
  }

  @override
  String get artworkStoryHeading => 'Story';

  @override
  String get artworkStoryEmpty => 'No story for this drawing.';

  @override
  String get artworkStoryAdd => 'Add a story';

  @override
  String get artworkStoryEdit => 'Edit the story';

  @override
  String get artworkStoryClear => 'Clear the story';

  @override
  String get artworkStoryHint => 'What the child says about their drawing.';

  @override
  String get artworkStorySaved => 'Story saved.';

  @override
  String get artworkStoryCleared => 'Story cleared.';

  @override
  String get artworkStoryClearConfirmTitle => 'Clear the story?';

  @override
  String get artworkStoryClearConfirmBody =>
      'The text will be removed from this drawing.';

  @override
  String get artworkStoryError => 'The story wasn\'t saved. Your text is kept.';

  @override
  String get artworkDrawnAtAdd => 'Add the drawing date';

  @override
  String get artworkDrawnAtEdit => 'Edit the drawing date';

  @override
  String get artworkDrawnAtClear => 'Clear the drawing date';

  @override
  String get artworkDrawnAtPickerTitle => 'Drawing date';

  @override
  String get artworkDrawnAtSaved => 'Drawing date saved.';

  @override
  String get artworkDrawnAtCleared => 'Drawing date cleared.';

  @override
  String get artworkDrawnAtClearConfirmTitle => 'Clear the drawing date?';

  @override
  String get artworkDrawnAtClearConfirmBody =>
      'The age shown will fall back to the day it was added.';

  @override
  String get artworkDrawnAtError => 'The drawing date wasn\'t saved.';

  @override
  String get artworkDrawnAtFutureError => 'That date hasn\'t happened yet.';

  @override
  String get artworkDrawnAtBeforeBirthError =>
      'That date is before the child\'s birth.';

  @override
  String get artworkSendImage => 'Send this image';

  @override
  String get artworkSendImageHelp =>
      'The image is sent through your messaging app.';

  @override
  String get artworkShareGallery => 'Share';

  @override
  String get artworkShareGalleryHelp => 'A web link to see all their drawings.';

  @override
  String artworkShareText(String childName, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'A drawing from $childName, added on $dateString.';
  }

  @override
  String get artworkZoom => 'Zoom in';

  @override
  String get artworkZoomIn => 'Zoom in further';

  @override
  String get artworkZoomOut => 'Zoom out';

  @override
  String get artworkZoomImageMissing => 'Image not found';

  @override
  String get artworkZoomDecodeFailed => 'This image could not be displayed.';

  @override
  String get artworkImageMissingTitle =>
      'This drawing\'s image can\'t be found';

  @override
  String get artworkImageMissingBody => 'The drawing\'s information is kept.';

  @override
  String get artworkDelete => 'Delete this drawing';

  @override
  String get artworkDeleteTitle => 'Delete this drawing?';

  @override
  String get artworkDeleteBody =>
      'The photo will be removed from this device. This action is permanent.';

  @override
  String get artworkDeleteCloudNotice =>
      'Any copy already backed up is not removed by this action.';

  @override
  String get artworkDeleteError => 'The drawing couldn\'t be deleted.';

  @override
  String get artworkDeleted => 'Drawing deleted.';

  @override
  String get artworkUnknownArtist => 'Unknown artist';

  @override
  String a11yArtworkImage(String childName, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Drawing from $childName, added on $dateString';
  }

  @override
  String get childrenTitle => 'Children';

  @override
  String get childrenHelp =>
      'Every drawing is assigned to a child, which makes it possible to show their age.';

  @override
  String get childrenAdd => 'Add a child';

  @override
  String childrenRowSubtitle(DateTime date, num count) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drawings',
      one: '1 drawing',
      zero: 'no drawings',
    );
    return 'Born on $dateString · $_temp0';
  }

  @override
  String get childrenEmptyTitle => 'No children yet';

  @override
  String get childrenEmptyBody =>
      'Add a child to assign their drawings and show their age.';

  @override
  String get childrenErrorTitle => 'The list of children couldn\'t be opened';

  @override
  String get childrenActionsViewArtworks => 'View their drawings';

  @override
  String get childrenActionsEdit => 'Edit profile';

  @override
  String get childrenActionsShare => 'Share';

  @override
  String get childrenActionsDelete => 'Delete profile';

  @override
  String childrenDeleteTitle(String childName) {
    return 'Delete $childName?';
  }

  @override
  String childrenDeleteBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drawings will also be deleted from this device.',
      one: '1 drawing will also be deleted from this device.',
      zero: 'No drawings will be deleted.',
    );
    return '$_temp0 This action is permanent.';
  }

  @override
  String childrenDeleteError(String childName) {
    return '$childName wasn\'t deleted.';
  }

  @override
  String childrenDeleted(String childName) {
    return '$childName and their drawings were deleted.';
  }

  @override
  String get childEditorTitleCreate => 'New child';

  @override
  String get childEditorTitleEdit => 'Edit profile';

  @override
  String get childEditorFromDraft => 'Your drawing is kept in the meantime.';

  @override
  String get childEditorNameLabel => 'First name or nickname';

  @override
  String get childEditorNameHint => 'For example: Léa, Nono';

  @override
  String get childEditorBirthDateLabel => 'Date of birth';

  @override
  String get childEditorBirthDateChoose => 'Choose a date';

  @override
  String get childEditorBirthDateHelp =>
      'Used to show the child\'s age on each drawing.';

  @override
  String get childEditorErrorNameEmpty => 'Enter a first name or nickname.';

  @override
  String get childEditorErrorNameTooLong => '40 characters maximum.';

  @override
  String get childEditorWarnNameDuplicate =>
      'Another child already has this name.';

  @override
  String get childEditorErrorBirthDateMissing => 'Choose the date of birth.';

  @override
  String get childEditorErrorBirthDateFuture => 'This date is in the future.';

  @override
  String get childEditorErrorBirthDateTooOld =>
      'This date seems too far in the past.';

  @override
  String get childEditorErrorWrite =>
      'The profile wasn\'t saved. Your information is kept.';

  @override
  String childEditorCreated(String childName) {
    return '$childName was added.';
  }

  @override
  String get childEditorUpdated => 'Profile updated.';

  @override
  String get childEditorSaveDisabledReason =>
      'Enter a first name and a date of birth.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLocalNotice =>
      'Your drawings are on this device. No account is needed.';

  @override
  String get settingsGroupBackup => 'Backup and sharing';

  @override
  String get settingsGroupApp => 'App';

  @override
  String get settingsGroupDocuments => 'Documents';

  @override
  String get settingsAccountRow => 'Backup and account';

  @override
  String get settingsAccountOff => 'Not turned on';

  @override
  String get settingsAccountExplain =>
      'An account lets you back up your drawings and share a web gallery.';

  @override
  String get settingsBackupNever => 'Never backed up';

  @override
  String settingsBackupLast(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Last backup: $dateString';
  }

  @override
  String get settingsBackupRun => 'Back up now';

  @override
  String settingsBackupRunning(int n, int total) {
    return 'Backup in progress… $n of $total';
  }

  @override
  String settingsBackupPartial(int n, int m) {
    return '$n drawings backed up, $m failed.';
  }

  @override
  String get settingsBackupFailed => 'The backup didn\'t complete.';

  @override
  String get settingsBackupUnavailable =>
      'The backup service is currently unavailable.';

  @override
  String get settingsBackupBlocked =>
      'Backup needs your attention before it can continue.';

  @override
  String get settingsRestoreNotice =>
      'Restoring on a new device isn\'t available yet.';

  @override
  String get settingsLanguageRow => 'Language';

  @override
  String get settingsLanguageSystem => 'Match device language';

  @override
  String get settingsLanguageFr => 'French (Canada)';

  @override
  String get settingsLanguageEn => 'English (Canada)';

  @override
  String get settingsAboutRow => 'About';

  @override
  String get settingsPrivacyRow => 'Privacy policy';

  @override
  String get settingsTermsRow => 'Terms of use';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsGroupFamily => 'Family';

  @override
  String get familyRow => 'Invite a member';

  @override
  String get familyTitle => 'Family';

  @override
  String get familyNameLabel => 'Family name';

  @override
  String get familyNameHint => 'E.g.: The Smith Family';

  @override
  String get familyNameSaved => 'Name saved.';

  @override
  String get familyInviteExplain =>
      'Share this code or QR with the person joining your family. It stays valid and can be reused as many times as needed.';

  @override
  String get familyInviteCodeLabel => 'Invitation code';

  @override
  String get familyInviteCopy => 'Copy code';

  @override
  String get familyInviteCopied => 'Code copied.';

  @override
  String get familyJoinExplain =>
      'Have a code? Enter it or scan the QR to join a family.';

  @override
  String get familyJoinCodeHint => 'Ex.: 7K4RTQ2M';

  @override
  String get familyJoinButton => 'Join';

  @override
  String get familyJoinChecking => 'Checking…';

  @override
  String get familyJoinConverging => 'Joining your family…';

  @override
  String get familyJoinSuccess => 'You\'ve joined the family.';

  @override
  String get familyJoinInvalidCode =>
      'This code doesn\'t exist. Check it and try again.';

  @override
  String get familyScanButton => 'Scan a code';

  @override
  String get familyScanTitle => 'Scan a code';

  @override
  String get familyScanExplain =>
      'Frame the QR code shown by the other person.';

  @override
  String get familyScanPermissionDenied =>
      'Camera access is needed to scan a code.';

  @override
  String get settingsOffline =>
      'No connection. Backup and sharing features are unavailable.';

  @override
  String get accountTitle => 'Backup and account';

  @override
  String get accountIntroTitle => 'What an account gives you';

  @override
  String get accountIntroBody =>
      'A backup of your drawings and a web link to share with your family. Your drawings stay on this device either way.';

  @override
  String get accountEmailLabel => 'Your email address';

  @override
  String get accountEmailHint => 'parent@example.ca';

  @override
  String get accountEmailInvalid => 'This address doesn\'t look valid.';

  @override
  String get accountPasswordLabel => 'Password';

  @override
  String get accountPasswordInvalid =>
      'Password must be at least 6 characters.';

  @override
  String get accountCodePaste => 'Paste';

  @override
  String get accountSubmit => 'Continue';

  @override
  String get accountSubmitting => 'Signing in…';

  @override
  String get accountErrorInvalidCredentials => 'Wrong email or password.';

  @override
  String get accountErrorWeakPassword =>
      'Password must be at least 6 characters.';

  @override
  String accountErrorRateLimited(int seconds) {
    return 'Too many requests. Try again in $seconds seconds.';
  }

  @override
  String get accountSignedIn => 'Account linked.';

  @override
  String accountConnectedAs(String email) {
    return 'Account linked: $email';
  }

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountSignOutTitle => 'Sign out?';

  @override
  String get accountSignOutBody => 'Your drawings stay on this device.';

  @override
  String get accountDelete => 'Delete my account';

  @override
  String get accountDeleteTitle => 'Delete your account?';

  @override
  String get accountDeleteBody =>
      'This deletes your sign-in identity. Your household\'s children and artwork are never affected — other household members keep full access.';

  @override
  String get accountDeleteConfirmCheck =>
      'I understand this action is permanent.';

  @override
  String get accountDeleteLastMemberWarning =>
      'You are the last active member of your household. Deleting your account will also immediately and permanently erase every child, artwork, and all cloud content of this household.';

  @override
  String get accountDeleteLocalChoiceTitle =>
      'What should happen to the vault on this device?';

  @override
  String get accountDeleteKeepLocal => 'Keep the local vault';

  @override
  String get accountDeleteKeepLocalBody =>
      'Drawings already on this device stay usable offline.';

  @override
  String get accountDeleteEraseLocal => 'Also erase the local vault';

  @override
  String get accountDeleteEraseLocalBody =>
      'Every drawing on this device is deleted, including any not yet backed up.';

  @override
  String get accountDeleting => 'Deleting account…';

  @override
  String get accountDeleteNetworkErrorBody =>
      'The account couldn\'t be deleted (no connection). Try again later.';

  @override
  String get accountDeletePartialTitle => 'Deletion couldn\'t be completed';

  @override
  String get accountDeletePartialBody =>
      'Here\'s what was deleted and what remains. Write to us and we\'ll finish the process.';

  @override
  String get accountOfflineReason => 'A connection is needed.';

  @override
  String shareTitle(String childName) {
    return 'Share $childName\'s gallery';
  }

  @override
  String get shareWarning => 'Anyone with the link can open this gallery.';

  @override
  String get shareSignedOutTitle => 'Web sharing needs an account';

  @override
  String get shareSignedOutBody =>
      'The gallery needs to be hosted so your family can open it without installing the app.';

  @override
  String get shareSignedOutAction => 'Sign in to share';

  @override
  String get shareSignedOutAlternative => 'Send an image instead';

  @override
  String get shareGalleryHeading => 'Share';

  @override
  String shareGalleryBody(String childName) {
    return 'A web link that shows $childName\'s backed-up drawings. It updates as new drawings are added.';
  }

  @override
  String get shareGalleryPickerBody =>
      'Choose the child whose artwork you want to share.';

  @override
  String get shareGalleryCreate => 'Create the link';

  @override
  String get shareGalleryCreating => 'Creating the link…';

  @override
  String get shareImageHeading => 'Send this image';

  @override
  String get shareImageBody =>
      'The image is sent as-is through your messaging app. It doesn\'t update.';

  @override
  String get shareDifference => 'The gallery updates; the sent image doesn\'t.';

  @override
  String get shareLinkReadyTitle => 'Link created';

  @override
  String shareLinkReadyCreatedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Created on $dateString';
  }

  @override
  String get shareLinkOtherDeviceBody =>
      'This link was created on another device — it can\'t be shown or copied here. You can still revoke it.';

  @override
  String get shareRevoke => 'Revoke this link';

  @override
  String get shareRevokeTitle => 'Revoke this link?';

  @override
  String get shareRevokeBody =>
      'People who received it will no longer be able to open the gallery.';

  @override
  String get shareRevoking => 'Revoking…';

  @override
  String get shareRevoked => 'Link revoked.';

  @override
  String get shareRevokeError => 'The link couldn\'t be revoked.';

  @override
  String get shareErrorNetwork => 'The link wasn\'t created: no connection.';

  @override
  String get shareErrorService => 'The link wasn\'t created.';

  @override
  String get trashTitle => 'Trash';

  @override
  String get trashEmptyTitle => 'Trash is empty';

  @override
  String get trashEmptyBody => 'Deleted artwork appears here for 30 days.';

  @override
  String get trashErrorTitle => 'Couldn\'t open the trash';

  @override
  String trashItemDeletedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Deleted on $dateString';
  }

  @override
  String trashItemPurgeOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Permanently deleted on $dateString';
  }

  @override
  String get trashRestore => 'Restore';

  @override
  String get trashRestoring => 'Restoring…';

  @override
  String get trashRestoreError => 'This artwork couldn\'t be restored.';

  @override
  String get trashPurge => 'Delete permanently';

  @override
  String get trashPurging => 'Deleting…';

  @override
  String get trashPurgeError =>
      'This artwork couldn\'t be permanently deleted.';

  @override
  String get trashPurgeConfirmTitle => 'Permanently delete this artwork?';

  @override
  String get trashPurgeConfirmBody =>
      'This can\'t be undone. The artwork and its image will be erased permanently.';

  @override
  String get trashPurgeAll => 'Empty trash';

  @override
  String get trashPurgeAllConfirmTitle => 'Empty the whole trash?';

  @override
  String get trashPurgeAllConfirmBody =>
      'Every artwork in the trash will be permanently erased. This can\'t be undone.';

  @override
  String get trashPurgeAllError => 'The trash couldn\'t be emptied.';

  @override
  String shareNotSyncedTitle(String childName) {
    return '$childName\'s drawings aren\'t backed up yet';
  }

  @override
  String get shareNotSyncedBody =>
      'The web gallery would be empty. Back up first, then create the link.';

  @override
  String get shareNotSyncedAction => 'Back up now';

  @override
  String get shareBackupRunning => 'Backing up…';

  @override
  String get shareChildMissing => 'This profile no longer exists.';

  @override
  String shareMessage(String childName, String url) {
    return 'Here\'s $childName\'s drawing gallery: $url';
  }

  @override
  String get shareExistingHeading => 'Active links';

  @override
  String get errorNetworkTitle => 'No connection';

  @override
  String get errorNetworkBody => 'Check your connection, then try again.';

  @override
  String get errorServiceTitle => 'The service isn\'t responding';

  @override
  String get errorServiceBody => 'Try again in a moment.';

  @override
  String get errorLocalWriteTitle => 'Saving failed';

  @override
  String get errorLocalWriteBody => 'Nothing was lost. You can try again.';

  @override
  String get errorNotFoundTitle => 'Not found';

  @override
  String get errorNotFoundBody => 'This item no longer exists.';

  @override
  String get errorNotSignedInTitle => 'Account required';

  @override
  String get errorNotSignedInBody => 'Sign in to use this feature.';

  @override
  String get errorUnavailableTitle => 'Feature unavailable';

  @override
  String get errorUnavailableBody => 'This action isn\'t available yet.';

  @override
  String get errorFoyerMismatchTitle => 'This device is linked elsewhere';

  @override
  String get errorFoyerMismatchBody =>
      'This vault is already linked to a different household. Sign out to keep working locally, or contact us to start a new vault for this account.';

  @override
  String get errorQuotaExceededTitle => 'Household storage is full';

  @override
  String get errorQuotaExceededBody =>
      'This artwork stays saved on this device. It will be sent automatically once space frees up.';

  @override
  String get errorUnknownTitle => 'Something went wrong';

  @override
  String get errorUnknownBody =>
      'Try again. If the problem continues, write to us.';

  @override
  String get familyHubTitle => 'Family Space';

  @override
  String get familyHubSectionArtists => 'Artists';

  @override
  String get familyHubAddArtist => 'Add an artist';

  @override
  String get familyHubSectionFamilyBackup => 'Family & backup';

  @override
  String get familyHubAccountLocalOnly => 'Backup on this device';

  @override
  String get familyHubAccountLocalSubtitle =>
      'Activate a private backup whenever you want.';

  @override
  String get familyHubFamilySubtitle => 'Invite, join or manage the household.';

  @override
  String get familyHubFamilyAndSettings => 'Family & settings';

  @override
  String get captureAnecdoteTitle => 'Add a note';

  @override
  String get captureAnecdoteSubtitle => 'Optional — you can also do it later.';

  @override
  String get captureIosCropTitle => 'Crop the drawing';

  @override
  String get artworkAudioSaveError => 'Unable to save voice note';

  @override
  String get syncUploadSuspendedTitle => 'Backups suspended';

  @override
  String get syncUploadSuspendedBody =>
      'New cloud backups are temporarily suspended to keep the app free.\n\nYour existing galleries, restores, and deletions remain fully available.';
}
