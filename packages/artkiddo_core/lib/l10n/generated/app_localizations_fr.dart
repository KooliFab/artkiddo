// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get commonAppName => 'artkiddo';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonSaving => 'Enregistrement…';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonNext => 'Suivant';

  @override
  String get commonSkip => 'Passer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonDeleting => 'Suppression…';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonCopy => 'Copier';

  @override
  String get commonCopied => 'Lien copié.';

  @override
  String get commonSend => 'Envoyer';

  @override
  String get commonOpenSettings => 'Ouvrir les réglages';

  @override
  String get commonUnderstood => 'J\'ai compris';

  @override
  String get commonContinueEditing => 'Continuer';

  @override
  String get commonDiscard => 'Abandonner';

  @override
  String get commonExampleLabel => 'Exemple';

  @override
  String get commonLoading => 'Chargement…';

  @override
  String get commonOptional => 'facultatif';

  @override
  String get commonRequired => 'requis';

  @override
  String get commonContactUs => 'Nous écrire';

  @override
  String get commonOpensBrowser => 'Ouvre le navigateur';

  @override
  String get commonDiscardTitle => 'Abandonner les modifications ?';

  @override
  String get commonDiscardBody =>
      'Ce que vous avez saisi ne sera pas conservé.';

  @override
  String get commonDateFormat => 'yMMMMd';

  @override
  String get commonDateFormatShort => 'yMMMd';

  @override
  String get onboardingPage1Title => 'Le dessin est rangé, le souvenir reste.';

  @override
  String get onboardingPage1Body =>
      'Prenez le dessin en photo avant qu\'il ne s\'abîme, et gardez-le sans encombrer la maison.';

  @override
  String get onboardingPage2Title => 'Tout reste sur votre appareil.';

  @override
  String get onboardingPage2Body =>
      'Les photos sont enregistrées sur cet appareil. Aucun compte n\'est nécessaire pour commencer.';

  @override
  String get onboardingPage3Title => 'Prêt à commencer.';

  @override
  String get onboardingPage3Body =>
      'Ajoutez un premier dessin quand vous voulez. Vous pourrez présenter l\'artiste juste après.';

  @override
  String get onboardingStart => 'Commencer mon album';

  @override
  String a11yOnboardingPageIndicator(int n) {
    return 'Page $n sur 3';
  }

  @override
  String get navGallery => 'Galerie';

  @override
  String get navChildren => 'Enfants';

  @override
  String get navSettings => 'Réglages';

  @override
  String a11yNavSelected(String label) {
    return '$label, sélectionné';
  }

  @override
  String get galleryTitle => 'Galerie';

  @override
  String galleryCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dessins',
      one: '1 dessin',
      zero: 'Aucun dessin',
    );
    return '$_temp0';
  }

  @override
  String galleryCountForChild(num count, String childName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dessins de $childName',
      one: '1 dessin de $childName',
      zero: 'Aucun dessin de $childName',
    );
    return '$_temp0';
  }

  @override
  String get galleryFilterAll => 'Tous';

  @override
  String get galleryFilterLabel => 'Filtrer par enfant';

  @override
  String get galleryAddArtwork => 'Ajouter un dessin';

  @override
  String galleryAddArtworkFor(String childName) {
    return 'Ajouter un dessin de $childName';
  }

  @override
  String get galleryEmptyNoChildTitle => 'Commencez par présenter l\'artiste';

  @override
  String get galleryEmptyNoChildBody =>
      'Ajoutez un enfant : chaque dessin lui sera attribué et son âge s\'affichera automatiquement.';

  @override
  String get galleryEmptyNoChildAction => 'Ajouter un enfant';

  @override
  String get galleryEmptyNoArtworkTitle => 'Votre galerie est prête';

  @override
  String get galleryEmptyNoArtworkBody =>
      'Ajoutez le premier dessin. Il restera sur cet appareil.';

  @override
  String galleryEmptyFilteredTitle(String childName) {
    return 'Aucun dessin de $childName pour l\'instant';
  }

  @override
  String get galleryEmptyFilteredBody =>
      'Ajoutez-en un, ou revenez à l\'ensemble de la galerie.';

  @override
  String get galleryEmptyFilteredShowAll => 'Voir tous les dessins';

  @override
  String get galleryErrorTitle => 'Impossible d\'ouvrir votre galerie';

  @override
  String get galleryErrorBody => 'Vos dessins sont toujours sur l\'appareil.';

  @override
  String get galleryVaultErrorBody =>
      'Vos dessins n’ont pas été supprimés. Ne désinstallez pas l’application : cela effacerait définitivement les originaux. Redémarrez, puis exportez-les si le problème persiste.';

  @override
  String get captureArtistsUnavailableTitle =>
      'Impossible de lire vos artistes';

  @override
  String get captureArtistsUnavailableBody =>
      'Votre photo est toujours là. Ne désinstallez pas l’application : cela effacerait définitivement l’original. Réessayez, puis exportez la photo si le problème persiste.';

  @override
  String get captureArtistsUnavailableSaveHint =>
      'Impossible de vérifier l’artiste pour le moment.';

  @override
  String get vaultRescueExportAction => 'Exporter mes photos';

  @override
  String get vaultRescueExportBody =>
      'Crée un fichier à partager avec vos originaux et la photo en cours, même si le coffre est illisible.';

  @override
  String get vaultRescueExportIncludesDraft =>
      'La photo en cours sera incluse dans l’export.';

  @override
  String vaultRescueInsufficientSpace(String required) {
    return 'Impossible de créer l’export : environ $required d’espace libre sont nécessaires.';
  }

  @override
  String galleryFilterReset(String childName) {
    return '$childName a été supprimé. La galerie affiche de nouveau tous les dessins.';
  }

  @override
  String get galleryImageMissing => 'Image introuvable';

  @override
  String get galleryArtworkAdded => 'Dessin ajouté à la galerie.';

  @override
  String a11yGalleryCard(String childName, DateTime date, String age) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Dessin de $childName, ajouté le $dateString, $age lors de l\'ajout.';
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

    return 'Dessin de $childName, ajouté le $dateString, $age lors de l\'ajout. Anecdote : $story';
  }

  @override
  String a11yGalleryFilterChanged(String label, int count) {
    return 'Filtre : $label. $count dessins.';
  }

  @override
  String artworkAddedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Ajouté le $dateString';
  }

  @override
  String artworkAddedBy(String author) {
    return 'Ajouté par $author';
  }

  @override
  String artworkAgeAtAddition(String age) {
    return 'Âge lors de l\'ajout : $age';
  }

  @override
  String artworkDrawnOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Dessiné le $dateString';
  }

  @override
  String artworkAgeAtDrawing(String age) {
    return 'Âge lors du dessin : $age';
  }

  @override
  String get ageLessThanMonth => 'Moins de 1 mois';

  @override
  String ageMonths(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mois',
      one: '1 mois',
    );
    return '$_temp0';
  }

  @override
  String ageYears(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ans',
      one: '1 an',
    );
    return '$_temp0';
  }

  @override
  String ageYearsMonths(num years, num months) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years ans',
      one: '1 an',
    );
    String _temp1 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months mois',
      one: '1 mois',
    );
    return '$_temp0 et $_temp1';
  }

  @override
  String get ageBeforeBirth => 'Avant la naissance';

  @override
  String get captureTitle => 'Ajouter un dessin';

  @override
  String get captureSourceCameraTitle => 'Prendre une photo';

  @override
  String get captureSourceCameraBody => 'Le dessin est devant vous.';

  @override
  String get captureSourceGalleryTitle => 'Choisir dans mes photos';

  @override
  String get captureSourceGalleryBody => 'Le dessin est déjà photographié.';

  @override
  String get captureReviewTitle => 'Le dessin est-il bien visible ?';

  @override
  String get captureReviewUse => 'Utiliser cette photo';

  @override
  String get captureReviewRetake => 'Reprendre';

  @override
  String get captureReviewUnreadable => 'Cette image n\'a pas pu être ouverte.';

  @override
  String get captureReviewTooLarge =>
      'Cette image est très volumineuse et pourrait ralentir l\'application.';

  @override
  String get captureDetailsTitle => 'À qui est ce dessin ?';

  @override
  String get captureDetailsViewLarge => 'Voir en grand';

  @override
  String get captureArtistLabel => 'Artiste';

  @override
  String get captureArtistChoose => 'Choisir l\'artiste';

  @override
  String get captureArtistRequired =>
      'Choisissez l\'artiste avant d\'enregistrer.';

  @override
  String get captureArtistAddChild => 'Ajouter un enfant';

  @override
  String get captureNoChildTitle => 'Ce dessin a besoin d\'un artiste';

  @override
  String get captureNoChildBody =>
      'Ajoutez un enfant : votre dessin est conservé pendant ce temps.';

  @override
  String get captureStoryLabel => 'Anecdote (facultatif)';

  @override
  String get captureStoryHint => 'Ce que l\'enfant raconte sur son dessin.';

  @override
  String get captureAudioCardTitle => 'Raconter le dessin';

  @override
  String get captureAudioCardSubtitle =>
      'Enregistrez la voix de l\'enfant racontant son dessin (max 2 min).';

  @override
  String get captureAudioRecord => 'Enregistrer la voix';

  @override
  String get captureAudioRecording => 'Enregistrement en cours…';

  @override
  String get captureAudioStop => 'Terminer';

  @override
  String get captureAudioCancel => 'Annuler';

  @override
  String get captureAudioPlay => 'Écouter';

  @override
  String get captureAudioPause => 'Pause';

  @override
  String get captureAudioReRecord => 'Recommencer';

  @override
  String get captureAudioReRecordConfirmTitle =>
      'Remplacer l\'enregistrement ?';

  @override
  String get captureAudioReRecordConfirmBody =>
      'L\'enregistrement actuel sera remplacé par un nouveau.';

  @override
  String get captureAudioDelete => 'Supprimer la voix';

  @override
  String get captureAudioDeleteConfirmTitle => 'Supprimer l\'enregistrement ?';

  @override
  String get captureAudioDeleteConfirmBody =>
      'Cette action supprimera l\'enregistrement audio.';

  @override
  String get captureAudioMicPermissionDeniedTitle =>
      'Accès au microphone requis';

  @override
  String get captureAudioMicPermissionDeniedBody =>
      'Pour enregistrer la voix de votre enfant, autorisez l\'accès au microphone dans les réglages.';

  @override
  String get artworkAudioCardTitle => 'La voix de l\'enfant';

  @override
  String get artworkAudioDownloading => 'Chargement de la voix…';

  @override
  String get artworkAudioDownloadError => 'Impossible de charger la voix';

  @override
  String get artworkAudioRetry => 'Réessayer';

  @override
  String get sharingIncludeAudio => 'Inclure les voix d\'enfants';

  @override
  String get sharingIncludeAudioSubtitle =>
      'Les proches avec le lien pourront écouter les enregistrements vocaux.';

  @override
  String captureAddedToday(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Ajouté le $dateString';
  }

  @override
  String get captureSave => 'Enregistrer le dessin';

  @override
  String captureChildCreated(String childName) {
    return '$childName a été ajouté.';
  }

  @override
  String get captureErrorWriteTitle => 'Le dessin n\'a pas été enregistré';

  @override
  String get captureErrorWriteBody =>
      'Rien n\'a été perdu. Vous pouvez réessayer.';

  @override
  String get captureErrorStorageFullTitle =>
      'Il n\'y a plus assez d\'espace sur l\'appareil';

  @override
  String get captureErrorStorageFullBody =>
      'Libérez de l\'espace, puis réessayez.';

  @override
  String get captureDiscardTitle => 'Abandonner ce dessin ?';

  @override
  String get captureDiscardBody =>
      'La photo et l\'anecdote ne seront pas enregistrées.';

  @override
  String get captureDiscardPhotoTitle => 'Abandonner cette photo ?';

  @override
  String get captureDiscardPhotoBody => 'Vous pourrez en reprendre une autre.';

  @override
  String get permissionCameraDeniedTitle =>
      'L\'accès à l\'appareil photo est refusé';

  @override
  String get permissionCameraDeniedBody =>
      'Vous pouvez tout de même choisir une photo existante.';

  @override
  String get permissionPhotosDeniedTitle => 'L\'accès aux photos est refusé';

  @override
  String get permissionPhotosDeniedBody =>
      'Vous pouvez tout de même prendre une nouvelle photo.';

  @override
  String get permissionBothDeniedTitle =>
      'artkiddo n\'a pas accès à vos photos';

  @override
  String get permissionBothDeniedBody =>
      'Autorisez l\'appareil photo ou les photos dans les réglages pour ajouter un dessin.';

  @override
  String get permissionCameraReason =>
      'Autorisation nécessaire pour prendre une photo.';

  @override
  String get permissionPhotosReason =>
      'Autorisation nécessaire pour choisir une photo.';

  @override
  String artworkTitle(String childName) {
    return 'Dessin de $childName';
  }

  @override
  String get artworkStoryHeading => 'Anecdote';

  @override
  String get artworkStoryEmpty => 'Aucune anecdote pour ce dessin.';

  @override
  String get artworkStoryAdd => 'Ajouter une anecdote';

  @override
  String get artworkStoryEdit => 'Modifier l\'anecdote';

  @override
  String get artworkStoryClear => 'Effacer l\'anecdote';

  @override
  String get artworkStoryHint => 'Ce que l\'enfant raconte sur son dessin.';

  @override
  String get artworkStorySaved => 'Anecdote enregistrée.';

  @override
  String get artworkStoryCleared => 'Anecdote effacée.';

  @override
  String get artworkStoryClearConfirmTitle => 'Effacer l\'anecdote ?';

  @override
  String get artworkStoryClearConfirmBody =>
      'Le texte sera retiré de ce dessin.';

  @override
  String get artworkStoryError =>
      'L\'anecdote n\'a pas été enregistrée. Votre texte est conservé.';

  @override
  String get artworkDrawnAtAdd => 'Ajouter la date du dessin';

  @override
  String get artworkDrawnAtEdit => 'Modifier la date du dessin';

  @override
  String get artworkDrawnAtClear => 'Effacer la date du dessin';

  @override
  String get artworkDrawnAtPickerTitle => 'Date du dessin';

  @override
  String get artworkDrawnAtSaved => 'Date du dessin enregistrée.';

  @override
  String get artworkDrawnAtCleared => 'Date du dessin effacée.';

  @override
  String get artworkDrawnAtClearConfirmTitle => 'Effacer la date du dessin ?';

  @override
  String get artworkDrawnAtClearConfirmBody =>
      'L\'âge affiché redeviendra celui du jour de l\'ajout.';

  @override
  String get artworkDrawnAtError =>
      'La date du dessin n\'a pas été enregistrée.';

  @override
  String get artworkDrawnAtFutureError =>
      'Cette date n\'est pas encore arrivée.';

  @override
  String get artworkDrawnAtBeforeBirthError =>
      'Cette date précède la naissance de l\'enfant.';

  @override
  String get artworkSendImage => 'Envoyer cette image';

  @override
  String get artworkSendImageHelp =>
      'L\'image part par votre application de messagerie.';

  @override
  String get artworkShareGallery => 'Partager';

  @override
  String get artworkShareGalleryHelp =>
      'Un lien web pour voir tous ses dessins.';

  @override
  String artworkShareText(String childName, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Un dessin de $childName, ajouté le $dateString.';
  }

  @override
  String get artworkZoom => 'Agrandir';

  @override
  String get artworkZoomIn => 'Agrandir davantage';

  @override
  String get artworkZoomOut => 'Réduire';

  @override
  String get artworkZoomImageMissing => 'Image introuvable';

  @override
  String get artworkZoomDecodeFailed =>
      'Cette image n\'a pas pu être affichée.';

  @override
  String get artworkImageMissingTitle =>
      'L\'image de ce dessin est introuvable';

  @override
  String get artworkImageMissingBody =>
      'Les informations du dessin sont conservées.';

  @override
  String get artworkDelete => 'Supprimer ce dessin';

  @override
  String get artworkDeleteTitle => 'Supprimer ce dessin ?';

  @override
  String get artworkDeleteBody =>
      'La photo sera retirée de cet appareil. Cette action est définitive.';

  @override
  String get artworkDeleteCloudNotice =>
      'La copie déjà sauvegardée n\'est pas retirée par cette action.';

  @override
  String get artworkDeleteError => 'Le dessin n\'a pas pu être supprimé.';

  @override
  String get artworkDeleted => 'Dessin supprimé.';

  @override
  String get artworkUnknownArtist => 'Artiste inconnu';

  @override
  String a11yArtworkImage(String childName, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Dessin de $childName, ajouté le $dateString';
  }

  @override
  String get childrenTitle => 'Enfants';

  @override
  String get childrenHelp =>
      'Chaque dessin est attribué à un enfant, ce qui permet d\'afficher son âge.';

  @override
  String get childrenAdd => 'Ajouter un enfant';

  @override
  String childrenRowSubtitle(DateTime date, num count) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dessins',
      one: '1 dessin',
      zero: 'aucun dessin',
    );
    return 'Né(e) le $dateString · $_temp0';
  }

  @override
  String get childrenEmptyTitle => 'Aucun enfant pour l\'instant';

  @override
  String get childrenEmptyBody =>
      'Ajoutez un enfant pour attribuer ses dessins et afficher son âge.';

  @override
  String get childrenErrorTitle => 'Impossible d\'ouvrir la liste des enfants';

  @override
  String get childrenActionsViewArtworks => 'Voir ses dessins';

  @override
  String get childrenActionsEdit => 'Modifier le profil';

  @override
  String get childrenActionsShare => 'Partager';

  @override
  String get childrenActionsDelete => 'Supprimer le profil';

  @override
  String childrenDeleteTitle(String childName) {
    return 'Supprimer $childName ?';
  }

  @override
  String childrenDeleteBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dessins seront également supprimés de cet appareil.',
      one: '1 dessin sera également supprimé de cet appareil.',
      zero: 'Aucun dessin ne sera supprimé.',
    );
    return '$_temp0 Cette action est définitive.';
  }

  @override
  String childrenDeleteError(String childName) {
    return '$childName n\'a pas été supprimé.';
  }

  @override
  String childrenDeleted(String childName) {
    return '$childName et ses dessins ont été supprimés.';
  }

  @override
  String get childEditorTitleCreate => 'Nouvel enfant';

  @override
  String get childEditorTitleEdit => 'Modifier le profil';

  @override
  String get childEditorFromDraft =>
      'Votre dessin est conservé pendant ce temps.';

  @override
  String get childEditorNameLabel => 'Prénom ou surnom';

  @override
  String get childEditorNameHint => 'Par exemple : Léa, Nono';

  @override
  String get childEditorBirthDateLabel => 'Date de naissance';

  @override
  String get childEditorBirthDateChoose => 'Choisir une date';

  @override
  String get childEditorBirthDateHelp =>
      'Sert à indiquer l\'âge de l\'enfant sur chaque dessin.';

  @override
  String get childEditorErrorNameEmpty => 'Indiquez un prénom ou un surnom.';

  @override
  String get childEditorErrorNameTooLong => '40 caractères au maximum.';

  @override
  String get childEditorWarnNameDuplicate =>
      'Un autre enfant porte déjà ce prénom.';

  @override
  String get childEditorErrorBirthDateMissing =>
      'Choisissez la date de naissance.';

  @override
  String get childEditorErrorBirthDateFuture => 'Cette date est dans le futur.';

  @override
  String get childEditorErrorBirthDateTooOld =>
      'Cette date semble trop ancienne.';

  @override
  String get childEditorErrorWrite =>
      'Le profil n\'a pas été enregistré. Vos informations sont conservées.';

  @override
  String childEditorCreated(String childName) {
    return '$childName a été ajouté.';
  }

  @override
  String get childEditorUpdated => 'Profil mis à jour.';

  @override
  String get childEditorSaveDisabledReason =>
      'Indiquez un prénom et une date de naissance.';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsLocalNotice =>
      'Vos dessins sont sur cet appareil. Aucun compte n\'est nécessaire.';

  @override
  String get settingsGroupBackup => 'Sauvegarde et partage';

  @override
  String get settingsGroupApp => 'Application';

  @override
  String get settingsNotificationsRow => 'Notifications';

  @override
  String get settingsNotificationsEnabled => 'Activées';

  @override
  String get settingsNotificationsNotRequested => 'Non demandées';

  @override
  String get settingsNotificationsDenied => 'Refusées';

  @override
  String get settingsNotificationsUnavailable => 'Indisponibles';

  @override
  String get settingsNotificationsEnabledMessage => 'Notifications activées.';

  @override
  String get settingsNotificationsDeniedMessage =>
      'Autorisez les notifications dans les réglages de l\'appareil pour suivre l\'état des sauvegardes.';

  @override
  String get settingsNotificationsRequestError =>
      'Impossible de mettre à jour l\'autorisation des notifications.';

  @override
  String get settingsGroupDocuments => 'Documents';

  @override
  String get settingsAccountRow => 'Sauvegarde et compte';

  @override
  String get settingsAccountOff => 'Non activée';

  @override
  String get settingsAccountExplain =>
      'Un compte permet de sauvegarder vos dessins et de partager une galerie web.';

  @override
  String get settingsBackupNever => 'Jamais sauvegardé';

  @override
  String settingsBackupLast(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Dernière sauvegarde : $dateString';
  }

  @override
  String get settingsBackupRun => 'Sauvegarder maintenant';

  @override
  String settingsBackupRunning(int n, int total) {
    return 'Sauvegarde en cours… $n sur $total';
  }

  @override
  String settingsBackupPartial(int n, int m) {
    return '$n dessins sauvegardés, $m en échec.';
  }

  @override
  String get settingsBackupFailed => 'La sauvegarde n\'a pas abouti.';

  @override
  String get settingsBackupUnavailable =>
      'Le service de sauvegarde est indisponible pour le moment.';

  @override
  String get settingsBackupBlocked =>
      'La sauvegarde a besoin de votre intervention pour continuer.';

  @override
  String get settingsRestoreNotice =>
      'La restauration sur un nouvel appareil n\'est pas encore disponible.';

  @override
  String get settingsLanguageRow => 'Langue';

  @override
  String get settingsLanguageSystem => 'Suivre la langue de l\'appareil';

  @override
  String get settingsLanguageFr => 'Français (Canada)';

  @override
  String get settingsLanguageEn => 'English (Canada)';

  @override
  String get settingsAboutRow => 'À propos';

  @override
  String get settingsPrivacyRow => 'Politique de confidentialité';

  @override
  String get settingsTermsRow => 'Conditions d\'utilisation';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsGroupFamily => 'Famille';

  @override
  String get familyRow => 'Inviter un membre';

  @override
  String get familyTitle => 'Famille';

  @override
  String get familyNameLabel => 'Nom de la famille';

  @override
  String get familyNameHint => 'Ex. : Famille Tremblay';

  @override
  String get familyNameSaved => 'Nom enregistré.';

  @override
  String get familyInviteExplain =>
      'Partagez ce code ou ce QR avec la personne qui rejoint votre famille. Il reste valable et peut être réutilisé autant de fois que nécessaire.';

  @override
  String get familyInviteCodeLabel => 'Code d\'invitation';

  @override
  String get familyInviteCopy => 'Copier le code';

  @override
  String get familyInviteCopied => 'Code copié.';

  @override
  String get familyJoinExplain =>
      'Vous avez un code ? Saisissez-le ou scannez le QR pour rejoindre une famille.';

  @override
  String get familyJoinCodeHint => 'Ex. : 7K4RTQ2M';

  @override
  String get familyJoinButton => 'Rejoindre';

  @override
  String get familyJoinChecking => 'Vérification…';

  @override
  String get familyJoinConverging => 'Adhésion à votre famille…';

  @override
  String get familyJoinSuccess => 'Vous avez rejoint la famille.';

  @override
  String get familyJoinInvalidCode =>
      'Ce code n\'existe pas. Vérifiez-le et réessayez.';

  @override
  String get familyJoinConfirmTitle => 'Rejoindre une autre famille ?';

  @override
  String get familyJoinConfirmIntro =>
      'Cet appareil ne peut être lié qu\'à une seule famille à la fois.';

  @override
  String familyJoinImpactChildren(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enfants',
      one: '1 enfant',
      zero: 'Aucun enfant',
    );
    return '$_temp0';
  }

  @override
  String familyJoinImpactArtworks(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count œuvres',
      one: '1 œuvre',
      zero: 'aucune œuvre',
    );
    return '$_temp0';
  }

  @override
  String get familyJoinInviteInsteadHint =>
      'Vous vouliez plutôt partager vos œuvres avec quelqu\'un ? Donnez-lui votre code d\'invitation, affiché plus haut — vous garderez tout.';

  @override
  String get familyJoinConfirmPurgeWarning =>
      'Vous êtes le seul membre actif de votre famille actuelle. Rejoindre une autre famille supprimera définitivement tous ses enfants, toutes ses œuvres et tout son contenu cloud.';

  @override
  String get familyJoinConfirmLeaveWarning =>
      'Vous quittez votre famille actuelle. Son contenu reste accessible aux autres membres, mais vous en perdrez l\'accès et il sera retiré de cet appareil.';

  @override
  String get familyJoinConfirmCheckFailedWarning =>
      'Impossible de vérifier l\'état de votre famille actuelle. Réessayez avant de continuer.';

  @override
  String get familyJoinConfirmCheck =>
      'J\'ai compris que cette action est définitive.';

  @override
  String get familyJoinConfirmAction => 'Rejoindre et tout supprimer';

  @override
  String get familyJoinConfirmActionLeave => 'Rejoindre et quitter';

  @override
  String get familyJoinDiscarding => 'Préparation de votre appareil…';

  @override
  String get familyJoinResetError =>
      'Le changement de famille a réussi, mais cet appareil n\'a pas pu être réinitialisé.';

  @override
  String get familyScanButton => 'Scanner un code';

  @override
  String get familyScanTitle => 'Scanner un code';

  @override
  String get familyScanExplain =>
      'Cadrez le QR code affiché par l\'autre personne.';

  @override
  String get familyScanPermissionDenied =>
      'L\'accès à l\'appareil photo est nécessaire pour scanner un code.';

  @override
  String get settingsOffline =>
      'Aucune connexion. Les fonctions de sauvegarde et de partage sont indisponibles.';

  @override
  String get accountTitle => 'Sauvegarde et compte';

  @override
  String get accountIntroTitle => 'Ce qu\'un compte apporte';

  @override
  String get accountIntroBody =>
      'Une sauvegarde de vos dessins et un lien web à partager avec vos proches. Vos dessins restent sur cet appareil dans tous les cas.';

  @override
  String get accountEmailLabel => 'Votre adresse courriel';

  @override
  String get accountEmailHint => 'parent@exemple.ca';

  @override
  String get accountEmailInvalid => 'Cette adresse ne semble pas valide.';

  @override
  String get accountPasswordLabel => 'Mot de passe';

  @override
  String get accountPasswordInvalid =>
      'Le mot de passe doit contenir au moins 6 caractères.';

  @override
  String get accountCodePaste => 'Coller';

  @override
  String get accountSubmit => 'Continuer';

  @override
  String get accountSubmitting => 'Connexion…';

  @override
  String get accountForgotPassword => 'Mot de passe oublié ?';

  @override
  String get accountRecoveryTitle => 'Réinitialiser votre mot de passe';

  @override
  String get accountRecoveryBody =>
      'Nous vous enverrons un lien si un compte utilise cette adresse courriel.';

  @override
  String get accountRecoverySend => 'Envoyer le lien';

  @override
  String get accountRecoverySending => 'Envoi…';

  @override
  String get accountRecoverySentTitle => 'Vérifiez votre courriel';

  @override
  String get accountRecoverySentBody =>
      'Si un compte utilise cette adresse, vous recevrez un lien. Vérifiez aussi les indésirables.';

  @override
  String get accountRecoveryNewPassword => 'Nouveau mot de passe';

  @override
  String get accountRecoveryConfirmPassword => 'Confirmer le mot de passe';

  @override
  String get accountRecoveryUpdate => 'Choisir ce mot de passe';

  @override
  String get accountRecoveryUpdating => 'Mise à jour…';

  @override
  String get accountRecoveryMismatch =>
      'Les mots de passe ne correspondent pas.';

  @override
  String get accountRecoveryUpdated => 'Votre mot de passe a été mis à jour.';

  @override
  String get accountRecoveryError =>
      'La demande n’a pas abouti. Réessayez plus tard.';

  @override
  String get accountErrorInvalidCredentials =>
      'Adresse ou mot de passe incorrect.';

  @override
  String get accountErrorWeakPassword =>
      'Le mot de passe doit contenir au moins 6 caractères.';

  @override
  String accountErrorRateLimited(int seconds) {
    return 'Trop de demandes. Réessayez dans $seconds secondes.';
  }

  @override
  String get accountSignedIn => 'Compte lié.';

  @override
  String accountConnectedAs(String email) {
    return 'Compte lié : $email';
  }

  @override
  String get accountMyProfile => 'Mon profil';

  @override
  String get accountFirstNameLabel => 'Prénom';

  @override
  String get accountFirstNameHint => 'Votre prénom';

  @override
  String get accountLastNameLabel => 'Nom de famille';

  @override
  String get accountLastNameHint => 'Votre nom de famille';

  @override
  String get accountProfileSaved => 'Profil mis à jour.';

  @override
  String get accountRoleParent => 'Parent';

  @override
  String get accountRoleContributor => 'Contributeur';

  @override
  String get familyMembersTitle => 'Membres de la famille';

  @override
  String familyMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
    );
    return '$_temp0';
  }

  @override
  String get accountSignOut => 'Se déconnecter';

  @override
  String get accountSignOutTitle => 'Se déconnecter ?';

  @override
  String get accountSignOutBody => 'Vos dessins restent sur cet appareil.';

  @override
  String get accountDelete => 'Supprimer mon compte';

  @override
  String get accountDeleteTitle => 'Supprimer votre compte ?';

  @override
  String get accountDeleteBody =>
      'Cela supprime votre identifiant de connexion. Les enfants et les œuvres de votre foyer ne sont jamais touchés — les autres membres du foyer gardent un accès complet.';

  @override
  String get accountDeleteConfirmCheck =>
      'J\'ai compris que cette action est définitive.';

  @override
  String get accountDeleteLastMemberWarning =>
      'Vous êtes le dernier membre actif de votre foyer. Supprimer votre compte effacera aussi, immédiatement et définitivement, tous les enfants, toutes les œuvres et tout le contenu cloud de ce foyer.';

  @override
  String get accountDeleteLocalChoiceTitle =>
      'Que faire du coffre sur cet appareil ?';

  @override
  String get accountDeleteKeepLocal => 'Conserver le coffre local';

  @override
  String get accountDeleteKeepLocalBody =>
      'Les dessins déjà sur cet appareil restent utilisables hors ligne.';

  @override
  String get accountDeleteEraseLocal => 'Effacer aussi le coffre local';

  @override
  String get accountDeleteEraseLocalBody =>
      'Tous les dessins de cet appareil sont supprimés, y compris ceux non sauvegardés.';

  @override
  String get accountDeleting => 'Suppression du compte…';

  @override
  String get accountDeleteNetworkErrorBody =>
      'Le compte n\'a pas pu être supprimé (aucune connexion). Réessayez plus tard.';

  @override
  String get accountDeletePartialTitle =>
      'La suppression n\'a pas pu être terminée';

  @override
  String get accountDeletePartialBody =>
      'Voici ce qui a été supprimé et ce qui reste. Écrivez-nous et nous terminerons l\'opération.';

  @override
  String get accountOfflineReason => 'Une connexion est nécessaire.';

  @override
  String shareTitle(String childName) {
    return 'Partager la galerie de $childName';
  }

  @override
  String get shareWarning =>
      'Toute personne disposant du lien peut ouvrir cette galerie.';

  @override
  String get shareSignedOutTitle => 'Le partage web a besoin d\'un compte';

  @override
  String get shareSignedOutBody =>
      'La galerie doit être hébergée pour que vos proches puissent l\'ouvrir sans installer l\'application.';

  @override
  String get shareSignedOutAction => 'Se connecter pour partager';

  @override
  String get shareSignedOutAlternative => 'Plutôt envoyer une image';

  @override
  String get shareGalleryHeading => 'Partager';

  @override
  String shareGalleryBody(String childName) {
    return 'Un lien web qui montre les dessins sauvegardés de $childName. Il se met à jour avec les nouveaux dessins.';
  }

  @override
  String get shareGalleryPickerBody =>
      'Choisissez l\'enfant dont vous souhaitez partager les œuvres.';

  @override
  String get shareGalleryCreate => 'Créer le lien';

  @override
  String get shareGalleryCreating => 'Création du lien…';

  @override
  String get shareImageHeading => 'Envoyer cette image';

  @override
  String get shareImageBody =>
      'L\'image part telle quelle par votre application de messagerie. Elle ne se met pas à jour.';

  @override
  String get shareDifference =>
      'La galerie se met à jour ; l\'image envoyée, non.';

  @override
  String get shareLinkReadyTitle => 'Lien créé';

  @override
  String shareLinkReadyCreatedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Créé le $dateString';
  }

  @override
  String get shareLinkOtherDeviceBody =>
      'Ce lien a été créé sur un autre appareil : impossible de l\'afficher ou de le copier ici. Vous pouvez tout de même le révoquer.';

  @override
  String get shareRevoke => 'Révoquer ce lien';

  @override
  String get shareRevokeTitle => 'Révoquer ce lien ?';

  @override
  String get shareRevokeBody =>
      'Les personnes qui l\'ont reçu ne pourront plus ouvrir la galerie.';

  @override
  String get shareRevoking => 'Révocation…';

  @override
  String get shareRevoked => 'Lien révoqué.';

  @override
  String get shareRevokeError => 'Le lien n\'a pas pu être révoqué.';

  @override
  String get shareErrorNetwork =>
      'Le lien n\'a pas été créé : aucune connexion.';

  @override
  String get shareErrorService => 'Le lien n\'a pas été créé.';

  @override
  String get trashTitle => 'Corbeille';

  @override
  String get trashEmptyTitle => 'La Corbeille est vide';

  @override
  String get trashEmptyBody =>
      'Les œuvres supprimées apparaissent ici pendant 30 jours.';

  @override
  String get trashErrorTitle => 'Impossible d\'ouvrir la Corbeille';

  @override
  String trashItemDeletedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Supprimé le $dateString';
  }

  @override
  String trashItemPurgeOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Supprimé définitivement le $dateString';
  }

  @override
  String get trashRestore => 'Restaurer';

  @override
  String get trashRestoring => 'Restauration…';

  @override
  String get trashRestoreError => 'L\'œuvre n\'a pas pu être restaurée.';

  @override
  String get trashPurge => 'Supprimer définitivement';

  @override
  String get trashPurging => 'Suppression…';

  @override
  String get trashPurgeError =>
      'L\'œuvre n\'a pas pu être supprimée définitivement.';

  @override
  String get trashPurgeConfirmTitle => 'Supprimer définitivement cette œuvre ?';

  @override
  String get trashPurgeConfirmBody =>
      'Cette action est irréversible. L\'œuvre et son image seront effacées définitivement.';

  @override
  String get trashPurgeAll => 'Vider la Corbeille';

  @override
  String get trashPurgeAllConfirmTitle => 'Vider toute la Corbeille ?';

  @override
  String get trashPurgeAllConfirmBody =>
      'Toutes les œuvres de la Corbeille seront effacées définitivement. Cette action est irréversible.';

  @override
  String get trashPurgeAllError => 'La Corbeille n\'a pas pu être vidée.';

  @override
  String shareNotSyncedTitle(String childName) {
    return 'Les dessins de $childName ne sont pas encore sauvegardés';
  }

  @override
  String get shareNotSyncedBody =>
      'La galerie web serait vide. Sauvegardez d\'abord, puis créez le lien.';

  @override
  String get shareNotSyncedAction => 'Sauvegarder maintenant';

  @override
  String get shareBackupRunning => 'Sauvegarde en cours…';

  @override
  String get shareChildMissing => 'Ce profil n\'existe plus.';

  @override
  String shareMessage(String childName, String url) {
    return 'Voici la galerie de dessins de $childName : $url';
  }

  @override
  String get shareExistingHeading => 'Liens actifs';

  @override
  String get errorNetworkTitle => 'Aucune connexion';

  @override
  String get errorNetworkBody => 'Vérifiez votre connexion, puis réessayez.';

  @override
  String get errorServiceTitle => 'Le service ne répond pas';

  @override
  String get errorServiceBody => 'Réessayez dans quelques instants.';

  @override
  String get errorLocalWriteTitle => 'L\'enregistrement a échoué';

  @override
  String get errorLocalWriteBody =>
      'Rien n\'a été perdu. Vous pouvez réessayer.';

  @override
  String get errorNotFoundTitle => 'Introuvable';

  @override
  String get errorNotFoundBody => 'Cet élément n\'existe plus.';

  @override
  String get errorNotSignedInTitle => 'Compte requis';

  @override
  String get errorNotSignedInBody =>
      'Connectez-vous pour utiliser cette fonction.';

  @override
  String get errorUnavailableTitle => 'Fonction indisponible';

  @override
  String get errorUnavailableBody =>
      'Cette opération n\'est pas encore disponible.';

  @override
  String get errorFamilyMismatchTitle => 'Cet appareil est lié ailleurs';

  @override
  String get errorFamilyMismatchBody =>
      'Ce coffre est déjà lié à un autre foyer. Déconnectez-vous pour continuer en local, ou contactez-nous pour démarrer un nouveau coffre avec ce compte.';

  @override
  String get errorQuotaExceededTitle => 'Espace de stockage du foyer atteint';

  @override
  String get errorQuotaExceededBody =>
      'Cette œuvre reste enregistrée sur cet appareil. Elle sera envoyée automatiquement dès qu\'une place se libère.';

  @override
  String get errorUnknownTitle => 'Une erreur est survenue';

  @override
  String get errorUnknownBody =>
      'Réessayez. Si le problème persiste, écrivez-nous.';

  @override
  String get familyHubTitle => 'Espace famille';

  @override
  String familyHubNamedTitle(String name) {
    return 'Famille $name';
  }

  @override
  String get familyHubSectionArtists => 'Artistes';

  @override
  String get familyHubAddArtist => 'Ajouter un artiste';

  @override
  String get familyHubSectionFamilyBackup => 'Famille et sauvegarde';

  @override
  String get familyHubAccountLocalOnly => 'Sauvegarde sur cet appareil';

  @override
  String get familyHubAccountLocalSubtitle =>
      'Activez une sauvegarde privée quand vous le souhaitez.';

  @override
  String get familyHubFamilySubtitle => 'Inviter, rejoindre ou gérer le foyer.';

  @override
  String get familyHubFamilyAndSettings => 'Famille et réglages';

  @override
  String get captureAnecdoteTitle => 'Ajouter une anecdote';

  @override
  String get captureAnecdoteSubtitle =>
      'Facultatif — vous pourrez aussi le faire plus tard.';

  @override
  String get captureIosCropTitle => 'Recadrer le dessin';

  @override
  String get artworkAudioSaveError => 'Impossible d\'enregistrer la voix';

  @override
  String get syncUploadSuspendedTitle => 'Sauvegardes suspendues';

  @override
  String get syncUploadSuspendedBody =>
      'Les nouvelles sauvegardes cloud sont temporairement suspendues afin de maintenir l\'application gratuite.\n\nVos galeries existantes, les restaurations et les suppressions restent pleinement disponibles.';
}
