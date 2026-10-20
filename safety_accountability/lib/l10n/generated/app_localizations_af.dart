// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Afrikaans (`af`).
class AppLocalizationsAf extends AppLocalizations {
  AppLocalizationsAf([String locale = 'af']) : super(locale);

  @override
  String get emergencyResponseTitle => 'Noodrespons';

  @override
  String get emergencyResponseSubtitle =>
      'Kies die tipe noodgeval wat jy ervaar';

  @override
  String get incidentBreakIn => 'Huisbraak';

  @override
  String get incidentBeingFollowed => 'Word Gevolg';

  @override
  String get incidentHijacking => 'Kaping';

  @override
  String get incidentDomesticViolence => 'Huishoudelike Geweld';

  @override
  String get incidentMedicalEmergency => 'Mediese Noodgeval';

  @override
  String get incidentFire => 'Brand';

  @override
  String get incidentAssault => 'Aanranding';

  @override
  String get incidentOther => 'Ander';

  @override
  String get sendingAlert => 'Stuur jou waarskuwing...';

  @override
  String get tryAgain => 'Probeer Weer';

  @override
  String get adminResponded =>
      '\'n Administrateur het op jou waarskuwing gereageer.';

  @override
  String referenceLabel(String ref) {
    return 'Verwysing: $ref';
  }

  @override
  String get noResponseWindow =>
      'Geen reaksie is binne die 5-minute-venster ontvang nie.';

  @override
  String get downloadPonr => 'Laai PONR af (Bewys van Nie-Reaksie)';

  @override
  String waitingForResponse(String time) {
    return 'Wag vir reaksie... $time';
  }

  @override
  String get emergencyDispatchMessage =>
      'Hulp word na jou ligging gestuur. Bly kalm en volg veiligheidsprotokolle.';

  @override
  String emergencyTitle(String type) {
    return 'Noodgeval: $type';
  }

  @override
  String contactNeedsHelp(String name) {
    return '$name het hulp nodig';
  }

  @override
  String get callAction => 'Bel';

  @override
  String get locationAction => 'Ligging';

  @override
  String get emergencyContactsTitle => 'Noodkontakte';

  @override
  String get emergencyContactsSubtitle =>
      'Die mense wat in kennis gestel word wanneer jy hulp nodig het';

  @override
  String get protectedLabel => 'Beskerm';

  @override
  String get pendingLabel => 'Hangende';

  @override
  String get addFromContacts => 'Voeg by vanaf Kontakte';

  @override
  String get contactsWhyBanner =>
      '\'n Kontak kan jou lewendige waarskuwings eers ontvang sodra hulle Safety & Accountability installeer. Stuur hulle \'n uitnodiging om van Hangende na Beskerm te verander.';

  @override
  String get yourCircle => 'Jou Kring';

  @override
  String get noContactsYet => 'Nog geen noodkontakte nie';

  @override
  String get addSomeoneYouTrust =>
      'Voeg iemand by wat jy vertrou vanaf jou foon se kontakte';

  @override
  String get couldNotLoadContacts => 'Kon nie kontakte laai nie.';

  @override
  String get invitePending => 'Uitnodiging Hangende';

  @override
  String get sendInvite => 'Stuur Uitnodiging';

  @override
  String get relationshipParent => 'Ouer';

  @override
  String get relationshipSibling => 'Broer/Suster';

  @override
  String get relationshipPartner => 'Lewensmaat';

  @override
  String get relationshipFriend => 'Vriend';

  @override
  String get relationshipRoommate => 'Kamermaat';

  @override
  String get relationshipColleague => 'Kollega';

  @override
  String get relationshipOther => 'Ander';

  @override
  String addPersonTitle(String name) {
    return 'Voeg $name by';
  }

  @override
  String get howDoYouKnowThisPerson => 'Hoe ken jy hierdie persoon?';

  @override
  String get cancel => 'Kanselleer';

  @override
  String get add => 'Voeg by';

  @override
  String get chooseAContact => 'Kies \'n Kontak';

  @override
  String get searchContacts => 'Deursoek kontakte...';

  @override
  String get noContactsFound => 'Geen kontakte gevind nie';

  @override
  String get retry => 'Probeer weer';

