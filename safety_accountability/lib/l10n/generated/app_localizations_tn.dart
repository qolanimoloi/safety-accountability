// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tswana (`tn`).
class AppLocalizationsTn extends AppLocalizations {
  AppLocalizationsTn([String locale = 'tn']) : super(locale);

  @override
  String get emergencyResponseTitle => 'Karabo ya Tshoganetso';

  @override
  String get emergencyResponseSubtitle =>
      'Tlhopha mofuta wa tshoganetso e o lebaneng nayo';

  @override
  String get incidentBreakIn => 'Go Tsenwa mo Ntlong';

  @override
  String get incidentBeingFollowed => 'Go Salwa Morago';

  @override
  String get incidentHijacking => 'Go Hukunngwa Koloi';

  @override
  String get incidentDomesticViolence => 'Tlhekefetso ya mo Lapeng';

  @override
  String get incidentMedicalEmergency => 'Tshoganetso ya Boitekanelo';

  @override
  String get incidentFire => 'Molelo';

  @override
  String get incidentAssault => 'Tlhaselo';

  @override
  String get incidentOther => 'Tse Dingwe';

  @override
  String get sendingAlert => 'Go romelwa temoso ya gago...';

  @override
  String get tryAgain => 'Leka Gape';

  @override
  String get adminResponded => 'Mokaedi o arabile temoso ya gago.';

  @override
  String referenceLabel(String ref) {
    return 'Tshupo: $ref';
  }

  @override
  String get noResponseWindow =>
      'Ga go na karabo e e amogetsweng mo metsotsong e e 5.';

  @override
  String get downloadPonr => 'Lata PONR (Bosupi jwa go sa Arabe)';

  @override
  String waitingForResponse(String time) {
    return 'Go emetswe karabo... $time';
  }

  @override
  String get emergencyDispatchMessage =>
      'Thuso e romelwa kwa lefelong la gago. Nna o ritibetse mme o latele melao ya tshireletso.';

  @override
  String emergencyTitle(String type) {
    return 'Tshoganetso: $type';
  }

  @override
  String contactNeedsHelp(String name) {
    return '$name o tlhoka thuso';
  }

  @override
  String get callAction => 'Founa';

  @override
  String get locationAction => 'Lefelo';

  @override
  String get emergencyContactsTitle => 'Dikgokagano tsa Tshoganetso';

  @override
  String get emergencyContactsSubtitle =>
      'Batho ba ba itsisiwang fa o tlhoka thuso';

  @override
  String get protectedLabel => 'O Sireletsegile';

  @override
  String get pendingLabel => 'E sa ntse e emetswe';

  @override
  String get addFromContacts => 'Tsenya go tswa mo Dikgokaganong';

  @override
  String get contactsWhyBanner =>
      'Mokgokagani a ka amogela fela ditemoso tsa gago tsa nnete fa a setse a tsentse Safety & Accountability. Mo romelele taletso go mo fetola go tswa mo go Emetsweng go ya go Sireleditsweng.';

  @override
  String get yourCircle => 'Setlhopha sa Gago';

  @override
  String get noContactsYet =>
      'Ga go na dikgokagano tsa tshoganetso go fitlha jaanong';

  @override
  String get addSomeoneYouTrust =>
      'Tsenya mongwe yo o mo ikanyang go tswa mo dikgokaganong tsa founo ya gago';

  @override
  String get couldNotLoadContacts => 'Go paletse go lata dikgokagano.';

  @override
  String get invitePending => 'Taletso e Emetswe';

  @override
  String get sendInvite => 'Romela Taletso';

  @override
  String get relationshipParent => 'Motsadi';

  @override
  String get relationshipSibling => 'Monnao/Kgaitsadio';

  @override
  String get relationshipPartner => 'Molekane';

  @override
  String get relationshipFriend => 'Tsala';

  @override
  String get relationshipRoommate => 'Moagisane wa Phaposi';

  @override
  String get relationshipColleague => 'Modirikgotsa';

  @override
  String get relationshipOther => 'Tse Dingwe';

  @override
  String addPersonTitle(String name) {
    return 'Tsenya $name';
  }

  @override
  String get howDoYouKnowThisPerson => 'O mo itse jang motho yo?';

  @override
  String get cancel => 'Khansela';

  @override
  String get add => 'Tsenya';

  @override
  String get chooseAContact => 'Tlhopha Mogokagani';

  @override
  String get searchContacts => 'Batla dikgokagano...';

  @override
  String get noContactsFound => 'Ga go dikgokagano tse di fitlhetsweng';

