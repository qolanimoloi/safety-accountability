// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Southern Sotho (`st`).
class AppLocalizationsSt extends AppLocalizations {
  AppLocalizationsSt([String locale = 'st']) : super(locale);

  @override
  String get emergencyResponseTitle => 'Karabo ya Tshohanyetso';

  @override
  String get emergencyResponseSubtitle =>
      'Khetha mofuta wa tshohanyetso eo o thulaneng le yona';

  @override
  String get incidentBreakIn => 'Ho Robuwa Ntlo';

  @override
  String get incidentBeingFollowed => 'Ho Saloa Morao';

  @override
  String get incidentHijacking => 'Ho Hlwauwa Koloi';

  @override
  String get incidentDomesticViolence => 'Tlhekefetso ya Lapeng';

  @override
  String get incidentMedicalEmergency => 'Tshohanyetso ya Bongaka';

  @override
  String get incidentFire => 'Mollo';

  @override
  String get incidentAssault => 'Tlhaselo';

  @override
  String get incidentOther => 'Tse Ding';

  @override
  String get sendingAlert => 'Ho romelwa temoso ya hao...';

  @override
  String get tryAgain => 'Leka Hape';

  @override
  String get adminResponded => 'Motsamaisi o arabetse temoso ya hao.';

  @override
  String referenceLabel(String ref) {
    return 'Tshupiso: $ref';
  }

  @override
  String get noResponseWindow =>
      'Ha ho karabo e fumanweng nakong ya metsotso e 5.';

  @override
  String get downloadPonr => 'Jarolla PONR (Bopaki ba ho se Arabe)';

  @override
  String waitingForResponse(String time) {
    return 'Ho letetswe karabo... $time';
  }

  @override
  String get emergencyDispatchMessage =>
      'Thuso e romellwa sebakeng sa hao. Dula o phutsitse mme o latele melawana ya tshireletso.';

  @override
  String emergencyTitle(String type) {
    return 'Tshohanyetso: $type';
  }

  @override
  String contactNeedsHelp(String name) {
    return '$name o hloka thuso';
  }

  @override
  String get callAction => 'Letsetsa';

  @override
  String get locationAction => 'Sebaka';

  @override
  String get emergencyContactsTitle =>
      'Dintlha tsa Boikopanyo tsa Tshohanyetso';

  @override
  String get emergencyContactsSubtitle =>
      'Batho ba tsebiswang ha o hloka thuso';

  @override
  String get protectedLabel => 'O Sirelelitswe';

  @override
  String get pendingLabel => 'E sa ntse e emetswe';

  @override
  String get addFromContacts => 'Kenya ho tswa Mananeng a Boikopanyo';

  @override
  String get contactsWhyBanner =>
      'Motho eo o ikopanyang le yena a ka fumana ditemoso tsa hao tsa nnete feela ha a se a kentse Safety & Accountability. Mo romelle memo ho mo fetola ho tloha ho e Emetsweng ho ya ho e Sirelleditsweng.';

  @override
  String get yourCircle => 'Sehlopha sa Hao';

  @override
  String get noContactsYet =>
      'Ha ho na dintlha tsa boikopanyo tsa tshohanyetso ho fihlela hajoale';

  @override
  String get addSomeoneYouTrust =>
      'Kenya motho eo o mo tshepang ho tswa mananeng a boikopanyo a founo ya hao';

  @override
  String get couldNotLoadContacts =>
      'Ha ho a khona ho jarolla mananeng a boikopanyo.';

  @override
  String get invitePending => 'Memo e Emetswe';

  @override
  String get sendInvite => 'Romela Memo';

  @override
  String get relationshipParent => 'Motswadi';

  @override
  String get relationshipSibling => 'Ngwaneo';

  @override
  String get relationshipPartner => 'Molekane';

  @override
  String get relationshipFriend => 'Motswalle';

  @override
  String get relationshipRoommate => 'Moahisane wa Kamoreng';

  @override
  String get relationshipColleague => 'Mosebetsi-mmoho';

  @override
  String get relationshipOther => 'Tse Ding';

  @override
  String addPersonTitle(String name) {
    return 'Kenya $name';
  }

  @override
  String get howDoYouKnowThisPerson => 'O mo tseba jwang motho enwa?';

  @override
  String get cancel => 'Hlakola';

  @override
  String get add => 'Kenya';

  @override
  String get chooseAContact => 'Kgetha Motho ya Ikopanyang';

  @override
  String get searchContacts => 'Batla mananeng a boikopanyo...';

