import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @languageName.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// No description provided for @languagePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languagePickerTitle;

  /// No description provided for @languagePickerHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a language for this register'**
  String get languagePickerHint;

  /// No description provided for @appearancePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearancePickerTitle;

  /// No description provided for @appearancePickerHint.
  ///
  /// In en, this message translates to:
  /// **'Choose how this app looks'**
  String get appearancePickerHint;

  /// No description provided for @themeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeModeSystem;

  /// No description provided for @themeModeSystemHint.
  ///
  /// In en, this message translates to:
  /// **'Match the device light or dark setting'**
  String get themeModeSystemHint;

  /// No description provided for @themeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeModeLight;

  /// No description provided for @themeModeLightHint.
  ///
  /// In en, this message translates to:
  /// **'Always use the light theme'**
  String get themeModeLightHint;

  /// No description provided for @themeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeModeDark;

  /// No description provided for @themeModeDarkHint.
  ///
  /// In en, this message translates to:
  /// **'Always use the dark theme'**
  String get themeModeDarkHint;

  /// No description provided for @shellAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get shellAppearance;

  /// No description provided for @shellAutoLock.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock'**
  String get shellAutoLock;

  /// No description provided for @autoLockPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock'**
  String get autoLockPickerTitle;

  /// No description provided for @autoLockPickerHint.
  ///
  /// In en, this message translates to:
  /// **'Choose whether this register locks itself when idle'**
  String get autoLockPickerHint;

  /// No description provided for @autoLockEnabled.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get autoLockEnabled;

  /// No description provided for @autoLockEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'Lock after 2 minutes of inactivity'**
  String get autoLockEnabledHint;

  /// No description provided for @autoLockDisabled.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get autoLockDisabled;

  /// No description provided for @autoLockDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Stay unlocked until you lock manually'**
  String get autoLockDisabledHint;

  /// No description provided for @adminManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get adminManage;

  /// No description provided for @adminManageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Menu, tables, orders, and reports'**
  String get adminManageSubtitle;

  /// No description provided for @adminMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get adminMenu;

  /// No description provided for @adminTables.
  ///
  /// In en, this message translates to:
  /// **'Tables'**
  String get adminTables;

  /// No description provided for @adminOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get adminOrders;

  /// No description provided for @adminOrdersPeriodToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get adminOrdersPeriodToday;

  /// No description provided for @adminOrdersPeriodYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get adminOrdersPeriodYesterday;

  /// No description provided for @adminOrdersPeriodLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get adminOrdersPeriodLast7Days;

  /// No description provided for @adminOrdersPeriodAll.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get adminOrdersPeriodAll;

  /// No description provided for @adminOrdersPaymentAll.
  ///
  /// In en, this message translates to:
  /// **'All payments'**
  String get adminOrdersPaymentAll;

  /// No description provided for @adminOrdersPaymentUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get adminOrdersPaymentUnpaid;

  /// No description provided for @adminOrdersPaymentPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get adminOrdersPaymentPaid;

  /// No description provided for @adminOrdersChannelCaptain.
  ///
  /// In en, this message translates to:
  /// **'POS - Captain'**
  String get adminOrdersChannelCaptain;

  /// No description provided for @adminOrdersChannelPos.
  ///
  /// In en, this message translates to:
  /// **'POS'**
  String get adminOrdersChannelPos;

  /// No description provided for @adminOrdersChannelRegister.
  ///
  /// In en, this message translates to:
  /// **'POS'**
  String get adminOrdersChannelRegister;

  /// No description provided for @adminOrdersChannelKiosk.
  ///
  /// In en, this message translates to:
  /// **'Kiosk'**
  String get adminOrdersChannelKiosk;

  /// No description provided for @adminOrdersChannelOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get adminOrdersChannelOnline;

  /// No description provided for @adminOrdersChannelApp.
  ///
  /// In en, this message translates to:
  /// **'Mobile app'**
  String get adminOrdersChannelApp;

  /// No description provided for @adminOrdersChannelApi.
  ///
  /// In en, this message translates to:
  /// **'API'**
  String get adminOrdersChannelApi;

  /// No description provided for @adminOrdersChannelUnknown.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get adminOrdersChannelUnknown;

  /// No description provided for @adminOrdersTableMeta.
  ///
  /// In en, this message translates to:
  /// **'Table {name}'**
  String adminOrdersTableMeta(String name);

  /// No description provided for @adminTokenShort.
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get adminTokenShort;

  /// No description provided for @adminOrdersAutoRefresh.
  ///
  /// In en, this message translates to:
  /// **'Auto-refresh · {time}'**
  String adminOrdersAutoRefresh(String time);

  /// No description provided for @adminModifiers.
  ///
  /// In en, this message translates to:
  /// **'Modifiers'**
  String get adminModifiers;

  /// No description provided for @adminTimeSlots.
  ///
  /// In en, this message translates to:
  /// **'Time slots'**
  String get adminTimeSlots;

  /// No description provided for @adminHours.
  ///
  /// In en, this message translates to:
  /// **'Hours & availability'**
  String get adminHours;

  /// No description provided for @adminHoursSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Store open/close and weekly schedule'**
  String get adminHoursSubtitle;

  /// No description provided for @storeOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get storeOpen;

  /// No description provided for @storeClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get storeClosed;

  /// No description provided for @storeOutsideHours.
  ///
  /// In en, this message translates to:
  /// **'Outside hours'**
  String get storeOutsideHours;

  /// No description provided for @storePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get storePaused;

  /// No description provided for @storeCloseTitle.
  ///
  /// In en, this message translates to:
  /// **'Close store to guests?'**
  String get storeCloseTitle;

  /// No description provided for @storeCloseMessage.
  ///
  /// In en, this message translates to:
  /// **'Storefront and kiosk will stop taking new orders. POS stays available.'**
  String get storeCloseMessage;

  /// No description provided for @storeCloseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Close to guests'**
  String get storeCloseConfirm;

  /// No description provided for @storeOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Open store to guests?'**
  String get storeOpenTitle;

  /// No description provided for @storeOpenMessage.
  ///
  /// In en, this message translates to:
  /// **'Storefront and kiosk can accept new orders again (subject to weekly hours).'**
  String get storeOpenMessage;

  /// No description provided for @storeOpenConfirm.
  ///
  /// In en, this message translates to:
  /// **'Open to guests'**
  String get storeOpenConfirm;

  /// No description provided for @storeGuestStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Guest ordering is open'**
  String get storeGuestStatusOpen;

  /// No description provided for @storeGuestStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Guest ordering is paused'**
  String get storeGuestStatusPaused;

  /// No description provided for @storeGuestStatusOutsideHours.
  ///
  /// In en, this message translates to:
  /// **'Outside weekly hours'**
  String get storeGuestStatusOutsideHours;

  /// No description provided for @storeGuestStatusOther.
  ///
  /// In en, this message translates to:
  /// **'Guest ordering is unavailable'**
  String get storeGuestStatusOther;

  /// No description provided for @storeAcceptOnlineOrders.
  ///
  /// In en, this message translates to:
  /// **'Restaurant is open'**
  String get storeAcceptOnlineOrders;

  /// No description provided for @storeAcceptOnlineOrdersHelp.
  ///
  /// In en, this message translates to:
  /// **'When off, storefront and kiosk pause. POS keeps working.'**
  String get storeAcceptOnlineOrdersHelp;

  /// No description provided for @storeScheduleEnabled.
  ///
  /// In en, this message translates to:
  /// **'Use weekly hours'**
  String get storeScheduleEnabled;

  /// No description provided for @storeScheduleEnabledHelp.
  ///
  /// In en, this message translates to:
  /// **'When on, guest channels close outside the schedule below.'**
  String get storeScheduleEnabledHelp;

  /// No description provided for @storeTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get storeTimezone;

  /// No description provided for @storeClosedMessage.
  ///
  /// In en, this message translates to:
  /// **'Closed message'**
  String get storeClosedMessage;

  /// No description provided for @storeClosedMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Shown when guests cannot order'**
  String get storeClosedMessageHint;

  /// No description provided for @storeScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly hours'**
  String get storeScheduleTitle;

  /// No description provided for @storeAddShift.
  ///
  /// In en, this message translates to:
  /// **'Add shift'**
  String get storeAddShift;

  /// No description provided for @storeCopyWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Copy Mon to weekdays'**
  String get storeCopyWeekdays;

  /// No description provided for @storeDayClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get storeDayClosed;

  /// No description provided for @storePosNote.
  ///
  /// In en, this message translates to:
  /// **'POS register keeps working when guest orders are closed.'**
  String get storePosNote;

  /// No description provided for @storeHoursSaved.
  ///
  /// In en, this message translates to:
  /// **'Hours saved'**
  String get storeHoursSaved;

  /// No description provided for @storeOpensAt.
  ///
  /// In en, this message translates to:
  /// **'Opens {when}'**
  String storeOpensAt(String when);

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonPleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait'**
  String get commonPleaseWait;

  /// No description provided for @commonSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonSomethingWentWrong;

  /// No description provided for @commonChangeServer.
  ///
  /// In en, this message translates to:
  /// **'Change server'**
  String get commonChangeServer;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get commonPrint;

  /// No description provided for @commonSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get commonSignOut;

  /// No description provided for @commonTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get commonTotal;

  /// No description provided for @commonSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get commonSubtotal;

  /// No description provided for @commonPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get commonPaid;

  /// No description provided for @commonUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get commonUnpaid;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// No description provided for @authStaffSignIn.
  ///
  /// In en, this message translates to:
  /// **'Staff sign in'**
  String get authStaffSignIn;

  /// No description provided for @authSignInOnce.
  ///
  /// In en, this message translates to:
  /// **'Sign in once, then unlock with your POS PIN'**
  String get authSignInOnce;

  /// No description provided for @authUseStaffEmail.
  ///
  /// In en, this message translates to:
  /// **'Use your staff email and password'**
  String get authUseStaffEmail;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authPairDeviceFirst.
  ///
  /// In en, this message translates to:
  /// **'Optional: bind this register'**
  String get authPairDeviceFirst;

  /// No description provided for @authChangePairedRegister.
  ///
  /// In en, this message translates to:
  /// **'Change paired register'**
  String get authChangePairedRegister;

  /// No description provided for @authRegisterPaired.
  ///
  /// In en, this message translates to:
  /// **'Register paired'**
  String get authRegisterPaired;

  /// No description provided for @authStaffPos.
  ///
  /// In en, this message translates to:
  /// **'Staff POS'**
  String get authStaffPos;

  /// No description provided for @authReadyForCashier.
  ///
  /// In en, this message translates to:
  /// **'Ready for staff sign-in'**
  String get authReadyForCashier;

  /// No description provided for @authPairThenSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your staff account'**
  String get authPairThenSignIn;

  /// No description provided for @authThisRegisterPaired.
  ///
  /// In en, this message translates to:
  /// **'Register is set — staff still sign in with email & password'**
  String get authThisRegisterPaired;

  /// No description provided for @setupServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Server setup'**
  String get setupServerTitle;

  /// No description provided for @setupConnectRegister.
  ///
  /// In en, this message translates to:
  /// **'Connect this register to your {app} server, then sign in and start taking orders.'**
  String setupConnectRegister(String app);

  /// No description provided for @setupServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get setupServerUrl;

  /// No description provided for @pairDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Optional register bind'**
  String get pairDeviceTitle;

  /// No description provided for @pairBindTerminal.
  ///
  /// In en, this message translates to:
  /// **'Remember which register this tablet is'**
  String get pairBindTerminal;

  /// No description provided for @pairFooterNote.
  ///
  /// In en, this message translates to:
  /// **'Pairing does not sign you in. It only remembers this register so staff skip picking a terminal after login.'**
  String get pairFooterNote;

  /// No description provided for @pairNewCode.
  ///
  /// In en, this message translates to:
  /// **'New code'**
  String get pairNewCode;

  /// No description provided for @pairSkipToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Skip — just sign in'**
  String get pairSkipToSignIn;

  /// No description provided for @lockRegisterLocked.
  ///
  /// In en, this message translates to:
  /// **'Register locked'**
  String get lockRegisterLocked;

  /// No description provided for @lockWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get lockWelcomeBack;

  /// No description provided for @lockWelcomeBackNamed.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String lockWelcomeBackNamed(String name);

  /// No description provided for @lockSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String lockSignedInAs(String name);

  /// No description provided for @lockEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your 6-digit POS PIN'**
  String get lockEnterPin;

  /// No description provided for @lockUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get lockUnlock;

  /// No description provided for @lockUnlocking.
  ///
  /// In en, this message translates to:
  /// **'Unlocking…'**
  String get lockUnlocking;

  /// No description provided for @lockUnlockWithPin.
  ///
  /// In en, this message translates to:
  /// **'Unlock with your POS PIN to continue'**
  String get lockUnlockWithPin;

  /// No description provided for @shellOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get shellOrders;

  /// No description provided for @shellReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get shellReports;

  /// No description provided for @shellHeld.
  ///
  /// In en, this message translates to:
  /// **'Held'**
  String get shellHeld;

  /// No description provided for @shellLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get shellLanguage;

  /// No description provided for @shellCheckForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get shellCheckForUpdates;

  /// No description provided for @shellKeyboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get shellKeyboardShortcuts;

  /// No description provided for @shellLockRegister.
  ///
  /// In en, this message translates to:
  /// **'Lock register'**
  String get shellLockRegister;

  /// No description provided for @opsOpenShift.
  ///
  /// In en, this message translates to:
  /// **'Open shift'**
  String get opsOpenShift;

  /// No description provided for @opsCloseShift.
  ///
  /// In en, this message translates to:
  /// **'Close shift'**
  String get opsCloseShift;

  /// No description provided for @cartHold.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get cartHold;

  /// No description provided for @cartPay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get cartPay;

  /// No description provided for @cartClear.
  ///
  /// In en, this message translates to:
  /// **'Clear cart'**
  String get cartClear;

  /// No description provided for @cartEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Cart is empty'**
  String get cartEmptyTitle;

  /// No description provided for @cartEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap menu items to start a ticket'**
  String get cartEmptySubtitle;

  /// No description provided for @cartHeldTicket.
  ///
  /// In en, this message translates to:
  /// **'Held ticket {label}'**
  String cartHeldTicket(String label);

  /// No description provided for @cartReplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace current ticket?'**
  String get cartReplaceTitle;

  /// No description provided for @cartReplaceMessage.
  ///
  /// In en, this message translates to:
  /// **'Resuming this held order will overwrite the items currently on the cart.'**
  String get cartReplaceMessage;

  /// No description provided for @cartResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get cartResume;

  /// No description provided for @ordersTitle.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get ordersTitle;

  /// No description provided for @ordersHeldTab.
  ///
  /// In en, this message translates to:
  /// **'Held'**
  String get ordersHeldTab;

  /// No description provided for @ordersOrdersTab.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get ordersOrdersTab;

  /// No description provided for @ordersHeldSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Parked drafts waiting to be resumed'**
  String get ordersHeldSubtitle;

  /// No description provided for @ordersHeldCountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} parked ticket ready to resume'**
  String ordersHeldCountSubtitle(int count);

  /// No description provided for @ordersHeldCountSubtitlePlural.
  ///
  /// In en, this message translates to:
  /// **'{count} parked tickets ready to resume'**
  String ordersHeldCountSubtitlePlural(int count);

  /// No description provided for @ordersBranchActivity.
  ///
  /// In en, this message translates to:
  /// **'Branch activity on this register'**
  String get ordersBranchActivity;

  /// No description provided for @ordersHeldHint.
  ///
  /// In en, this message translates to:
  /// **'Hold parks the current cart. Resume loads it back so you can keep editing or pay.'**
  String get ordersHeldHint;

  /// No description provided for @ordersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search order #, customer, table…'**
  String get ordersSearchHint;

  /// No description provided for @ordersFilterToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get ordersFilterToday;

  /// No description provided for @ordersFilterUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get ordersFilterUnpaid;

  /// No description provided for @ordersFilterSevenDays.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get ordersFilterSevenDays;

  /// No description provided for @ordersNoHeldTitle.
  ///
  /// In en, this message translates to:
  /// **'No held tickets'**
  String get ordersNoHeldTitle;

  /// No description provided for @ordersNoHeldSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap Hold on the cart to park a draft, then resume it here.'**
  String get ordersNoHeldSubtitle;

  /// No description provided for @ordersNoOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'No orders found'**
  String get ordersNoOrdersTitle;

  /// No description provided for @ordersNoOrdersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try another filter or search term.'**
  String get ordersNoOrdersSubtitle;

  /// No description provided for @ordersCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load orders'**
  String get ordersCouldNotLoad;

  /// No description provided for @ordersResumeTicket.
  ///
  /// In en, this message translates to:
  /// **'Resume ticket'**
  String get ordersResumeTicket;

  /// No description provided for @ordersAlreadyOnCart.
  ///
  /// In en, this message translates to:
  /// **'Already on cart'**
  String get ordersAlreadyOnCart;

  /// No description provided for @ordersOnCart.
  ///
  /// In en, this message translates to:
  /// **'On cart'**
  String get ordersOnCart;

  /// No description provided for @ordersHeldTicket.
  ///
  /// In en, this message translates to:
  /// **'Held ticket'**
  String get ordersHeldTicket;

  /// No description provided for @ordersCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect {amount}'**
  String ordersCollect(String amount);

  /// No description provided for @ordersPrintReceipt.
  ///
  /// In en, this message translates to:
  /// **'Print receipt'**
  String get ordersPrintReceipt;

  /// No description provided for @ordersPrintKot.
  ///
  /// In en, this message translates to:
  /// **'Print KOT'**
  String get ordersPrintKot;

  /// No description provided for @ordersDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get ordersDetailTitle;

  /// No description provided for @ordersDetailLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading order…'**
  String get ordersDetailLoading;

  /// No description provided for @ordersDetailItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get ordersDetailItems;

  /// No description provided for @ordersDetailNoItems.
  ///
  /// In en, this message translates to:
  /// **'No line items'**
  String get ordersDetailNoItems;

  /// No description provided for @ordersDetailPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get ordersDetailPaid;

  /// No description provided for @ordersDetailDue.
  ///
  /// In en, this message translates to:
  /// **'Amount due'**
  String get ordersDetailDue;

  /// No description provided for @printKotPrinted.
  ///
  /// In en, this message translates to:
  /// **'KOT printed for {label}'**
  String printKotPrinted(String label);

  /// No description provided for @ordersPaymentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded for {label}'**
  String ordersPaymentRecorded(String label);

  /// No description provided for @ordersPaymentReceived.
  ///
  /// In en, this message translates to:
  /// **'Payment received for {label}'**
  String ordersPaymentReceived(String label);

  /// No description provided for @ordersPaymentNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Payment not completed for {label}'**
  String ordersPaymentNotCompleted(String label);

  /// No description provided for @ordersLoaded.
  ///
  /// In en, this message translates to:
  /// **'Loaded {label}'**
  String ordersLoaded(String label);

  /// No description provided for @ordersUpdated.
  ///
  /// In en, this message translates to:
  /// **'Order updated'**
  String get ordersUpdated;

  /// No description provided for @ordersCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this order?'**
  String get ordersCancelTitle;

  /// No description provided for @ordersCancelMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes the order from the kitchen flow. You can’t undo this.'**
  String get ordersCancelMessage;

  /// No description provided for @ordersCancelPaidMessage.
  ///
  /// In en, this message translates to:
  /// **'This order is marked paid ({amount}). Cancel only keeps the payment on record, or cancel and refund to mark it refunded (return cash/card manually).'**
  String ordersCancelPaidMessage(String amount);

  /// No description provided for @ordersCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get ordersCancelConfirm;

  /// No description provided for @ordersCancelAndRefund.
  ///
  /// In en, this message translates to:
  /// **'Cancel & refund'**
  String get ordersCancelAndRefund;

  /// No description provided for @ordersCancelKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep order'**
  String get ordersCancelKeep;

  /// No description provided for @ordersCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled'**
  String get ordersCancelled;

  /// No description provided for @ordersCancelledRefunded.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled and marked refunded'**
  String get ordersCancelledRefunded;

  /// No description provided for @ordersCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get ordersCancelAction;

  /// No description provided for @payTakePayment.
  ///
  /// In en, this message translates to:
  /// **'Take payment'**
  String get payTakePayment;

  /// No description provided for @payCollectPayment.
  ///
  /// In en, this message translates to:
  /// **'Collect payment'**
  String get payCollectPayment;

  /// No description provided for @payAmountDue.
  ///
  /// In en, this message translates to:
  /// **'AMOUNT DUE'**
  String get payAmountDue;

  /// No description provided for @payCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get payCash;

  /// No description provided for @payCashSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tender & change'**
  String get payCashSubtitle;

  /// No description provided for @payCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get payCard;

  /// No description provided for @payCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get payCardSubtitle;

  /// No description provided for @payWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get payWallet;

  /// No description provided for @payWalletSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Digital pay'**
  String get payWalletSubtitle;

  /// No description provided for @payOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get payOther;

  /// No description provided for @payOtherSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Voucher, etc.'**
  String get payOtherSubtitle;

  /// No description provided for @payLater.
  ///
  /// In en, this message translates to:
  /// **'Pay later'**
  String get payLater;

  /// No description provided for @payLaterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open tab'**
  String get payLaterSubtitle;

  /// No description provided for @payUpiQr.
  ///
  /// In en, this message translates to:
  /// **'UPI QR'**
  String get payUpiQr;

  /// No description provided for @payConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm payment'**
  String get payConfirm;

  /// No description provided for @shiftOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Open shift'**
  String get shiftOpenTitle;

  /// No description provided for @shiftCloseTitle.
  ///
  /// In en, this message translates to:
  /// **'Close shift'**
  String get shiftCloseTitle;

  /// No description provided for @authAccountLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load account data from server. Try again.'**
  String get authAccountLoadFailed;

  /// No description provided for @authLoginNoToken.
  ///
  /// In en, this message translates to:
  /// **'Login did not return a token.'**
  String get authLoginNoToken;

  /// No description provided for @authNoRestaurantBranch.
  ///
  /// In en, this message translates to:
  /// **'No restaurant or branch assigned to this account.'**
  String get authNoRestaurantBranch;

  /// No description provided for @authNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get authNotSignedIn;

  /// No description provided for @authSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please sign in again.'**
  String get authSessionExpired;

  /// No description provided for @authSignOutFromLock.
  ///
  /// In en, this message translates to:
  /// **'You will need email and password to sign in again. Cancel to stay on PIN unlock.'**
  String get authSignOutFromLock;

  /// No description provided for @authSignOutMessageNoPin.
  ///
  /// In en, this message translates to:
  /// **'You will need your email and password to sign in again.'**
  String get authSignOutMessageNoPin;

  /// No description provided for @authSignOutMessageWithPin.
  ///
  /// In en, this message translates to:
  /// **'You will need your email and password, or POS PIN, to sign in again.'**
  String get authSignOutMessageWithPin;

  /// No description provided for @authSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get authSignOutTitle;

  /// No description provided for @brandTagline.
  ///
  /// In en, this message translates to:
  /// **'Fast staff ordering — sign in, open a shift, and take payments.'**
  String get brandTagline;

  /// No description provided for @cartAddCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get cartAddCustomer;

  /// No description provided for @cartClearCustomer.
  ///
  /// In en, this message translates to:
  /// **'Clear customer'**
  String get cartClearCustomer;

  /// No description provided for @cartClearMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove all items and reset customer, table, notes, and discount.'**
  String get cartClearMessage;

  /// No description provided for @cartClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear ticket?'**
  String get cartClearTitle;

  /// No description provided for @cartClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear ticket'**
  String get cartClearTooltip;

  /// No description provided for @cartCurrentTicket.
  ///
  /// In en, this message translates to:
  /// **'Current ticket'**
  String get cartCurrentTicket;

  /// No description provided for @cartCustomerFallback.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get cartCustomerFallback;

  /// No description provided for @cartCustomerNameHint.
  ///
  /// In en, this message translates to:
  /// **'Or type a name'**
  String get cartCustomerNameHint;

  /// No description provided for @cartCustomerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search name, phone, email'**
  String get cartCustomerSearchHint;

  /// No description provided for @cartEmptyPanelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap menu items to build this order.'**
  String get cartEmptyPanelSubtitle;

  /// No description provided for @cartEmptyPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Empty ticket'**
  String get cartEmptyPanelTitle;

  /// No description provided for @cartHeldSnack.
  ///
  /// In en, this message translates to:
  /// **'Ticket {label} held — open Orders → Held to resume'**
  String cartHeldSnack(String label);

  /// No description provided for @cartIsEmptyError.
  ///
  /// In en, this message translates to:
  /// **'Cart is empty.'**
  String get cartIsEmptyError;

  /// No description provided for @cartItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} item'**
  String cartItemCount(int count);

  /// No description provided for @cartItemCountPlural.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String cartItemCountPlural(int count);

  /// No description provided for @cartNoItemsYet.
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get cartNoItemsYet;

  /// No description provided for @cartNoTable.
  ///
  /// In en, this message translates to:
  /// **'No table'**
  String get cartNoTable;

  /// No description provided for @cartNoTablesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask your manager to add tables in Admin.'**
  String get cartNoTablesSubtitle;

  /// No description provided for @cartNoTablesTitle.
  ///
  /// In en, this message translates to:
  /// **'No tables configured'**
  String get cartNoTablesTitle;

  /// No description provided for @cartPayable.
  ///
  /// In en, this message translates to:
  /// **'Payable'**
  String get cartPayable;

  /// No description provided for @cartRemoveLine.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get cartRemoveLine;

  /// No description provided for @cartSaveName.
  ///
  /// In en, this message translates to:
  /// **'Save name'**
  String get cartSaveName;

  /// No description provided for @cartSelectTable.
  ///
  /// In en, this message translates to:
  /// **'Select table'**
  String get cartSelectTable;

  /// No description provided for @cartServiceCharge.
  ///
  /// In en, this message translates to:
  /// **'Service charge'**
  String get cartServiceCharge;

  /// No description provided for @cartTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get cartTable;

  /// No description provided for @cartTableNamed.
  ///
  /// In en, this message translates to:
  /// **'Table {name}'**
  String cartTableNamed(String name);

  /// No description provided for @cartTableOccupied.
  ///
  /// In en, this message translates to:
  /// **'Occupied'**
  String get cartTableOccupied;

  /// No description provided for @cartTablesLegend.
  ///
  /// In en, this message translates to:
  /// **'Available tables are green · occupied are red'**
  String get cartTablesLegend;

  /// No description provided for @cartTablesOther.
  ///
  /// In en, this message translates to:
  /// **'OTHER'**
  String get cartTablesOther;

  /// No description provided for @cartTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get cartTax;

  /// No description provided for @cartTicketNotes.
  ///
  /// In en, this message translates to:
  /// **'Ticket notes'**
  String get cartTicketNotes;

  /// No description provided for @cartTicketNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Ticket notes'**
  String get cartTicketNotesHint;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

  /// No description provided for @confirmDestructiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone easily'**
  String get confirmDestructiveSubtitle;

  /// No description provided for @connIssueFooter.
  ///
  /// In en, this message translates to:
  /// **'Check the server URL and try again.'**
  String get connIssueFooter;

  /// No description provided for @connIssueTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection issue'**
  String get connIssueTitle;

  /// No description provided for @connUnableToReach.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the server.'**
  String get connUnableToReach;

  /// No description provided for @subscriptionEndedTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription ended'**
  String get subscriptionEndedTitle;

  /// No description provided for @subscriptionTrialEndedTitle.
  ///
  /// In en, this message translates to:
  /// **'Trial ended'**
  String get subscriptionTrialEndedTitle;

  /// No description provided for @subscriptionEndedBody.
  ///
  /// In en, this message translates to:
  /// **'This restaurant\'s subscription is inactive. Ask an owner to renew billing to keep using POS.'**
  String get subscriptionEndedBody;

  /// No description provided for @subscriptionTrialEndedBody.
  ///
  /// In en, this message translates to:
  /// **'This restaurant\'s free trial has ended. Ask an owner to choose a plan to continue.'**
  String get subscriptionTrialEndedBody;

  /// No description provided for @subscriptionEndedFooter.
  ///
  /// In en, this message translates to:
  /// **'POS stays locked until billing is active again.'**
  String get subscriptionEndedFooter;

  /// No description provided for @billingTitle.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get billingTitle;

  /// No description provided for @billingManageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Plans, trial, and subscription'**
  String get billingManageSubtitle;

  /// No description provided for @billingUpgradePlan.
  ///
  /// In en, this message translates to:
  /// **'Upgrade plan'**
  String get billingUpgradePlan;

  /// No description provided for @billingUpgradeBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a plan to restore POS access for this restaurant.'**
  String get billingUpgradeBody;

  /// No description provided for @billingRenewBody.
  ///
  /// In en, this message translates to:
  /// **'Your subscription is inactive. Choose a plan to restore POS access.'**
  String get billingRenewBody;

  /// No description provided for @billingUpgradeFooter.
  ///
  /// In en, this message translates to:
  /// **'POS unlocks as soon as a plan is active.'**
  String get billingUpgradeFooter;

  /// No description provided for @billingChoosePlan.
  ///
  /// In en, this message translates to:
  /// **'Pick a plan for this restaurant.'**
  String get billingChoosePlan;

  /// No description provided for @billingMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get billingMonthly;

  /// No description provided for @billingYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get billingYearly;

  /// No description provided for @billingSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get billingSubscribe;

  /// No description provided for @billingActivateFree.
  ///
  /// In en, this message translates to:
  /// **'Activate free plan'**
  String get billingActivateFree;

  /// No description provided for @billingCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get billingCurrentPlan;

  /// No description provided for @billingPayWith.
  ///
  /// In en, this message translates to:
  /// **'Pay with {provider}'**
  String billingPayWith(String provider);

  /// No description provided for @billingPaymentOff.
  ///
  /// In en, this message translates to:
  /// **'Online checkout is not enabled. Activate a free plan, or ask support to enable payments.'**
  String get billingPaymentOff;

  /// No description provided for @billingPaymentProvider.
  ///
  /// In en, this message translates to:
  /// **'the payment provider'**
  String get billingPaymentProvider;

  /// No description provided for @billingCoveredBody.
  ///
  /// In en, this message translates to:
  /// **'Billing for this restaurant is managed by {org}. Ask that organization to renew the plan.'**
  String billingCoveredBody(String org);

  /// No description provided for @billingOrganization.
  ///
  /// In en, this message translates to:
  /// **'the organization'**
  String get billingOrganization;

  /// No description provided for @billingIvePaid.
  ///
  /// In en, this message translates to:
  /// **'I\'ve paid — continue'**
  String get billingIvePaid;

  /// No description provided for @billingReturnFromCheckout.
  ///
  /// In en, this message translates to:
  /// **'Finish payment in the browser, then tap below to unlock POS.'**
  String get billingReturnFromCheckout;

  /// No description provided for @billingNoPlans.
  ///
  /// In en, this message translates to:
  /// **'No plans are available right now.'**
  String get billingNoPlans;

  /// No description provided for @billingFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get billingFree;

  /// No description provided for @billingPerMonth.
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get billingPerMonth;

  /// No description provided for @billingPerYear.
  ///
  /// In en, this message translates to:
  /// **'year'**
  String get billingPerYear;

  /// No description provided for @billingActivated.
  ///
  /// In en, this message translates to:
  /// **'Plan activated'**
  String get billingActivated;

  /// No description provided for @billingPaymentPending.
  ///
  /// In en, this message translates to:
  /// **'Payment is not confirmed yet. Finish checkout, then try again.'**
  String get billingPaymentPending;

  /// No description provided for @contextBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get contextBranch;

  /// No description provided for @contextChooseLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose location'**
  String get contextChooseLocation;

  /// No description provided for @contextCurrentRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Current restaurant'**
  String get contextCurrentRestaurant;

  /// No description provided for @contextDefaultBranch.
  ///
  /// In en, this message translates to:
  /// **'Default branch'**
  String get contextDefaultBranch;

  /// No description provided for @contextFooterNote.
  ///
  /// In en, this message translates to:
  /// **'Pick where this register will take orders today.'**
  String get contextFooterNote;

  /// No description provided for @contextNoOtherLocation.
  ///
  /// In en, this message translates to:
  /// **'No other restaurant or branch is available for this account.'**
  String get contextNoOtherLocation;

  /// No description provided for @contextRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get contextRestaurant;

  /// No description provided for @contextSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select the restaurant and branch for this register session.'**
  String get contextSubtitle;

  /// No description provided for @dietNonVeg.
  ///
  /// In en, this message translates to:
  /// **'Non-veg'**
  String get dietNonVeg;

  /// No description provided for @dietVeg.
  ///
  /// In en, this message translates to:
  /// **'Veg'**
  String get dietVeg;

  /// No description provided for @dietVegan.
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get dietVegan;

  /// No description provided for @dietEgg.
  ///
  /// In en, this message translates to:
  /// **'Egg'**
  String get dietEgg;

  /// No description provided for @dietDrink.
  ///
  /// In en, this message translates to:
  /// **'Drink'**
  String get dietDrink;

  /// No description provided for @discountAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get discountAmount;

  /// No description provided for @discountApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get discountApply;

  /// No description provided for @discountApplyTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply discount'**
  String get discountApplyTitle;

  /// No description provided for @discountEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit discount'**
  String get discountEditTitle;

  /// No description provided for @discountLabel.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discountLabel;

  /// No description provided for @discountNewTaxableBase.
  ///
  /// In en, this message translates to:
  /// **'New taxable base'**
  String get discountNewTaxableBase;

  /// No description provided for @discountOffSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Off cart subtotal · {amount}'**
  String discountOffSubtotal(String amount);

  /// No description provided for @discountPercent.
  ///
  /// In en, this message translates to:
  /// **'Percent'**
  String get discountPercent;

  /// No description provided for @discountReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get discountReason;

  /// No description provided for @discountReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — staff note for the ticket'**
  String get discountReasonHint;

  /// No description provided for @discountRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove discount'**
  String get discountRemove;

  /// No description provided for @discountTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Discount type'**
  String get discountTypeLabel;

  /// No description provided for @discountUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get discountUpdate;

  /// No description provided for @menuAllItems.
  ///
  /// In en, this message translates to:
  /// **'All items'**
  String get menuAllItems;

  /// No description provided for @menuBarcodeTooltip.
  ///
  /// In en, this message translates to:
  /// **'USB barcode scanners work here automatically'**
  String get menuBarcodeTooltip;

  /// No description provided for @menuBrowseFull.
  ///
  /// In en, this message translates to:
  /// **'Browse the full menu'**
  String get menuBrowseFull;

  /// No description provided for @menuCategoryFallback.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get menuCategoryFallback;

  /// No description provided for @menuCategoryItems.
  ///
  /// In en, this message translates to:
  /// **'Items in this category'**
  String get menuCategoryItems;

  /// No description provided for @menuChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get menuChoose;

  /// No description provided for @menuFrom.
  ///
  /// In en, this message translates to:
  /// **'FROM'**
  String get menuFrom;

  /// No description provided for @menuNavLabel.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menuNavLabel;

  /// No description provided for @menuNoItemsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try another category or search term.'**
  String get menuNoItemsSubtitle;

  /// No description provided for @menuNoItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get menuNoItemsTitle;

  /// No description provided for @menuOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get menuOptions;

  /// No description provided for @menuNotAvailableBadge.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get menuNotAvailableBadge;

  /// No description provided for @menuNotAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Not available?'**
  String get menuNotAvailableTitle;

  /// No description provided for @menuNotAvailableMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} is marked not available. Add it to this ticket anyway?'**
  String menuNotAvailableMessage(String name);

  /// No description provided for @menuNotAvailableConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add anyway'**
  String get menuNotAvailableConfirm;

  /// No description provided for @menuOutsideScheduleBadge.
  ///
  /// In en, this message translates to:
  /// **'Outside schedule'**
  String get menuOutsideScheduleBadge;

  /// No description provided for @menuOutsideScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Outside schedule?'**
  String get menuOutsideScheduleTitle;

  /// No description provided for @menuOutsideScheduleMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} is outside its menu time slot. Add it to this ticket anyway?'**
  String menuOutsideScheduleMessage(String name);

  /// No description provided for @menuOutsideScheduleConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add anyway'**
  String get menuOutsideScheduleConfirm;

  /// No description provided for @menuPopularSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fast picks for this register'**
  String get menuPopularSubtitle;

  /// No description provided for @menuPopularTitle.
  ///
  /// In en, this message translates to:
  /// **'Popular items'**
  String get menuPopularTitle;

  /// No description provided for @menuScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get menuScan;

  /// No description provided for @menuSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search menu or scan barcode…'**
  String get menuSearchHint;

  /// No description provided for @menuSearchResults.
  ///
  /// In en, this message translates to:
  /// **'Results for \"{query}\"'**
  String menuSearchResults(String query);

  /// No description provided for @modifierAddToTicket.
  ///
  /// In en, this message translates to:
  /// **'Add to ticket'**
  String get modifierAddToTicket;

  /// No description provided for @modifierChooseUpTo.
  ///
  /// In en, this message translates to:
  /// **'Choose up to {max} for {name}'**
  String modifierChooseUpTo(int max, String name);

  /// No description provided for @modifierChooseVariant.
  ///
  /// In en, this message translates to:
  /// **'Choose Variant'**
  String get modifierChooseVariant;

  /// No description provided for @modifierNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note or special request…'**
  String get modifierNotesHint;

  /// No description provided for @modifierOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get modifierOptional;

  /// No description provided for @modifierPleaseChoose.
  ///
  /// In en, this message translates to:
  /// **'Please choose {name}'**
  String modifierPleaseChoose(String name);

  /// No description provided for @modifierQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get modifierQuantity;

  /// No description provided for @modifierRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get modifierRequired;

  /// No description provided for @modifierSpecialInstructions.
  ///
  /// In en, this message translates to:
  /// **'Special Instructions'**
  String get modifierSpecialInstructions;

  /// No description provided for @netBlocked.
  ///
  /// In en, this message translates to:
  /// **'Network access blocked. Check permissions and try again.'**
  String get netBlocked;

  /// No description provided for @netCannotConnect.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the server. Is it running?'**
  String netCannotConnect(String url);

  /// No description provided for @netCannotReach.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection and try again.'**
  String netCannotReach(String url);

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection and try again.'**
  String get errorNetwork;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'Offline — cash & external payments still work; orders sync when connected'**
  String get offlineBanner;

  /// No description provided for @offlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offlineLabel;

  /// No description provided for @offlineNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Offline mode not available'**
  String get offlineNotAvailable;

  /// No description provided for @offlinePending.
  ///
  /// In en, this message translates to:
  /// **'Offline ({count} pending)'**
  String offlinePending(int count);

  /// No description provided for @offlineSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get offlineSyncing;

  /// No description provided for @offlineSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'{count} need sync'**
  String offlineSyncFailed(int count);

  /// No description provided for @offlineSyncFailedBanner.
  ///
  /// In en, this message translates to:
  /// **'{count} offline order(s) failed to sync — open Sync from the menu or check shift status'**
  String offlineSyncFailedBanner(int count);

  /// No description provided for @offlinePaymentBlocked.
  ///
  /// In en, this message translates to:
  /// **'This payment method needs a network connection. Use cash or another offline method.'**
  String get offlinePaymentBlocked;

  /// No description provided for @offlineHeldPayBlocked.
  ///
  /// In en, this message translates to:
  /// **'Server held tickets need a network connection to settle. Local offline holds can be paid with cash or another offline method.'**
  String get offlineHeldPayBlocked;

  /// No description provided for @offlineHeldNotFound.
  ///
  /// In en, this message translates to:
  /// **'That held ticket is no longer on this device.'**
  String get offlineHeldNotFound;

  /// No description provided for @offlinePinNeedsNetwork.
  ///
  /// In en, this message translates to:
  /// **'Unlock once while online to enable offline PIN unlock on this device.'**
  String get offlinePinNeedsNetwork;

  /// No description provided for @offlineSyncNothingPending.
  ///
  /// In en, this message translates to:
  /// **'No pending offline orders'**
  String get offlineSyncNothingPending;

  /// No description provided for @offlineSyncPartial.
  ///
  /// In en, this message translates to:
  /// **'Synced with {count} still pending'**
  String offlineSyncPartial(int count);

  /// No description provided for @opsNoShift.
  ///
  /// In en, this message translates to:
  /// **'No shift'**
  String get opsNoShift;

  /// No description provided for @opsOpenOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional — open when ready'**
  String get opsOpenOptional;

  /// No description provided for @opsOpenToTakeOrders.
  ///
  /// In en, this message translates to:
  /// **'Open a shift to take orders'**
  String get opsOpenToTakeOrders;

  /// No description provided for @opsRegShort.
  ///
  /// In en, this message translates to:
  /// **'Reg'**
  String get opsRegShort;

  /// No description provided for @opsRegisterReady.
  ///
  /// In en, this message translates to:
  /// **'Register is ready'**
  String get opsRegisterReady;

  /// No description provided for @opsShiftOpen.
  ///
  /// In en, this message translates to:
  /// **'Shift open'**
  String get opsShiftOpen;

  /// No description provided for @opsShiftRequired.
  ///
  /// In en, this message translates to:
  /// **'Shift required'**
  String get opsShiftRequired;

  /// No description provided for @opsSince.
  ///
  /// In en, this message translates to:
  /// **'since {time}'**
  String opsSince(String time);

  /// No description provided for @orderPlaced.
  ///
  /// In en, this message translates to:
  /// **'Order {label} placed'**
  String orderPlaced(String label);

  /// No description provided for @orderSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Order {label} saved (offline)'**
  String orderSavedOffline(String label);

  /// No description provided for @orderTypeDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get orderTypeDelivery;

  /// No description provided for @orderTypeDineIn.
  ///
  /// In en, this message translates to:
  /// **'Dine in'**
  String get orderTypeDineIn;

  /// No description provided for @orderTypeTakeaway.
  ///
  /// In en, this message translates to:
  /// **'Takeaway'**
  String get orderTypeTakeaway;

  /// No description provided for @ordersAdvanceAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get ordersAdvanceAccept;

  /// No description provided for @ordersAdvanceDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get ordersAdvanceDone;

  /// No description provided for @ordersAdvanceKitchen.
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get ordersAdvanceKitchen;

  /// No description provided for @ordersAdvanceReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ordersAdvanceReady;

  /// No description provided for @ordersItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} item'**
  String ordersItemCount(int count);

  /// No description provided for @ordersItemCountPlural.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String ordersItemCountPlural(int count);

  /// No description provided for @ordersMoreItems.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String ordersMoreItems(int count);

  /// No description provided for @ordersNumberMissing.
  ///
  /// In en, this message translates to:
  /// **'Order number missing'**
  String get ordersNumberMissing;

  /// No description provided for @ordersPagination.
  ///
  /// In en, this message translates to:
  /// **'{from}–{to} of {total}'**
  String ordersPagination(int from, int to, int total);

  /// No description provided for @ordersTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Token {token}'**
  String ordersTokenLabel(String token);

  /// No description provided for @pairAdminHint.
  ///
  /// In en, this message translates to:
  /// **'Optional. In Admin → POS terminals, tap Pair tablet on this register, then enter the code shown there. You will still sign in afterward.'**
  String get pairAdminHint;

  /// No description provided for @pairCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'Pairing code expired. Tap New code to try again.'**
  String get pairCodeExpired;

  /// No description provided for @pairThisTablet.
  ///
  /// In en, this message translates to:
  /// **'Bind this tablet to a register'**
  String get pairThisTablet;

  /// No description provided for @pairWaitingManager.
  ///
  /// In en, this message translates to:
  /// **'Waiting for manager to confirm…'**
  String get pairWaitingManager;

  /// No description provided for @payCashTendered.
  ///
  /// In en, this message translates to:
  /// **'Cash tendered'**
  String get payCashTendered;

  /// No description provided for @payChangeDue.
  ///
  /// In en, this message translates to:
  /// **'Change due'**
  String get payChangeDue;

  /// No description provided for @payCharge.
  ///
  /// In en, this message translates to:
  /// **'Charge {amount}'**
  String payCharge(String amount);

  /// No description provided for @payConfirmMethod.
  ///
  /// In en, this message translates to:
  /// **'Confirm {method}'**
  String payConfirmMethod(String method);

  /// No description provided for @payExact.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get payExact;

  /// No description provided for @payLaterHelp.
  ///
  /// In en, this message translates to:
  /// **'Order is saved as an open tab — charge when ready.'**
  String get payLaterHelp;

  /// No description provided for @payMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get payMethodLabel;

  /// No description provided for @payNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Payment not completed'**
  String get payNotCompleted;

  /// No description provided for @payPlaceOrder.
  ///
  /// In en, this message translates to:
  /// **'Place order'**
  String get payPlaceOrder;

  /// No description provided for @payPlaceWithout.
  ///
  /// In en, this message translates to:
  /// **'Place without payment'**
  String get payPlaceWithout;

  /// No description provided for @payQrHelp.
  ///
  /// In en, this message translates to:
  /// **'Customer scans and pays with UPI on their phone.'**
  String get payQrHelp;

  /// No description provided for @payReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get payReceived;

  /// No description provided for @payShort.
  ///
  /// In en, this message translates to:
  /// **'Short of total'**
  String get payShort;

  /// No description provided for @payShortHelp.
  ///
  /// In en, this message translates to:
  /// **'Amount received is less than total due.'**
  String get payShortHelp;

  /// No description provided for @payShowQr.
  ///
  /// In en, this message translates to:
  /// **'Show QR for customer'**
  String get payShowQr;

  /// No description provided for @payTerminalHelp.
  ///
  /// In en, this message translates to:
  /// **'Complete on the terminal or record the payment.'**
  String get payTerminalHelp;

  /// No description provided for @payTip.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get payTip;

  /// No description provided for @payTipCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom tip'**
  String get payTipCustom;

  /// No description provided for @payTipNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get payTipNone;

  /// No description provided for @payUpi.
  ///
  /// In en, this message translates to:
  /// **'UPI'**
  String get payUpi;

  /// No description provided for @pinAccountPassword.
  ///
  /// In en, this message translates to:
  /// **'Account password'**
  String get pinAccountPassword;

  /// No description provided for @pinBannerBody.
  ///
  /// In en, this message translates to:
  /// **'Set a 6-digit PIN to unlock this register after relaunch. Prefer Lock between shifts.'**
  String get pinBannerBody;

  /// No description provided for @pinBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock with a POS PIN'**
  String get pinBannerTitle;

  /// No description provided for @pinChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Change POS PIN'**
  String get pinChangeTitle;

  /// No description provided for @pinConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get pinConfirm;

  /// No description provided for @pinCreateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a 6-digit PIN to unlock this register'**
  String get pinCreateSubtitle;

  /// No description provided for @pinIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get pinIncorrect;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match.'**
  String get pinMismatch;

  /// No description provided for @pinMustBeSix.
  ///
  /// In en, this message translates to:
  /// **'PIN must be exactly 6 digits.'**
  String get pinMustBeSix;

  /// No description provided for @pinNeedPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your account password.'**
  String get pinNeedPassword;

  /// No description provided for @pinNew.
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get pinNew;

  /// No description provided for @pinPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'Required to save your PIN'**
  String get pinPasswordHelper;

  /// No description provided for @pinPromptMessage.
  ///
  /// In en, this message translates to:
  /// **'Unlock this register with a short PIN instead of email and password. Recommended after pairing.'**
  String get pinPromptMessage;

  /// No description provided for @pinPromptNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get pinPromptNotNow;

  /// No description provided for @pinPromptSet.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get pinPromptSet;

  /// No description provided for @pinPromptSetNow.
  ///
  /// In en, this message translates to:
  /// **'Set PIN now'**
  String get pinPromptSetNow;

  /// No description provided for @pinPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a POS PIN?'**
  String get pinPromptTitle;

  /// No description provided for @pinSave.
  ///
  /// In en, this message translates to:
  /// **'Save PIN'**
  String get pinSave;

  /// No description provided for @pinSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save PIN'**
  String get pinSaveFailed;

  /// No description provided for @pinSaved.
  ///
  /// In en, this message translates to:
  /// **'POS PIN saved.'**
  String get pinSaved;

  /// No description provided for @pinSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Set POS PIN'**
  String get pinSetTitle;

  /// No description provided for @pinUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update PIN'**
  String get pinUpdate;

  /// No description provided for @poweredBy.
  ///
  /// In en, this message translates to:
  /// **'Powered by'**
  String get poweredBy;

  /// No description provided for @printCouldNot.
  ///
  /// In en, this message translates to:
  /// **'Could not print: {error}'**
  String printCouldNot(String error);

  /// No description provided for @printOrderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Order {label} not found'**
  String printOrderNotFound(String label);

  /// No description provided for @printPrinted.
  ///
  /// In en, this message translates to:
  /// **'Printed {label}'**
  String printPrinted(String label);

  /// No description provided for @printReceiptConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Print a duplicate receipt for {label}?'**
  String printReceiptConfirmMessage(String label);

  /// No description provided for @printReceiptConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Print receipt?'**
  String get printReceiptConfirmTitle;

  /// No description provided for @printerActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get printerActive;

  /// No description provided for @printerAutoPrintKot.
  ///
  /// In en, this message translates to:
  /// **'Auto-print KOT on new orders'**
  String get printerAutoPrintKot;

  /// No description provided for @printerAutoPrintKotHelp.
  ///
  /// In en, this message translates to:
  /// **'When a guest, kiosk, online, or partner order arrives, print kitchen tickets on this device’s printer.'**
  String get printerAutoPrintKotHelp;

  /// No description provided for @printerAutoPrintKotOnSnack.
  ///
  /// In en, this message translates to:
  /// **'New orders will auto-print KOT'**
  String get printerAutoPrintKotOnSnack;

  /// No description provided for @printerAutoPrintKotOffSnack.
  ///
  /// In en, this message translates to:
  /// **'New orders will not auto-print KOT'**
  String get printerAutoPrintKotOffSnack;

  /// No description provided for @printerTestPrint.
  ///
  /// In en, this message translates to:
  /// **'Test print'**
  String get printerTestPrint;

  /// No description provided for @printerTestSent.
  ///
  /// In en, this message translates to:
  /// **'Test print sent'**
  String get printerTestSent;

  /// No description provided for @printerTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Test print failed'**
  String get printerTestFailed;

  /// No description provided for @printerTesting.
  ///
  /// In en, this message translates to:
  /// **'Printing test…'**
  String get printerTesting;

  /// No description provided for @printerBluetoothHint.
  ///
  /// In en, this message translates to:
  /// **'Put the printer in pairing mode, then scan'**
  String get printerBluetoothHint;

  /// No description provided for @printerBluetoothTitle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth printers'**
  String get printerBluetoothTitle;

  /// No description provided for @printerConfirmBefore.
  ///
  /// In en, this message translates to:
  /// **'Confirm before scan-to-print'**
  String get printerConfirmBefore;

  /// No description provided for @printerConnectBt.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to Bluetooth printer \"{name}\". Keep the printer powered on and nearby, then try again.'**
  String printerConnectBt(String name);

  /// No description provided for @printerConnectMac.
  ///
  /// In en, this message translates to:
  /// **'Could not print to \"{name}\". Confirm the printer is online in System Settings and supports raw ESC/POS via CUPS.'**
  String printerConnectMac(String name);

  /// No description provided for @printerConnectUsb.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to USB printer \"{name}\". Unplug and replug the printer, then try again.'**
  String printerConnectUsb(String name);

  /// No description provided for @printerConnectWeb.
  ///
  /// In en, this message translates to:
  /// **'Could not print to \"{name}\" in the browser. Run the native POS app with a USB or Bluetooth thermal printer.'**
  String printerConnectWeb(String name);

  /// No description provided for @printerCountFound.
  ///
  /// In en, this message translates to:
  /// **'{count} found'**
  String printerCountFound(int count);

  /// No description provided for @printerEmptyBt.
  ///
  /// In en, this message translates to:
  /// **'No Bluetooth printers found nearby.'**
  String get printerEmptyBt;

  /// No description provided for @printerEmptyUsb.
  ///
  /// In en, this message translates to:
  /// **'No USB / system printers found.'**
  String get printerEmptyUsb;

  /// No description provided for @printerEmptyWeb.
  ///
  /// In en, this message translates to:
  /// **'Printing is not supported in the browser.'**
  String get printerEmptyWeb;

  /// No description provided for @printerHelpAndroid.
  ///
  /// In en, this message translates to:
  /// **'Use USB, LAN (IP:9100 on the same network), or Bluetooth for an ESC/POS printer. Allow USB / nearby devices when Android prompts.'**
  String get printerHelpAndroid;

  /// No description provided for @printerHelpIos.
  ///
  /// In en, this message translates to:
  /// **'iOS supports Bluetooth or LAN (same Wi‑Fi) ESC/POS printers. For LAN, enter the printer IP and port 9100.'**
  String get printerHelpIos;

  /// No description provided for @printerHelpMac.
  ///
  /// In en, this message translates to:
  /// **'Choose USB / system, LAN (IP:9100), or Bluetooth ESC/POS. macOS CUPS printers appear under USB — use a raw/ESC-POS queue when available.'**
  String get printerHelpMac;

  /// No description provided for @printerHelpWin.
  ///
  /// In en, this message translates to:
  /// **'Connect USB, enter a LAN printer IP (port 9100), or pair Bluetooth in Windows Settings, then select it below.'**
  String get printerHelpWin;

  /// No description provided for @printerConnectLan.
  ///
  /// In en, this message translates to:
  /// **'Could not reach LAN printer \"{name}\" at {endpoint}. Check power, Wi‑Fi/Ethernet, and that raw TCP port 9100 is open.'**
  String printerConnectLan(String name, String endpoint);

  /// No description provided for @printerLanTitle.
  ///
  /// In en, this message translates to:
  /// **'Network printer'**
  String get printerLanTitle;

  /// No description provided for @printerLanHint.
  ///
  /// In en, this message translates to:
  /// **'Same Wi‑Fi/Ethernet as this device. Most ESC/POS printers use port 9100.'**
  String get printerLanHint;

  /// No description provided for @printerLanHost.
  ///
  /// In en, this message translates to:
  /// **'IP address or hostname'**
  String get printerLanHost;

  /// No description provided for @printerLanPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get printerLanPort;

  /// No description provided for @printerLanNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get printerLanNameOptional;

  /// No description provided for @printerLanNameHint.
  ///
  /// In en, this message translates to:
  /// **'Front counter'**
  String get printerLanNameHint;

  /// No description provided for @printerLanSave.
  ///
  /// In en, this message translates to:
  /// **'Save LAN printer'**
  String get printerLanSave;

  /// No description provided for @printerLanHostRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the printer IP address or hostname.'**
  String get printerLanHostRequired;

  /// No description provided for @printerLanPortInvalid.
  ///
  /// In en, this message translates to:
  /// **'Port must be between 1 and 65535.'**
  String get printerLanPortInvalid;

  /// No description provided for @printerLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load printers'**
  String get printerLoadFailed;

  /// No description provided for @printerLooking.
  ///
  /// In en, this message translates to:
  /// **'Looking for printers…'**
  String get printerLooking;

  /// No description provided for @printerMissing.
  ///
  /// In en, this message translates to:
  /// **'No receipt printer selected.'**
  String get printerMissing;

  /// No description provided for @printerMissingWeb.
  ///
  /// In en, this message translates to:
  /// **'Receipt printing requires the native POS app.'**
  String get printerMissingWeb;

  /// No description provided for @printerNoBluetooth.
  ///
  /// In en, this message translates to:
  /// **'No Bluetooth printers'**
  String get printerNoBluetooth;

  /// No description provided for @printerNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No printers found'**
  String get printerNoneFound;

  /// No description provided for @printerReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt printer'**
  String get printerReceiptTitle;

  /// No description provided for @printerScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get printerScan;

  /// No description provided for @printerScanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get printerScanAgain;

  /// No description provided for @printerScanAskHelp.
  ///
  /// In en, this message translates to:
  /// **'Ask before printing when an order QR is scanned'**
  String get printerScanAskHelp;

  /// No description provided for @printerScanAskSnack.
  ///
  /// In en, this message translates to:
  /// **'Scan-to-print will ask before printing'**
  String get printerScanAskSnack;

  /// No description provided for @printerScanAutoHelp.
  ///
  /// In en, this message translates to:
  /// **'Print automatically when an order QR is scanned'**
  String get printerScanAutoHelp;

  /// No description provided for @printerScanAutoSnack.
  ///
  /// In en, this message translates to:
  /// **'Scan-to-print will print automatically'**
  String get printerScanAutoSnack;

  /// No description provided for @printerScanBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Scan for Bluetooth printers'**
  String get printerScanBluetooth;

  /// No description provided for @printerScanToPrint.
  ///
  /// In en, this message translates to:
  /// **'Scan to print'**
  String get printerScanToPrint;

  /// No description provided for @statusPrinterReady.
  ///
  /// In en, this message translates to:
  /// **'Printer ready'**
  String get statusPrinterReady;

  /// No description provided for @statusPrinterNone.
  ///
  /// In en, this message translates to:
  /// **'No printer'**
  String get statusPrinterNone;

  /// No description provided for @statusPrinterMissing.
  ///
  /// In en, this message translates to:
  /// **'Printer missing'**
  String get statusPrinterMissing;

  /// No description provided for @statusPrinterMissingHelp.
  ///
  /// In en, this message translates to:
  /// **'The selected receipt printer wasn’t found. Check power and cable, or pick another printer.'**
  String get statusPrinterMissingHelp;

  /// No description provided for @statusPrinterNeedsSetup.
  ///
  /// In en, this message translates to:
  /// **'Printer needs setup'**
  String get statusPrinterNeedsSetup;

  /// No description provided for @statusPrinterNeedsSetupHelp.
  ///
  /// In en, this message translates to:
  /// **'This device isn’t ready for raw ESC/POS yet. Open Printer setup and choose a printable queue.'**
  String get statusPrinterNeedsSetupHelp;

  /// No description provided for @statusPrinterAttentionHelp.
  ///
  /// In en, this message translates to:
  /// **'The printer reported a problem (paper, cover, or pause). Fix it, then recheck.'**
  String get statusPrinterAttentionHelp;

  /// No description provided for @statusPrinterError.
  ///
  /// In en, this message translates to:
  /// **'Printer error'**
  String get statusPrinterError;

  /// No description provided for @statusPrinterErrorHelp.
  ///
  /// In en, this message translates to:
  /// **'The last check failed. Confirm the printer is online, then open Printer setup if it persists.'**
  String get statusPrinterErrorHelp;

  /// No description provided for @statusPrinterUnsupported.
  ///
  /// In en, this message translates to:
  /// **'No printing'**
  String get statusPrinterUnsupported;

  /// No description provided for @statusPrinterTapSetup.
  ///
  /// In en, this message translates to:
  /// **'Tap to open Printer setup'**
  String get statusPrinterTapSetup;

  /// No description provided for @statusPrinterRecheck.
  ///
  /// In en, this message translates to:
  /// **'Recheck'**
  String get statusPrinterRecheck;

  /// No description provided for @printerScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get printerScanning;

  /// No description provided for @printerSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get printerSelected;

  /// No description provided for @printerSelectedSnack.
  ///
  /// In en, this message translates to:
  /// **'{connection} printer \"{name}\" selected'**
  String printerSelectedSnack(String connection, String name);

  /// No description provided for @printerSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Printer setup'**
  String get printerSetupTitle;

  /// No description provided for @printerTabBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get printerTabBluetooth;

  /// No description provided for @printerTabLan.
  ///
  /// In en, this message translates to:
  /// **'LAN'**
  String get printerTabLan;

  /// No description provided for @printerTabUsb.
  ///
  /// In en, this message translates to:
  /// **'USB / System'**
  String get printerTabUsb;

  /// No description provided for @printerUnsupportedWeb.
  ///
  /// In en, this message translates to:
  /// **'ESC/POS receipt printing is not available in the browser. Run the native POS app on Android, iOS, macOS, or Windows.'**
  String get printerUnsupportedWeb;

  /// No description provided for @printerUsbHint.
  ///
  /// In en, this message translates to:
  /// **'Plug in or add the printer, then refresh'**
  String get printerUsbHint;

  /// No description provided for @printerUsbTitle.
  ///
  /// In en, this message translates to:
  /// **'USB / system printers'**
  String get printerUsbTitle;

  /// No description provided for @qrAskCustomer.
  ///
  /// In en, this message translates to:
  /// **'Ask the customer to scan with their UPI app'**
  String get qrAskCustomer;

  /// No description provided for @qrCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel payment'**
  String get qrCancelConfirm;

  /// No description provided for @qrCancelMessage.
  ///
  /// In en, this message translates to:
  /// **'Stop waiting for this {gateway} payment? The order stays unpaid.'**
  String qrCancelMessage(String gateway);

  /// No description provided for @qrCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel payment?'**
  String get qrCancelTitle;

  /// No description provided for @qrGenerateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not generate QR. Check PhonePe/Paytm settings.'**
  String get qrGenerateFailed;

  /// No description provided for @qrGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating secure QR…'**
  String get qrGenerating;

  /// No description provided for @qrHurry.
  ///
  /// In en, this message translates to:
  /// **'Hurry'**
  String get qrHurry;

  /// No description provided for @qrKeepWaiting.
  ///
  /// In en, this message translates to:
  /// **'Keep waiting'**
  String get qrKeepWaiting;

  /// No description provided for @qrOrderLabel.
  ///
  /// In en, this message translates to:
  /// **'Order {label}'**
  String qrOrderLabel(String label);

  /// No description provided for @qrPrintSlip.
  ///
  /// In en, this message translates to:
  /// **'Print slip'**
  String get qrPrintSlip;

  /// No description provided for @qrPrinting.
  ///
  /// In en, this message translates to:
  /// **'Printing…'**
  String get qrPrinting;

  /// No description provided for @qrScanToPay.
  ///
  /// In en, this message translates to:
  /// **'Scan to pay'**
  String get qrScanToPay;

  /// No description provided for @qrSlipPrintFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not print QR slip'**
  String get qrSlipPrintFailed;

  /// No description provided for @qrSlipPrinted.
  ///
  /// In en, this message translates to:
  /// **'QR slip sent to printer'**
  String get qrSlipPrinted;

  /// No description provided for @qrTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get qrTimeLeft;

  /// No description provided for @qrTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Payment timed out or failed'**
  String get qrTimedOut;

  /// No description provided for @qrUnavailable.
  ///
  /// In en, this message translates to:
  /// **'QR unavailable'**
  String get qrUnavailable;

  /// No description provided for @qrWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for payment confirmation…'**
  String get qrWaiting;

  /// No description provided for @reportsCategoryWise.
  ///
  /// In en, this message translates to:
  /// **'Category wise'**
  String get reportsCategoryWise;

  /// No description provided for @reportsCategoryWiseDesc.
  ///
  /// In en, this message translates to:
  /// **'Quantity and sales total by menu category.'**
  String get reportsCategoryWiseDesc;

  /// No description provided for @reportsItemWise.
  ///
  /// In en, this message translates to:
  /// **'Item wise report'**
  String get reportsItemWise;

  /// No description provided for @reportsItemWiseDesc.
  ///
  /// In en, this message translates to:
  /// **'Item codes, quantities sold, and sales amount.'**
  String get reportsItemWiseDesc;

  /// No description provided for @reportsOrderType.
  ///
  /// In en, this message translates to:
  /// **'Order type'**
  String get reportsOrderType;

  /// No description provided for @reportsOrderTypeDesc.
  ///
  /// In en, this message translates to:
  /// **'Dine-in, takeaway, and delivery sales with order counts.'**
  String get reportsOrderTypeDesc;

  /// No description provided for @reportsPrintFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not print report: {error}'**
  String reportsPrintFailed(String error);

  /// No description provided for @reportsSalesChannel.
  ///
  /// In en, this message translates to:
  /// **'Sales channel'**
  String get reportsSalesChannel;

  /// No description provided for @reportsSalesChannelDesc.
  ///
  /// In en, this message translates to:
  /// **'POS, kiosk, online, and other channel totals.'**
  String get reportsSalesChannelDesc;

  /// No description provided for @reportsSalesSummary.
  ///
  /// In en, this message translates to:
  /// **'Sales summary'**
  String get reportsSalesSummary;

  /// No description provided for @reportsSalesSummaryDesc.
  ///
  /// In en, this message translates to:
  /// **'Orders, items sold, average ticket, tax, tips, and discounts.'**
  String get reportsSalesSummaryDesc;

  /// No description provided for @reportsSentToPrinter.
  ///
  /// In en, this message translates to:
  /// **'Report sent to printer'**
  String get reportsSentToPrinter;

  /// No description provided for @reportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Print today’s sales for this branch to the thermal printer.'**
  String get reportsSubtitle;

  /// No description provided for @reportsTaxSummary.
  ///
  /// In en, this message translates to:
  /// **'Tax summary'**
  String get reportsTaxSummary;

  /// No description provided for @reportsTaxSummaryDesc.
  ///
  /// In en, this message translates to:
  /// **'Collected tax by rate/name with period totals.'**
  String get reportsTaxSummaryDesc;

  /// No description provided for @reportsTerminalConsolidated.
  ///
  /// In en, this message translates to:
  /// **'Terminal bill consolidated'**
  String get reportsTerminalConsolidated;

  /// No description provided for @reportsTerminalConsolidatedDesc.
  ///
  /// In en, this message translates to:
  /// **'Payment method totals with grand total for today.'**
  String get reportsTerminalConsolidatedDesc;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Day-end reports'**
  String get reportsTitle;

  /// No description provided for @setupEnterUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter your {app} server URL to continue.'**
  String setupEnterUrl(String app);

  /// No description provided for @setupStep1.
  ///
  /// In en, this message translates to:
  /// **'STEP 1 OF SETUP'**
  String get setupStep1;

  /// No description provided for @shellChangeRegister.
  ///
  /// In en, this message translates to:
  /// **'Change register'**
  String get shellChangeRegister;

  /// No description provided for @shellChangeLocation.
  ///
  /// In en, this message translates to:
  /// **'Change location'**
  String get shellChangeLocation;

  /// No description provided for @shellClearPairing.
  ///
  /// In en, this message translates to:
  /// **'Clear device pairing'**
  String get shellClearPairing;

  /// No description provided for @shellLockShort.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get shellLockShort;

  /// No description provided for @shellMenuDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get shellMenuDevice;

  /// No description provided for @shellMenuRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Menu refreshed'**
  String get shellMenuRefreshed;

  /// No description provided for @shellMenuSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get shellMenuSession;

  /// No description provided for @shellMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get shellMore;

  /// No description provided for @shellMoreCustomize.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get shellMoreCustomize;

  /// No description provided for @shellMoreCustomizeHint.
  ///
  /// In en, this message translates to:
  /// **'Uncheck options to hide them from the menu.'**
  String get shellMoreCustomizeHint;

  /// No description provided for @shellPairingCleared.
  ///
  /// In en, this message translates to:
  /// **'Device pairing cleared'**
  String get shellPairingCleared;

  /// No description provided for @shellRefreshMenu.
  ///
  /// In en, this message translates to:
  /// **'Refresh menu'**
  String get shellRefreshMenu;

  /// No description provided for @shellSyncCompleted.
  ///
  /// In en, this message translates to:
  /// **'Sync completed'**
  String get shellSyncCompleted;

  /// No description provided for @shellSyncOrders.
  ///
  /// In en, this message translates to:
  /// **'Sync orders'**
  String get shellSyncOrders;

  /// No description provided for @shellViewCart.
  ///
  /// In en, this message translates to:
  /// **'View cart'**
  String get shellViewCart;

  /// No description provided for @shiftBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get shiftBalanced;

  /// No description provided for @shiftByMethodSection.
  ///
  /// In en, this message translates to:
  /// **'BY PAYMENT METHOD'**
  String get shiftByMethodSection;

  /// No description provided for @shiftCashCounted.
  ///
  /// In en, this message translates to:
  /// **'Cash counted'**
  String get shiftCashCounted;

  /// No description provided for @shiftCashDrawerSection.
  ///
  /// In en, this message translates to:
  /// **'CASH DRAWER'**
  String get shiftCashDrawerSection;

  /// No description provided for @shiftCashSales.
  ///
  /// In en, this message translates to:
  /// **'Cash sales'**
  String get shiftCashSales;

  /// No description provided for @shiftChangeGiven.
  ///
  /// In en, this message translates to:
  /// **'Change given'**
  String get shiftChangeGiven;

  /// No description provided for @shiftCloseNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — e.g. variance explained'**
  String get shiftCloseNotesHint;

  /// No description provided for @shiftCloseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Count the drawer and confirm against expected cash'**
  String get shiftCloseSubtitle;

  /// No description provided for @shiftClosedSnack.
  ///
  /// In en, this message translates to:
  /// **'Shift closed'**
  String get shiftClosedSnack;

  /// No description provided for @shiftClosing.
  ///
  /// In en, this message translates to:
  /// **'Closing…'**
  String get shiftClosing;

  /// No description provided for @shiftCounted.
  ///
  /// In en, this message translates to:
  /// **'Counted'**
  String get shiftCounted;

  /// No description provided for @shiftExpectedDrawer.
  ///
  /// In en, this message translates to:
  /// **'Expected in drawer'**
  String get shiftExpectedDrawer;

  /// No description provided for @shiftNoPaidSales.
  ///
  /// In en, this message translates to:
  /// **'No paid sales yet'**
  String get shiftNoPaidSales;

  /// No description provided for @shiftNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get shiftNotes;

  /// No description provided for @shiftOpenNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — e.g. counted with manager'**
  String get shiftOpenNotesHint;

  /// No description provided for @shiftOpenRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Open shift to continue'**
  String get shiftOpenRequiredTitle;

  /// No description provided for @shiftOpenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Count the drawer, then start selling'**
  String get shiftOpenSubtitle;

  /// No description provided for @shiftOpenedSnack.
  ///
  /// In en, this message translates to:
  /// **'Shift opened'**
  String get shiftOpenedSnack;

  /// No description provided for @shiftOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening…'**
  String get shiftOpening;

  /// No description provided for @shiftOpeningFloat.
  ///
  /// In en, this message translates to:
  /// **'Opening float'**
  String get shiftOpeningFloat;

  /// No description provided for @shiftOpeningFloatFor.
  ///
  /// In en, this message translates to:
  /// **'Opening float for {branch}'**
  String shiftOpeningFloatFor(String branch);

  /// No description provided for @shiftOpeningFloatHelp.
  ///
  /// In en, this message translates to:
  /// **'Cash in the drawer before the first sale'**
  String get shiftOpeningFloatHelp;

  /// No description provided for @shiftOver.
  ///
  /// In en, this message translates to:
  /// **'Over'**
  String get shiftOver;

  /// No description provided for @shiftPaidOrderOne.
  ///
  /// In en, this message translates to:
  /// **'1 paid order'**
  String get shiftPaidOrderOne;

  /// No description provided for @shiftPaidOrders.
  ///
  /// In en, this message translates to:
  /// **'{count} paid orders'**
  String shiftPaidOrders(int count);

  /// No description provided for @shiftRequiredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A shift is required before taking orders'**
  String get shiftRequiredSubtitle;

  /// No description provided for @shiftSalesSection.
  ///
  /// In en, this message translates to:
  /// **'SALES THIS SHIFT'**
  String get shiftSalesSection;

  /// No description provided for @shiftShort.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get shiftShort;

  /// No description provided for @shiftSummaryLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load shift summary.'**
  String get shiftSummaryLoadFailed;

  /// No description provided for @shiftSummaryLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading shift summary…'**
  String get shiftSummaryLoading;

  /// No description provided for @shiftThisBranch.
  ///
  /// In en, this message translates to:
  /// **'this branch'**
  String get shiftThisBranch;

  /// No description provided for @shiftTipsOnOrders.
  ///
  /// In en, this message translates to:
  /// **'Tips on orders: {amount}'**
  String shiftTipsOnOrders(String amount);

  /// No description provided for @shiftVariance.
  ///
  /// In en, this message translates to:
  /// **'Variance'**
  String get shiftVariance;

  /// No description provided for @shortcutsAll.
  ///
  /// In en, this message translates to:
  /// **'All shortcuts'**
  String get shortcutsAll;

  /// No description provided for @shortcutsBarcodeNote.
  ///
  /// In en, this message translates to:
  /// **'/ search  ·  F2 hold  ·  F3 pay  ·  F4 orders  ·  F6 lock'**
  String get shortcutsBarcodeNote;

  /// No description provided for @shortcutsClearCart.
  ///
  /// In en, this message translates to:
  /// **'Clear cart'**
  String get shortcutsClearCart;

  /// No description provided for @shortcutsClearCartDesc.
  ///
  /// In en, this message translates to:
  /// **'Asks for confirmation'**
  String get shortcutsClearCartDesc;

  /// No description provided for @shortcutsClearCartKeys.
  ///
  /// In en, this message translates to:
  /// **'⇧ Delete / ⇧ ⌫'**
  String get shortcutsClearCartKeys;

  /// No description provided for @shortcutsFocusSearch.
  ///
  /// In en, this message translates to:
  /// **'Focus search'**
  String get shortcutsFocusSearch;

  /// No description provided for @shortcutsFocusSearchDesc.
  ///
  /// In en, this message translates to:
  /// **'Type to filter the menu'**
  String get shortcutsFocusSearchDesc;

  /// No description provided for @shortcutsGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get shortcutsGotIt;

  /// No description provided for @shortcutsHeldOrders.
  ///
  /// In en, this message translates to:
  /// **'Held orders'**
  String get shortcutsHeldOrders;

  /// No description provided for @shortcutsHeldOrdersDesc.
  ///
  /// In en, this message translates to:
  /// **'Open parked tickets'**
  String get shortcutsHeldOrdersDesc;

  /// No description provided for @shortcutsHoldTicket.
  ///
  /// In en, this message translates to:
  /// **'Hold ticket'**
  String get shortcutsHoldTicket;

  /// No description provided for @shortcutsHoldTicketDesc.
  ///
  /// In en, this message translates to:
  /// **'Park the current cart'**
  String get shortcutsHoldTicketDesc;

  /// No description provided for @shortcutsLockRegister.
  ///
  /// In en, this message translates to:
  /// **'Lock register'**
  String get shortcutsLockRegister;

  /// No description provided for @shortcutsLockRegisterDesc.
  ///
  /// In en, this message translates to:
  /// **'Requires a POS PIN'**
  String get shortcutsLockRegisterDesc;

  /// No description provided for @shortcutsLockAlt.
  ///
  /// In en, this message translates to:
  /// **'⌘ L / Ctrl L'**
  String get shortcutsLockAlt;

  /// No description provided for @shortcutsLockAltDesc.
  ///
  /// In en, this message translates to:
  /// **'Same as F6'**
  String get shortcutsLockAltDesc;

  /// No description provided for @shortcutsPay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get shortcutsPay;

  /// No description provided for @shortcutsPayAlt.
  ///
  /// In en, this message translates to:
  /// **'⇧ Enter'**
  String get shortcutsPayAlt;

  /// No description provided for @shortcutsPayAltDesc.
  ///
  /// In en, this message translates to:
  /// **'Same as F3'**
  String get shortcutsPayAltDesc;

  /// No description provided for @shortcutsPayDesc.
  ///
  /// In en, this message translates to:
  /// **'Open the payment flow'**
  String get shortcutsPayDesc;

  /// No description provided for @shortcutsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Faster register workflow with a keyboard'**
  String get shortcutsSubtitle;

  /// No description provided for @shortcutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get shortcutsTitle;

  /// No description provided for @terminalCode.
  ///
  /// In en, this message translates to:
  /// **'Code {code}'**
  String terminalCode(String code);

  /// No description provided for @terminalContinueWithout.
  ///
  /// In en, this message translates to:
  /// **'Continue without terminal'**
  String get terminalContinueWithout;

  /// No description provided for @terminalEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask your manager to add POS terminals in Admin, then try again.'**
  String get terminalEmptySubtitle;

  /// No description provided for @terminalEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No terminals yet'**
  String get terminalEmptyTitle;

  /// No description provided for @terminalFooterNote.
  ///
  /// In en, this message translates to:
  /// **'This device will stay bound to the register you pick.'**
  String get terminalFooterNote;

  /// No description provided for @terminalSelectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Which POS terminal is this device?'**
  String get terminalSelectSubtitle;

  /// No description provided for @terminalSelectSubtitleNamed.
  ///
  /// In en, this message translates to:
  /// **'Which POS terminal is this device? ({branch})'**
  String terminalSelectSubtitleNamed(String branch);

  /// No description provided for @terminalSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select register'**
  String get terminalSelectTitle;

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String timeDaysAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String timeHoursAgo(int count);

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String timeMinutesAgo(int count);

  /// No description provided for @updateAction.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateAction;

  /// No description provided for @updateAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'Running {version}. Tap Update to download and install.'**
  String updateAvailableBody(String version);

  /// No description provided for @updateAvailableSnack.
  ///
  /// In en, this message translates to:
  /// **'Update available · v{version}'**
  String updateAvailableSnack(String version);

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available · v{version}'**
  String updateAvailableTitle(String version);

  /// No description provided for @updateCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get updateCancelled;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates'**
  String get updateCheckFailed;

  /// No description provided for @updateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get updateChecking;

  /// No description provided for @updateDoneAndroid.
  ///
  /// In en, this message translates to:
  /// **'Complete the system install prompt, then reopen this POS app.'**
  String get updateDoneAndroid;

  /// No description provided for @updateDoneGeneric.
  ///
  /// In en, this message translates to:
  /// **'Finish installing, then reopen this POS app.'**
  String get updateDoneGeneric;

  /// No description provided for @updateDoneMac.
  ///
  /// In en, this message translates to:
  /// **'Install from the opened package (DMG/app), then reopen this POS app.'**
  String get updateDoneMac;

  /// No description provided for @updateDoneWin.
  ///
  /// In en, this message translates to:
  /// **'Finish the installer wizard, then reopen this POS app.'**
  String get updateDoneWin;

  /// No description provided for @updateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download update'**
  String get updateDownload;

  /// No description provided for @updateDownloadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Download cancelled.'**
  String get updateDownloadCancelled;

  /// No description provided for @updateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed ({code}).'**
  String updateDownloadFailed(String code);

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update'**
  String get updateDownloading;

  /// No description provided for @updateDownloadingPct.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {pct}%'**
  String updateDownloadingPct(int pct);

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get updateFailed;

  /// No description provided for @updateInAppUnavailable.
  ///
  /// In en, this message translates to:
  /// **'In-app install is not available on this platform.'**
  String get updateInAppUnavailable;

  /// No description provided for @updateInstallerOpened.
  ///
  /// In en, this message translates to:
  /// **'Installer opened'**
  String get updateInstallerOpened;

  /// No description provided for @updateInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing the latest POS build'**
  String get updateInstalling;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateNoLink.
  ///
  /// In en, this message translates to:
  /// **'No download link is published yet. Contact your platform administrator.'**
  String get updateNoLink;

  /// No description provided for @updateNoLinkDevice.
  ///
  /// In en, this message translates to:
  /// **'No download link is available for this device.'**
  String get updateNoLinkDevice;

  /// No description provided for @updateOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get updateOpenBrowser;

  /// No description provided for @updateOpeningAndroid.
  ///
  /// In en, this message translates to:
  /// **'Opening the Android installer…'**
  String get updateOpeningAndroid;

  /// No description provided for @updateOpeningGeneric.
  ///
  /// In en, this message translates to:
  /// **'Opening the installer…'**
  String get updateOpeningGeneric;

  /// No description provided for @updateOpeningMac.
  ///
  /// In en, this message translates to:
  /// **'Opening the macOS installer…'**
  String get updateOpeningMac;

  /// No description provided for @updateOpeningWin.
  ///
  /// In en, this message translates to:
  /// **'Opening the Windows installer…'**
  String get updateOpeningWin;

  /// No description provided for @updatePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing download…'**
  String get updatePreparing;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'This POS is on {current}. Install {latest} to continue.'**
  String updateRequiredBody(String current, String latest);

  /// No description provided for @updateRequiredSnack.
  ///
  /// In en, this message translates to:
  /// **'A required update is available'**
  String get updateRequiredSnack;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequiredTitle;

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You are up to date ({version})'**
  String updateUpToDate(String version);

  /// No description provided for @updateVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String updateVersion(String version);

  /// No description provided for @updateWorking.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get updateWorking;

  /// No description provided for @upsellAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get upsellAdd;

  /// No description provided for @upsellSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Popular extras for this ticket. Optional — continue when ready.'**
  String get upsellSubtitle;

  /// No description provided for @upsellTitle.
  ///
  /// In en, this message translates to:
  /// **'Add anything else?'**
  String get upsellTitle;

  /// No description provided for @shiftUnpaidSuffix.
  ///
  /// In en, this message translates to:
  /// **' · {count} unpaid ({amount})'**
  String shiftUnpaidSuffix(String amount, int count);

  /// No description provided for @payAmountWithTip.
  ///
  /// In en, this message translates to:
  /// **'{total} + {tip} tip'**
  String payAmountWithTip(String tip, String total);

  /// No description provided for @payStatusPartial.
  ///
  /// In en, this message translates to:
  /// **'Partially paid'**
  String get payStatusPartial;

  /// No description provided for @payStatusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get payStatusRefunded;

  /// No description provided for @payStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Payment pending'**
  String get payStatusPending;

  /// No description provided for @authStaffOrderingFooter.
  ///
  /// In en, this message translates to:
  /// **'{app} · staff ordering'**
  String authStaffOrderingFooter(String app);

  /// No description provided for @modePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'How are you working?'**
  String get modePickerTitle;

  /// No description provided for @modePickerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose register POS for the counter, or Waiter for phone floor service.'**
  String get modePickerSubtitle;

  /// No description provided for @modePickerRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Register POS'**
  String get modePickerRegisterTitle;

  /// No description provided for @modePickerRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Full cashier: payments, shifts, printers'**
  String get modePickerRegisterSubtitle;

  /// No description provided for @modePickerWaiterTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiter / Captain'**
  String get modePickerWaiterTitle;

  /// No description provided for @modePickerWaiterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tables, KOT, and bill requests on the floor'**
  String get modePickerWaiterSubtitle;

  /// No description provided for @modePickerFooter.
  ///
  /// In en, this message translates to:
  /// **'You can switch modes later from Profile'**
  String get modePickerFooter;

  /// No description provided for @waiterNavTables.
  ///
  /// In en, this message translates to:
  /// **'Tables'**
  String get waiterNavTables;

  /// No description provided for @waiterNavOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get waiterNavOrders;

  /// No description provided for @waiterNavAlerts.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get waiterNavAlerts;

  /// No description provided for @waiterNavProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get waiterNavProfile;

  /// No description provided for @waiterConnectionLive.
  ///
  /// In en, this message translates to:
  /// **'Live · floor updating'**
  String get waiterConnectionLive;

  /// No description provided for @waiterConnectionOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline · showing last floor'**
  String get waiterConnectionOffline;

  /// No description provided for @waiterZoneAll.
  ///
  /// In en, this message translates to:
  /// **'All tables'**
  String get waiterZoneAll;

  /// No description provided for @waiterZoneOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get waiterZoneOther;

  /// No description provided for @waiterStatusAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get waiterStatusAvailable;

  /// No description provided for @waiterStatusOccupied.
  ///
  /// In en, this message translates to:
  /// **'Occupied'**
  String get waiterStatusOccupied;

  /// No description provided for @waiterStatusBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get waiterStatusBilling;

  /// No description provided for @waiterStatusReserved.
  ///
  /// In en, this message translates to:
  /// **'Reserved'**
  String get waiterStatusReserved;

  /// No description provided for @waiterStatusCleaning.
  ///
  /// In en, this message translates to:
  /// **'Needs cleaning'**
  String get waiterStatusCleaning;

  /// No description provided for @waiterTableCleaningHint.
  ///
  /// In en, this message translates to:
  /// **'This table needs cleaning before seating.'**
  String get waiterTableCleaningHint;

  /// No description provided for @waiterOpenTableTitle.
  ///
  /// In en, this message translates to:
  /// **'Open {table}'**
  String waiterOpenTableTitle(String table);

  /// No description provided for @waiterOpenTableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set guest count, then start taking the order.'**
  String get waiterOpenTableSubtitle;

  /// No description provided for @waiterGuestsLabel.
  ///
  /// In en, this message translates to:
  /// **'Number of guests'**
  String get waiterGuestsLabel;

  /// No description provided for @waiterOpenTableConfirm.
  ///
  /// In en, this message translates to:
  /// **'Open table'**
  String get waiterOpenTableConfirm;

  /// No description provided for @waiterTableSeatsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} seats'**
  String waiterTableSeatsCount(int count);

  /// No description provided for @waiterGuestsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} guests'**
  String waiterGuestsCount(int count);

  /// No description provided for @waiterOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get waiterOrderTitle;

  /// No description provided for @waiterCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get waiterCategoryAll;

  /// No description provided for @waiterSendToKitchen.
  ///
  /// In en, this message translates to:
  /// **'Send to Kitchen'**
  String get waiterSendToKitchen;

  /// No description provided for @waiterAlreadySent.
  ///
  /// In en, this message translates to:
  /// **'Already sent · {count}'**
  String waiterAlreadySent(int count);

  /// No description provided for @waiterNewItemsHint.
  ///
  /// In en, this message translates to:
  /// **'Add new items below, then send to kitchen.'**
  String get waiterNewItemsHint;

  /// No description provided for @waiterChannelInHouse.
  ///
  /// In en, this message translates to:
  /// **'In-house'**
  String get waiterChannelInHouse;

  /// No description provided for @waiterCaptainNamed.
  ///
  /// In en, this message translates to:
  /// **'Captain · {name}'**
  String waiterCaptainNamed(String name);

  /// No description provided for @waiterBillRequestedBadge.
  ///
  /// In en, this message translates to:
  /// **'Bill requested'**
  String get waiterBillRequestedBadge;

  /// No description provided for @waiterKotRound.
  ///
  /// In en, this message translates to:
  /// **'KOT {round}'**
  String waiterKotRound(int round);

  /// No description provided for @ordersFilterFloor.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get ordersFilterFloor;

  /// No description provided for @ordersFilterPartners.
  ///
  /// In en, this message translates to:
  /// **'Delivery partners'**
  String get ordersFilterPartners;

  /// No description provided for @ordersFilterZomato.
  ///
  /// In en, this message translates to:
  /// **'Zomato'**
  String get ordersFilterZomato;

  /// No description provided for @ordersFilterSwiggy.
  ///
  /// In en, this message translates to:
  /// **'Swiggy'**
  String get ordersFilterSwiggy;

  /// No description provided for @ordersEmptyZomato.
  ///
  /// In en, this message translates to:
  /// **'No Zomato orders today.'**
  String get ordersEmptyZomato;

  /// No description provided for @ordersEmptySwiggy.
  ///
  /// In en, this message translates to:
  /// **'No Swiggy orders today.'**
  String get ordersEmptySwiggy;

  /// No description provided for @ordersSourceZomato.
  ///
  /// In en, this message translates to:
  /// **'Zomato'**
  String get ordersSourceZomato;

  /// No description provided for @ordersSourceSwiggy.
  ///
  /// In en, this message translates to:
  /// **'Swiggy'**
  String get ordersSourceSwiggy;

  /// No description provided for @waiterCartBanner.
  ///
  /// In en, this message translates to:
  /// **'{count} items · {subtotal}'**
  String waiterCartBanner(int count, String subtotal);

  /// No description provided for @waiterKotSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Order Sent to Kitchen!'**
  String get waiterKotSentTitle;

  /// No description provided for @waiterKotSentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Kitchen has the ticket — keep serving this table or open another.'**
  String get waiterKotSentSubtitle;

  /// No description provided for @waiterKotSent.
  ///
  /// In en, this message translates to:
  /// **'KOT sent · {number}'**
  String waiterKotSent(String number);

  /// No description provided for @waiterOrdersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No active orders'**
  String get waiterOrdersEmptyTitle;

  /// No description provided for @waiterOrdersEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open a table and send items to the kitchen.'**
  String get waiterOrdersEmptySubtitle;

  /// No description provided for @waiterOrdersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Live floor tickets and KOT progress'**
  String get waiterOrdersSubtitle;

  /// No description provided for @waiterOrdersSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String waiterOrdersSummary(int count);

  /// No description provided for @waiterOrdersFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get waiterOrdersFilterAll;

  /// No description provided for @waiterOrdersFilterPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get waiterOrdersFilterPreparing;

  /// No description provided for @waiterOrdersFilterReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to serve'**
  String get waiterOrdersFilterReady;

  /// No description provided for @waiterOrdersFilterBilling.
  ///
  /// In en, this message translates to:
  /// **'Bill ready'**
  String get waiterOrdersFilterBilling;

  /// No description provided for @waiterOrdersFilterMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get waiterOrdersFilterMine;

  /// No description provided for @waiterOrdersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search table or ticket…'**
  String get waiterOrdersSearchHint;

  /// No description provided for @waiterOrdersNoFilterMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'No orders match'**
  String get waiterOrdersNoFilterMatchesTitle;

  /// No description provided for @waiterOrdersNoFilterMatchesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try another filter or clear search.'**
  String get waiterOrdersNoFilterMatchesSubtitle;

  /// No description provided for @waiterOrdersSummaryReady.
  ///
  /// In en, this message translates to:
  /// **'{count} ready'**
  String waiterOrdersSummaryReady(int count);

  /// No description provided for @waiterOrdersSummaryBilling.
  ///
  /// In en, this message translates to:
  /// **'{count} bill ready'**
  String waiterOrdersSummaryBilling(int count);

  /// No description provided for @waiterOrdersSummaryMine.
  ///
  /// In en, this message translates to:
  /// **'{count} mine'**
  String waiterOrdersSummaryMine(int count);

  /// No description provided for @waiterOrdersMoreItems.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String waiterOrdersMoreItems(int count);

  /// No description provided for @waiterOrdersTapToExpand.
  ///
  /// In en, this message translates to:
  /// **'Tap for full ticket'**
  String get waiterOrdersTapToExpand;

  /// No description provided for @waiterOrdersTapToCollapse.
  ///
  /// In en, this message translates to:
  /// **'Tap to collapse'**
  String get waiterOrdersTapToCollapse;

  /// No description provided for @waiterOrdersReadyCount.
  ///
  /// In en, this message translates to:
  /// **'{count} ready'**
  String waiterOrdersReadyCount(int count);

  /// No description provided for @waiterOrdersPrepCount.
  ///
  /// In en, this message translates to:
  /// **'{count} prep'**
  String waiterOrdersPrepCount(int count);

  /// No description provided for @waiterOrdersSentCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sent'**
  String waiterOrdersSentCount(int count);

  /// No description provided for @waiterOrdersShowItems.
  ///
  /// In en, this message translates to:
  /// **'Show items'**
  String get waiterOrdersShowItems;

  /// No description provided for @waiterOrdersHideItems.
  ///
  /// In en, this message translates to:
  /// **'Hide items'**
  String get waiterOrdersHideItems;

  /// No description provided for @waiterOrdersToken.
  ///
  /// In en, this message translates to:
  /// **'T{token}'**
  String waiterOrdersToken(String token);

  /// No description provided for @waiterItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String waiterItemsCount(int count);

  /// No description provided for @waiterPipelineSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get waiterPipelineSent;

  /// No description provided for @waiterPipelinePreparing.
  ///
  /// In en, this message translates to:
  /// **'Prep'**
  String get waiterPipelinePreparing;

  /// No description provided for @waiterPipelineReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get waiterPipelineReady;

  /// No description provided for @waiterPipelineServed.
  ///
  /// In en, this message translates to:
  /// **'Served'**
  String get waiterPipelineServed;

  /// No description provided for @waiterMarkServed.
  ///
  /// In en, this message translates to:
  /// **'Mark served'**
  String get waiterMarkServed;

  /// No description provided for @waiterMarkServedAll.
  ///
  /// In en, this message translates to:
  /// **'Mark all ready served'**
  String get waiterMarkServedAll;

  /// No description provided for @waiterMarkServedDone.
  ///
  /// In en, this message translates to:
  /// **'Marked served'**
  String get waiterMarkServedDone;

  /// No description provided for @waiterMarkServedDoneCount.
  ///
  /// In en, this message translates to:
  /// **'Marked {count} ready as served'**
  String waiterMarkServedDoneCount(int count);

  /// No description provided for @waiterMarkServedNeedsOnline.
  ///
  /// In en, this message translates to:
  /// **'Connect to the server to mark food served.'**
  String get waiterMarkServedNeedsOnline;

  /// No description provided for @waiterRunFoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Run food now'**
  String get waiterRunFoodTitle;

  /// No description provided for @waiterRunFoodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} ready at the pass'**
  String waiterRunFoodSubtitle(int count);

  /// No description provided for @waiterRunFoodAction.
  ///
  /// In en, this message translates to:
  /// **'Mark served'**
  String get waiterRunFoodAction;

  /// No description provided for @waiterKitchenWorkingTitle.
  ///
  /// In en, this message translates to:
  /// **'Kitchen cooking'**
  String get waiterKitchenWorkingTitle;

  /// No description provided for @waiterKitchenWorkingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{prep} cooking · {sent} in queue'**
  String waiterKitchenWorkingSubtitle(int prep, int sent);

  /// No description provided for @waiterAllServedTitle.
  ///
  /// In en, this message translates to:
  /// **'Food delivered'**
  String get waiterAllServedTitle;

  /// No description provided for @waiterAllServedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ready when guests want the bill'**
  String get waiterAllServedSubtitle;

  /// No description provided for @waiterCardNeedsYou.
  ///
  /// In en, this message translates to:
  /// **'Needs you'**
  String get waiterCardNeedsYou;

  /// No description provided for @waiterCardWaitingKitchen.
  ///
  /// In en, this message translates to:
  /// **'In kitchen'**
  String get waiterCardWaitingKitchen;

  /// No description provided for @waiterCardBillPending.
  ///
  /// In en, this message translates to:
  /// **'Bill out'**
  String get waiterCardBillPending;

  /// No description provided for @waiterCardDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get waiterCardDelivered;

  /// No description provided for @waiterCardItemsHeading.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get waiterCardItemsHeading;

  /// No description provided for @waiterCardShowTicket.
  ///
  /// In en, this message translates to:
  /// **'Show full ticket'**
  String get waiterCardShowTicket;

  /// No description provided for @waiterCardHideTicket.
  ///
  /// In en, this message translates to:
  /// **'Hide ticket'**
  String get waiterCardHideTicket;

  /// No description provided for @waiterCardMoreReady.
  ///
  /// In en, this message translates to:
  /// **'+{count} more ready'**
  String waiterCardMoreReady(int count);

  /// No description provided for @waiterCardAge.
  ///
  /// In en, this message translates to:
  /// **'Open {age}'**
  String waiterCardAge(String age);

  /// No description provided for @waiterAddMore.
  ///
  /// In en, this message translates to:
  /// **'Add more'**
  String get waiterAddMore;

  /// No description provided for @waiterRequestBill.
  ///
  /// In en, this message translates to:
  /// **'Request bill'**
  String get waiterRequestBill;

  /// No description provided for @waiterBillTitle.
  ///
  /// In en, this message translates to:
  /// **'Bill · {table}'**
  String waiterBillTitle(String table);

  /// No description provided for @waiterBillNoTicket.
  ///
  /// In en, this message translates to:
  /// **'No open ticket on this table yet'**
  String get waiterBillNoTicket;

  /// No description provided for @waiterBillEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Totals appear when a ticket is linked to this table.'**
  String get waiterBillEmptyHint;

  /// No description provided for @waiterBillDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get waiterBillDiscount;

  /// No description provided for @waiterBillTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get waiterBillTax;

  /// No description provided for @waiterBillRequestedToast.
  ///
  /// In en, this message translates to:
  /// **'Checkout requested for this table'**
  String get waiterBillRequestedToast;

  /// No description provided for @waiterBillAlreadyRequestedHint.
  ///
  /// In en, this message translates to:
  /// **'Register already has this bill — waiting for payment.'**
  String get waiterBillAlreadyRequestedHint;

  /// No description provided for @waiterBillRequestedAlert.
  ///
  /// In en, this message translates to:
  /// **'Bill requested for table'**
  String get waiterBillRequestedAlert;

  /// No description provided for @waiterOrderReadyAlert.
  ///
  /// In en, this message translates to:
  /// **'Order {number} is ready{table}'**
  String waiterOrderReadyAlert(String number, String table);

  /// No description provided for @waiterAlertsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get waiterAlertsEmptyTitle;

  /// No description provided for @waiterAlertsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Kitchen ready alerts and bill requests will show up here.'**
  String get waiterAlertsEmptySubtitle;

  /// No description provided for @waiterNotificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get waiterNotificationsMarkAllRead;

  /// No description provided for @waiterNotificationsAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'No unread notifications'**
  String get waiterNotificationsAllCaughtUp;

  /// No description provided for @waiterNotificationsUnread.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String waiterNotificationsUnread(int count);

  /// No description provided for @waiterNotificationsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get waiterNotificationsToday;

  /// No description provided for @waiterNotificationsEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get waiterNotificationsEarlier;

  /// No description provided for @waiterNotificationReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Order ready'**
  String get waiterNotificationReadyTitle;

  /// No description provided for @waiterNotificationReadyBody.
  ///
  /// In en, this message translates to:
  /// **'{number} is ready for pickup{table}'**
  String waiterNotificationReadyBody(String number, String table);

  /// No description provided for @waiterNotificationBillTitle.
  ///
  /// In en, this message translates to:
  /// **'Bill requested'**
  String get waiterNotificationBillTitle;

  /// No description provided for @waiterNotificationSplitBillTitle.
  ///
  /// In en, this message translates to:
  /// **'Split bill requested'**
  String get waiterNotificationSplitBillTitle;

  /// No description provided for @waiterNotificationBillBody.
  ///
  /// In en, this message translates to:
  /// **'{table} is waiting for checkout'**
  String waiterNotificationBillBody(String table);

  /// No description provided for @registerNotificationBillBody.
  ///
  /// In en, this message translates to:
  /// **'Captain requested checkout for {table}'**
  String registerNotificationBillBody(String table);

  /// No description provided for @registerNotificationNewOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get registerNotificationNewOrderTitle;

  /// No description provided for @registerNotificationNewOrderBody.
  ///
  /// In en, this message translates to:
  /// **'Order {number} received'**
  String registerNotificationNewOrderBody(String number);

  /// No description provided for @marketplacePriorityTitle.
  ///
  /// In en, this message translates to:
  /// **'Priority · {partner}'**
  String marketplacePriorityTitle(String partner);

  /// No description provided for @marketplacePriorityBody.
  ///
  /// In en, this message translates to:
  /// **'Partner order {number} needs attention'**
  String marketplacePriorityBody(String number);

  /// No description provided for @marketplacePriorityBodyWithExternal.
  ///
  /// In en, this message translates to:
  /// **'Partner order {number} · {externalId}'**
  String marketplacePriorityBodyWithExternal(String number, String externalId);

  /// No description provided for @marketplacePriorityChip.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get marketplacePriorityChip;

  /// No description provided for @newOrderAlertDescription.
  ///
  /// In en, this message translates to:
  /// **'A fresh order just landed — here are the details.'**
  String get newOrderAlertDescription;

  /// No description provided for @marketplacePriorityDescription.
  ///
  /// In en, this message translates to:
  /// **'Partner delivery order needs quick attention.'**
  String get marketplacePriorityDescription;

  /// No description provided for @newOrderAlertTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get newOrderAlertTotal;

  /// No description provided for @newOrderAlertPlaced.
  ///
  /// In en, this message translates to:
  /// **'Placed'**
  String get newOrderAlertPlaced;

  /// No description provided for @newOrderAlertTitleOne.
  ///
  /// In en, this message translates to:
  /// **'New order {number}'**
  String newOrderAlertTitleOne(String number);

  /// No description provided for @newOrderAlertView.
  ///
  /// In en, this message translates to:
  /// **'View order'**
  String get newOrderAlertView;

  /// No description provided for @newOrderAlertOpen.
  ///
  /// In en, this message translates to:
  /// **'Open order'**
  String get newOrderAlertOpen;

  /// No description provided for @newOrderAlertDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get newOrderAlertDismiss;

  /// No description provided for @newOrderAlertMore.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String newOrderAlertMore(int count);

  /// No description provided for @newOrderAlertToken.
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get newOrderAlertToken;

  /// No description provided for @registerNotificationsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'New guest orders and captain bill requests show up here.'**
  String get registerNotificationsEmptySubtitle;

  /// No description provided for @waiterSwitchToRegister.
  ///
  /// In en, this message translates to:
  /// **'Switch to Register POS'**
  String get waiterSwitchToRegister;

  /// No description provided for @waiterSwitchToRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open the full cashier experience'**
  String get waiterSwitchToRegisterSubtitle;

  /// No description provided for @waiterSwitchToRegisterConfirm.
  ///
  /// In en, this message translates to:
  /// **'Switch this device to Register POS mode?'**
  String get waiterSwitchToRegisterConfirm;

  /// No description provided for @waiterSwitchToWaiter.
  ///
  /// In en, this message translates to:
  /// **'Switch to Waiter / Captain'**
  String get waiterSwitchToWaiter;

  /// No description provided for @waiterSwitchToWaiterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Phone floor: tables, KOT, and bill requests'**
  String get waiterSwitchToWaiterSubtitle;

  /// No description provided for @waiterSwitchToWaiterConfirm.
  ///
  /// In en, this message translates to:
  /// **'Switch this device to Waiter / Captain mode?'**
  String get waiterSwitchToWaiterConfirm;

  /// No description provided for @waiterChangeMode.
  ///
  /// In en, this message translates to:
  /// **'Change work mode'**
  String get waiterChangeMode;

  /// No description provided for @waiterChangeModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick Register or Waiter again'**
  String get waiterChangeModeSubtitle;

  /// No description provided for @waiterFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get waiterFilterAll;

  /// No description provided for @waiterFilterMyTables.
  ///
  /// In en, this message translates to:
  /// **'My tables'**
  String get waiterFilterMyTables;

  /// No description provided for @waiterFilterZones.
  ///
  /// In en, this message translates to:
  /// **'Zones'**
  String get waiterFilterZones;

  /// No description provided for @waiterSearchTables.
  ///
  /// In en, this message translates to:
  /// **'Search tables…'**
  String get waiterSearchTables;

  /// No description provided for @waiterBillModeFull.
  ///
  /// In en, this message translates to:
  /// **'Full bill'**
  String get waiterBillModeFull;

  /// No description provided for @waiterBillModeSplitItems.
  ///
  /// In en, this message translates to:
  /// **'Split items'**
  String get waiterBillModeSplitItems;

  /// No description provided for @waiterBillModeSplitEqual.
  ///
  /// In en, this message translates to:
  /// **'Equal split'**
  String get waiterBillModeSplitEqual;

  /// No description provided for @waiterBillSplitParts.
  ///
  /// In en, this message translates to:
  /// **'Ways to split'**
  String get waiterBillSplitParts;

  /// No description provided for @waiterBillSplitNote.
  ///
  /// In en, this message translates to:
  /// **'Note for register (optional)'**
  String get waiterBillSplitNote;

  /// No description provided for @waiterBillSplitNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Guest A pays drinks'**
  String get waiterBillSplitNoteHint;

  /// No description provided for @waiterBillRequestSplit.
  ///
  /// In en, this message translates to:
  /// **'Request split bill'**
  String get waiterBillRequestSplit;

  /// No description provided for @waiterBillSplitSelectItemsRequired.
  ///
  /// In en, this message translates to:
  /// **'Select at least one item to split'**
  String get waiterBillSplitSelectItemsRequired;

  /// No description provided for @waiterBillSplitSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} items selected · {amount}'**
  String waiterBillSplitSelected(int count, String amount);

  /// No description provided for @waiterBillSplitEqualPreview.
  ///
  /// In en, this message translates to:
  /// **'{parts} ways · ~{amount} each'**
  String waiterBillSplitEqualPreview(int parts, String amount);

  /// No description provided for @registerSplitBillBadge.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get registerSplitBillBadge;

  /// No description provided for @registerSplitBillEqualHint.
  ///
  /// In en, this message translates to:
  /// **'Split equally · {parts} ways'**
  String registerSplitBillEqualHint(int parts);

  /// No description provided for @registerSplitBillItemsHint.
  ///
  /// In en, this message translates to:
  /// **'Split selected items'**
  String get registerSplitBillItemsHint;

  /// No description provided for @collectModeFull.
  ///
  /// In en, this message translates to:
  /// **'Full amount'**
  String get collectModeFull;

  /// No description provided for @collectModeSplit.
  ///
  /// In en, this message translates to:
  /// **'Split payments'**
  String get collectModeSplit;

  /// No description provided for @splitBillQrFullOnly.
  ///
  /// In en, this message translates to:
  /// **'QR only for full remaining'**
  String get splitBillQrFullOnly;

  /// No description provided for @splitBillTitle.
  ///
  /// In en, this message translates to:
  /// **'Split / multi-pay'**
  String get splitBillTitle;

  /// No description provided for @splitBillCollectHint.
  ///
  /// In en, this message translates to:
  /// **'Charge the full remaining balance at once, or record multiple payments toward this bill.'**
  String get splitBillCollectHint;

  /// No description provided for @splitBillPayFullRemaining.
  ///
  /// In en, this message translates to:
  /// **'Pay remaining in full'**
  String get splitBillPayFullRemaining;

  /// No description provided for @splitBillOrderTotal.
  ///
  /// In en, this message translates to:
  /// **'Order total'**
  String get splitBillOrderTotal;

  /// No description provided for @splitBillPaidSoFar.
  ///
  /// In en, this message translates to:
  /// **'Paid so far'**
  String get splitBillPaidSoFar;

  /// No description provided for @splitBillRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get splitBillRemaining;

  /// No description provided for @splitBillPaidCheck.
  ///
  /// In en, this message translates to:
  /// **'Paid ✓'**
  String get splitBillPaidCheck;

  /// No description provided for @splitBillPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get splitBillPayments;

  /// No description provided for @splitBillAddPayment.
  ///
  /// In en, this message translates to:
  /// **'Add payment'**
  String get splitBillAddPayment;

  /// No description provided for @splitBillAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get splitBillAmount;

  /// No description provided for @splitBillFillRemaining.
  ///
  /// In en, this message translates to:
  /// **'Full remaining'**
  String get splitBillFillRemaining;

  /// No description provided for @splitBillQuickHalf.
  ///
  /// In en, this message translates to:
  /// **'½'**
  String get splitBillQuickHalf;

  /// No description provided for @splitBillQuickThird.
  ///
  /// In en, this message translates to:
  /// **'⅓'**
  String get splitBillQuickThird;

  /// No description provided for @splitBillNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get splitBillNoteOptional;

  /// No description provided for @splitBillNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Guest 2 · Card'**
  String get splitBillNoteHint;

  /// No description provided for @splitBillRecordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record {method} payment'**
  String splitBillRecordPayment(String method);

  /// No description provided for @splitBillRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording…'**
  String get splitBillRecording;

  /// No description provided for @splitBillPaymentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Recorded {amount}'**
  String splitBillPaymentRecorded(String amount);

  /// No description provided for @splitBillFullyPaid.
  ///
  /// In en, this message translates to:
  /// **'Order fully paid'**
  String get splitBillFullyPaid;

  /// No description provided for @splitBillInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get splitBillInvalidAmount;

  /// No description provided for @splitBillAmountExceeds.
  ///
  /// In en, this message translates to:
  /// **'Amount exceeds remaining balance'**
  String get splitBillAmountExceeds;

  /// No description provided for @splitBillLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load payments'**
  String get splitBillLoadFailed;

  /// No description provided for @waiterTablesSummary.
  ///
  /// In en, this message translates to:
  /// **'{total} tables'**
  String waiterTablesSummary(int total);

  /// No description provided for @waiterTablesShowing.
  ///
  /// In en, this message translates to:
  /// **'Showing {count}'**
  String waiterTablesShowing(int count);

  /// No description provided for @waiterClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get waiterClearFilters;

  /// No description provided for @waiterNoFilterMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'No tables match'**
  String get waiterNoFilterMatchesTitle;

  /// No description provided for @waiterNoFilterMatchesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try another status, zone, or search.'**
  String get waiterNoFilterMatchesSubtitle;

  /// No description provided for @waiterActionSeat.
  ///
  /// In en, this message translates to:
  /// **'Tap to seat'**
  String get waiterActionSeat;

  /// No description provided for @waiterActionOrder.
  ///
  /// In en, this message translates to:
  /// **'Tap to order'**
  String get waiterActionOrder;

  /// No description provided for @waiterActionBill.
  ///
  /// In en, this message translates to:
  /// **'Tap for bill'**
  String get waiterActionBill;

  /// No description provided for @waiterActionClean.
  ///
  /// In en, this message translates to:
  /// **'Needs clean'**
  String get waiterActionClean;

  /// No description provided for @waiterOpenTicketBadge.
  ///
  /// In en, this message translates to:
  /// **'Ticket'**
  String get waiterOpenTicketBadge;

  /// No description provided for @waiterNoOrderBadge.
  ///
  /// In en, this message translates to:
  /// **'No order'**
  String get waiterNoOrderBadge;

  /// No description provided for @waiterTableActionStartOrder.
  ///
  /// In en, this message translates to:
  /// **'Start order'**
  String get waiterTableActionStartOrder;

  /// No description provided for @waiterTableActionStartOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Open the menu and send items to kitchen.'**
  String get waiterTableActionStartOrderHint;

  /// No description provided for @waiterTableActionAddMoreHint.
  ///
  /// In en, this message translates to:
  /// **'Add new items to this table’s ticket.'**
  String get waiterTableActionAddMoreHint;

  /// No description provided for @waiterTableActionViewBill.
  ///
  /// In en, this message translates to:
  /// **'View bill'**
  String get waiterTableActionViewBill;

  /// No description provided for @waiterTableActionViewBillHint.
  ///
  /// In en, this message translates to:
  /// **'See totals and hand off to register.'**
  String get waiterTableActionViewBillHint;

  /// No description provided for @waiterTableActionRequestBillHint.
  ///
  /// In en, this message translates to:
  /// **'Ask register to collect payment.'**
  String get waiterTableActionRequestBillHint;

  /// No description provided for @waiterTableActionClearBill.
  ///
  /// In en, this message translates to:
  /// **'Cancel bill request'**
  String get waiterTableActionClearBill;

  /// No description provided for @waiterTableActionClearBillHint.
  ///
  /// In en, this message translates to:
  /// **'Guests want to keep ordering.'**
  String get waiterTableActionClearBillHint;

  /// No description provided for @waiterTableActionClearBillDone.
  ///
  /// In en, this message translates to:
  /// **'Bill request cleared'**
  String get waiterTableActionClearBillDone;

  /// No description provided for @waiterTableActionMarkCleaning.
  ///
  /// In en, this message translates to:
  /// **'Needs cleaning'**
  String get waiterTableActionMarkCleaning;

  /// No description provided for @waiterTableActionMarkCleaningHint.
  ///
  /// In en, this message translates to:
  /// **'Guests have left — clear the table before the next party.'**
  String get waiterTableActionMarkCleaningHint;

  /// No description provided for @waiterTableActionMarkAvailable.
  ///
  /// In en, this message translates to:
  /// **'Mark as available'**
  String get waiterTableActionMarkAvailable;

  /// No description provided for @waiterTableActionMarkAvailableHint.
  ///
  /// In en, this message translates to:
  /// **'Ready for the next guests.'**
  String get waiterTableActionMarkAvailableHint;

  /// No description provided for @waiterTableActionFreeTable.
  ///
  /// In en, this message translates to:
  /// **'Free table'**
  String get waiterTableActionFreeTable;

  /// No description provided for @waiterTableActionFreeTableHint.
  ///
  /// In en, this message translates to:
  /// **'Guests left without an order — open this table again.'**
  String get waiterTableActionFreeTableHint;

  /// No description provided for @waiterTableActionCancelReservation.
  ///
  /// In en, this message translates to:
  /// **'Cancel reservation'**
  String get waiterTableActionCancelReservation;

  /// No description provided for @waiterTableActionCancelReservationHint.
  ///
  /// In en, this message translates to:
  /// **'Release this hold so others can be seated.'**
  String get waiterTableActionCancelReservationHint;

  /// No description provided for @waiterTableActionReserve.
  ///
  /// In en, this message translates to:
  /// **'Reserve table'**
  String get waiterTableActionReserve;

  /// No description provided for @waiterTableActionReserveHint.
  ///
  /// In en, this message translates to:
  /// **'Hold this table for an upcoming party.'**
  String get waiterTableActionReserveHint;

  /// No description provided for @waiterTableActionMarkedReserved.
  ///
  /// In en, this message translates to:
  /// **'Table reserved'**
  String get waiterTableActionMarkedReserved;

  /// No description provided for @waiterTableActionSeatGuests.
  ///
  /// In en, this message translates to:
  /// **'Seat guests'**
  String get waiterTableActionSeatGuests;

  /// No description provided for @waiterTableActionSeatGuestsHint.
  ///
  /// In en, this message translates to:
  /// **'Set party size and start their visit.'**
  String get waiterTableActionSeatGuestsHint;

  /// No description provided for @waiterTableActionReadyToSeat.
  ///
  /// In en, this message translates to:
  /// **'Ready to seat'**
  String get waiterTableActionReadyToSeat;

  /// No description provided for @waiterTableActionReadyToSeatHint.
  ///
  /// In en, this message translates to:
  /// **'Cleaning done — open for the next party.'**
  String get waiterTableActionReadyToSeatHint;

  /// No description provided for @waiterTableActionMarkedCleaning.
  ///
  /// In en, this message translates to:
  /// **'Table marked as cleaning'**
  String get waiterTableActionMarkedCleaning;

  /// No description provided for @waiterTableActionMarkedAvailable.
  ///
  /// In en, this message translates to:
  /// **'Table is available'**
  String get waiterTableActionMarkedAvailable;

  /// No description provided for @waiterTableActionsMore.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get waiterTableActionsMore;

  /// No description provided for @waiterTableStatusHintAvailable.
  ///
  /// In en, this message translates to:
  /// **'Open — start an order, reserve, or mark cleaning.'**
  String get waiterTableStatusHintAvailable;

  /// No description provided for @waiterTableStatusHintOccupied.
  ///
  /// In en, this message translates to:
  /// **'Guests are dining — add items or request the bill.'**
  String get waiterTableStatusHintOccupied;

  /// No description provided for @waiterTableStatusHintOccupiedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Seated with no ticket yet — start an order or free the table.'**
  String get waiterTableStatusHintOccupiedEmpty;

  /// No description provided for @waiterTableStatusHintBilling.
  ///
  /// In en, this message translates to:
  /// **'Bill requested — show totals or clear the request if they keep ordering.'**
  String get waiterTableStatusHintBilling;

  /// No description provided for @waiterTableStatusHintBillingDone.
  ///
  /// In en, this message translates to:
  /// **'Ticket closed — mark cleaning or free the table.'**
  String get waiterTableStatusHintBillingDone;

  /// No description provided for @waiterTableStatusHintReserved.
  ///
  /// In en, this message translates to:
  /// **'Held for a reservation — start an order or cancel the hold.'**
  String get waiterTableStatusHintReserved;

  /// No description provided for @waiterTableStatusHintCleaning.
  ///
  /// In en, this message translates to:
  /// **'Being reset — mark available when the table is ready.'**
  String get waiterTableStatusHintCleaning;
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