  @override
  String get retry => 'Leka gape';

  @override
  String get close => 'Tswala';

  @override
  String get join => 'Tsena';

  @override
  String get leave => 'Tswa';

  @override
  String get authWelcomeBack =>
      'Re a go amogela gape — tsena gore o nne o sireletsegile';

  @override
  String get authCreatePrompt => 'Dira akhaonte go simolola';

  @override
  String get logIn => 'Tsena';

  @override
  String get signUp => 'Kwadisa';

  @override
  String get fullName => 'Leina le le Feletseng';

  @override
  String get emailAddress => 'Aterese ya Imeile';

  @override
  String get phoneNumber => 'Nomoro ya Mogala';

  @override
  String get phoneHint => 'sk. +27 71 234 5678';

  @override
  String get password => 'Phasewete';

  @override
  String get confirmPassword => 'Tlhomamisa Phasewete';

  @override
  String get forgotPassword => 'O lebetse Phasewete?';

  @override
  String get forgotPasswordSoon => 'Go baya phasewete gape go tla ka bonako.';

  @override
  String get agreeToTerms =>
      'Ke dumela Dipeelo tsa Ditirelo le Pholisi ya Poraefete';

  @override
  String get createAccount => 'Dira Akhaonte';

  @override
  String get orDivider => 'KGOTSA';

  @override
  String get continueWithGoogle => 'Tswelela le Google';

  @override
  String get signUpWithGoogle => 'Kwadisa ka Google';

  @override
  String get noAccountPrompt => 'Ga o na akhaonte?';

  @override
  String get haveAccountPrompt => 'O setse o na le akhaonte?';

  @override
  String get acceptTermsSnack =>
      'Tsweetswee amogela Dipeelo le Pholisi ya Poraefete gore o tswelele.';

  @override
  String get serverUnreachable =>
      'Ga go a kgonega go fitlhelela sebereki. Lekola tshwaragano ya gago o bo o leke gape.';

  @override
  String get googleSoon => 'Go tsena ka Google go tla ka bonako.';

  @override
  String get fullNameRequired => 'Leina le le feletseng le a tlhokega';

  @override
  String get emailRequired => 'Imeile e a tlhokega';

  @override
  String get emailInvalid => 'Tsenya aterese ya imeile e e siameng';

  @override
  String get phoneRequired => 'Nomoro ya mogala e a tlhokega';

  @override
  String get phoneInvalid => 'Tsenya nomoro ya mogala e e siameng';

  @override
  String get passwordRequired => 'Phasewete e a tlhokega';

  @override
  String get passwordTooShort => 'Dirisa bonnye ditlhaka di le 8';

  @override
  String get confirmPasswordRequired => 'Tlhomamisa phasewete ya gago';

  @override
  String get passwordsDontMatch => 'Diphasewete ga di tshwane';

  @override
  String get locationServicesOff =>
      'Ditirelo tsa lefelo di tshwarilwe — go bontshiwa lefelo la kakaretso.';

  @override
  String get locationPermissionDenied =>
      'Tetla ya lefelo e ganetswe — go bontshiwa lefelo la kakaretso.';

  @override
  String get locationFailed =>
      'Re paletswe ke go bona lefelo la gago la jaanong — go bontshiwa lefelo la kakaretso.';

  @override
  String get gettingLocation => 'Go bona lefelo la gago...';

  @override
  String get defaultArea => 'Lefelo la kakaretso';

  @override
  String get youAreHere => 'O fa';

  @override
  String get somethingWentWrong => 'Go na le sengwe se se sa tsamaang sentle.';

  @override
  String get panicAlertActive => 'TLHOKOMELISO YA TSHABO E A TSAMAYA';

  @override
  String get noResponseYet =>
      'Ga go na karabo le gale — nna o tlhokometse mme o batle thuso fa o kgona.';

  @override
  String get liveLocationShared => 'Lefelo le le teng jaanong le abilwe';

  @override
  String get adminNotified => 'Molaodi o itsisiwe';

  @override
  String get imSafeCancel => 'Ke sireletsegile — Khansela Tlhokomeliso';

  @override
  String contextTripAttached(String service) {
    return 'Dintlha tsa $service di ntshitswe';
  }

  @override
  String get contextNoTrip => 'Ga go na loeto lo lo dirang lo lo ntshitsweng';

  @override
  String contextCommunityNotified(String community) {
    return '$community e itsisiwe';
  }

  @override
  String get contextPassengerAttached => 'Mopalami wa jaanong o ntshitswe';

  @override
  String get contextNoCommunity => 'Ga o ise o tsene mo setšhabeng';

