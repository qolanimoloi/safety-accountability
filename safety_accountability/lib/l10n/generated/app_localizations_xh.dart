// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Xhosa (`xh`).
class AppLocalizationsXh extends AppLocalizations {
  AppLocalizationsXh([String locale = 'xh']) : super(locale);

  @override
  String get emergencyResponseTitle => 'Impendulo Yongxamiseko';

  @override
  String get emergencyResponseSubtitle =>
      'Khetha uhlobo longxamiseko oluthile olujongene nalo';

  @override
  String get incidentBreakIn => 'Ukungena Ngenkani Endlini';

  @override
  String get incidentBeingFollowed => 'Ukulandelwa';

  @override
  String get incidentHijacking => 'Ukuthathwa Ngenkani Imoto';

  @override
  String get incidentDomesticViolence => 'Ubundlobongela Basekhaya';

  @override
  String get incidentMedicalEmergency => 'Ongxamiseko Lwezonyango';

  @override
  String get incidentFire => 'Umlilo';

  @override
  String get incidentAssault => 'Ukuhlaselwa';

  @override
  String get incidentOther => 'Okunye';

  @override
  String get sendingAlert => 'Kuthunyelwa isilumkiso sakho...';

  @override
  String get tryAgain => 'Zama Kwakhona';

  @override
  String get adminResponded => 'Umlawuli uphendule kwisilumkiso sakho.';

  @override
  String referenceLabel(String ref) {
    return 'Isalathiso: $ref';
  }

  @override
  String get noResponseWindow =>
      'Akukho mpendulo ifunyenwe ngexesha lemizuzu emi-5.';

  @override
  String get downloadPonr => 'Khuphela i-PONR (Ubungqina Bokungaphenduli)';

  @override
  String waitingForResponse(String time) {
    return 'Kulindwe impendulo... $time';
  }

  @override
  String get emergencyDispatchMessage =>
      'Uncedo luyathunyelwa kwindawo yakho. Hlala uzolile uze ulandele imigaqo yokhuseleko.';

  @override
  String emergencyTitle(String type) {
    return 'Ongxamiseko: $type';
  }

  @override
  String contactNeedsHelp(String name) {
    return '$name ufuna uncedo';
  }

  @override
  String get callAction => 'Fowunela';

  @override
  String get locationAction => 'Indawo';

  @override
  String get emergencyContactsTitle => 'Abaqhagamshelwana Nabo Ngongxamiseko';

  @override
  String get emergencyContactsSubtitle => 'Abantu abaziswayo xa ufuna uncedo';

  @override
  String get protectedLabel => 'Ukhuselekile';

  @override
  String get pendingLabel => 'Kulindwe';

  @override
  String get addFromContacts => 'Yongeza Kwiiqhagamshelwano';

  @override
  String get contactsWhyBanner =>
      'Umntu oqhagamshelwana naye angafumana izilumkiso zakho zokwenene kuphela xa sele efake i-Safety & Accountability. Mthumele isimemo ukuze aguquke esuka ekulindweni aye ekukhuselekeni.';

  @override
  String get yourCircle => 'Umjikelo Wakho';

  @override
  String get noContactsYet => 'Akukabikho baqhagamshelwana nabo ngongxamiseko';

  @override
  String get addSomeoneYouTrust =>
      'Yongeza umntu omthembayo kwiqhagamshelwano lefowuni yakho';

  @override
  String get couldNotLoadContacts =>
      'Ayikwazanga ukulayisha abaqhagamshelwana.';

  @override
  String get invitePending => 'Isimemo Silindile';

  @override
  String get sendInvite => 'Thumela Isimemo';

  @override
  String get relationshipParent => 'Umzali';

  @override
  String get relationshipSibling => 'Umntakwabo/Udade wabo';

  @override
  String get relationshipPartner => 'Iqabane';

  @override
  String get relationshipFriend => 'Umhlobo';

  @override
  String get relationshipRoommate => 'Ohlala Naye Egumbini';

  @override
  String get relationshipColleague => 'Osebenza Naye';

  @override
  String get relationshipOther => 'Okunye';

  @override
  String addPersonTitle(String name) {
    return 'Yongeza u-$name';
  }

  @override
  String get howDoYouKnowThisPerson => 'Umazi njani lo mntu?';

  @override
  String get cancel => 'Rhoxisa';

  @override
  String get add => 'Yongeza';

  @override
  String get chooseAContact => 'Khetha Umntu Oqhagamshelwana Naye';

  @override
  String get searchContacts => 'Khangela abaqhagamshelwana...';

  @override
  String get noContactsFound => 'Akukho baqhagamshelwana bafunyenwe';

  @override
  String get retry => 'Zama kwakhona';

