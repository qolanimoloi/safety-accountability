import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_af.dart';
import 'app_localizations_en.dart';
import 'app_localizations_st.dart';
import 'app_localizations_tn.dart';
import 'app_localizations_xh.dart';
import 'app_localizations_zu.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('af'),
    Locale('en'),
    Locale('st'),
    Locale('tn'),
    Locale('xh'),
    Locale('zu'),
  ];

  /// No description provided for @emergencyResponseTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency Response'**
  String get emergencyResponseTitle;

  /// No description provided for @emergencyResponseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select the type of emergency you\'re experiencing'**
  String get emergencyResponseSubtitle;

  /// No description provided for @incidentBreakIn.
  ///
  /// In en, this message translates to:
  /// **'Break-In'**
  String get incidentBreakIn;

  /// No description provided for @incidentBeingFollowed.
  ///
  /// In en, this message translates to:
  /// **'Being Followed'**
  String get incidentBeingFollowed;

  /// No description provided for @incidentHijacking.
  ///
  /// In en, this message translates to:
  /// **'Hijacking'**
  String get incidentHijacking;

  /// No description provided for @incidentDomesticViolence.
  ///
  /// In en, this message translates to:
  /// **'Domestic Violence'**
  String get incidentDomesticViolence;

  /// No description provided for @incidentMedicalEmergency.
  ///
  /// In en, this message translates to:
  /// **'Medical Emergency'**
  String get incidentMedicalEmergency;

  /// No description provided for @incidentFire.
  ///
  /// In en, this message translates to:
  /// **'Fire'**
  String get incidentFire;

  /// No description provided for @incidentAssault.
  ///
  /// In en, this message translates to:
  /// **'Assault'**
  String get incidentAssault;

  /// No description provided for @incidentOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get incidentOther;

  /// No description provided for @sendingAlert.
  ///
  /// In en, this message translates to:
  /// **'Sending your alert...'**
  String get sendingAlert;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @adminResponded.
  ///
  /// In en, this message translates to:
  /// **'An admin has responded to your alert.'**
  String get adminResponded;

  /// No description provided for @referenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference: {ref}'**
  String referenceLabel(String ref);

  /// No description provided for @noResponseWindow.
  ///
  /// In en, this message translates to:
  /// **'No response was received within the 5-minute window.'**
  String get noResponseWindow;

  /// No description provided for @downloadPonr.
  ///
  /// In en, this message translates to:
  /// **'Download PONR (Proof of Non-Response)'**
  String get downloadPonr;

  /// No description provided for @waitingForResponse.
  ///
  /// In en, this message translates to:
  /// **'Waiting for response... {time}'**
  String waitingForResponse(String time);

  /// No description provided for @emergencyDispatchMessage.
  ///
  /// In en, this message translates to:
  /// **'Help is being dispatched to your location. Stay calm and follow safety protocols.'**
  String get emergencyDispatchMessage;

  /// No description provided for @emergencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency: {type}'**
  String emergencyTitle(String type);

  /// No description provided for @contactNeedsHelp.
  ///
  /// In en, this message translates to:
  /// **'{name} needs help'**
  String contactNeedsHelp(String name);

  /// No description provided for @callAction.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get callAction;

  /// No description provided for @locationAction.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationAction;

  /// No description provided for @emergencyContactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contacts'**
  String get emergencyContactsTitle;

  /// No description provided for @emergencyContactsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The people who get notified when you need help'**
  String get emergencyContactsSubtitle;

  /// No description provided for @protectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Protected'**
  String get protectedLabel;

  /// No description provided for @pendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingLabel;

  /// No description provided for @addFromContacts.
  ///
  /// In en, this message translates to:
  /// **'Add From Contacts'**
  String get addFromContacts;

  /// No description provided for @contactsWhyBanner.
  ///
  /// In en, this message translates to:
  /// **'A contact can only receive your live alerts once they install Safety & Accountability. Send them an invite to switch them from Pending to Protected.'**
  String get contactsWhyBanner;

  /// No description provided for @yourCircle.
  ///
  /// In en, this message translates to:
  /// **'Your Circle'**
  String get yourCircle;

  /// No description provided for @noContactsYet.
  ///
  /// In en, this message translates to:
  /// **'No emergency contacts yet'**
  String get noContactsYet;

  /// No description provided for @addSomeoneYouTrust.
  ///
  /// In en, this message translates to:
  /// **'Add someone you trust from your phone contacts'**
  String get addSomeoneYouTrust;

  /// No description provided for @couldNotLoadContacts.
  ///
  /// In en, this message translates to:
  /// **'Could not load contacts.'**
  String get couldNotLoadContacts;

  /// No description provided for @invitePending.
  ///
  /// In en, this message translates to:
  /// **'Invite Pending'**
  String get invitePending;

  /// No description provided for @sendInvite.
  ///
  /// In en, this message translates to:
  /// **'Send Invite'**
  String get sendInvite;

  /// No description provided for @relationshipParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get relationshipParent;

  /// No description provided for @relationshipSibling.
  ///
  /// In en, this message translates to:
  /// **'Sibling'**
  String get relationshipSibling;

  /// No description provided for @relationshipPartner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get relationshipPartner;

  /// No description provided for @relationshipFriend.
  ///
  /// In en, this message translates to:
  /// **'Friend'**
  String get relationshipFriend;

  /// No description provided for @relationshipRoommate.
  ///
  /// In en, this message translates to:
  /// **'Roommate'**
  String get relationshipRoommate;

  /// No description provided for @relationshipColleague.
  ///
  /// In en, this message translates to:
  /// **'Colleague'**
  String get relationshipColleague;

  /// No description provided for @relationshipOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get relationshipOther;

  /// No description provided for @addPersonTitle.
  ///
  /// In en, this message translates to:
  /// **'Add {name}'**
  String addPersonTitle(String name);

  /// No description provided for @howDoYouKnowThisPerson.
  ///
  /// In en, this message translates to:
  /// **'How do you know this person?'**
  String get howDoYouKnowThisPerson;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @chooseAContact.
  ///
  /// In en, this message translates to:
  /// **'Choose a Contact'**
  String get chooseAContact;

  /// No description provided for @searchContacts.
  ///
  /// In en, this message translates to:
  /// **'Search contacts...'**
  String get searchContacts;

  /// No description provided for @noContactsFound.
  ///
  /// In en, this message translates to:
  /// **'No contacts found'**
  String get noContactsFound;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back — log in to stay protected'**
  String get authWelcomeBack;

  /// No description provided for @authCreatePrompt.
  ///
  /// In en, this message translates to:
  /// **'Create an account to get started'**
  String get authCreatePrompt;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. +27 71 234 5678'**
  String get phoneHint;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordSoon.
  ///
  /// In en, this message translates to:
  /// **'Password reset is coming soon.'**
  String get forgotPasswordSoon;

  /// No description provided for @agreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms of Service and Privacy Policy'**
  String get agreeToTerms;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get orDivider;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @signUpWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign up with Google'**
  String get signUpWithGoogle;

  /// No description provided for @noAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccountPrompt;

  /// No description provided for @haveAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get haveAccountPrompt;

  /// No description provided for @acceptTermsSnack.
  ///
  /// In en, this message translates to:
  /// **'Please accept the Terms & Privacy Policy to continue.'**
  String get acceptTermsSnack;

  /// No description provided for @serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection and try again.'**
  String get serverUnreachable;

  /// No description provided for @googleSoon.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In is coming soon.'**
  String get googleSoon;

  /// No description provided for @fullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Full name is required'**
  String get fullNameRequired;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get emailInvalid;

  /// No description provided for @phoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get phoneRequired;

  /// No description provided for @phoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get phoneInvalid;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @confirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get confirmPasswordRequired;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get passwordsDontMatch;

  /// No description provided for @locationServicesOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are off — showing a default area instead.'**
  String get locationServicesOff;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was denied — showing a default area instead.'**
  String get locationPermissionDenied;

  /// No description provided for @locationFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your current location — showing a default area instead.'**
  String get locationFailed;

  /// No description provided for @gettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Getting your location...'**
  String get gettingLocation;

  /// No description provided for @defaultArea.
  ///
  /// In en, this message translates to:
  /// **'Default area'**
  String get defaultArea;

  /// No description provided for @youAreHere.
  ///
  /// In en, this message translates to:
  /// **'You are here'**
  String get youAreHere;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get somethingWentWrong;

  /// No description provided for @panicAlertActive.
  ///
  /// In en, this message translates to:
  /// **'PANIC ALERT ACTIVE'**
  String get panicAlertActive;

  /// No description provided for @noResponseYet.
  ///
  /// In en, this message translates to:
  /// **'No response yet — stay alert and seek help if you can.'**
  String get noResponseYet;

  /// No description provided for @liveLocationShared.
  ///
  /// In en, this message translates to:
  /// **'Live location shared'**
  String get liveLocationShared;

  /// No description provided for @adminNotified.
  ///
  /// In en, this message translates to:
  /// **'Admin notified'**
  String get adminNotified;

  /// No description provided for @imSafeCancel.
  ///
  /// In en, this message translates to:
  /// **'I\'m Safe — Cancel Alert'**
  String get imSafeCancel;

  /// No description provided for @contextTripAttached.
  ///
  /// In en, this message translates to:
  /// **'{service} details attached'**
  String contextTripAttached(String service);

  /// No description provided for @contextNoTrip.
  ///
  /// In en, this message translates to:
  /// **'No active trip attached'**
  String get contextNoTrip;

  /// No description provided for @contextCommunityNotified.
  ///
  /// In en, this message translates to:
  /// **'{community} notified'**
  String contextCommunityNotified(String community);

  /// No description provided for @contextPassengerAttached.
  ///
  /// In en, this message translates to:
  /// **'Current passenger attached'**
  String get contextPassengerAttached;

  /// No description provided for @contextNoCommunity.
  ///
  /// In en, this message translates to:
  /// **'No community joined'**
  String get contextNoCommunity;

  /// No description provided for @passengerMode.
  ///
  /// In en, this message translates to:
  /// **'Passenger Mode'**
  String get passengerMode;

  /// No description provided for @driverMode.
  ///
  /// In en, this message translates to:
  /// **'Driver Mode'**
  String get driverMode;

  /// No description provided for @switchLabel.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchLabel;

  /// No description provided for @ehailingSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'E-Hailing Safety'**
  String get ehailingSafetyTitle;

  /// No description provided for @ehailingRoleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Before we start, tell us which side of the ride you\'re on'**
  String get ehailingRoleSubtitle;

  /// No description provided for @imAPassenger.
  ///
  /// In en, this message translates to:
  /// **'I\'m a Passenger'**
  String get imAPassenger;

  /// No description provided for @passengerDesc.
  ///
  /// In en, this message translates to:
  /// **'Share your trip and driver details with your emergency contacts automatically.'**
  String get passengerDesc;

  /// No description provided for @imADriver.
  ///
  /// In en, this message translates to:
  /// **'I\'m a Driver'**
  String get imADriver;

  /// No description provided for @driverDesc.
  ///
  /// In en, this message translates to:
  /// **'Join your driver community, log passenger details, and trigger a panic alert if you need help.'**
  String get driverDesc;

  /// No description provided for @triggerPanicTitle.
  ///
  /// In en, this message translates to:
  /// **'Trigger Panic Alert?'**
  String get triggerPanicTitle;

  /// No description provided for @panicConfirmWithTrip.
  ///
  /// In en, this message translates to:
  /// **'This will immediately notify an admin with your live location and this trip\'s details.'**
  String get panicConfirmWithTrip;

  /// No description provided for @panicConfirmNoTrip.
  ///
  /// In en, this message translates to:
  /// **'This will immediately notify an admin with your live location.'**
  String get panicConfirmNoTrip;

  /// No description provided for @triggerAlert.
  ///
  /// In en, this message translates to:
  /// **'Trigger Alert'**
  String get triggerAlert;

  /// No description provided for @pickRideApp.
  ///
  /// In en, this message translates to:
  /// **'Pick your ride app. Your trip details will be shared with your protected emergency contacts.'**
  String get pickRideApp;

  /// No description provided for @chooseYourRide.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Ride'**
  String get chooseYourRide;

  /// No description provided for @tripDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'{service} Trip Details'**
  String tripDetailsTitle(String service);

  /// No description provided for @driverNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver\'s Name *'**
  String get driverNameLabel;

  /// No description provided for @driverNameHint.
  ///
  /// In en, this message translates to:
  /// **'As shown in the app'**
  String get driverNameHint;

  /// No description provided for @vehicleRegLabel.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Reg *'**
  String get vehicleRegLabel;

  /// No description provided for @vehicleRegHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. CA 123-456'**
  String get vehicleRegHint;

  /// No description provided for @vehicleColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Color'**
  String get vehicleColorLabel;

  /// No description provided for @vehicleColorHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. White'**
  String get vehicleColorHint;

  /// No description provided for @vehicleModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Make & Model'**
  String get vehicleModelLabel;

  /// No description provided for @vehicleModelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Toyota Corolla'**
  String get vehicleModelHint;

  /// No description provided for @pickupLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Pickup Location'**
  String get pickupLocationLabel;

  /// No description provided for @pickupLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Where you got in'**
  String get pickupLocationHint;

  /// No description provided for @destinationLabel.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destinationLabel;

  /// No description provided for @destinationHint.
  ///
  /// In en, this message translates to:
  /// **'Where you\'re headed'**
  String get destinationHint;

  /// No description provided for @verificationPinLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver\'s Verification PIN'**
  String get verificationPinLabel;

  /// No description provided for @verificationPinHint.
  ///
  /// In en, this message translates to:
  /// **'Ask the driver for their passenger PIN'**
  String get verificationPinHint;

  /// No description provided for @pinWarning.
  ///
  /// In en, this message translates to:
  /// **'Many trusted apps give drivers a PIN for their logged passenger. If the driver can\'t give you one, or it doesn\'t match what you were told, treat that as a warning sign before you get in.'**
  String get pinWarning;

  /// No description provided for @tripSharedInfo.
  ///
  /// In en, this message translates to:
  /// **'Once shared, your trip is sent live to your Protected emergency contacts.'**
  String get tripSharedInfo;

  /// No description provided for @sharingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Sharing...'**
  String get sharingEllipsis;

  /// No description provided for @shareTripButton.
  ///
  /// In en, this message translates to:
  /// **'Share Trip With Emergency Contacts'**
  String get shareTripButton;

  /// No description provided for @tripSharedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Trip Shared Successfully'**
  String get tripSharedSuccess;

  /// No description provided for @startedAt.
  ///
  /// In en, this message translates to:
  /// **'Started at {time}'**
  String startedAt(String time);

  /// No description provided for @sentTo.
  ///
  /// In en, this message translates to:
  /// **'Sent to'**
  String get sentTo;

  /// No description provided for @endingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Ending...'**
  String get endingEllipsis;

  /// No description provided for @endTrip.
  ///
  /// In en, this message translates to:
  /// **'End Trip'**
  String get endTrip;

  /// No description provided for @rowDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get rowDriver;

  /// No description provided for @rowRegistration.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get rowRegistration;

  /// No description provided for @rowVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get rowVehicle;

  /// No description provided for @rowPickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get rowPickup;

  /// No description provided for @rowDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get rowDestination;

  /// No description provided for @rowPinConfirmed.
  ///
  /// In en, this message translates to:
  /// **'PIN Confirmed'**
  String get rowPinConfirmed;

  /// No description provided for @rowNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get rowNotes;

  /// No description provided for @noProtectedContacts.
  ///
  /// In en, this message translates to:
  /// **'No Protected contacts yet — add contacts and invite them to install the app.'**
  String get noProtectedContacts;

  /// No description provided for @createCommunityTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a Community'**
  String get createCommunityTitle;

  /// No description provided for @communityNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Community name'**
  String get communityNameLabel;

  /// No description provided for @communityAreaLabel.
  ///
  /// In en, this message translates to:
  /// **'Area it covers'**
  String get communityAreaLabel;

  /// No description provided for @createAndJoin.
  ///
  /// In en, this message translates to:
  /// **'Create & Join'**
  String get createAndJoin;

  /// No description provided for @inDanger.
  ///
  /// In en, this message translates to:
  /// **'In Danger?'**
  String get inDanger;

  /// No description provided for @alertsAdminInstantly.
  ///
  /// In en, this message translates to:
  /// **'Alerts an admin instantly with your location'**
  String get alertsAdminInstantly;

  /// No description provided for @driverCommunity.
  ///
  /// In en, this message translates to:
  /// **'Driver Community'**
  String get driverCommunity;

  /// No description provided for @joinCommunityPrompt.
  ///
  /// In en, this message translates to:
  /// **'Join a community so help can reach you fast, or start your own'**
  String get joinCommunityPrompt;

  /// No description provided for @noCommunitiesYet.
  ///
  /// In en, this message translates to:
  /// **'No communities yet — be the first to create one.'**
  String get noCommunitiesYet;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{area} · {count} members'**
  String membersCount(String area, int count);

  /// No description provided for @createNewCommunity.
  ///
  /// In en, this message translates to:
  /// **'Create New Community'**
  String get createNewCommunity;

  /// No description provided for @communityUpdatesInfo.
  ///
  /// In en, this message translates to:
  /// **'Real-time updates from drivers in your community'**
  String get communityUpdatesInfo;

  /// No description provided for @shareUpdateHint.
  ///
  /// In en, this message translates to:
  /// **'Share an update with your community...'**
  String get shareUpdateHint;

  /// No description provided for @noPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No posts yet in this community.'**
  String get noPostsYet;

  /// No description provided for @logThisPassenger.
  ///
  /// In en, this message translates to:
  /// **'Log This Passenger'**
  String get logThisPassenger;

  /// No description provided for @logPassengerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Capture the full trip so both of you are protected if something goes wrong'**
  String get logPassengerSubtitle;

  /// No description provided for @passengerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Passenger\'s Name *'**
  String get passengerNameLabel;

  /// No description provided for @passengerNameHint.
  ///
  /// In en, this message translates to:
  /// **'As they introduced themselves'**
  String get passengerNameHint;

  /// No description provided for @passengerPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Passenger\'s Phone Number'**
  String get passengerPhoneLabel;

  /// No description provided for @passengerPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Optional, for your records'**
  String get passengerPhoneHint;

  /// No description provided for @pickupPointLabel.
  ///
  /// In en, this message translates to:
  /// **'Pickup Point'**
  String get pickupPointLabel;

  /// No description provided for @pickupPointHint.
  ///
  /// In en, this message translates to:
  /// **'Where you collected them'**
  String get pickupPointHint;

  /// No description provided for @dropoffHint.
  ///
  /// In en, this message translates to:
  /// **'Where you\'re dropping off'**
  String get dropoffHint;

  /// No description provided for @passengersInVehicle.
  ///
  /// In en, this message translates to:
  /// **'Passengers in vehicle'**
  String get passengersInVehicle;

  /// No description provided for @notesOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptionalLabel;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. regular client, going to hospital, seemed anxious'**
  String get notesHint;

  /// No description provided for @photoCaptured.
  ///
  /// In en, this message translates to:
  /// **'Photo captured — tap to retake'**
  String get photoCaptured;

  /// No description provided for @addPassengerPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a quick passenger photo (optional)'**
  String get addPassengerPhoto;

  /// No description provided for @pinGeneratedInfo.
  ///
  /// In en, this message translates to:
  /// **'A one-time verification PIN will be generated so the passenger can confirm they\'re getting into the right vehicle.'**
  String get pinGeneratedInfo;

  /// No description provided for @loggingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Logging...'**
  String get loggingEllipsis;

  /// No description provided for @logPassengerButton.
  ///
  /// In en, this message translates to:
  /// **'Log Passenger & Generate PIN'**
  String get logPassengerButton;

  /// No description provided for @passengerLogged.
  ///
  /// In en, this message translates to:
  /// **'Passenger Logged'**
  String get passengerLogged;

  /// No description provided for @verificationPinCaps.
  ///
  /// In en, this message translates to:
  /// **'VERIFICATION PIN'**
  String get verificationPinCaps;

  /// No description provided for @tellPassengerPin.
  ///
  /// In en, this message translates to:
  /// **'Tell the passenger this PIN before they get in'**
  String get tellPassengerPin;

  /// No description provided for @passengersCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Passengers: {count}'**
  String passengersCountLabel(int count);

  /// No description provided for @attachedToRecord.
  ///
  /// In en, this message translates to:
  /// **'This passenger is attached to your account record'**
  String get attachedToRecord;

  /// No description provided for @autoSafetyCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Auto Safety Check-In'**
  String get autoSafetyCheckIn;

  /// No description provided for @autoCheckInSub.
  ///
  /// In en, this message translates to:
  /// **'Logged with this trip for admin visibility'**
  String get autoCheckInSub;

  /// No description provided for @markDroppedOff.
  ///
  /// In en, this message translates to:
  /// **'Mark Passenger Dropped Off Safely'**
  String get markDroppedOff;

  /// No description provided for @savingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get savingEllipsis;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}m ago'**
  String minutesAgo(int n);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}h ago'**
  String hoursAgo(int n);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}d ago'**
  String daysAgo(int n);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'af',
    'en',
    'st',
    'tn',
    'xh',
    'zu',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'af':
      return AppLocalizationsAf();
    case 'en':
      return AppLocalizationsEn();
    case 'st':
      return AppLocalizationsSt();
    case 'tn':
      return AppLocalizationsTn();
    case 'xh':
      return AppLocalizationsXh();
    case 'zu':
      return AppLocalizationsZu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
