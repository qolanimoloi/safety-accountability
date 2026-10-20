// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get emergencyResponseTitle => 'Emergency Response';

  @override
  String get emergencyResponseSubtitle =>
      'Select the type of emergency you\'re experiencing';

  @override
  String get incidentBreakIn => 'Break-In';

  @override
  String get incidentBeingFollowed => 'Being Followed';

  @override
  String get incidentHijacking => 'Hijacking';

  @override
  String get incidentDomesticViolence => 'Domestic Violence';

  @override
  String get incidentMedicalEmergency => 'Medical Emergency';

  @override
  String get incidentFire => 'Fire';

  @override
  String get incidentAssault => 'Assault';

  @override
  String get incidentOther => 'Other';

  @override
  String get sendingAlert => 'Sending your alert...';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get adminResponded => 'An admin has responded to your alert.';

  @override
  String referenceLabel(String ref) {
    return 'Reference: $ref';
  }

  @override
  String get noResponseWindow =>
      'No response was received within the 5-minute window.';

  @override
  String get downloadPonr => 'Download PONR (Proof of Non-Response)';

  @override
  String waitingForResponse(String time) {
    return 'Waiting for response... $time';
  }

  @override
  String get emergencyDispatchMessage =>
      'Help is being dispatched to your location. Stay calm and follow safety protocols.';

  @override
  String emergencyTitle(String type) {
    return 'Emergency: $type';
  }

  @override
  String contactNeedsHelp(String name) {
    return '$name needs help';
  }

  @override
  String get callAction => 'Call';

  @override
  String get locationAction => 'Location';

  @override
  String get emergencyContactsTitle => 'Emergency Contacts';

  @override
  String get emergencyContactsSubtitle =>
      'The people who get notified when you need help';

  @override
  String get protectedLabel => 'Protected';

  @override
  String get pendingLabel => 'Pending';

  @override
  String get addFromContacts => 'Add From Contacts';

  @override
  String get contactsWhyBanner =>
      'A contact can only receive your live alerts once they install Safety & Accountability. Send them an invite to switch them from Pending to Protected.';

  @override
  String get yourCircle => 'Your Circle';

  @override
  String get noContactsYet => 'No emergency contacts yet';

  @override
  String get addSomeoneYouTrust =>
      'Add someone you trust from your phone contacts';

  @override
  String get couldNotLoadContacts => 'Could not load contacts.';

  @override
  String get invitePending => 'Invite Pending';

  @override
  String get sendInvite => 'Send Invite';

  @override
  String get relationshipParent => 'Parent';

  @override
  String get relationshipSibling => 'Sibling';

  @override
  String get relationshipPartner => 'Partner';

  @override
  String get relationshipFriend => 'Friend';

  @override
  String get relationshipRoommate => 'Roommate';

  @override
  String get relationshipColleague => 'Colleague';

  @override
  String get relationshipOther => 'Other';

  @override
  String addPersonTitle(String name) {
    return 'Add $name';
  }

  @override
  String get howDoYouKnowThisPerson => 'How do you know this person?';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get chooseAContact => 'Choose a Contact';

  @override
  String get searchContacts => 'Search contacts...';

  @override
  String get noContactsFound => 'No contacts found';

  @override
  String get retry => 'Retry';

  @override
  String get close => 'Close';

  @override
  String get join => 'Join';

  @override
  String get leave => 'Leave';

  @override
  String get authWelcomeBack => 'Welcome back — log in to stay protected';

  @override
  String get authCreatePrompt => 'Create an account to get started';

  @override
  String get logIn => 'Log In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get fullName => 'Full Name';

  @override
  String get emailAddress => 'Email Address';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get phoneHint => 'e.g. +27 71 234 5678';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get forgotPasswordSoon => 'Password reset is coming soon.';

  @override
  String get agreeToTerms =>
      'I agree to the Terms of Service and Privacy Policy';

  @override
  String get createAccount => 'Create Account';

  @override
  String get orDivider => 'OR';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get signUpWithGoogle => 'Sign up with Google';

  @override
  String get noAccountPrompt => 'Don\'t have an account?';

  @override
  String get haveAccountPrompt => 'Already have an account?';

  @override
  String get acceptTermsSnack =>
      'Please accept the Terms & Privacy Policy to continue.';

  @override
  String get serverUnreachable =>
      'Could not reach the server. Check your connection and try again.';

  @override
  String get googleSoon => 'Google Sign-In is coming soon.';

  @override
  String get fullNameRequired => 'Full name is required';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get emailInvalid => 'Enter a valid email address';

  @override
  String get phoneRequired => 'Phone number is required';

  @override
  String get phoneInvalid => 'Enter a valid phone number';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get passwordTooShort => 'Use at least 8 characters';

  @override
  String get confirmPasswordRequired => 'Confirm your password';

  @override
  String get passwordsDontMatch => 'Passwords don\'t match';

  @override
  String get locationServicesOff =>
      'Location services are off — showing a default area instead.';

  @override
  String get locationPermissionDenied =>
      'Location permission was denied — showing a default area instead.';

  @override
  String get locationFailed =>
      'Couldn\'t get your current location — showing a default area instead.';

  @override
  String get gettingLocation => 'Getting your location...';

  @override
  String get defaultArea => 'Default area';

  @override
  String get youAreHere => 'You are here';

  @override
  String get somethingWentWrong => 'Something went wrong.';

  @override
  String get panicAlertActive => 'PANIC ALERT ACTIVE';

  @override
  String get noResponseYet =>
      'No response yet — stay alert and seek help if you can.';

  @override
  String get liveLocationShared => 'Live location shared';

  @override
  String get adminNotified => 'Admin notified';

  @override
  String get imSafeCancel => 'I\'m Safe — Cancel Alert';

  @override
  String contextTripAttached(String service) {
    return '$service details attached';
  }

  @override
  String get contextNoTrip => 'No active trip attached';

  @override
  String contextCommunityNotified(String community) {
    return '$community notified';
  }

  @override
  String get contextPassengerAttached => 'Current passenger attached';

  @override
  String get contextNoCommunity => 'No community joined';

  @override
  String get passengerMode => 'Passenger Mode';

  @override
  String get driverMode => 'Driver Mode';

  @override
  String get switchLabel => 'Switch';

  @override
  String get ehailingSafetyTitle => 'E-Hailing Safety';

  @override
  String get ehailingRoleSubtitle =>
      'Before we start, tell us which side of the ride you\'re on';

  @override
  String get imAPassenger => 'I\'m a Passenger';

  @override
  String get passengerDesc =>
      'Share your trip and driver details with your emergency contacts automatically.';

  @override
  String get imADriver => 'I\'m a Driver';

  @override
  String get driverDesc =>
      'Join your driver community, log passenger details, and trigger a panic alert if you need help.';

  @override
  String get triggerPanicTitle => 'Trigger Panic Alert?';

  @override
  String get panicConfirmWithTrip =>
      'This will immediately notify an admin with your live location and this trip\'s details.';

  @override
  String get panicConfirmNoTrip =>
      'This will immediately notify an admin with your live location.';

  @override
  String get triggerAlert => 'Trigger Alert';

  @override
  String get pickRideApp =>
      'Pick your ride app. Your trip details will be shared with your protected emergency contacts.';

  @override
  String get chooseYourRide => 'Choose Your Ride';

  @override
  String tripDetailsTitle(String service) {
    return '$service Trip Details';
  }

  @override
  String get driverNameLabel => 'Driver\'s Name *';

  @override
  String get driverNameHint => 'As shown in the app';

  @override
  String get vehicleRegLabel => 'Vehicle Reg *';

  @override
  String get vehicleRegHint => 'e.g. CA 123-456';

  @override
  String get vehicleColorLabel => 'Vehicle Color';

  @override
  String get vehicleColorHint => 'e.g. White';

  @override
  String get vehicleModelLabel => 'Vehicle Make & Model';

  @override
  String get vehicleModelHint => 'e.g. Toyota Corolla';

  @override
  String get pickupLocationLabel => 'Pickup Location';

  @override
  String get pickupLocationHint => 'Where you got in';

  @override
  String get destinationLabel => 'Destination';

  @override
  String get destinationHint => 'Where you\'re headed';

  @override
  String get verificationPinLabel => 'Driver\'s Verification PIN';

  @override
  String get verificationPinHint => 'Ask the driver for their passenger PIN';

  @override
  String get pinWarning =>
      'Many trusted apps give drivers a PIN for their logged passenger. If the driver can\'t give you one, or it doesn\'t match what you were told, treat that as a warning sign before you get in.';

  @override
  String get tripSharedInfo =>
      'Once shared, your trip is sent live to your Protected emergency contacts.';

  @override
  String get sharingEllipsis => 'Sharing...';

  @override
  String get shareTripButton => 'Share Trip With Emergency Contacts';

  @override
  String get tripSharedSuccess => 'Trip Shared Successfully';

  @override
  String startedAt(String time) {
    return 'Started at $time';
  }

  @override
  String get sentTo => 'Sent to';

  @override
  String get endingEllipsis => 'Ending...';

  @override
  String get endTrip => 'End Trip';

  @override
  String get rowDriver => 'Driver';

  @override
  String get rowRegistration => 'Registration';

  @override
  String get rowVehicle => 'Vehicle';

  @override
  String get rowPickup => 'Pickup';

  @override
  String get rowDestination => 'Destination';

  @override
  String get rowPinConfirmed => 'PIN Confirmed';

  @override
  String get rowNotes => 'Notes';

  @override
  String get noProtectedContacts =>
      'No Protected contacts yet — add contacts and invite them to install the app.';

  @override
  String get createCommunityTitle => 'Create a Community';

  @override
  String get communityNameLabel => 'Community name';

  @override
  String get communityAreaLabel => 'Area it covers';

  @override
  String get createAndJoin => 'Create & Join';

  @override
  String get inDanger => 'In Danger?';

  @override
  String get alertsAdminInstantly =>
      'Alerts an admin instantly with your location';

  @override
  String get driverCommunity => 'Driver Community';

  @override
  String get joinCommunityPrompt =>
      'Join a community so help can reach you fast, or start your own';

  @override
  String get noCommunitiesYet =>
      'No communities yet — be the first to create one.';

  @override
  String membersCount(String area, int count) {
    return '$area · $count members';
  }

  @override
  String get createNewCommunity => 'Create New Community';

  @override
  String get communityUpdatesInfo =>
      'Real-time updates from drivers in your community';

  @override
  String get shareUpdateHint => 'Share an update with your community...';

  @override
  String get noPostsYet => 'No posts yet in this community.';

  @override
  String get logThisPassenger => 'Log This Passenger';

  @override
  String get logPassengerSubtitle =>
      'Capture the full trip so both of you are protected if something goes wrong';

  @override
  String get passengerNameLabel => 'Passenger\'s Name *';

  @override
  String get passengerNameHint => 'As they introduced themselves';

  @override
  String get passengerPhoneLabel => 'Passenger\'s Phone Number';

  @override
  String get passengerPhoneHint => 'Optional, for your records';

  @override
  String get pickupPointLabel => 'Pickup Point';

  @override
  String get pickupPointHint => 'Where you collected them';

  @override
  String get dropoffHint => 'Where you\'re dropping off';

  @override
  String get passengersInVehicle => 'Passengers in vehicle';

  @override
  String get notesOptionalLabel => 'Notes (optional)';

  @override
  String get notesHint =>
      'e.g. regular client, going to hospital, seemed anxious';

  @override
  String get photoCaptured => 'Photo captured — tap to retake';

  @override
  String get addPassengerPhoto => 'Add a quick passenger photo (optional)';

  @override
  String get pinGeneratedInfo =>
      'A one-time verification PIN will be generated so the passenger can confirm they\'re getting into the right vehicle.';

  @override
  String get loggingEllipsis => 'Logging...';

  @override
  String get logPassengerButton => 'Log Passenger & Generate PIN';

  @override
  String get passengerLogged => 'Passenger Logged';

  @override
  String get verificationPinCaps => 'VERIFICATION PIN';

  @override
  String get tellPassengerPin =>
      'Tell the passenger this PIN before they get in';

  @override
  String passengersCountLabel(int count) {
    return 'Passengers: $count';
  }

  @override
  String get attachedToRecord =>
      'This passenger is attached to your account record';

  @override
  String get autoSafetyCheckIn => 'Auto Safety Check-In';

  @override
  String get autoCheckInSub => 'Logged with this trip for admin visibility';

  @override
  String get markDroppedOff => 'Mark Passenger Dropped Off Safely';

  @override
  String get savingEllipsis => 'Saving...';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int n) {
    return '${n}m ago';
  }

  @override
  String hoursAgo(int n) {
    return '${n}h ago';
  }

  @override
  String daysAgo(int n) {
    return '${n}d ago';
  }
}