  @override
  String get noContactsFound => 'Ha ho mananeng a boikopanyo a fumanweng';

  @override
  String get retry => 'Leka hape';

  @override
  String get close => 'Koala';

  @override
  String get join => 'Kena';

  @override
  String get leave => 'Tsoa';

  @override
  String get authWelcomeBack =>
      'Rea u amohela hape — kena ho lula u sirelelitsoe';

  @override
  String get authCreatePrompt => 'Theha akhaonto ho qala';

  @override
  String get logIn => 'Kena';

  @override
  String get signUp => 'Ngolisa';

  @override
  String get fullName => 'Lebitso le Feletseng';

  @override
  String get emailAddress => 'Aterese ea Email';

  @override
  String get phoneNumber => 'Nomoro ea Mohala';

  @override
  String get phoneHint => 'mohl. +27 71 234 5678';

  @override
  String get password => 'Phasewete';

  @override
  String get confirmPassword => 'Netefatsa Phasewete';

  @override
  String get forgotPassword => 'U lebetse Phasewete?';

  @override
  String get forgotPasswordSoon => 'Ho beha phasewete hape ho tla haufinyane.';

  @override
  String get agreeToTerms =>
      'Ke lumela Melao ea Tšebeletso le Pholisi ea Lekunutu';

  @override
  String get createAccount => 'Theha Akhaonto';

  @override
  String get orDivider => 'KAPA';

  @override
  String get continueWithGoogle => 'Tsoela pele le Google';

  @override
  String get signUpWithGoogle => 'Ngolisa ka Google';

  @override
  String get noAccountPrompt => 'Ha o na akhaonto?';

  @override
  String get haveAccountPrompt => 'O se o na le akhaonto?';

  @override
  String get acceptTermsSnack =>
      'Ka kopo amohela Melao le Pholisi ea Lekunutu ho tsoela pele.';

  @override
  String get serverUnreachable =>
      'Ha ho khonehe ho fihla ho seva. Hlahloba khokahano ea hau ebe u leka hape.';

  @override
  String get googleSoon => 'Ho kena ka Google ho tla haufinyane.';

  @override
  String get fullNameRequired => 'Lebitso le feletseng le a hlokahala';

  @override
  String get emailRequired => 'Email e a hlokahala';

  @override
  String get emailInvalid => 'Kenya aterese ea email e nepahetseng';

  @override
  String get phoneRequired => 'Nomoro ea mohala e a hlokahala';

  @override
  String get phoneInvalid => 'Kenya nomoro ea mohala e nepahetseng';

  @override
  String get passwordRequired => 'Phasewete e a hlokahala';

  @override
  String get passwordTooShort => 'Sebelisa bonyane litlhaku tse 8';

  @override
  String get confirmPasswordRequired => 'Netefatsa phasewete ea hau';

  @override
  String get passwordsDontMatch => 'Diphasewete ha di lumellane';

  @override
  String get locationServicesOff =>
      'Ditshebeletso tsa sebaka di koetsoe — ho bontšoa sebaka se tloaelehileng.';

  @override
  String get locationPermissionDenied =>
      'Tumello ea sebaka e hanetsoe — ho bontšoa sebaka se tloaelehileng.';

  @override
  String get locationFailed =>
      'Re hlolehile ho fumana sebaka sa hau sa hajoale — ho bontšoa sebaka se tloaelehileng.';

  @override
  String get gettingLocation => 'Ho fumana sebaka sa hau...';

  @override
  String get defaultArea => 'Sebaka se tloaelehileng';

  @override
  String get youAreHere => 'U mona';

  @override
  String get somethingWentWrong => 'Ho na le se fosahetseng.';

  @override
  String get panicAlertActive => 'TLHOKOMELISO EA TŠOSOLO E SEBETSA';

  @override
  String get noResponseYet =>
      'Ha ho karabo hajoale — lula u hlokometse \'me u batle thuso haeba u khona.';

  @override
  String get liveLocationShared => 'Sebaka se phelang se arolelanoe';

  @override
  String get adminNotified => 'Mookameli o tsebisitsoe';

  @override
  String get imSafeCancel => 'Ke sireletsehile — Hlakola Tlhokomeliso';

  @override
  String contextTripAttached(String service) {
    return 'Lintlha tsa $service li kentsoe';
  }

  @override
  String get contextNoTrip => 'Ha ho leeto le sebetsang le kentsoeng';

  @override
  String contextCommunityNotified(String community) {
    return '$community e tsebisitsoe';
  }

  @override
  String get contextPassengerAttached => 'Mopalami oa hajoale o kentsoe';