  @override
  String get passengerMode => 'Mokgwa wa Mopalami';

  @override
  String get driverMode => 'Mokgwa wa Mokgweetsi';

  @override
  String get switchLabel => 'Fetola';

  @override
  String get ehailingSafetyTitle => 'Polokesego ya E-Hailing';

  @override
  String get ehailingRoleSubtitle =>
      'Pele re simolola, re bolelele gore o fa letlhakoreng lefe la loeto';

  @override
  String get imAPassenger => 'Ke Mopalami';

  @override
  String get passengerDesc =>
      'Aba loeto la gago le dintlha tsa mokgweetsi le batho ba tshoganyetso ka othomatiki.';

  @override
  String get imADriver => 'Ke Mokgweetsi';

  @override
  String get driverDesc =>
      'Tsena mo setšhabeng sa bagweetsi, kwala dintlha tsa bapalami, mme o tsose tshabo fa o tlhoka thuso.';

  @override
  String get triggerPanicTitle => 'Tsosa Tlhokomeliso ya Tshabo?';

  @override
  String get panicConfirmWithTrip =>
      'Seno se tla itsise molaodi ka bonako ka lefelo la gago le le teng le dintlha tsa loeto lono.';

  @override
  String get panicConfirmNoTrip =>
      'Seno se tla itsise molaodi ka bonako ka lefelo la gago le le teng.';

  @override
  String get triggerAlert => 'Tsosa Tlhokomeliso';

  @override
  String get pickRideApp =>
      'Tlhopha app ya gago ya loeto. Dintlha tsa loeto la gago di tla abiwa le batho ba gago ba ba sireletsegileng.';

  @override
  String get chooseYourRide => 'Tlhopha Loeto la Gago';

  @override
  String tripDetailsTitle(String service) {
    return 'Dintlha tsa Loeto la $service';
  }

  @override
  String get driverNameLabel => 'Leina la Mokgweetsi *';

  @override
  String get driverNameHint => 'Jaaka go bontshitswe mo app';

  @override
  String get vehicleRegLabel => 'Kwadiso ya Koloi *';

  @override
  String get vehicleRegHint => 'sk. CA 123-456';

  @override
  String get vehicleColorLabel => 'Mmala wa Koloi';

  @override
  String get vehicleColorHint => 'sk. Tshweu';

  @override
  String get vehicleModelLabel => 'Mofuta le Setshwano sa Koloi';

  @override
  String get vehicleModelHint => 'sk. Toyota Corolla';

  @override
  String get pickupLocationLabel => 'Lefelo la go Tsewa';

  @override
  String get pickupLocationHint => 'Kwa o tsenyeng teng';

  @override
  String get destinationLabel => 'Kwa o yang teng';

  @override
  String get destinationHint => 'Kwa o yang teng';

  @override
  String get verificationPinLabel => 'PIN ya Tlhomamiso ya Mokgweetsi';

  @override
  String get verificationPinHint => 'Kopa mokgweetsi PIN ya bapalami';

  @override
  String get pinWarning =>
      'Di-app tse dintsi tse di botsalano di naya bagweetsi PIN ya mopalami yo ba mo kwadileng. Fa mokgweetsi a sa kgone go go naya nngwe, kgotsa e sa tshwane le se o builweng, tsaya seo e le sesupo sa tlhokomelo pele o tsena.';

  @override
  String get tripSharedInfo =>
      'Fa e abilwe, loeto la gago lo romelwa ka tlhamalalo go batho ba gago ba Ba Sireletsegileng.';

  @override
  String get sharingEllipsis => 'Go aba...';

  @override
  String get shareTripButton => 'Aba Loeto le Batho ba Tshoganyetso';

  @override
  String get tripSharedSuccess => 'Loeto lo Abilwe ka Katlego';

  @override
  String startedAt(String time) {
    return 'E simolotse ka $time';
  }

  @override
  String get sentTo => 'E rometswe go';

  @override
  String get endingEllipsis => 'Go fela...';

  @override
  String get endTrip => 'Fetsa Loeto';

  @override
  String get rowDriver => 'Mokgweetsi';

  @override
  String get rowRegistration => 'Kwadiso';

  @override
  String get rowVehicle => 'Koloi';

  @override
  String get rowPickup => 'Go Tsewa';

  @override
  String get rowDestination => 'Kwa o yang';

  @override
  String get rowPinConfirmed => 'PIN e Tlhomamisitswe';

  @override
  String get rowNotes => 'Dintlha';

