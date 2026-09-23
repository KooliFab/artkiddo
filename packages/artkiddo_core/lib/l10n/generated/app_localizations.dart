import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'artkiddo'**
  String get commonAppName;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get commonSave;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement…'**
  String get commonSaving;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get commonCancel;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get commonClose;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get commonBack;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get commonNext;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get commonSkip;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get commonDelete;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Suppression…'**
  String get commonDeleting;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get commonEdit;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get commonRetry;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get commonCopy;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Lien copié.'**
  String get commonCopied;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get commonSend;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les réglages'**
  String get commonOpenSettings;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai compris'**
  String get commonUnderstood;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get commonContinueEditing;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Abandonner'**
  String get commonDiscard;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Exemple'**
  String get commonExampleLabel;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Chargement…'**
  String get commonLoading;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'facultatif'**
  String get commonOptional;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'requis'**
  String get commonRequired;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Nous écrire'**
  String get commonContactUs;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ouvre le navigateur'**
  String get commonOpensBrowser;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Abandonner les modifications ?'**
  String get commonDiscardTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ce que vous avez saisi ne sera pas conservé.'**
  String get commonDiscardBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'yMMMMd'**
  String get commonDateFormat;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'yMMMd'**
  String get commonDateFormatShort;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Le dessin est rangé, le souvenir reste.'**
  String get onboardingPage1Title;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Prenez le dessin en photo avant qu\'il ne s\'abîme, et gardez-le sans encombrer la maison.'**
  String get onboardingPage1Body;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Tout reste sur votre appareil.'**
  String get onboardingPage2Title;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Les photos sont enregistrées sur cet appareil. Aucun compte n\'est nécessaire pour commencer.'**
  String get onboardingPage2Body;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Prêt à commencer.'**
  String get onboardingPage3Title;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez un premier dessin quand vous voulez. Vous pourrez présenter l\'artiste juste après.'**
  String get onboardingPage3Body;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Commencer mon album'**
  String get onboardingStart;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Page {n} sur 3'**
  String a11yOnboardingPageIndicator(int n);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Galerie'**
  String get navGallery;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Enfants'**
  String get navChildren;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get navSettings;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'{label}, sélectionné'**
  String a11yNavSelected(String label);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Galerie'**
  String get galleryTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun dessin} =1{1 dessin} other{{count} dessins}}'**
  String galleryCount(num count);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun dessin de {childName}} =1{1 dessin de {childName}} other{{count} dessins de {childName}}}'**
  String galleryCountForChild(num count, String childName);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get galleryFilterAll;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer par enfant'**
  String get galleryFilterLabel;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un dessin'**
  String get galleryAddArtwork;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un dessin de {childName}'**
  String galleryAddArtworkFor(String childName);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Commencez par présenter l\'artiste'**
  String get galleryEmptyNoChildTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez un enfant : chaque dessin lui sera attribué et son âge s\'affichera automatiquement.'**
  String get galleryEmptyNoChildBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un enfant'**
  String get galleryEmptyNoChildAction;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Votre galerie est prête'**
  String get galleryEmptyNoArtworkTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez le premier dessin. Il restera sur cet appareil.'**
  String get galleryEmptyNoArtworkBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Aucun dessin de {childName} pour l\'instant'**
  String galleryEmptyFilteredTitle(String childName);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez-en un, ou revenez à l\'ensemble de la galerie.'**
  String get galleryEmptyFilteredBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Voir tous les dessins'**
  String get galleryEmptyFilteredShowAll;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir votre galerie'**
  String get galleryErrorTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Vos dessins sont toujours sur l\'appareil.'**
  String get galleryErrorBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Vos dessins n’ont pas été supprimés. Ne désinstallez pas l’application : cela effacerait définitivement les originaux. Redémarrez, puis exportez-les si le problème persiste.'**
  String get galleryVaultErrorBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire vos artistes'**
  String get captureArtistsUnavailableTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Votre photo est toujours là. Ne désinstallez pas l’application : cela effacerait définitivement l’original. Réessayez, puis exportez la photo si le problème persiste.'**
  String get captureArtistsUnavailableBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de vérifier l’artiste pour le moment.'**
  String get captureArtistsUnavailableSaveHint;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Exporter mes photos'**
  String get vaultRescueExportAction;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Crée un fichier à partager avec vos originaux et la photo en cours, même si le coffre est illisible.'**
  String get vaultRescueExportBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'La photo en cours sera incluse dans l’export.'**
  String get vaultRescueExportIncludesDraft;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de créer l’export : environ {required} d’espace libre sont nécessaires.'**
  String vaultRescueInsufficientSpace(String required);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'{childName} a été supprimé. La galerie affiche de nouveau tous les dessins.'**
  String galleryFilterReset(String childName);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Image introuvable'**
  String get galleryImageMissing;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Dessin ajouté à la galerie.'**
  String get galleryArtworkAdded;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Dessin de {childName}, ajouté le {date}, {age} lors de l\'ajout.'**
  String a11yGalleryCard(String childName, DateTime date, String age);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Dessin de {childName}, ajouté le {date}, {age} lors de l\'ajout. Anecdote : {story}'**
  String a11yGalleryCardWithStory(
    String childName,
    DateTime date,
    String age,
    String story,
  );

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Filtre : {label}. {count} dessins.'**
  String a11yGalleryFilterChanged(String label, int count);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté le {date}'**
  String artworkAddedOn(DateTime date);

  /// Attribution de l'auteur du dessin.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté par {author}'**
  String artworkAddedBy(String author);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Âge lors de l\'ajout : {age}'**
  String artworkAgeAtAddition(String age);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Dessiné le {date}'**
  String artworkDrawnOn(DateTime date);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Âge lors du dessin : {age}'**
  String artworkAgeAtDrawing(String age);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Moins de 1 mois'**
  String get ageLessThanMonth;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 mois} other{{count} mois}}'**
  String ageMonths(num count);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 an} other{{count} ans}}'**
  String ageYears(num count);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'{years, plural, =1{1 an} other{{years} ans}} et {months, plural, =1{1 mois} other{{months} mois}}'**
  String ageYearsMonths(num years, num months);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Avant la naissance'**
  String get ageBeforeBirth;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un dessin'**
  String get captureTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get captureSourceCameraTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Le dessin est devant vous.'**
  String get captureSourceCameraBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans mes photos'**
  String get captureSourceGalleryTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Le dessin est déjà photographié.'**
  String get captureSourceGalleryBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Le dessin est-il bien visible ?'**
  String get captureReviewTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser cette photo'**
  String get captureReviewUse;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get captureReviewRetake;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Cette image n\'a pas pu être ouverte.'**
  String get captureReviewUnreadable;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Cette image est très volumineuse et pourrait ralentir l\'application.'**
  String get captureReviewTooLarge;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'À qui est ce dessin ?'**
  String get captureDetailsTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Voir en grand'**
  String get captureDetailsViewLarge;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Artiste'**
  String get captureArtistLabel;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Choisir l\'artiste'**
  String get captureArtistChoose;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez l\'artiste avant d\'enregistrer.'**
  String get captureArtistRequired;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un enfant'**
  String get captureArtistAddChild;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ce dessin a besoin d\'un artiste'**
  String get captureNoChildTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez un enfant : votre dessin est conservé pendant ce temps.'**
  String get captureNoChildBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Anecdote (facultatif)'**
  String get captureStoryLabel;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ce que l\'enfant raconte sur son dessin.'**
  String get captureStoryHint;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Raconter le dessin'**
  String get captureAudioCardTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrez la voix de l\'enfant racontant son dessin (max 2 min).'**
  String get captureAudioCardSubtitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer la voix'**
  String get captureAudioRecord;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement en cours…'**
  String get captureAudioRecording;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get captureAudioStop;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get captureAudioCancel;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Écouter'**
  String get captureAudioPlay;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Pause'**
  String get captureAudioPause;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Recommencer'**
  String get captureAudioReRecord;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Remplacer l\'enregistrement ?'**
  String get captureAudioReRecordConfirmTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'L\'enregistrement actuel sera remplacé par un nouveau.'**
  String get captureAudioReRecordConfirmBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la voix'**
  String get captureAudioDelete;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'enregistrement ?'**
  String get captureAudioDeleteConfirmTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Cette action supprimera l\'enregistrement audio.'**
  String get captureAudioDeleteConfirmBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Accès au microphone requis'**
  String get captureAudioMicPermissionDeniedTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Pour enregistrer la voix de votre enfant, autorisez l\'accès au microphone dans les réglages.'**
  String get captureAudioMicPermissionDeniedBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'La voix de l\'enfant'**
  String get artworkAudioCardTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Chargement de la voix…'**
  String get artworkAudioDownloading;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger la voix'**
  String get artworkAudioDownloadError;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get artworkAudioRetry;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Inclure les voix d\'enfants'**
  String get sharingIncludeAudio;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Les proches avec le lien pourront écouter les enregistrements vocaux.'**
  String get sharingIncludeAudioSubtitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté le {date}'**
  String captureAddedToday(DateTime date);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le dessin'**
  String get captureSave;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'{childName} a été ajouté.'**
  String captureChildCreated(String childName);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Le dessin n\'a pas été enregistré'**
  String get captureErrorWriteTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Rien n\'a été perdu. Vous pouvez réessayer.'**
  String get captureErrorWriteBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Il n\'y a plus assez d\'espace sur l\'appareil'**
  String get captureErrorStorageFullTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Libérez de l\'espace, puis réessayez.'**
  String get captureErrorStorageFullBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Abandonner ce dessin ?'**
  String get captureDiscardTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'La photo et l\'anecdote ne seront pas enregistrées.'**
  String get captureDiscardBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Abandonner cette photo ?'**
  String get captureDiscardPhotoTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez en reprendre une autre.'**
  String get captureDiscardPhotoBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'L\'accès à l\'appareil photo est refusé'**
  String get permissionCameraDeniedTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez tout de même choisir une photo existante.'**
  String get permissionCameraDeniedBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'L\'accès aux photos est refusé'**
  String get permissionPhotosDeniedTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez tout de même prendre une nouvelle photo.'**
  String get permissionPhotosDeniedBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'artkiddo n\'a pas accès à vos photos'**
  String get permissionBothDeniedTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Autorisez l\'appareil photo ou les photos dans les réglages pour ajouter un dessin.'**
  String get permissionBothDeniedBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Autorisation nécessaire pour prendre une photo.'**
  String get permissionCameraReason;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Autorisation nécessaire pour choisir une photo.'**
  String get permissionPhotosReason;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Dessin de {childName}'**
  String artworkTitle(String childName);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Anecdote'**
  String get artworkStoryHeading;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Aucune anecdote pour ce dessin.'**
  String get artworkStoryEmpty;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une anecdote'**
  String get artworkStoryAdd;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'anecdote'**
  String get artworkStoryEdit;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Effacer l\'anecdote'**
  String get artworkStoryClear;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ce que l\'enfant raconte sur son dessin.'**
  String get artworkStoryHint;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Anecdote enregistrée.'**
  String get artworkStorySaved;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Anecdote effacée.'**
  String get artworkStoryCleared;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Effacer l\'anecdote ?'**
  String get artworkStoryClearConfirmTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Le texte sera retiré de ce dessin.'**
  String get artworkStoryClearConfirmBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'L\'anecdote n\'a pas été enregistrée. Votre texte est conservé.'**
  String get artworkStoryError;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter la date du dessin'**
  String get artworkDrawnAtAdd;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la date du dessin'**
  String get artworkDrawnAtEdit;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Effacer la date du dessin'**
  String get artworkDrawnAtClear;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Date du dessin'**
  String get artworkDrawnAtPickerTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Date du dessin enregistrée.'**
  String get artworkDrawnAtSaved;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Date du dessin effacée.'**
  String get artworkDrawnAtCleared;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Effacer la date du dessin ?'**
  String get artworkDrawnAtClearConfirmTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'L\'âge affiché redeviendra celui du jour de l\'ajout.'**
  String get artworkDrawnAtClearConfirmBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'La date du dessin n\'a pas été enregistrée.'**
  String get artworkDrawnAtError;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Cette date n\'est pas encore arrivée.'**
  String get artworkDrawnAtFutureError;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Cette date précède la naissance de l\'enfant.'**
  String get artworkDrawnAtBeforeBirthError;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer cette image'**
  String get artworkSendImage;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'L\'image part par votre application de messagerie.'**
  String get artworkSendImageHelp;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get artworkShareGallery;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Un lien web pour voir tous ses dessins.'**
  String get artworkShareGalleryHelp;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Un dessin de {childName}, ajouté le {date}.'**
  String artworkShareText(String childName, DateTime date);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Agrandir'**
  String get artworkZoom;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Agrandir davantage'**
  String get artworkZoomIn;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Réduire'**
  String get artworkZoomOut;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Image introuvable'**
  String get artworkZoomImageMissing;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Cette image n\'a pas pu être affichée.'**
  String get artworkZoomDecodeFailed;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'L\'image de ce dessin est introuvable'**
  String get artworkImageMissingTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Les informations du dessin sont conservées.'**
  String get artworkImageMissingBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce dessin'**
  String get artworkDelete;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce dessin ?'**
  String get artworkDeleteTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'La photo sera retirée de cet appareil. Cette action est définitive.'**
  String get artworkDeleteBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'La copie déjà sauvegardée n\'est pas retirée par cette action.'**
  String get artworkDeleteCloudNotice;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Le dessin n\'a pas pu être supprimé.'**
  String get artworkDeleteError;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Dessin supprimé.'**
  String get artworkDeleted;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Artiste inconnu'**
  String get artworkUnknownArtist;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Dessin de {childName}, ajouté le {date}'**
  String a11yArtworkImage(String childName, DateTime date);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Enfants'**
  String get childrenTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Chaque dessin est attribué à un enfant, ce qui permet d\'afficher son âge.'**
  String get childrenHelp;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un enfant'**
  String get childrenAdd;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Né(e) le {date} · {count, plural, =0{aucun dessin} =1{1 dessin} other{{count} dessins}}'**
  String childrenRowSubtitle(DateTime date, num count);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Aucun enfant pour l\'instant'**
  String get childrenEmptyTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez un enfant pour attribuer ses dessins et afficher son âge.'**
  String get childrenEmptyBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir la liste des enfants'**
  String get childrenErrorTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Voir ses dessins'**
  String get childrenActionsViewArtworks;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le profil'**
  String get childrenActionsEdit;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get childrenActionsShare;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le profil'**
  String get childrenActionsDelete;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer {childName} ?'**
  String childrenDeleteTitle(String childName);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun dessin ne sera supprimé.} =1{1 dessin sera également supprimé de cet appareil.} other{{count} dessins seront également supprimés de cet appareil.}} Cette action est définitive.'**
  String childrenDeleteBody(num count);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'{childName} n\'a pas été supprimé.'**
  String childrenDeleteError(String childName);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'{childName} et ses dessins ont été supprimés.'**
  String childrenDeleted(String childName);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel enfant'**
  String get childEditorTitleCreate;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le profil'**
  String get childEditorTitleEdit;

  /// Title shown while editing an artist profile.
  ///
  /// In fr, this message translates to:
  /// **'Artiste'**
  String get childEditorTitleArtist;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Votre dessin est conservé pendant ce temps.'**
  String get childEditorFromDraft;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Prénom ou surnom'**
  String get childEditorNameLabel;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Par exemple : Léa, Nono'**
  String get childEditorNameHint;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Date de naissance'**
  String get childEditorBirthDateLabel;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une date'**
  String get childEditorBirthDateChoose;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Sert à indiquer l\'âge de l\'enfant sur chaque dessin.'**
  String get childEditorBirthDateHelp;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez un prénom ou un surnom.'**
  String get childEditorErrorNameEmpty;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'40 caractères au maximum.'**
  String get childEditorErrorNameTooLong;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Un autre enfant porte déjà ce prénom.'**
  String get childEditorWarnNameDuplicate;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la date de naissance.'**
  String get childEditorErrorBirthDateMissing;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Cette date est dans le futur.'**
  String get childEditorErrorBirthDateFuture;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Cette date semble trop ancienne.'**
  String get childEditorErrorBirthDateTooOld;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Le profil n\'a pas été enregistré. Vos informations sont conservées.'**
  String get childEditorErrorWrite;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'{childName} a été ajouté.'**
  String childEditorCreated(String childName);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Profil mis à jour.'**
  String get childEditorUpdated;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez un prénom et une date de naissance.'**
  String get childEditorSaveDisabledReason;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get settingsTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Vos dessins sont sur cet appareil. Aucun compte n\'est nécessaire.'**
  String get settingsLocalNotice;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde et partage'**
  String get settingsGroupBackup;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Application'**
  String get settingsGroupApp;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationsRow;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Activées'**
  String get settingsNotificationsEnabled;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Non demandées'**
  String get settingsNotificationsNotRequested;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Refusées'**
  String get settingsNotificationsDenied;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Indisponibles'**
  String get settingsNotificationsUnavailable;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Notifications activées.'**
  String get settingsNotificationsEnabledMessage;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Autorisez les notifications dans les réglages de l\'appareil pour suivre l\'état des sauvegardes.'**
  String get settingsNotificationsDeniedMessage;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de mettre à jour l\'autorisation des notifications.'**
  String get settingsNotificationsRequestError;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Documents'**
  String get settingsGroupDocuments;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Non activée'**
  String get settingsAccountOff;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Un compte permet de sauvegarder vos dessins et de partager une galerie web.'**
  String get settingsAccountExplain;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Jamais sauvegardé'**
  String get settingsBackupNever;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Dernière sauvegarde : {date}'**
  String settingsBackupLast(DateTime date);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde en cours… {n} sur {total}'**
  String settingsBackupRunning(int n, int total);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'{n} dessins sauvegardés, {m} en échec.'**
  String settingsBackupPartial(int n, int m);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'La sauvegarde n\'a pas abouti.'**
  String get settingsBackupFailed;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Le service de sauvegarde est indisponible pour le moment.'**
  String get settingsBackupUnavailable;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'La sauvegarde a besoin de votre intervention pour continuer.'**
  String get settingsBackupBlocked;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'La restauration sur un nouvel appareil n\'est pas encore disponible.'**
  String get settingsRestoreNotice;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingsLanguageRow;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Suivre la langue de l\'appareil'**
  String get settingsLanguageSystem;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Français (Canada)'**
  String get settingsLanguageFr;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'English (Canada)'**
  String get settingsLanguageEn;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get settingsAboutRow;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Outils de débogage'**
  String get settingsDebugRow;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Politique de confidentialité'**
  String get settingsPrivacyRow;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d\'utilisation'**
  String get settingsTermsRow;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Famille'**
  String get familyTitle;

  String get familyInviteTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la famille'**
  String get familyNameLabel;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Famille Tremblay'**
  String get familyNameHint;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Nom enregistré.'**
  String get familyNameSaved;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Partagez ce code ou ce QR avec la personne qui rejoint votre famille. Il reste valable et peut être réutilisé autant de fois que nécessaire.'**
  String get familyInviteExplain;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Code d\'invitation'**
  String get familyInviteCodeLabel;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Copier le code'**
  String get familyInviteCopy;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Code copié.'**
  String get familyInviteCopied;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez un code ? Saisissez-le ou scannez le QR pour rejoindre une famille.'**
  String get familyJoinExplain;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : 7K4RTQ2M'**
  String get familyJoinCodeHint;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get familyJoinButton;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Vérification…'**
  String get familyJoinChecking;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Adhésion à votre famille…'**
  String get familyJoinConverging;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez rejoint la famille.'**
  String get familyJoinSuccess;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ce code n\'existe pas. Vérifiez-le et réessayez.'**
  String get familyJoinInvalidCode;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre une autre famille ?'**
  String get familyJoinConfirmTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil ne peut être lié qu\'à une seule famille à la fois.'**
  String get familyJoinConfirmIntro;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun enfant} =1{1 enfant} other{{count} enfants}}'**
  String familyJoinImpactChildren(num count);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{aucune œuvre} =1{1 œuvre} other{{count} œuvres}}'**
  String familyJoinImpactArtworks(num count);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Vous vouliez plutôt partager vos œuvres avec quelqu\'un ? Donnez-lui votre code d\'invitation, affiché plus haut — vous garderez tout.'**
  String get familyJoinInviteInsteadHint;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes le seul membre actif de votre famille actuelle. Rejoindre une autre famille supprimera définitivement tous ses enfants, toutes ses œuvres et tout son contenu cloud.'**
  String get familyJoinConfirmPurgeWarning;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Vous quittez votre famille actuelle. Son contenu reste accessible aux autres membres, mais vous en perdrez l\'accès et il sera retiré de cet appareil.'**
  String get familyJoinConfirmLeaveWarning;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de vérifier l\'état de votre famille actuelle. Réessayez avant de continuer.'**
  String get familyJoinConfirmCheckFailedWarning;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai compris que cette action est définitive.'**
  String get familyJoinConfirmCheck;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre et tout supprimer'**
  String get familyJoinConfirmAction;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre et quitter'**
  String get familyJoinConfirmActionLeave;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Préparation de votre appareil…'**
  String get familyJoinDiscarding;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Le changement de famille a réussi, mais cet appareil n\'a pas pu être réinitialisé.'**
  String get familyJoinResetError;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un code'**
  String get familyScanButton;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un code'**
  String get familyScanTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Cadrez le QR code affiché par l\'autre personne.'**
  String get familyScanExplain;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'L\'accès à l\'appareil photo est nécessaire pour scanner un code.'**
  String get familyScanPermissionDenied;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Aucune connexion. Les fonctions de sauvegarde et de partage sont indisponibles.'**
  String get settingsOffline;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde et compte'**
  String get accountTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ce qu\'un compte apporte'**
  String get accountIntroTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Une sauvegarde de vos dessins et un lien web à partager avec vos proches. Vos dessins restent sur cet appareil dans tous les cas.'**
  String get accountIntroBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Votre adresse courriel'**
  String get accountEmailLabel;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'parent@exemple.ca'**
  String get accountEmailHint;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Cette adresse ne semble pas valide.'**
  String get accountEmailInvalid;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get accountPasswordLabel;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe doit contenir au moins 6 caractères.'**
  String get accountPasswordInvalid;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Coller'**
  String get accountCodePaste;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get accountSubmit;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Connexion…'**
  String get accountSubmitting;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get accountForgotPassword;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser votre mot de passe'**
  String get accountRecoveryTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Nous vous enverrons un lien si un compte utilise cette adresse courriel.'**
  String get accountRecoveryBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le lien'**
  String get accountRecoverySend;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Envoi…'**
  String get accountRecoverySending;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez votre courriel'**
  String get accountRecoverySentTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Si un compte utilise cette adresse, vous recevrez un lien. Vérifiez aussi les indésirables.'**
  String get accountRecoverySentBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get accountRecoveryNewPassword;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le mot de passe'**
  String get accountRecoveryConfirmPassword;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Choisir ce mot de passe'**
  String get accountRecoveryUpdate;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour…'**
  String get accountRecoveryUpdating;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Les mots de passe ne correspondent pas.'**
  String get accountRecoveryMismatch;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Votre mot de passe a été mis à jour.'**
  String get accountRecoveryUpdated;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'La demande n’a pas abouti. Réessayez plus tard.'**
  String get accountRecoveryError;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Adresse ou mot de passe incorrect.'**
  String get accountErrorInvalidCredentials;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe doit contenir au moins 6 caractères.'**
  String get accountErrorWeakPassword;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Trop de demandes. Réessayez dans {seconds} secondes.'**
  String accountErrorRateLimited(int seconds);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Compte lié.'**
  String get accountSignedIn;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Compte lié : {email}'**
  String accountConnectedAs(String email);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Mon profil'**
  String get accountMyProfile;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get accountFirstNameLabel;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Votre prénom'**
  String get accountFirstNameHint;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Nom de famille'**
  String get accountLastNameLabel;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Votre nom de famille'**
  String get accountLastNameHint;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Profil mis à jour.'**
  String get accountProfileSaved;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Parent'**
  String get accountRoleParent;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Contributeur'**
  String get accountRoleContributor;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get accountSignOut;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter ?'**
  String get accountSignOutTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Vos dessins restent sur cet appareil.'**
  String get accountSignOutBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get accountDelete;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer votre compte ?'**
  String get accountDeleteTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Cela supprime votre identifiant de connexion. Les enfants et les œuvres de votre foyer ne sont jamais touchés — les autres membres du foyer gardent un accès complet.'**
  String get accountDeleteBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai compris que cette action est définitive.'**
  String get accountDeleteConfirmCheck;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes le dernier membre actif de votre foyer. Supprimer votre compte effacera aussi, immédiatement et définitivement, tous les enfants, toutes les œuvres et tout le contenu cloud de ce foyer.'**
  String get accountDeleteLastMemberWarning;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Que faire du coffre sur cet appareil ?'**
  String get accountDeleteLocalChoiceTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Conserver le coffre local'**
  String get accountDeleteKeepLocal;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Les dessins déjà sur cet appareil restent utilisables hors ligne.'**
  String get accountDeleteKeepLocalBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Effacer aussi le coffre local'**
  String get accountDeleteEraseLocal;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Tous les dessins de cet appareil sont supprimés, y compris ceux non sauvegardés.'**
  String get accountDeleteEraseLocalBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Suppression du compte…'**
  String get accountDeleting;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Le compte n\'a pas pu être supprimé (aucune connexion). Réessayez plus tard.'**
  String get accountDeleteNetworkErrorBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'La suppression n\'a pas pu être terminée'**
  String get accountDeletePartialTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Voici ce qui a été supprimé et ce qui reste. Écrivez-nous et nous terminerons l\'opération.'**
  String get accountDeletePartialBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Une connexion est nécessaire.'**
  String get accountOfflineReason;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Partager la galerie de {childName}'**
  String shareTitle(String childName);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Toute personne disposant du lien peut ouvrir cette galerie.'**
  String get shareWarning;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Le partage web a besoin d\'un compte'**
  String get shareSignedOutTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'La galerie doit être hébergée pour que vos proches puissent l\'ouvrir sans installer l\'application.'**
  String get shareSignedOutBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter pour partager'**
  String get shareSignedOutAction;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Plutôt envoyer une image'**
  String get shareSignedOutAlternative;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get shareGalleryHeading;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Un lien web qui montre les dessins sauvegardés de {childName}. Il se met à jour avec les nouveaux dessins.'**
  String shareGalleryBody(String childName);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez l\'enfant dont vous souhaitez partager les œuvres.'**
  String get shareGalleryPickerBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Créer le lien'**
  String get shareGalleryCreate;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Création du lien…'**
  String get shareGalleryCreating;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer cette image'**
  String get shareImageHeading;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'L\'image part telle quelle par votre application de messagerie. Elle ne se met pas à jour.'**
  String get shareImageBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'La galerie se met à jour ; l\'image envoyée, non.'**
  String get shareDifference;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Lien créé'**
  String get shareLinkReadyTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Créé le {date}'**
  String shareLinkReadyCreatedOn(DateTime date);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien a été créé sur un autre appareil : impossible de l\'afficher ou de le copier ici. Vous pouvez tout de même le révoquer.'**
  String get shareLinkOtherDeviceBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer ce lien'**
  String get shareRevoke;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer ce lien ?'**
  String get shareRevokeTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Les personnes qui l\'ont reçu ne pourront plus ouvrir la galerie.'**
  String get shareRevokeBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Révocation…'**
  String get shareRevoking;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Lien révoqué.'**
  String get shareRevoked;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Le lien n\'a pas pu être révoqué.'**
  String get shareRevokeError;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Le lien n\'a pas été créé : aucune connexion.'**
  String get shareErrorNetwork;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Le lien n\'a pas été créé.'**
  String get shareErrorService;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Corbeille'**
  String get trashTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'La Corbeille est vide'**
  String get trashEmptyTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Les œuvres supprimées apparaissent ici pendant 30 jours.'**
  String get trashEmptyBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir la Corbeille'**
  String get trashErrorTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Supprimé le {date}'**
  String trashItemDeletedOn(DateTime date);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Supprimé définitivement le {date}'**
  String trashItemPurgeOn(DateTime date);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer'**
  String get trashRestore;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Restauration…'**
  String get trashRestoring;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'L\'œuvre n\'a pas pu être restaurée.'**
  String get trashRestoreError;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer définitivement'**
  String get trashPurge;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Suppression…'**
  String get trashPurging;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'L\'œuvre n\'a pas pu être supprimée définitivement.'**
  String get trashPurgeError;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer définitivement cette œuvre ?'**
  String get trashPurgeConfirmTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. L\'œuvre et son image seront effacées définitivement.'**
  String get trashPurgeConfirmBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Vider la Corbeille'**
  String get trashPurgeAll;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Vider toute la Corbeille ?'**
  String get trashPurgeAllConfirmTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les œuvres de la Corbeille seront effacées définitivement. Cette action est irréversible.'**
  String get trashPurgeAllConfirmBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'La Corbeille n\'a pas pu être vidée.'**
  String get trashPurgeAllError;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Les dessins de {childName} ne sont pas encore sauvegardés'**
  String shareNotSyncedTitle(String childName);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'La galerie web serait vide. Sauvegardez d\'abord, puis créez le lien.'**
  String get shareNotSyncedBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder maintenant'**
  String get shareNotSyncedAction;

  /// No description provided for @shareBackupRunning.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde en cours…'**
  String get shareBackupRunning;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ce profil n\'existe plus.'**
  String get shareChildMissing;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Voici la galerie de dessins de {childName} : {url}'**
  String shareMessage(String childName, String url);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Liens actifs'**
  String get shareExistingHeading;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Aucune connexion'**
  String get errorNetworkTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez votre connexion, puis réessayez.'**
  String get errorNetworkBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Le service ne répond pas'**
  String get errorServiceTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Réessayez dans quelques instants.'**
  String get errorServiceBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'L\'enregistrement a échoué'**
  String get errorLocalWriteTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Rien n\'a été perdu. Vous pouvez réessayer.'**
  String get errorLocalWriteBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Introuvable'**
  String get errorNotFoundTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Cet élément n\'existe plus.'**
  String get errorNotFoundBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Compte requis'**
  String get errorNotSignedInTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour utiliser cette fonction.'**
  String get errorNotSignedInBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Fonction indisponible'**
  String get errorUnavailableTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Cette opération n\'est pas encore disponible.'**
  String get errorUnavailableBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil est lié ailleurs'**
  String get errorFamilyMismatchTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ce coffre est déjà lié à un autre foyer. Déconnectez-vous pour continuer en local, ou contactez-nous pour démarrer un nouveau coffre avec ce compte.'**
  String get errorFamilyMismatchBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Espace de stockage du foyer atteint'**
  String get errorQuotaExceededTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Cette œuvre reste enregistrée sur cet appareil. Elle sera envoyée automatiquement dès qu\'une place se libère.'**
  String get errorQuotaExceededBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue'**
  String get errorUnknownTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Réessayez. Si le problème persiste, écrivez-nous.'**
  String get errorUnknownBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Espace famille'**
  String get familyHubTitle;

  /// Titre du hub famille lorsqu'une famille est nommée.
  ///
  /// In fr, this message translates to:
  /// **'Famille {name}'**
  String familyHubNamedTitle(String name);

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Artistes'**
  String get familyHubSectionArtists;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un artiste'**
  String get familyHubAddArtist;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Famille et réglages'**
  String get familyHubFamilyAndSettings;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Parents'**
  String get familyHubSectionParents;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Contributeurs'**
  String get familyHubSectionContributors;

  /// Titre de la section des membres de la famille autres que les parents.
  ///
  /// In fr, this message translates to:
  /// **'Autres membres'**
  String get familyHubSectionOtherMembers;

  /// Action permettant au membre connecté de quitter sa famille.
  ///
  /// In fr, this message translates to:
  /// **'Quitter la famille'**
  String get familyHubLeaveFamily;

  /// Titre de confirmation de sortie de la famille.
  ///
  /// In fr, this message translates to:
  /// **'Quitter cette famille ?'**
  String get familyHubLeaveFamilyTitle;

  /// Conséquence de la sortie de famille.
  ///
  /// In fr, this message translates to:
  /// **'Vous perdrez l’accès à cette famille et à son contenu partagé. Vos données locales ne seront pas supprimées.'**
  String get familyHubLeaveFamilyBody;

  /// Confirmation destructive de sortie de famille.
  ///
  /// In fr, this message translates to:
  /// **'Quitter la famille'**
  String get familyHubLeaveFamilyConfirm;

  /// Libellé administré par un parent, par exemple Oncle ou Papy.
  ///
  /// In fr, this message translates to:
  /// **'Lien avec la famille'**
  String get familyMemberRelationLabel;

  /// Exemple pour la saisie du libellé de relation familiale.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Oncle, Papy, Tata'**
  String get familyMemberRelationHint;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un membre'**
  String get familyHubAddMember;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte ou se connecter'**
  String get familyHubCreateAccount;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Voir les photos supprimés'**
  String get familyHubTrashRow;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Synchroniser les photos'**
  String get familyHubSyncPhotos;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Réglages famille'**
  String get familySettingsTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Retirer ce membre ?'**
  String get familySettingsRemoveMemberTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Cette personne perdra l\'accès à la famille et à son contenu partagé. Rien n\'est supprimé sur son appareil.'**
  String get familySettingsRemoveMemberBody;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get familySettingsRemoveMemberAction;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Nommer parent'**
  String get familySettingsMakeParent;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Nommer contributeur'**
  String get familySettingsMakeContributor;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Le foyer doit garder au moins un parent actif.'**
  String get familySettingsLastParentError;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Connexion et compte'**
  String get settingsAccountRowNeutral;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une anecdote'**
  String get captureAnecdoteTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Facultatif — vous pourrez aussi le faire plus tard.'**
  String get captureAnecdoteSubtitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Recadrer le dessin'**
  String get captureIosCropTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer la voix'**
  String get artworkAudioSaveError;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegardes suspendues'**
  String get syncUploadSuspendedTitle;

  /// Localized user-facing copy.
  ///
  /// In fr, this message translates to:
  /// **'Les nouvelles sauvegardes cloud sont temporairement suspendues afin de maintenir l\'application gratuite.\n\nVos galeries existantes, les restaurations et les suppressions restent pleinement disponibles.'**
  String get syncUploadSuspendedBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