  @override
  String get contextNoCommunity => 'Ha o so kene sechabeng';

  @override
  String get passengerMode => 'Mokhoa oa Mopalami';

  @override
  String get driverMode => 'Mokhoa oa Mokhanni';

  @override
  String get switchLabel => 'Fetola';

  @override
  String get ehailingSafetyTitle => 'Polokeho ea E-Hailing';

  @override
  String get ehailingRoleSubtitle =>
      'Pele re qala, re bolelle hore u lehlakoreng lefe la leeto';

  @override
  String get imAPassenger => 'Ke Mopalami';

  @override
  String get passengerDesc =>
      'Arolelana leeto la hau le lintlha tsa mokhanni le batho ba tšohanyetso ka boiketsetso.';

  @override
  String get imADriver => 'Ke Mokhanni';

  @override
  String get driverDesc =>
      'Kena sechabeng sa bakhanni, ngola lintlha tsa bapalami, \'me u hlahise tšosolo haeba u hloka thuso.';

  @override
  String get triggerPanicTitle => 'Hlahisa Tšosolo?';

  @override
  String get panicConfirmWithTrip =>
      'Sena se tla tsebisa mookameli hang ka sebaka sa hau se phelang le lintlha tsa leeto lena.';

  @override
  String get panicConfirmNoTrip =>
      'Sena se tla tsebisa mookameli hang ka sebaka sa hau se phelang.';

  @override
  String get triggerAlert => 'Hlahisa Tlhokomeliso';

  @override
  String get pickRideApp =>
      'Kgetha app ea hau ea leeto. Lintlha tsa leeto la hau li tla arolelanoa le batho ba hau ba sirelelitsoeng.';

  @override
  String get chooseYourRide => 'Kgetha Leeto la Hau';

  @override
  String tripDetailsTitle(String service) {
    return 'Lintlha tsa Leeto la $service';
  }

  @override
  String get driverNameLabel => 'Lebitso la Mokhanni *';

  @override
  String get driverNameHint => 'Kamoo ho bontšitsoeng ka app';

  @override
  String get vehicleRegLabel => 'Ngoliso ea Koloi *';

  @override
  String get vehicleRegHint => 'mohl. CA 123-456';

  @override
  String get vehicleColorLabel => 'Mmala oa Koloi';

  @override
  String get vehicleColorHint => 'mohl. Tšoeu';

  @override
  String get vehicleModelLabel => 'Mofuta le Mohlala oa Koloi';

  @override
  String get vehicleModelHint => 'mohl. Toyota Corolla';

  @override
  String get pickupLocationLabel => 'Sebaka sa ho Nkoa';

  @override
  String get pickupLocationHint => 'Moo u kene teng';

  @override
  String get destinationLabel => 'Moo u eang teng';

  @override
  String get destinationHint => 'Moo u eang teng';

  @override
  String get verificationPinLabel => 'PIN ea Netefatso ea Mokhanni';

  @override
  String get verificationPinHint => 'Kopa mokhanni PIN ea bapalami';

  @override
  String get pinWarning =>
      'Li-app tse ngata tse tšepehang li fa bakhanni PIN bakeng sa mopalami eo ba mo ngotseng. Haeba mokhanni a sa khone ho u fa e \'ngoe, kapa e sa lumellane le seo u boletsoeng sona, nka seo e le letšoao la temoso pele u kena.';

  @override
  String get tripSharedInfo =>
      'Hang ha e arolelanoe, leeto la hau le romelloa ka kotloloho ho batho ba hau ba Sirelelitsoeng.';

  @override
  String get sharingEllipsis => 'Ho arolelana...';

  @override
  String get shareTripButton => 'Arolelana Leeto le Batho ba Tšohanyetso';

  @override
  String get tripSharedSuccess => 'Leeto le Arolelanoe ka Katleho';

  @override
  String startedAt(String time) {
    return 'E qalile ka $time';
  }

  @override
  String get sentTo => 'E rometsoe ho';

  @override
  String get endingEllipsis => 'Ho fela...';

  @override
  String get endTrip => 'Phetha Leeto';

  @override
  String get rowDriver => 'Mokhanni';

  @override
  String get rowRegistration => 'Ngoliso';

  @override
  String get rowVehicle => 'Koloi';

  @override
  String get rowPickup => 'Ho Nkoa';

  @override
  String get rowDestination => 'Moo u eang';

  @override
  String get rowPinConfirmed => 'PIN e Netefalitsoe';

  @override
  String get rowNotes => 'Lintlha';