  @override
  String get noProtectedContacts =>
      'Ga go na batho ba Ba Sireletsegileng — tsenya batho mme o ba laletse go tsenya app.';

  @override
  String get createCommunityTitle => 'Dira Setšhaba';

  @override
  String get communityNameLabel => 'Leina la setšhaba';

  @override
  String get communityAreaLabel => 'Lefelo le le le khurumetsang';

  @override
  String get createAndJoin => 'Dira mme o Tsene';

  @override
  String get inDanger => 'O mo Kotsing?';

  @override
  String get alertsAdminInstantly =>
      'E itsise molaodi ka bonako ka lefelo la gago';

  @override
  String get driverCommunity => 'Setšhaba sa Bagweetsi';

  @override
  String get joinCommunityPrompt =>
      'Tsena mo setšhabeng gore thuso e go fitlhelele ka bonako, kgotsa o simolole sa gago';

  @override
  String get noCommunitiesYet =>
      'Ga go na ditšhaba le gone — nna wa ntlha go dira nngwe.';

  @override
  String membersCount(String area, int count) {
    return '$area · ditho di le $count';
  }

  @override
  String get createNewCommunity => 'Dira Setšhaba se Sešwa';

  @override
  String get communityUpdatesInfo =>
      'Dintlha tsa nako ya nnete go tswa mo bagweetsing mo setšhabeng sa gago';

  @override
  String get shareUpdateHint =>
      'Aba dintlha tse dintšha le setšhaba sa gago...';

  @override
  String get noPostsYet => 'Ga go na diposo mo setšhabeng seno le gone.';

  @override
  String get logThisPassenger => 'Kwala Mopalami Yono';

  @override
  String get logPassengerSubtitle =>
      'Kwala loeto lotlhe gore lona ka bobedi le sireletsege fa go na le sengwe se se sa tsamaeng sentle';

  @override
  String get passengerNameLabel => 'Leina la Mopalami *';

  @override
  String get passengerNameHint => 'Jaaka ba ipolelela';

  @override
  String get passengerPhoneLabel => 'Nomoro ya Mogala ya Mopalami';

  @override
  String get passengerPhoneHint => 'Ga e patelesege, ya direkoto tsa gago';

  @override
  String get pickupPointLabel => 'Lefelo la go Tsewa';

  @override
  String get pickupPointHint => 'Kwa o ba tserego teng';

  @override
  String get dropoffHint => 'Kwa o ba tlogelang teng';

  @override
  String get passengersInVehicle => 'Bapalami mo koloing';

  @override
  String get notesOptionalLabel => 'Dintlha (ga di patelesege)';

  @override
  String get notesHint =>
      'sk. moreki yo o tlwaelegileng, o ya kwa bookelong, o ne a bonala a tshogile';

  @override
  String get photoCaptured =>
      'Setshwantsho se tserwe — kgotla go se tseela gape';

  @override
  String get addPassengerPhoto =>
      'Tsenya setshwantsho sa mopalami ka bonako (ga se patelesege)';

  @override
  String get pinGeneratedInfo =>
      'PIN ya tlhomamiso ya nako e le nngwe e tla dirwa gore mopalami a tlhomamise gore o tsena mo koloing e e siameng.';

  @override
  String get loggingEllipsis => 'Go kwala...';

  @override
  String get logPassengerButton => 'Kwala Mopalami mme o Dire PIN';

  @override
  String get passengerLogged => 'Mopalami o Kwadilwe';

  @override
  String get verificationPinCaps => 'PIN YA TLHOMAMISO';

  @override
  String get tellPassengerPin => 'Bolelela mopalami PIN eno pele a tsena';

  @override
  String passengersCountLabel(int count) {
    return 'Bapalami: $count';
  }

  @override
  String get attachedToRecord =>
      'Mopalami yono o ntshitswe mo direkotong tsa akhaonte ya gago';

  @override
  String get autoSafetyCheckIn => 'Tlhatlhobo ya Polokesego ka Othomatiki';

  @override
  String get autoCheckInSub => 'E kwadilwe le loeto lono gore molaodi a e bone';

  @override
  String get markDroppedOff => 'Tshwaya Mopalami a Tlogetswe a Sireletsegile';

  @override
  String get savingEllipsis => 'Go boloka...';

  @override
  String get justNow => 'jaanong fela';

  @override
  String minutesAgo(int n) {
    return '${n}m e e fetileng';
  }

  @override
  String hoursAgo(int n) {
    return '${n}h e e fetileng';
  }

  @override
  String daysAgo(int n) {
    return '${n}d e e fetileng';
  }
}
