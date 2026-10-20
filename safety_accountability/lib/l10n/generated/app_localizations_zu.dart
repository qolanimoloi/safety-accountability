// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Zulu (`zu`).
class AppLocalizationsZu extends AppLocalizations {
  AppLocalizationsZu([String locale = 'zu']) : super(locale);

  @override
  String get emergencyResponseTitle => 'Impendulo Yesimo Esiphuthumayo';

  @override
  String get emergencyResponseSubtitle =>
      'Khetha uhlobo lwesimo esiphuthumayo osibhekene naso';

  @override
  String get incidentBreakIn => 'Ukufohlelwa Endlini';

  @override
  String get incidentBeingFollowed => 'Ukulandelwa';

  @override
  String get incidentHijacking => 'Ukuhlwithwa Imoto';

  @override
  String get incidentDomesticViolence => 'Udlame Lwasekhaya';

  @override
  String get incidentMedicalEmergency => 'Isimo Esiphuthumayo Sezempilo';

  @override
  String get incidentFire => 'Umlilo';

  @override
  String get incidentAssault => 'Ukuhlukunyezwa';

  @override
  String get incidentOther => 'Okunye';

  @override
  String get sendingAlert => 'Kuthunyelwa isixwayiso sakho...';

  @override
  String get tryAgain => 'Zama Futhi';

  @override
  String get adminResponded => 'Umphathi uphendule isixwayiso sakho.';

  @override
  String referenceLabel(String ref) {
    return 'Inkomba: $ref';
  }

  @override
  String get noResponseWindow =>
      'Akukho mpendulo etholakele ngesikhathi semizuzu emi-5.';

  @override
  String get downloadPonr => 'Landa i-PONR (Ubufakazi Bokungaphenduli)';

  @override
  String waitingForResponse(String time) {
    return 'Kulindelwe impendulo... $time';
  }

  @override
  String get emergencyDispatchMessage =>
      'Usizo luyathunyelwa endaweni yakho. Hlala uzolile futhi ulandele imigomo yokuphepha.';

  @override
  String emergencyTitle(String type) {
    return 'Isimo Esiphuthumayo: $type';
  }

  @override
  String contactNeedsHelp(String name) {
    return '$name udinga usizo';
  }

  @override
  String get callAction => 'Shayela';

  @override
  String get locationAction => 'Indawo';

  @override
  String get emergencyContactsTitle => 'Oxhumana Nabo Ezimweni Eziphuthumayo';

  @override
  String get emergencyContactsSubtitle => 'Abantu abaziswayo uma udinga usizo';

  @override
  String get protectedLabel => 'Uvikelekile';

  @override
  String get pendingLabel => 'Kulindiwe';

  @override
  String get addFromContacts => 'Engeza Kusuka Kubaxhumani';

  @override
  String get contactsWhyBanner =>
      'Umuntu oxhumana naye angathola izexwayiso zakho zangempela kuphela uma esefake i-Safety & Accountability. Mthumele isimemo ukuze aguqule isimo kusuka Kulindiwe aye Kuvikelekile.';

  @override
  String get yourCircle => 'Isiyingi Sakho';

  @override
  String get noContactsYet =>
      'Abekho oxhumana nabo ezimweni eziphuthumayo okwamanje';

  @override
  String get addSomeoneYouTrust =>
      'Engeza umuntu omethembayo kubaxhumani bakho befoni';

  @override
  String get couldNotLoadContacts => 'Ayikwazanga ukulayisha abaxhumani.';

  @override
  String get invitePending => 'Isimemo Silindile';

  @override
  String get sendInvite => 'Thumela Isimemo';

  @override
  String get relationshipParent => 'Umzali';

  @override
  String get relationshipSibling => 'Umfowabo/Udadewabo';

  @override
  String get relationshipPartner => 'Umlingani';

  @override
  String get relationshipFriend => 'Umngane';

  @override
  String get relationshipRoommate => 'Ohlala Naye Ekamelweni';

  @override
  String get relationshipColleague => 'Ozosebenza Naye';

  @override
  String get relationshipOther => 'Okunye';

  @override
  String addPersonTitle(String name) {
    return 'Engeza u-$name';
  }

  @override
  String get howDoYouKnowThisPerson => 'Umazi kanjani lo muntu?';

  @override
  String get cancel => 'Khansela';

  @override
  String get add => 'Engeza';

  @override
  String get chooseAContact => 'Khetha Umuntu Oxhumana Naye';

  @override
  String get searchContacts => 'Sesha abaxhumani...';

  @override
  String get noContactsFound => 'Abekho abaxhumani abatholakele';

  @override
  String get retry => 'Zama futhi';