  @override
  String get noProtectedContacts =>
      'Ha ho batho ba Sirelelitsoeng — kenya batho \'me uba memele ho kenya app.';

  @override
  String get createCommunityTitle => 'Theha Sechaba';

  @override
  String get communityNameLabel => 'Lebitso la sechaba';

  @override
  String get communityAreaLabel => 'Sebaka seo se se koahelang';

  @override
  String get createAndJoin => 'Theha \'me u Kene';

  @override
  String get inDanger => 'U Kotsing?';

  @override
  String get alertsAdminInstantly =>
      'E tsebisa mookameli hang ka sebaka sa hau';

  @override
  String get driverCommunity => 'Sechaba sa Bakhanni';

  @override
  String get joinCommunityPrompt =>
      'Kena sechabeng hore thuso e u fihlele kapele, kapa u qale sa hau';

  @override
  String get noCommunitiesYet =>
      'Ha ho lichaba hajoale — e-ba oa pele ho theha le leng.';

  @override
  String membersCount(String area, int count) {
    return '$area · litho tse $count';
  }

  @override
  String get createNewCommunity => 'Theha Sechaba se Secha';

  @override
  String get communityUpdatesInfo =>
      'Lintlha tsa nako ea nnete ho tsoa ho bakhanni sechabeng sa hau';

  @override
  String get shareUpdateHint =>
      'Arolelana tlhahisoleseling le sechaba sa hau...';

  @override
  String get noPostsYet => 'Ha ho likhatiso sechabeng sena hajoale.';

  @override
  String get logThisPassenger => 'Ngola Mopalami Enoa';

  @override
  String get logPassengerSubtitle =>
      'Ngola leeto lohle hore le lōna ka bobeli le sirelelitsoe haeba ho na le se fosahetseng';

  @override
  String get passengerNameLabel => 'Lebitso la Mopalami *';

  @override
  String get passengerNameHint => 'Kamoo ba iketsitseng';

  @override
  String get passengerPhoneLabel => 'Nomoro ea Mohala ea Mopalami';

  @override
  String get passengerPhoneHint => 'Ha e qobelloe, bakeng sa lirekoto tsa hau';

  @override
  String get pickupPointLabel => 'Sebaka sa ho Nkoa';

  @override
  String get pickupPointHint => 'Moo u ba nkileng teng';

  @override
  String get dropoffHint => 'Moo u ba tlohelang teng';

  @override
  String get passengersInVehicle => 'Bapalami koloing';

  @override
  String get notesOptionalLabel => 'Lintlha (ha li qobelloe)';

  @override
  String get notesHint =>
      'mohl. moreki ea tloaelehileng, o ea sepetlele, o ne a bonahala a tšohile';

  @override
  String get photoCaptured => 'Setšoantšo se nkiloe — tobetsa ho se nka hape';

  @override
  String get addPassengerPhoto =>
      'Kenya setšoantšo se potlakileng sa mopalami (ha se qobelloe)';

  @override
  String get pinGeneratedInfo =>
      'PIN ea netefatso ea lekhetlo le le leng e tla hlahisoa hore mopalami a netefatse hore o kena koloing e nepahetseng.';

  @override
  String get loggingEllipsis => 'Ho ngola...';

  @override
  String get logPassengerButton => 'Ngola Mopalami \'me u Hlahise PIN';

  @override
  String get passengerLogged => 'Mopalami o Ngotsoe';

  @override
  String get verificationPinCaps => 'PIN EA NETEFATSO';

  @override
  String get tellPassengerPin => 'Bolella mopalami PIN ena pele a kena';

  @override
  String passengersCountLabel(int count) {
    return 'Bapalami: $count';
  }

  @override
  String get attachedToRecord =>
      'Mopalami enoa o kentsoe rekotong ea akhaonto ea hau';

  @override
  String get autoSafetyCheckIn => 'Tlhahlobo ea Polokeho ka Boiketsetso';

  @override
  String get autoCheckInSub =>
      'E ngotsoe le leeto lena hore mookameli a e bone';

  @override
  String get markDroppedOff => 'Tšoaea Mopalami a Tlohetsoe a Sireletsehile';

  @override
  String get savingEllipsis => 'Ho boloka...';

  @override
  String get justNow => 'joale feela';

  @override
  String minutesAgo(int n) {
    return '${n}m e fetileng';
  }

  @override
  String hoursAgo(int n) {
    return '${n}h e fetileng';
  }

  @override
  String daysAgo(int n) {
    return '${n}d e fetileng';
  }
}