  @override
  String get close => 'Maak toe';

  @override
  String get join => 'Sluit aan';

  @override
  String get leave => 'Verlaat';

  @override
  String get authWelcomeBack => 'Welkom terug — meld aan om beskerm te bly';

  @override
  String get authCreatePrompt => 'Skep \'n rekening om te begin';

  @override
  String get logIn => 'Meld Aan';

  @override
  String get signUp => 'Registreer';

  @override
  String get fullName => 'Volle Naam';

  @override
  String get emailAddress => 'E-posadres';

  @override
  String get phoneNumber => 'Telefoonnommer';

  @override
  String get phoneHint => 'bv. +27 71 234 5678';

  @override
  String get password => 'Wagwoord';

  @override
  String get confirmPassword => 'Bevestig Wagwoord';

  @override
  String get forgotPassword => 'Wagwoord vergeet?';

  @override
  String get forgotPasswordSoon => 'Wagwoordherstel kom binnekort.';

  @override
  String get agreeToTerms =>
      'Ek stem in met die Diensbepalings en Privaatheidsbeleid';

  @override
  String get createAccount => 'Skep Rekening';

  @override
  String get orDivider => 'OF';

  @override
  String get continueWithGoogle => 'Gaan voort met Google';

  @override
  String get signUpWithGoogle => 'Registreer met Google';

  @override
  String get noAccountPrompt => 'Het jy nie \'n rekening nie?';

  @override
  String get haveAccountPrompt => 'Het jy reeds \'n rekening?';

  @override
  String get acceptTermsSnack =>
      'Aanvaar asseblief die Bepalings en Privaatheidsbeleid om voort te gaan.';

  @override
  String get serverUnreachable =>
      'Kon nie die bediener bereik nie. Kontroleer jou verbinding en probeer weer.';

  @override
  String get googleSoon => 'Google-aanmelding kom binnekort.';

  @override
  String get fullNameRequired => 'Volle naam is verpligtend';

  @override
  String get emailRequired => 'E-pos is verpligtend';

  @override
  String get emailInvalid => 'Voer \'n geldige e-posadres in';

  @override
  String get phoneRequired => 'Telefoonnommer is verpligtend';

  @override
  String get phoneInvalid => 'Voer \'n geldige telefoonnommer in';

  @override
  String get passwordRequired => 'Wagwoord is verpligtend';

  @override
  String get passwordTooShort => 'Gebruik ten minste 8 karakters';

  @override
  String get confirmPasswordRequired => 'Bevestig jou wagwoord';

  @override
  String get passwordsDontMatch => 'Wagwoorde stem nie ooreen nie';

  @override
  String get locationServicesOff =>
      'Liggingdienste is af — wys \'n verstekarea.';

  @override
  String get locationPermissionDenied =>
      'Liggingtoestemming is geweier — wys \'n verstekarea.';

  @override
  String get locationFailed =>
      'Kon nie jou huidige ligging kry nie — wys \'n verstekarea.';

  @override
  String get gettingLocation => 'Kry tans jou ligging...';

  @override
  String get defaultArea => 'Verstekarea';

  @override
  String get youAreHere => 'Jy is hier';

  @override
  String get somethingWentWrong => 'Iets het skeef gegaan.';

  @override
  String get panicAlertActive => 'NOODSEIN AKTIEF';

  @override
  String get noResponseYet =>
      'Nog geen antwoord nie — bly waaksaam en soek hulp as jy kan.';

  @override
  String get liveLocationShared => 'Lewendige ligging gedeel';

  @override
  String get adminNotified => 'Admin in kennis gestel';

  @override
  String get imSafeCancel => 'Ek is veilig — kanselleer waarskuwing';

  @override
  String contextTripAttached(String service) {
    return '$service-besonderhede aangeheg';
  }

  @override
  String get contextNoTrip => 'Geen aktiewe rit aangeheg nie';

  @override
  String contextCommunityNotified(String community) {
    return '$community in kennis gestel';
  }

  @override
  String get contextPassengerAttached => 'Huidige passasier aangeheg';

  @override
  String get contextNoCommunity => 'Geen gemeenskap aangesluit nie';