  @override
  String get close => 'Vala';

  @override
  String get join => 'Joyina';

  @override
  String get leave => 'Phuma';

  @override
  String get authWelcomeBack =>
      'Siyakwamukela futhi — ngena ukuze uqhubeke uvikelekile';

  @override
  String get authCreatePrompt => 'Dala i-akhawunti ukuze uqale';

  @override
  String get logIn => 'Ngena';

  @override
  String get signUp => 'Bhalisa';

  @override
  String get fullName => 'Igama Eliphelele';

  @override
  String get emailAddress => 'Ikheli le-imeyili';

  @override
  String get phoneNumber => 'Inombolo Yocingo';

  @override
  String get phoneHint => 'isb. +27 71 234 5678';

  @override
  String get password => 'Iphasiwedi';

  @override
  String get confirmPassword => 'Qinisekisa Iphasiwedi';

  @override
  String get forgotPassword => 'Ukhohlwe Iphasiwedi?';

  @override
  String get forgotPasswordSoon =>
      'Ukusetha kabusha iphasiwedi kuzofika maduze.';

  @override
  String get agreeToTerms =>
      'Ngiyavuma Imigomo Yesevisi Nenqubomgomo Yobumfihlo';

  @override
  String get createAccount => 'Dala I-akhawunti';

  @override
  String get orDivider => 'NOMA';

  @override
  String get continueWithGoogle => 'Qhubeka ne-Google';

  @override
  String get signUpWithGoogle => 'Bhalisa nge-Google';

  @override
  String get noAccountPrompt => 'Awunayo i-akhawunti?';

  @override
  String get haveAccountPrompt => 'Usunayo i-akhawunti?';

  @override
  String get acceptTermsSnack =>
      'Sicela wamukele Imigomo Nenqubomgomo Yobumfihlo ukuze uqhubeke.';

  @override
  String get serverUnreachable =>
      'Ayikwazanga ukufinyelela iseva. Hlola uxhumano lwakho bese uyazama futhi.';

  @override
  String get googleSoon => 'Ukungena nge-Google kuzofika maduze.';

  @override
  String get fullNameRequired => 'Igama eliphelele liyadingeka';

  @override
  String get emailRequired => 'I-imeyili iyadingeka';

  @override
  String get emailInvalid => 'Faka ikheli le-imeyili elivumelekile';

  @override
  String get phoneRequired => 'Inombolo yocingo iyadingeka';

  @override
  String get phoneInvalid => 'Faka inombolo yocingo evumelekile';

  @override
  String get passwordRequired => 'Iphasiwedi iyadingeka';

  @override
  String get passwordTooShort => 'Sebenzisa okungenani izinhlamvu eziyi-8';

  @override
  String get confirmPasswordRequired => 'Qinisekisa iphasiwedi yakho';

  @override
  String get passwordsDontMatch => 'Amaphasiwedi ahlukile';

  @override
  String get locationServicesOff =>
      'Amasevisi endawo avaliwe — kuboniswa indawo ejwayelekile esikhundleni.';

  @override
  String get locationPermissionDenied =>
      'Imvume yendawo ayinikeziwe — kuboniswa indawo ejwayelekile esikhundleni.';

  @override
  String get locationFailed =>
      'Asikwazanga ukuthola indawo yakho yamanje — kuboniswa indawo ejwayelekile esikhundleni.';

  @override
  String get gettingLocation => 'Sithola indawo yakho...';

  @override
  String get defaultArea => 'Indawo ejwayelekile';

  @override
  String get youAreHere => 'Ukhona lapha';

  @override
  String get somethingWentWrong => 'Kukhona okungahambanga kahle.';

  @override
  String get panicAlertActive => 'ISIXWAYISO SOKWETHUKA SISEBENZA';

  @override
  String get noResponseYet =>
      'Akukabikho mpendulo — hlala uqaphile ufune usizo uma ukwazi.';

  @override
  String get liveLocationShared => 'Indawo ephilayo yabiwe';

  @override
  String get adminNotified => 'Umlawuli wazisiwe';

  @override
  String get imSafeCancel => 'Ngiphephile — Khansela Isixwayiso';

  @override
  String contextTripAttached(String service) {
    return 'Imininingwane ye-$service inamathiselwe';
  }

  @override
  String get contextNoTrip => 'Alukho uhambo olusebenzayo olunamathiselwe';

  @override
  String contextCommunityNotified(String community) {
    return '$community yazisiwe';
  }

  @override
  String get contextPassengerAttached => 'Umgibeli wamanje unamathiselwe';

  @override
  String get contextNoCommunity => 'Awukajoyinanga nomphakathi';