  @override
  String get close => 'Vala';

  @override
  String get join => 'Joyina';

  @override
  String get leave => 'Phuma';

  @override
  String get authWelcomeBack =>
      'Wamkelekile kwakhona — ngena ukuze uhlale ukhuselekile';

  @override
  String get authCreatePrompt => 'Yenza iakhawunti ukuze uqalise';

  @override
  String get logIn => 'Ngena';

  @override
  String get signUp => 'Bhalisa';

  @override
  String get fullName => 'Igama Elipheleleyo';

  @override
  String get emailAddress => 'Idilesi ye-imeyile';

  @override
  String get phoneNumber => 'Inombolo Yefowuni';

  @override
  String get phoneHint => 'umz. +27 71 234 5678';

  @override
  String get password => 'Iphasiwedi';

  @override
  String get confirmPassword => 'Qinisekisa Iphasiwedi';

  @override
  String get forgotPassword => 'Ulibele Iphasiwedi?';

  @override
  String get forgotPasswordSoon =>
      'Ukuseta ngokutsha iphasiwedi kuyeza kungekudala.';

  @override
  String get agreeToTerms =>
      'Ndiyavuma Imiqathango yeNkonzo noMgaqo-nkqubo wobuMfihlo';

  @override
  String get createAccount => 'Yenza iAkhawunti';

  @override
  String get orDivider => 'OKANYE';

  @override
  String get continueWithGoogle => 'Qhubeka ne-Google';

  @override
  String get signUpWithGoogle => 'Bhalisa nge-Google';

  @override
  String get noAccountPrompt => 'Awunayo iakhawunti?';

  @override
  String get haveAccountPrompt => 'Sele unayo iakhawunti?';

  @override
  String get acceptTermsSnack =>
      'Nceda wamkele Imiqathango noMgaqo-nkqubo wobuMfihlo ukuze uqhubeke.';

  @override
  String get serverUnreachable =>
      'Ayikwazanga ukufikelela kwiseva. Jonga unxibelelwano lwakho uphinde uzame.';

  @override
  String get googleSoon => 'Ukungena nge-Google kuyeza kungekudala.';

  @override
  String get fullNameRequired => 'Igama elipheleleyo liyafuneka';

  @override
  String get emailRequired => 'I-imeyile iyafuneka';

  @override
  String get emailInvalid => 'Faka idilesi ye-imeyile esebenzayo';

  @override
  String get phoneRequired => 'Inombolo yefowuni iyafuneka';

  @override
  String get phoneInvalid => 'Faka inombolo yefowuni esebenzayo';

  @override
  String get passwordRequired => 'Iphasiwedi iyafuneka';

  @override
  String get passwordTooShort => 'Sebenzisa ubuncinane oonobumba abangama-8';

  @override
  String get confirmPasswordRequired => 'Qinisekisa iphasiwedi yakho';

  @override
  String get passwordsDontMatch => 'Amaphasiwedi ayahlukana';

  @override
  String get locationServicesOff =>
      'Iinkonzo zendawo zivaliwe — kubonisa indawo engagqibekanga endaweni yoko.';

  @override
  String get locationPermissionDenied =>
      'Imvume yendawo ayinikwanga — kubonisa indawo engagqibekanga endaweni yoko.';

  @override
  String get locationFailed =>
      'Asikwazanga ukufumana indawo yakho yangoku — kubonisa indawo engagqibekanga endaweni yoko.';

  @override
  String get gettingLocation => 'Sifumana indawo yakho...';

  @override
  String get defaultArea => 'Indawo engagqibekanga';

  @override
  String get youAreHere => 'Ulapha';

  @override
  String get somethingWentWrong => 'Kukho into engahambanga kakuhle.';

  @override
  String get panicAlertActive => 'ISILUMKISO SOKOYIKA SISEBENZA';

  @override
  String get noResponseYet =>
      'Akukabikho mpendulo — hlala ulumkile ufune uncedo ukuba unako.';

  @override
  String get liveLocationShared => 'Indawo ephilayo yabelwene';

  @override
  String get adminNotified => 'Ulawulo luziviwe';

  @override
  String get imSafeCancel => 'Ndikhuselekile — Rhoxisa Isilumkiso';

  @override
  String contextTripAttached(String service) {
    return 'Iinkcukacha ze-$service zincanyathisiwe';
  }

  @override
  String get contextNoTrip => 'Akukho hambo lusebenzayo luncanyathisiweyo';

  @override
  String contextCommunityNotified(String community) {
    return '$community yaziswe';
  }

  @override
  String get contextPassengerAttached => 'Umkhweli wangoku uncanyathisiwe';

  @override
  String get contextNoCommunity => 'Awukajoyinanga luluntu';