  @override
  String get passengerMode => 'Passasiersmodus';

  @override
  String get driverMode => 'Bestuurdermodus';

  @override
  String get switchLabel => 'Wissel';

  @override
  String get ehailingSafetyTitle => 'E-Hailing Veiligheid';

  @override
  String get ehailingRoleSubtitle =>
      'Voordat ons begin, sê vir ons aan watter kant van die rit jy is';

  @override
  String get imAPassenger => 'Ek is \'n Passasier';

  @override
  String get passengerDesc =>
      'Deel jou rit en bestuurder se besonderhede outomaties met jou noodkontakte.';

  @override
  String get imADriver => 'Ek is \'n Bestuurder';

  @override
  String get driverDesc =>
      'Sluit aan by jou bestuurdergemeenskap, teken passasiersbesonderhede aan en aktiveer \'n noodsein as jy hulp nodig het.';

  @override
  String get triggerPanicTitle => 'Aktiveer noodsein?';

  @override
  String get panicConfirmWithTrip =>
      'Dit sal dadelik \'n admin in kennis stel met jou lewendige ligging en hierdie rit se besonderhede.';

  @override
  String get panicConfirmNoTrip =>
      'Dit sal dadelik \'n admin in kennis stel met jou lewendige ligging.';

  @override
  String get triggerAlert => 'Aktiveer waarskuwing';

  @override
  String get pickRideApp =>
      'Kies jou ritprogram. Jou ritbesonderhede sal gedeel word met jou beskermde noodkontakte.';

  @override
  String get chooseYourRide => 'Kies Jou Rit';

  @override
  String tripDetailsTitle(String service) {
    return '$service-ritbesonderhede';
  }

  @override
  String get driverNameLabel => 'Bestuurder se Naam *';

  @override
  String get driverNameHint => 'Soos in die program gewys';

  @override
  String get vehicleRegLabel => 'Voertuigregistrasie *';

  @override
  String get vehicleRegHint => 'bv. CA 123-456';

  @override
  String get vehicleColorLabel => 'Voertuigkleur';

  @override
  String get vehicleColorHint => 'bv. Wit';

  @override
  String get vehicleModelLabel => 'Voertuigmerk en -model';

  @override
  String get vehicleModelHint => 'bv. Toyota Corolla';

  @override
  String get pickupLocationLabel => 'Oplaaipunt';

  @override
  String get pickupLocationHint => 'Waar jy ingeklim het';

  @override
  String get destinationLabel => 'Bestemming';

  @override
  String get destinationHint => 'Waarheen jy op pad is';

  @override
  String get verificationPinLabel => 'Bestuurder se Verifikasie-PIN';

  @override
  String get verificationPinHint => 'Vra die bestuurder vir hul passasiers-PIN';

  @override
  String get pinWarning =>
      'Baie betroubare programme gee bestuurders \'n PIN vir hul aangetekende passasier. As die bestuurder nie een kan gee nie, of dit stem nie ooreen met wat jy gesê is nie, beskou dit as \'n waarskuwingsteken voordat jy inklim.';

  @override
  String get tripSharedInfo =>
      'Sodra dit gedeel is, word jou rit regstreeks gestuur na jou Beskermde noodkontakte.';

  @override
  String get sharingEllipsis => 'Deel tans...';

  @override
  String get shareTripButton => 'Deel Rit Met Noodkontakte';

  @override
  String get tripSharedSuccess => 'Rit Suksesvol Gedeel';

  @override
  String startedAt(String time) {
    return 'Begin om $time';
  }

  @override
  String get sentTo => 'Gestuur na';

  @override
  String get endingEllipsis => 'Beëindig tans...';

  @override
  String get endTrip => 'Beëindig Rit';

  @override
  String get rowDriver => 'Bestuurder';

  @override
  String get rowRegistration => 'Registrasie';

  @override
  String get rowVehicle => 'Voertuig';

  @override
  String get rowPickup => 'Oplaai';

  @override
  String get rowDestination => 'Bestemming';

  @override
  String get rowPinConfirmed => 'PIN Bevestig';

  @override
  String get rowNotes => 'Notas';