  @override
  String get passengerMode => 'Imodi Yomgibeli';

  @override
  String get driverMode => 'Imodi Yomshayeli';

  @override
  String get switchLabel => 'Shintsha';

  @override
  String get ehailingSafetyTitle => 'Ukuphepha Kwe-E-Hailing';

  @override
  String get ehailingRoleSubtitle =>
      'Ngaphambi kokuthi siqale, sitshele ukuthi ukuliphi uhlangothi lohambo';

  @override
  String get imAPassenger => 'Ngingumgibeli';

  @override
  String get passengerDesc =>
      'Yabelana ngohambo lwakho nemininingwane yomshayeli nabaxhumana nabo ezimweni eziphuthumayo ngokuzenzakalelayo.';

  @override
  String get imADriver => 'Ngingumshayeli';

  @override
  String get driverDesc =>
      'Joyina umphakathi wabashayeli, qopha imininingwane yabagibeli, bese ubambisa isixwayiso sokwethuka uma udinga usizo.';

  @override
  String get triggerPanicTitle => 'Ubambisa Isixwayiso Sokwethuka?';

  @override
  String get panicConfirmWithTrip =>
      'Lokhu kuzazisa umlawuli ngokushesha ngendawo yakho ephilayo nemininingwane yalolu hambo.';

  @override
  String get panicConfirmNoTrip =>
      'Lokhu kuzazisa umlawuli ngokushesha ngendawo yakho ephilayo.';

  @override
  String get triggerAlert => 'Bambisa Isixwayiso';

  @override
  String get pickRideApp =>
      'Khetha uhlelo lwakho lokugibela. Imininingwane yohambo lwakho izabelwana nabaxhumana nabo abavikelekile.';

  @override
  String get chooseYourRide => 'Khetha Ukugibela Kwakho';

  @override
  String tripDetailsTitle(String service) {
    return 'Imininingwane Yohambo Ye-$service';
  }

  @override
  String get driverNameLabel => 'Igama Lomshayeli *';

  @override
  String get driverNameHint => 'Njengoba kuboniswa ku-app';

  @override
  String get vehicleRegLabel => 'Ukubhaliswa Kwemoto *';

  @override
  String get vehicleRegHint => 'isb. CA 123-456';

  @override
  String get vehicleColorLabel => 'Umbala Wemoto';

  @override
  String get vehicleColorHint => 'isb. Mhlophe';

  @override
  String get vehicleModelLabel => 'Uhlobo Nemodeli Yemoto';

  @override
  String get vehicleModelHint => 'isb. Toyota Corolla';

  @override
  String get pickupLocationLabel => 'Indawo Yokuthatha';

  @override
  String get pickupLocationHint => 'Lapho ungene khona';

  @override
  String get destinationLabel => 'Indawo Oya Kuyo';

  @override
  String get destinationHint => 'Lapho uya khona';

  @override
  String get verificationPinLabel => 'I-PIN Yokuqinisekisa Yomshayeli';

  @override
  String get verificationPinHint => 'Cela umshayeli i-PIN yabagibeli';

  @override
  String get pinWarning =>
      'Izinhlelo eziningi ezethembekile zinika abashayeli i-PIN yomgibeli abamqopheyo. Uma umshayeli engakwazi ukukunika eyodwa, noma ingahambisani nalokho okutshelwe kona, thatha lokho njengophawu lokuxwayisa ngaphambi kokuba ungene.';

  @override
  String get tripSharedInfo =>
      'Uma kwabelwanisiwe, uhambo lwakho luthunyelwa ngqo kubaxhumana nabo Abavikelekile.';

  @override
  String get sharingEllipsis => 'Iyabelana...';

  @override
  String get shareTripButton =>
      'Yabelana Ngohambo Nabaxhumana Nabo Ezimweni Eziphuthumayo';

  @override
  String get tripSharedSuccess => 'Uhambo Lubelwane Ngempumelelo';

  @override
  String startedAt(String time) {
    return 'Kuqale ngo-$time';
  }

  @override
  String get sentTo => 'Kuthunyelwe ku';

  @override
  String get endingEllipsis => 'Iyaphela...';

  @override
  String get endTrip => 'Qeda Uhambo';

  @override
  String get rowDriver => 'Umshayeli';

  @override
  String get rowRegistration => 'Ukubhaliswa';

  @override
  String get rowVehicle => 'Imoto';

  @override
  String get rowPickup => 'Ukuthatha';

  @override
  String get rowDestination => 'Indawo Oya Kuyo';

  @override
  String get rowPinConfirmed => 'I-PIN Iqinisekisiwe';