  @override
  String get passengerMode => 'Imowudi Yomkhweli';

  @override
  String get driverMode => 'Imowudi Yomqhubi';

  @override
  String get switchLabel => 'Tshintsha';

  @override
  String get ehailingSafetyTitle => 'Ukhuseleko lwe-E-Hailing';

  @override
  String get ehailingRoleSubtitle =>
      'Phambi kokuba siqalise, sixelele ukuba ukweyiphi inxalenye yohambo';

  @override
  String get imAPassenger => 'Ndingumkhweli';

  @override
  String get passengerDesc =>
      'Wabelane ngohambo lwakho neenkcukacha zomqhubi nabafowunelwa bakho ngexesha lengxakeko ngokuzenzekelayo.';

  @override
  String get imADriver => 'Ndingumqhubi';

  @override
  String get driverDesc =>
      'Joyina uluntu lwabaqhubi, rekhoda iinkcukacha zabakhweli, uze uvuselele isilumkiso sokoyika ukuba udinga uncedo.';

  @override
  String get triggerPanicTitle => 'Vuselela Isilumkiso Sokoyika?';

  @override
  String get panicConfirmWithTrip =>
      'Oku kuya kuwazisa ulawulo ngoko nangoko ngendawo yakho ephilayo neenkcukacha zalo hambo.';

  @override
  String get panicConfirmNoTrip =>
      'Oku kuya kuwazisa ulawulo ngoko nangoko ngendawo yakho ephilayo.';

  @override
  String get triggerAlert => 'Vuselela Isilumkiso';

  @override
  String get pickRideApp =>
      'Khetha i-app yakho yohambo. Iinkcukacha zohambo lwakho ziya kwabelwana nabafowunelwa bakho abakhuselekileyo.';

  @override
  String get chooseYourRide => 'Khetha Uhambo Lwakho';

  @override
  String tripDetailsTitle(String service) {
    return 'Iinkcukacha Zohambo Lwe-$service';
  }

  @override
  String get driverNameLabel => 'Igama Lomqhubi *';

  @override
  String get driverNameHint => 'Njengoko kuboniswe kwi-app';

  @override
  String get vehicleRegLabel => 'Ubhaliso Lwemoto *';

  @override
  String get vehicleRegHint => 'umz. CA 123-456';

  @override
  String get vehicleColorLabel => 'Umbala Wemoto';

  @override
  String get vehicleColorHint => 'umz. Mhlophe';

  @override
  String get vehicleModelLabel => 'Uhlobo Nemodeli Yemoto';

  @override
  String get vehicleModelHint => 'umz. Toyota Corolla';

  @override
  String get pickupLocationLabel => 'Indawo Yokuthatha';

  @override
  String get pickupLocationHint => 'Apho ungene khona';

  @override
  String get destinationLabel => 'Apho Uya Khona';

  @override
  String get destinationHint => 'Apho uya khona';

  @override
  String get verificationPinLabel => 'I-PIN Yokuqinisekisa Yomqhubi';

  @override
  String get verificationPinHint => 'Cela umqhubi i-PIN yabakhweli';

  @override
  String get pinWarning =>
      'Ii-app ezininzi ezithembekileyo zinika abaqhubi i-PIN yomkhweli abamrekhodileyo. Ukuba umqhubi akakwazi ukukunika enye, okanye ayihambelani nalokho ubuxelelwe kona, kubone oko njengophawu lwesilumkiso ngaphambi kokuba ungene.';

  @override
  String get tripSharedInfo =>
      'Xa kwabelwene, uhambo lwakho luthunyelwa ngqo kubafowunelwa bakho Abakhuselekileyo.';

  @override
  String get sharingEllipsis => 'Iyabelana...';

  @override
  String get shareTripButton => 'Wabelane Ngohambo Nabafowunelwa Bakho';

  @override
  String get tripSharedSuccess => 'Uhambo Lwabelwene Ngempumelelo';

  @override
  String startedAt(String time) {
    return 'Kuqale nge-$time';
  }

  @override
  String get sentTo => 'Kuthunyelwe kwi';

  @override
  String get endingEllipsis => 'Iyaphela...';

  @override
  String get endTrip => 'Phelisa Uhambo';

  @override
  String get rowDriver => 'Umqhubi';

  @override
  String get rowRegistration => 'Ubhaliso';

  @override
  String get rowVehicle => 'Imoto';

  @override
  String get rowPickup => 'Ukuthatha';

  @override
  String get rowDestination => 'Apho Uya Khona';

  @override
  String get rowPinConfirmed => 'I-PIN Iqinisekisiwe';

  @override
  String get rowNotes => 'Amanqaku';