  @override
  String get noProtectedContacts =>
      'Nog geen Beskermde kontakte nie — voeg kontakte by en nooi hulle om die program te installeer.';

  @override
  String get createCommunityTitle => 'Skep \'n Gemeenskap';

  @override
  String get communityNameLabel => 'Gemeenskapnaam';

  @override
  String get communityAreaLabel => 'Area wat dit dek';

  @override
  String get createAndJoin => 'Skep en Sluit aan';

  @override
  String get inDanger => 'In Gevaar?';

  @override
  String get alertsAdminInstantly =>
      'Waarsku dadelik \'n admin met jou ligging';

  @override
  String get driverCommunity => 'Bestuurdergemeenskap';

  @override
  String get joinCommunityPrompt =>
      'Sluit aan by \'n gemeenskap sodat hulp jou vinnig kan bereik, of begin jou eie';

  @override
  String get noCommunitiesYet =>
      'Nog geen gemeenskappe nie — wees die eerste om een te skep.';

  @override
  String membersCount(String area, int count) {
    return '$area · $count lede';
  }

  @override
  String get createNewCommunity => 'Skep Nuwe Gemeenskap';

  @override
  String get communityUpdatesInfo =>
      'Intydse opdaterings van bestuurders in jou gemeenskap';

  @override
  String get shareUpdateHint => 'Deel \'n opdatering met jou gemeenskap...';

  @override
  String get noPostsYet => 'Nog geen plasings in hierdie gemeenskap nie.';

  @override
  String get logThisPassenger => 'Teken Hierdie Passasier Aan';

  @override
  String get logPassengerSubtitle =>
      'Vang die volle rit sodat julle albei beskerm is as iets skeef loop';

  @override
  String get passengerNameLabel => 'Passasier se Naam *';

  @override
  String get passengerNameHint => 'Soos hulle hulself voorgestel het';

  @override
  String get passengerPhoneLabel => 'Passasier se Telefoonnommer';

  @override
  String get passengerPhoneHint => 'Opsioneel, vir jou rekords';

  @override
  String get pickupPointLabel => 'Oplaaipunt';

  @override
  String get pickupPointHint => 'Waar jy hulle opgelaai het';

  @override
  String get dropoffHint => 'Waar jy hulle aflaai';

  @override
  String get passengersInVehicle => 'Passasiers in voertuig';

  @override
  String get notesOptionalLabel => 'Notas (opsioneel)';

  @override
  String get notesHint =>
      'bv. gereelde kliënt, op pad hospitaal toe, het angstig gelyk';

  @override
  String get photoCaptured => 'Foto geneem — tik om weer te neem';

  @override
  String get addPassengerPhoto =>
      'Voeg \'n vinnige passasierfoto by (opsioneel)';

  @override
  String get pinGeneratedInfo =>
      '\'n Eenmalige verifikasie-PIN sal gegenereer word sodat die passasier kan bevestig dat hulle in die regte voertuig klim.';

  @override
  String get loggingEllipsis => 'Teken tans aan...';

  @override
  String get logPassengerButton => 'Teken Passasier Aan en Genereer PIN';

  @override
  String get passengerLogged => 'Passasier Aangeteken';

  @override
  String get verificationPinCaps => 'VERIFIKASIE-PIN';

  @override
  String get tellPassengerPin =>
      'Sê vir die passasier hierdie PIN voordat hulle inklim';

  @override
  String passengersCountLabel(int count) {
    return 'Passasiers: $count';
  }

  @override
  String get attachedToRecord =>
      'Hierdie passasier is aan jou rekeningrekord geheg';

  @override
  String get autoSafetyCheckIn => 'Outomatiese Veiligheidsinsek';

  @override
  String get autoCheckInSub =>
      'Saam met hierdie rit aangeteken vir admin-sigbaarheid';

  @override
  String get markDroppedOff => 'Merk Passasier Veilig Afgelaai';

  @override
  String get savingEllipsis => 'Stoor tans...';

  @override
  String get justNow => 'nou net';

  @override
  String minutesAgo(int n) {
    return '${n}m gelede';
  }

  @override
  String hoursAgo(int n) {
    return '${n}u gelede';
  }

  @override
  String daysAgo(int n) {
    return '${n}d gelede';
  }
}