  @override
  String get rowNotes => 'Amanothi';

  @override
  String get noProtectedContacts =>
      'Abukho abaxhumana nabo Abavikelekile — engeza abaxhumana nabo ubamemele ukuthi bafake i-app.';

  @override
  String get createCommunityTitle => 'Dala Umphakathi';

  @override
  String get communityNameLabel => 'Igama lomphakathi';

  @override
  String get communityAreaLabel => 'Indawo ekubhekene nayo';

  @override
  String get createAndJoin => 'Dala Futhi Ujoyine';

  @override
  String get inDanger => 'Usengozini?';

  @override
  String get alertsAdminInstantly =>
      'Kwazisa umlawuli ngokushesha ngendawo yakho';

  @override
  String get driverCommunity => 'Umphakathi Wabashayeli';

  @override
  String get joinCommunityPrompt =>
      'Joyina umphakathi ukuze usizo lukufinyelele ngokushesha, noma uqale owakho';

  @override
  String get noCommunitiesYet =>
      'Akukho miphakathi okwamanje — yiba owokuqala ukudala.';

  @override
  String membersCount(String area, int count) {
    return '$area · amalungu angu-$count';
  }

  @override
  String get createNewCommunity => 'Dala Umphakathi Omusha';

  @override
  String get communityUpdatesInfo =>
      'Izibuyekezo zesikhathi sangempela ezivela kubashayeli emphakathini wakho';

  @override
  String get shareUpdateHint => 'Yabelana ngesibuyekezo nomphakathi wakho...';

  @override
  String get noPostsYet => 'Awukho amaposi kulo mphakathi okwamanje.';

  @override
  String get logThisPassenger => 'Qopha Lo Mgibeli';

  @override
  String get logPassengerSubtitle =>
      'Qopha lonke uhambo ukuze nobabili nivikelwe uma kukhona okungahambi kahle';

  @override
  String get passengerNameLabel => 'Igama Lomgibeli *';

  @override
  String get passengerNameHint => 'Njengoba beziethula';

  @override
  String get passengerPhoneLabel => 'Inombolo Yocingo Yomgibeli';

  @override
  String get passengerPhoneHint => 'Ngokuzithandela, ezincwadini zakho';

  @override
  String get pickupPointLabel => 'Indawo Yokuthatha';

  @override
  String get pickupPointHint => 'Lapho ubathathe khona';

  @override
  String get dropoffHint => 'Lapho ubayokubeka khona';

  @override
  String get passengersInVehicle => 'Abagibeli emotweni';

  @override
  String get notesOptionalLabel => 'Amanothi (ngokuzithandela)';

  @override
  String get notesHint =>
      'isb. ikhasimende elivamile, liya esibhedlela, ubonakala ethukile';

  @override
  String get photoCaptured =>
      'Isithombe sithathiwe — thinta ukuze uphinde uthathe';

  @override
  String get addPassengerPhoto =>
      'Engeza isithombe somgibeli esisheshayo (ngokuzithandela)';

  @override
  String get pinGeneratedInfo =>
      'Kuzakhiqizwa i-PIN yokuqinisekisa esetshenziswa kanye ukuze umgibeli aqinisekise ukuthi ungena emotweni efanele.';

  @override
  String get loggingEllipsis => 'Iyaqopha...';

  @override
  String get logPassengerButton => 'Qopha Umgibeli Bese Ukhiqiza I-PIN';

  @override
  String get passengerLogged => 'Umgibeli Uqoshiwe';

  @override
  String get verificationPinCaps => 'I-PIN YOKUQINISEKISA';

  @override
  String get tellPassengerPin =>
      'Tshela umgibeli le-PIN ngaphambi kokuba angene';

  @override
  String passengersCountLabel(int count) {
    return 'Abagibeli: $count';
  }

  @override
  String get attachedToRecord =>
      'Lo mgibeli unamathiselwe kurekhodi ye-akhawunti yakho';

  @override
  String get autoSafetyCheckIn => 'Ukuhlola Ukuphepha Okuzenzakalelayo';

  @override
  String get autoCheckInSub => 'Kuqoshwe nalolu hambo ukuze umlawuli akubone';

  @override
  String get markDroppedOff => 'Maka Ukuthi Umgibeli Ushiywe Aphephile';

  @override
  String get savingEllipsis => 'Iyalondoloza...';

  @override
  String get justNow => 'khona manje';

  @override
  String minutesAgo(int n) {
    return '${n}m edlule';
  }

  @override
  String hoursAgo(int n) {
    return '${n}h edlule';
  }

  @override
  String daysAgo(int n) {
    return '${n}d edlule';
  }
}