  @override
  String get noProtectedContacts =>
      'Akukho bafowunelwa Abakhuselekileyo — yongeza abafowunelwa uze ubamemele ukuba bafake i-app.';

  @override
  String get createCommunityTitle => 'Yenza Uluntu';

  @override
  String get communityNameLabel => 'Igama loluntu';

  @override
  String get communityAreaLabel => 'Indawo ebhekiswe kuyo';

  @override
  String get createAndJoin => 'Yenza Uze Ujoyine';

  @override
  String get inDanger => 'Usengozini?';

  @override
  String get alertsAdminInstantly =>
      'Kuyawazisa ulawulo ngoko nangoko ngendawo yakho';

  @override
  String get driverCommunity => 'Uluntu Lwabaqhubi';

  @override
  String get joinCommunityPrompt =>
      'Joyina uluntu ukuze uncedo lukufikelele ngokukhawuleza, okanye uqalise olwakho';

  @override
  String get noCommunitiesYet =>
      'Akukho luntu okwangoku — yiba ngowokuqala ukuyenza.';

  @override
  String membersCount(String area, int count) {
    return '$area · amalungu angama-$count';
  }

  @override
  String get createNewCommunity => 'Yenza Uluntu Olutsha';

  @override
  String get communityUpdatesInfo =>
      'Uhlaziyo lwexesha lokwenyani oluvela kubaqhubi koluntu lwakho';

  @override
  String get shareUpdateHint => 'Wabelane ngohlaziyo noluntu lwakho...';

  @override
  String get noPostsYet => 'Akukho zithuba kolu luntu okwangoku.';

  @override
  String get logThisPassenger => 'Rekhoda Lo Mkhweli';

  @override
  String get logPassengerSubtitle =>
      'Rekhoda lonke uhambo ukuze nobabini nikhuselwe ukuba kukho into engahambi kakuhle';

  @override
  String get passengerNameLabel => 'Igama Lomkhweli *';

  @override
  String get passengerNameHint => 'Njengoko bezazisile';

  @override
  String get passengerPhoneLabel => 'Inombolo Yefowuni Yomkhweli';

  @override
  String get passengerPhoneHint => 'Ngokuzikhethela, kwiirekhodi zakho';

  @override
  String get pickupPointLabel => 'Indawo Yokuthatha';

  @override
  String get pickupPointHint => 'Apho ubathathe khona';

  @override
  String get dropoffHint => 'Apho uza kubashiya khona';

  @override
  String get passengersInVehicle => 'Abakhweli emotweni';

  @override
  String get notesOptionalLabel => 'Amanqaku (ngokuzikhethela)';

  @override
  String get notesHint =>
      'umz. ikhasimende eliqhelekileyo, uya esibhedlele, ebonakala exhalabile';

  @override
  String get photoCaptured =>
      'Umfanekiso uthathiwe — cofa ukuze uphinde uthathe';

  @override
  String get addPassengerPhoto =>
      'Yongeza umfanekiso womkhweli osebenzayo (ngokuzikhethela)';

  @override
  String get pinGeneratedInfo =>
      'Kuya kuveliswa i-PIN yokuqinisekisa isetyenziswa kanye ukuze umkhweli aqinisekise ukuba ungena kwimoto echanekileyo.';

  @override
  String get loggingEllipsis => 'Iyarekhoda...';

  @override
  String get logPassengerButton => 'Rekhoda Umkhweli Uze Uvelise I-PIN';

  @override
  String get passengerLogged => 'Umkhweli Urekhodiwe';

  @override
  String get verificationPinCaps => 'I-PIN YOKUQINISEKISA';

  @override
  String get tellPassengerPin => 'Xelela umkhweli le-PIN phambi kokuba angene';

  @override
  String passengersCountLabel(int count) {
    return 'Abakhweli: $count';
  }

  @override
  String get attachedToRecord =>
      'Lo mkhweli uncanyathiselwe kwirekhodi yeakhawunti yakho';

  @override
  String get autoSafetyCheckIn => 'Ukhangelo Lokhuseleko Oluzenzekelayo';

  @override
  String get autoCheckInSub => 'Kurekhodwe nalo hambo ukuze ulawulo lukubone';

  @override
  String get markDroppedOff => 'Phawula Ukuba Umkhweli Ushiywe Ekhuselekile';

  @override
  String get savingEllipsis => 'Iyagcina...';

  @override
  String get justNow => 'ngoku nje';

  @override
  String minutesAgo(int n) {
    return '${n}m eyadlulayo';
  }

  @override
  String hoursAgo(int n) {
    return '${n}h eyadlulayo';
  }

  @override
  String daysAgo(int n) {
    return '${n}d eyadlulayo';
  }
}
