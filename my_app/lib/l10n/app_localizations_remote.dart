// GENERATED from app_en.arb — do not edit by hand.
// Prefer updating lang/*/pos_app.php on the server; English fallback stays in ARB.

import 'app_localizations.dart';
import 'app_localizations_en.dart';
import 'pos_translation_store.dart';

/// Remote (server) strings with English [AppLocalizationsEn] backup.
class AppLocalizationsRemote extends AppLocalizations {
  AppLocalizationsRemote(this._remote, {AppLocalizations? fallback, String locale = 'und'})
      : _fallback = fallback ?? AppLocalizationsEn(),
        super(locale);

  final Map<String, String> _remote;
  final AppLocalizations _fallback;

  String? _string(String key) {
    final value = _remote[key];
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : value;
  }

  String _fill(String raw, Map<String, Object> replacements) {
    return PosTranslationStore.interpolate(raw, replacements);
  }

  @override
  String get languageName => _string('languageName') ?? _fallback.languageName;
  @override
  String get languagePickerTitle => _string('languagePickerTitle') ?? _fallback.languagePickerTitle;
  @override
  String get languagePickerHint => _string('languagePickerHint') ?? _fallback.languagePickerHint;
  @override
  String get appearancePickerTitle => _string('appearancePickerTitle') ?? _fallback.appearancePickerTitle;
  @override
  String get appearancePickerHint => _string('appearancePickerHint') ?? _fallback.appearancePickerHint;
  @override
  String get themeModeSystem => _string('themeModeSystem') ?? _fallback.themeModeSystem;
  @override
  String get themeModeSystemHint => _string('themeModeSystemHint') ?? _fallback.themeModeSystemHint;
  @override
  String get themeModeLight => _string('themeModeLight') ?? _fallback.themeModeLight;
  @override
  String get themeModeLightHint => _string('themeModeLightHint') ?? _fallback.themeModeLightHint;
  @override
  String get themeModeDark => _string('themeModeDark') ?? _fallback.themeModeDark;
  @override
  String get themeModeDarkHint => _string('themeModeDarkHint') ?? _fallback.themeModeDarkHint;
  @override
  String get shellAppearance => _string('shellAppearance') ?? _fallback.shellAppearance;
  @override
  String get shellAutoLock => _string('shellAutoLock') ?? _fallback.shellAutoLock;
  @override
  String get autoLockPickerTitle => _string('autoLockPickerTitle') ?? _fallback.autoLockPickerTitle;
  @override
  String get autoLockPickerHint => _string('autoLockPickerHint') ?? _fallback.autoLockPickerHint;
  @override
  String get autoLockEnabled => _string('autoLockEnabled') ?? _fallback.autoLockEnabled;
  @override
  String get autoLockEnabledHint => _string('autoLockEnabledHint') ?? _fallback.autoLockEnabledHint;
  @override
  String get autoLockDisabled => _string('autoLockDisabled') ?? _fallback.autoLockDisabled;
  @override
  String get autoLockDisabledHint => _string('autoLockDisabledHint') ?? _fallback.autoLockDisabledHint;
  @override
  String get adminManage => _string('adminManage') ?? _fallback.adminManage;
  @override
  String get adminManageSubtitle => _string('adminManageSubtitle') ?? _fallback.adminManageSubtitle;
  @override
  String get adminMenu => _string('adminMenu') ?? _fallback.adminMenu;
  @override
  String get adminTables => _string('adminTables') ?? _fallback.adminTables;
  @override
  String get adminOrders => _string('adminOrders') ?? _fallback.adminOrders;
  @override
  String get adminOrdersPeriodToday => _string('adminOrdersPeriodToday') ?? _fallback.adminOrdersPeriodToday;
  @override
  String get adminOrdersPeriodYesterday => _string('adminOrdersPeriodYesterday') ?? _fallback.adminOrdersPeriodYesterday;
  @override
  String get adminOrdersPeriodLast7Days => _string('adminOrdersPeriodLast7Days') ?? _fallback.adminOrdersPeriodLast7Days;
  @override
  String get adminOrdersPeriodAll => _string('adminOrdersPeriodAll') ?? _fallback.adminOrdersPeriodAll;
  @override
  String get adminOrdersPaymentAll => _string('adminOrdersPaymentAll') ?? _fallback.adminOrdersPaymentAll;
  @override
  String get adminOrdersPaymentUnpaid => _string('adminOrdersPaymentUnpaid') ?? _fallback.adminOrdersPaymentUnpaid;
  @override
  String get adminOrdersPaymentPaid => _string('adminOrdersPaymentPaid') ?? _fallback.adminOrdersPaymentPaid;
  @override
  String get adminOrdersChannelCaptain => _string('adminOrdersChannelCaptain') ?? _fallback.adminOrdersChannelCaptain;
  @override
  String get adminOrdersChannelPos => _string('adminOrdersChannelPos') ?? _fallback.adminOrdersChannelPos;
  @override
  String get adminOrdersChannelRegister => _string('adminOrdersChannelRegister') ?? _fallback.adminOrdersChannelRegister;
  @override
  String get adminOrdersChannelKiosk => _string('adminOrdersChannelKiosk') ?? _fallback.adminOrdersChannelKiosk;
  @override
  String get adminOrdersChannelOnline => _string('adminOrdersChannelOnline') ?? _fallback.adminOrdersChannelOnline;
  @override
  String get adminOrdersChannelApp => _string('adminOrdersChannelApp') ?? _fallback.adminOrdersChannelApp;
  @override
  String get adminOrdersChannelApi => _string('adminOrdersChannelApi') ?? _fallback.adminOrdersChannelApi;
  @override
  String get adminOrdersChannelUnknown => _string('adminOrdersChannelUnknown') ?? _fallback.adminOrdersChannelUnknown;
  @override
  String adminOrdersTableMeta(String name) {
    final raw = _string('adminOrdersTableMeta');
    if (raw != null) {
      return _fill(raw, {'name': name});
    }
    return _fallback.adminOrdersTableMeta(name);
  }
  @override
  String get adminTokenShort => _string('adminTokenShort') ?? _fallback.adminTokenShort;
  @override
  String adminOrdersAutoRefresh(String time) {
    final raw = _string('adminOrdersAutoRefresh');
    if (raw != null) {
      return _fill(raw, {'time': time});
    }
    return _fallback.adminOrdersAutoRefresh(time);
  }
  @override
  String get adminModifiers => _string('adminModifiers') ?? _fallback.adminModifiers;
  @override
  String get adminTimeSlots => _string('adminTimeSlots') ?? _fallback.adminTimeSlots;
  @override
  String get adminHours => _string('adminHours') ?? _fallback.adminHours;
  @override
  String get adminHoursSubtitle => _string('adminHoursSubtitle') ?? _fallback.adminHoursSubtitle;
  @override
  String get storeOpen => _string('storeOpen') ?? _fallback.storeOpen;
  @override
  String get storeClosed => _string('storeClosed') ?? _fallback.storeClosed;
  @override
  String get storeOutsideHours => _string('storeOutsideHours') ?? _fallback.storeOutsideHours;
  @override
  String get storePaused => _string('storePaused') ?? _fallback.storePaused;
  @override
  String get storeCloseTitle => _string('storeCloseTitle') ?? _fallback.storeCloseTitle;
  @override
  String get storeCloseMessage => _string('storeCloseMessage') ?? _fallback.storeCloseMessage;
  @override
  String get storeCloseConfirm => _string('storeCloseConfirm') ?? _fallback.storeCloseConfirm;
  @override
  String get storeOpenTitle => _string('storeOpenTitle') ?? _fallback.storeOpenTitle;
  @override
  String get storeOpenMessage => _string('storeOpenMessage') ?? _fallback.storeOpenMessage;
  @override
  String get storeOpenConfirm => _string('storeOpenConfirm') ?? _fallback.storeOpenConfirm;
  @override
  String get storeGuestStatusOpen => _string('storeGuestStatusOpen') ?? _fallback.storeGuestStatusOpen;
  @override
  String get storeGuestStatusPaused => _string('storeGuestStatusPaused') ?? _fallback.storeGuestStatusPaused;
  @override
  String get storeGuestStatusOutsideHours => _string('storeGuestStatusOutsideHours') ?? _fallback.storeGuestStatusOutsideHours;
  @override
  String get storeGuestStatusOther => _string('storeGuestStatusOther') ?? _fallback.storeGuestStatusOther;
  @override
  String get storeAcceptOnlineOrders => _string('storeAcceptOnlineOrders') ?? _fallback.storeAcceptOnlineOrders;
  @override
  String get storeAcceptOnlineOrdersHelp => _string('storeAcceptOnlineOrdersHelp') ?? _fallback.storeAcceptOnlineOrdersHelp;
  @override
  String get storeScheduleEnabled => _string('storeScheduleEnabled') ?? _fallback.storeScheduleEnabled;
  @override
  String get storeScheduleEnabledHelp => _string('storeScheduleEnabledHelp') ?? _fallback.storeScheduleEnabledHelp;
  @override
  String get storeTimezone => _string('storeTimezone') ?? _fallback.storeTimezone;
  @override
  String get storeClosedMessage => _string('storeClosedMessage') ?? _fallback.storeClosedMessage;
  @override
  String get storeClosedMessageHint => _string('storeClosedMessageHint') ?? _fallback.storeClosedMessageHint;
  @override
  String get storeScheduleTitle => _string('storeScheduleTitle') ?? _fallback.storeScheduleTitle;
  @override
  String get storeAddShift => _string('storeAddShift') ?? _fallback.storeAddShift;
  @override
  String get storeCopyWeekdays => _string('storeCopyWeekdays') ?? _fallback.storeCopyWeekdays;
  @override
  String get storeDayClosed => _string('storeDayClosed') ?? _fallback.storeDayClosed;
  @override
  String get storePosNote => _string('storePosNote') ?? _fallback.storePosNote;
  @override
  String get storeHoursSaved => _string('storeHoursSaved') ?? _fallback.storeHoursSaved;
  @override
  String storeOpensAt(String when) {
    final raw = _string('storeOpensAt');
    if (raw != null) {
      return _fill(raw, {'when': when});
    }
    return _fallback.storeOpensAt(when);
  }
  @override
  String get commonRetry => _string('commonRetry') ?? _fallback.commonRetry;
  @override
  String get commonCancel => _string('commonCancel') ?? _fallback.commonCancel;
  @override
  String get commonClose => _string('commonClose') ?? _fallback.commonClose;
  @override
  String get commonContinue => _string('commonContinue') ?? _fallback.commonContinue;
  @override
  String get commonClear => _string('commonClear') ?? _fallback.commonClear;
  @override
  String get commonSave => _string('commonSave') ?? _fallback.commonSave;
  @override
  String get commonDone => _string('commonDone') ?? _fallback.commonDone;
  @override
  String get commonLoading => _string('commonLoading') ?? _fallback.commonLoading;
  @override
  String get commonPleaseWait => _string('commonPleaseWait') ?? _fallback.commonPleaseWait;
  @override
  String get commonSomethingWentWrong => _string('commonSomethingWentWrong') ?? _fallback.commonSomethingWentWrong;
  @override
  String get commonChangeServer => _string('commonChangeServer') ?? _fallback.commonChangeServer;
  @override
  String get commonSearch => _string('commonSearch') ?? _fallback.commonSearch;
  @override
  String get commonRefresh => _string('commonRefresh') ?? _fallback.commonRefresh;
  @override
  String get commonPrint => _string('commonPrint') ?? _fallback.commonPrint;
  @override
  String get commonSignOut => _string('commonSignOut') ?? _fallback.commonSignOut;
  @override
  String get commonTotal => _string('commonTotal') ?? _fallback.commonTotal;
  @override
  String get commonSubtotal => _string('commonSubtotal') ?? _fallback.commonSubtotal;
  @override
  String get commonPaid => _string('commonPaid') ?? _fallback.commonPaid;
  @override
  String get commonUnpaid => _string('commonUnpaid') ?? _fallback.commonUnpaid;
  @override
  String get commonTryAgain => _string('commonTryAgain') ?? _fallback.commonTryAgain;
  @override
  String get authStaffSignIn => _string('authStaffSignIn') ?? _fallback.authStaffSignIn;
  @override
  String get authSignInOnce => _string('authSignInOnce') ?? _fallback.authSignInOnce;
  @override
  String get authUseStaffEmail => _string('authUseStaffEmail') ?? _fallback.authUseStaffEmail;
  @override
  String get authEmail => _string('authEmail') ?? _fallback.authEmail;
  @override
  String get authPassword => _string('authPassword') ?? _fallback.authPassword;
  @override
  String get authSignIn => _string('authSignIn') ?? _fallback.authSignIn;
  @override
  String get authPairDeviceFirst => _string('authPairDeviceFirst') ?? _fallback.authPairDeviceFirst;
  @override
  String get authChangePairedRegister => _string('authChangePairedRegister') ?? _fallback.authChangePairedRegister;
  @override
  String get authRegisterPaired => _string('authRegisterPaired') ?? _fallback.authRegisterPaired;
  @override
  String get authStaffPos => _string('authStaffPos') ?? _fallback.authStaffPos;
  @override
  String get authReadyForCashier => _string('authReadyForCashier') ?? _fallback.authReadyForCashier;
  @override
  String get authPairThenSignIn => _string('authPairThenSignIn') ?? _fallback.authPairThenSignIn;
  @override
  String get authThisRegisterPaired => _string('authThisRegisterPaired') ?? _fallback.authThisRegisterPaired;
  @override
  String get setupServerTitle => _string('setupServerTitle') ?? _fallback.setupServerTitle;
  @override
  String setupConnectRegister(String app) {
    final raw = _string('setupConnectRegister');
    if (raw != null) {
      return _fill(raw, {'app': app});
    }
    return _fallback.setupConnectRegister(app);
  }
  @override
  String get setupServerUrl => _string('setupServerUrl') ?? _fallback.setupServerUrl;
  @override
  String get pairDeviceTitle => _string('pairDeviceTitle') ?? _fallback.pairDeviceTitle;
  @override
  String get pairBindTerminal => _string('pairBindTerminal') ?? _fallback.pairBindTerminal;
  @override
  String get pairFooterNote => _string('pairFooterNote') ?? _fallback.pairFooterNote;
  @override
  String get pairNewCode => _string('pairNewCode') ?? _fallback.pairNewCode;
  @override
  String get pairSkipToSignIn => _string('pairSkipToSignIn') ?? _fallback.pairSkipToSignIn;
  @override
  String get lockRegisterLocked => _string('lockRegisterLocked') ?? _fallback.lockRegisterLocked;
  @override
  String get lockWelcomeBack => _string('lockWelcomeBack') ?? _fallback.lockWelcomeBack;
  @override
  String lockWelcomeBackNamed(String name) {
    final raw = _string('lockWelcomeBackNamed');
    if (raw != null) {
      return _fill(raw, {'name': name});
    }
    return _fallback.lockWelcomeBackNamed(name);
  }
  @override
  String lockSignedInAs(String name) {
    final raw = _string('lockSignedInAs');
    if (raw != null) {
      return _fill(raw, {'name': name});
    }
    return _fallback.lockSignedInAs(name);
  }
  @override
  String get lockEnterPin => _string('lockEnterPin') ?? _fallback.lockEnterPin;
  @override
  String get lockUnlock => _string('lockUnlock') ?? _fallback.lockUnlock;
  @override
  String get lockUnlocking => _string('lockUnlocking') ?? _fallback.lockUnlocking;
  @override
  String get lockUnlockWithPin => _string('lockUnlockWithPin') ?? _fallback.lockUnlockWithPin;
  @override
  String get shellOrders => _string('shellOrders') ?? _fallback.shellOrders;
  @override
  String get shellReports => _string('shellReports') ?? _fallback.shellReports;
  @override
  String get shellHeld => _string('shellHeld') ?? _fallback.shellHeld;
  @override
  String get shellLanguage => _string('shellLanguage') ?? _fallback.shellLanguage;
  @override
  String get shellCheckForUpdates => _string('shellCheckForUpdates') ?? _fallback.shellCheckForUpdates;
  @override
  String get shellKeyboardShortcuts => _string('shellKeyboardShortcuts') ?? _fallback.shellKeyboardShortcuts;
  @override
  String get shellLockRegister => _string('shellLockRegister') ?? _fallback.shellLockRegister;
  @override
  String get opsOpenShift => _string('opsOpenShift') ?? _fallback.opsOpenShift;
  @override
  String get opsCloseShift => _string('opsCloseShift') ?? _fallback.opsCloseShift;
  @override
  String get cartHold => _string('cartHold') ?? _fallback.cartHold;
  @override
  String get cartPay => _string('cartPay') ?? _fallback.cartPay;
  @override
  String get cartClear => _string('cartClear') ?? _fallback.cartClear;
  @override
  String get cartEmptyTitle => _string('cartEmptyTitle') ?? _fallback.cartEmptyTitle;
  @override
  String get cartEmptySubtitle => _string('cartEmptySubtitle') ?? _fallback.cartEmptySubtitle;
  @override
  String cartHeldTicket(String label) {
    final raw = _string('cartHeldTicket');
    if (raw != null) {
      return _fill(raw, {'label': label});
    }
    return _fallback.cartHeldTicket(label);
  }
  @override
  String get cartReplaceTitle => _string('cartReplaceTitle') ?? _fallback.cartReplaceTitle;
  @override
  String get cartReplaceMessage => _string('cartReplaceMessage') ?? _fallback.cartReplaceMessage;
  @override
  String get cartResume => _string('cartResume') ?? _fallback.cartResume;
  @override
  String get ordersTitle => _string('ordersTitle') ?? _fallback.ordersTitle;
  @override
  String get ordersHeldTab => _string('ordersHeldTab') ?? _fallback.ordersHeldTab;
  @override
  String get ordersOrdersTab => _string('ordersOrdersTab') ?? _fallback.ordersOrdersTab;
  @override
  String get ordersHeldSubtitle => _string('ordersHeldSubtitle') ?? _fallback.ordersHeldSubtitle;
  @override
  String ordersHeldCountSubtitle(int count) {
    final raw = _string('ordersHeldCountSubtitle');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.ordersHeldCountSubtitle(count);
  }
  @override
  String ordersHeldCountSubtitlePlural(int count) {
    final raw = _string('ordersHeldCountSubtitlePlural');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.ordersHeldCountSubtitlePlural(count);
  }
  @override
  String get ordersBranchActivity => _string('ordersBranchActivity') ?? _fallback.ordersBranchActivity;
  @override
  String get ordersHeldHint => _string('ordersHeldHint') ?? _fallback.ordersHeldHint;
  @override
  String get ordersSearchHint => _string('ordersSearchHint') ?? _fallback.ordersSearchHint;
  @override
  String get ordersFilterToday => _string('ordersFilterToday') ?? _fallback.ordersFilterToday;
  @override
  String get ordersFilterUnpaid => _string('ordersFilterUnpaid') ?? _fallback.ordersFilterUnpaid;
  @override
  String get ordersFilterSevenDays => _string('ordersFilterSevenDays') ?? _fallback.ordersFilterSevenDays;
  @override
  String get ordersNoHeldTitle => _string('ordersNoHeldTitle') ?? _fallback.ordersNoHeldTitle;
  @override
  String get ordersNoHeldSubtitle => _string('ordersNoHeldSubtitle') ?? _fallback.ordersNoHeldSubtitle;
  @override
  String get ordersNoOrdersTitle => _string('ordersNoOrdersTitle') ?? _fallback.ordersNoOrdersTitle;
  @override
  String get ordersNoOrdersSubtitle => _string('ordersNoOrdersSubtitle') ?? _fallback.ordersNoOrdersSubtitle;
  @override
  String get ordersCouldNotLoad => _string('ordersCouldNotLoad') ?? _fallback.ordersCouldNotLoad;
  @override
  String get ordersResumeTicket => _string('ordersResumeTicket') ?? _fallback.ordersResumeTicket;
  @override
  String get ordersAlreadyOnCart => _string('ordersAlreadyOnCart') ?? _fallback.ordersAlreadyOnCart;
  @override
  String get ordersOnCart => _string('ordersOnCart') ?? _fallback.ordersOnCart;
  @override
  String get ordersHeldTicket => _string('ordersHeldTicket') ?? _fallback.ordersHeldTicket;
  @override
  String ordersCollect(String amount) {
    final raw = _string('ordersCollect');
    if (raw != null) {
      return _fill(raw, {'amount': amount});
    }
    return _fallback.ordersCollect(amount);
  }
  @override
  String get ordersPrintReceipt => _string('ordersPrintReceipt') ?? _fallback.ordersPrintReceipt;
  @override
  String get ordersPrintKot => _string('ordersPrintKot') ?? _fallback.ordersPrintKot;
  @override
  String get ordersDetailTitle =>
      _string('ordersDetailTitle') ?? _fallback.ordersDetailTitle;
  @override
  String get ordersDetailLoading =>
      _string('ordersDetailLoading') ?? _fallback.ordersDetailLoading;
  @override
  String get ordersDetailItems =>
      _string('ordersDetailItems') ?? _fallback.ordersDetailItems;
  @override
  String get ordersDetailNoItems =>
      _string('ordersDetailNoItems') ?? _fallback.ordersDetailNoItems;
  @override
  String get ordersDetailPaid =>
      _string('ordersDetailPaid') ?? _fallback.ordersDetailPaid;
  @override
  String get ordersDetailDue =>
      _string('ordersDetailDue') ?? _fallback.ordersDetailDue;
  @override
  String printKotPrinted(String label) {
    final raw = _string('printKotPrinted');
    if (raw != null) {
      return _fill(raw, {'label': label});
    }
    return _fallback.printKotPrinted(label);
  }
  @override
  String ordersPaymentRecorded(String label) {
    final raw = _string('ordersPaymentRecorded');
    if (raw != null) {
      return _fill(raw, {'label': label});
    }
    return _fallback.ordersPaymentRecorded(label);
  }
  @override
  String ordersPaymentReceived(String label) {
    final raw = _string('ordersPaymentReceived');
    if (raw != null) {
      return _fill(raw, {'label': label});
    }
    return _fallback.ordersPaymentReceived(label);
  }
  @override
  String ordersPaymentNotCompleted(String label) {
    final raw = _string('ordersPaymentNotCompleted');
    if (raw != null) {
      return _fill(raw, {'label': label});
    }
    return _fallback.ordersPaymentNotCompleted(label);
  }
  @override
  String ordersLoaded(String label) {
    final raw = _string('ordersLoaded');
    if (raw != null) {
      return _fill(raw, {'label': label});
    }
    return _fallback.ordersLoaded(label);
  }
  @override
  String get ordersUpdated => _string('ordersUpdated') ?? _fallback.ordersUpdated;
  @override
  String get ordersCancelTitle => _string('ordersCancelTitle') ?? _fallback.ordersCancelTitle;
  @override
  String get ordersCancelMessage => _string('ordersCancelMessage') ?? _fallback.ordersCancelMessage;
  @override
  String ordersCancelPaidMessage(String amount) {
    final raw = _string('ordersCancelPaidMessage');
    if (raw != null) {
      return _fill(raw, {'amount': amount});
    }
    return _fallback.ordersCancelPaidMessage(amount);
  }
  @override
  String get ordersCancelConfirm => _string('ordersCancelConfirm') ?? _fallback.ordersCancelConfirm;
  @override
  String get ordersCancelAndRefund => _string('ordersCancelAndRefund') ?? _fallback.ordersCancelAndRefund;
  @override
  String get ordersCancelKeep => _string('ordersCancelKeep') ?? _fallback.ordersCancelKeep;
  @override
  String get ordersCancelled => _string('ordersCancelled') ?? _fallback.ordersCancelled;
  @override
  String get ordersCancelledRefunded => _string('ordersCancelledRefunded') ?? _fallback.ordersCancelledRefunded;
  @override
  String get ordersCancelAction => _string('ordersCancelAction') ?? _fallback.ordersCancelAction;
  @override
  String get payTakePayment => _string('payTakePayment') ?? _fallback.payTakePayment;
  @override
  String get payCollectPayment => _string('payCollectPayment') ?? _fallback.payCollectPayment;
  @override
  String get payAmountDue => _string('payAmountDue') ?? _fallback.payAmountDue;
  @override
  String get payCash => _string('payCash') ?? _fallback.payCash;
  @override
  String get payCashSubtitle => _string('payCashSubtitle') ?? _fallback.payCashSubtitle;
  @override
  String get payCard => _string('payCard') ?? _fallback.payCard;
  @override
  String get payCardSubtitle => _string('payCardSubtitle') ?? _fallback.payCardSubtitle;
  @override
  String get payWallet => _string('payWallet') ?? _fallback.payWallet;
  @override
  String get payWalletSubtitle => _string('payWalletSubtitle') ?? _fallback.payWalletSubtitle;
  @override
  String get payOther => _string('payOther') ?? _fallback.payOther;
  @override
  String get payOtherSubtitle => _string('payOtherSubtitle') ?? _fallback.payOtherSubtitle;
  @override
  String get payLater => _string('payLater') ?? _fallback.payLater;
  @override
  String get payLaterSubtitle => _string('payLaterSubtitle') ?? _fallback.payLaterSubtitle;
  @override
  String get payUpiQr => _string('payUpiQr') ?? _fallback.payUpiQr;
  @override
  String get payConfirm => _string('payConfirm') ?? _fallback.payConfirm;
  @override
  String get shiftOpenTitle => _string('shiftOpenTitle') ?? _fallback.shiftOpenTitle;
  @override
  String get shiftCloseTitle => _string('shiftCloseTitle') ?? _fallback.shiftCloseTitle;
  @override
  String get authAccountLoadFailed => _string('authAccountLoadFailed') ?? _fallback.authAccountLoadFailed;
  @override
  String get authLoginNoToken => _string('authLoginNoToken') ?? _fallback.authLoginNoToken;
  @override
  String get authNoRestaurantBranch => _string('authNoRestaurantBranch') ?? _fallback.authNoRestaurantBranch;
  @override
  String get authNotSignedIn => _string('authNotSignedIn') ?? _fallback.authNotSignedIn;
  @override
  String get authSessionExpired => _string('authSessionExpired') ?? _fallback.authSessionExpired;
  @override
  String get authSignOutFromLock => _string('authSignOutFromLock') ?? _fallback.authSignOutFromLock;
  @override
  String get authSignOutMessageNoPin => _string('authSignOutMessageNoPin') ?? _fallback.authSignOutMessageNoPin;
  @override
  String get authSignOutMessageWithPin => _string('authSignOutMessageWithPin') ?? _fallback.authSignOutMessageWithPin;
  @override
  String get authSignOutTitle => _string('authSignOutTitle') ?? _fallback.authSignOutTitle;
  @override
  String get brandTagline => _string('brandTagline') ?? _fallback.brandTagline;
  @override
  String get cartAddCustomer => _string('cartAddCustomer') ?? _fallback.cartAddCustomer;
  @override
  String get cartClearCustomer => _string('cartClearCustomer') ?? _fallback.cartClearCustomer;
  @override
  String get cartClearMessage => _string('cartClearMessage') ?? _fallback.cartClearMessage;
  @override
  String get cartClearTitle => _string('cartClearTitle') ?? _fallback.cartClearTitle;
  @override
  String get cartClearTooltip => _string('cartClearTooltip') ?? _fallback.cartClearTooltip;
  @override
  String get cartCurrentTicket => _string('cartCurrentTicket') ?? _fallback.cartCurrentTicket;
  @override
  String get cartCustomerFallback => _string('cartCustomerFallback') ?? _fallback.cartCustomerFallback;
  @override
  String get cartCustomerNameHint => _string('cartCustomerNameHint') ?? _fallback.cartCustomerNameHint;
  @override
  String get cartCustomerSearchHint => _string('cartCustomerSearchHint') ?? _fallback.cartCustomerSearchHint;
  @override
  String get cartEmptyPanelSubtitle => _string('cartEmptyPanelSubtitle') ?? _fallback.cartEmptyPanelSubtitle;
  @override
  String get cartEmptyPanelTitle => _string('cartEmptyPanelTitle') ?? _fallback.cartEmptyPanelTitle;
  @override
  String cartHeldSnack(String label) {
    final raw = _string('cartHeldSnack');
    if (raw != null) {
      return _fill(raw, {'label': label});
    }
    return _fallback.cartHeldSnack(label);
  }
  @override
  String get cartIsEmptyError => _string('cartIsEmptyError') ?? _fallback.cartIsEmptyError;
  @override
  String cartItemCount(int count) {
    final raw = _string('cartItemCount');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.cartItemCount(count);
  }
  @override
  String cartItemCountPlural(int count) {
    final raw = _string('cartItemCountPlural');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.cartItemCountPlural(count);
  }
  @override
  String get cartNoItemsYet => _string('cartNoItemsYet') ?? _fallback.cartNoItemsYet;
  @override
  String get cartNoTable => _string('cartNoTable') ?? _fallback.cartNoTable;
  @override
  String get cartNoTablesSubtitle => _string('cartNoTablesSubtitle') ?? _fallback.cartNoTablesSubtitle;
  @override
  String get cartNoTablesTitle => _string('cartNoTablesTitle') ?? _fallback.cartNoTablesTitle;
  @override
  String get cartPayable => _string('cartPayable') ?? _fallback.cartPayable;
  @override
  String get cartRemoveLine => _string('cartRemoveLine') ?? _fallback.cartRemoveLine;
  @override
  String get cartSaveName => _string('cartSaveName') ?? _fallback.cartSaveName;
  @override
  String get cartSelectTable => _string('cartSelectTable') ?? _fallback.cartSelectTable;
  @override
  String get cartServiceCharge => _string('cartServiceCharge') ?? _fallback.cartServiceCharge;
  @override
  String get cartTable => _string('cartTable') ?? _fallback.cartTable;
  @override
  String cartTableNamed(String name) {
    final raw = _string('cartTableNamed');
    if (raw != null) {
      return _fill(raw, {'name': name});
    }
    return _fallback.cartTableNamed(name);
  }
  @override
  String get cartTableOccupied => _string('cartTableOccupied') ?? _fallback.cartTableOccupied;
  @override
  String get cartTablesLegend => _string('cartTablesLegend') ?? _fallback.cartTablesLegend;
  @override
  String get cartTablesOther => _string('cartTablesOther') ?? _fallback.cartTablesOther;
  @override
  String get cartTax => _string('cartTax') ?? _fallback.cartTax;
  @override
  String get cartTicketNotes => _string('cartTicketNotes') ?? _fallback.cartTicketNotes;
  @override
  String get cartTicketNotesHint => _string('cartTicketNotesHint') ?? _fallback.cartTicketNotesHint;
  @override
  String get commonConfirm => _string('commonConfirm') ?? _fallback.commonConfirm;
  @override
  String get commonDismiss => _string('commonDismiss') ?? _fallback.commonDismiss;
  @override
  String get confirmDestructiveSubtitle => _string('confirmDestructiveSubtitle') ?? _fallback.confirmDestructiveSubtitle;
  @override
  String get connIssueFooter => _string('connIssueFooter') ?? _fallback.connIssueFooter;
  @override
  String get connIssueTitle => _string('connIssueTitle') ?? _fallback.connIssueTitle;
  @override
  String get connUnableToReach => _string('connUnableToReach') ?? _fallback.connUnableToReach;
  @override
  String get subscriptionEndedTitle => _string('subscriptionEndedTitle') ?? _fallback.subscriptionEndedTitle;
  @override
  String get subscriptionTrialEndedTitle => _string('subscriptionTrialEndedTitle') ?? _fallback.subscriptionTrialEndedTitle;
  @override
  String get subscriptionEndedBody => _string('subscriptionEndedBody') ?? _fallback.subscriptionEndedBody;
  @override
  String get subscriptionTrialEndedBody => _string('subscriptionTrialEndedBody') ?? _fallback.subscriptionTrialEndedBody;
  @override
  String get subscriptionEndedFooter => _string('subscriptionEndedFooter') ?? _fallback.subscriptionEndedFooter;
  @override
  String get billingTitle => _string('billingTitle') ?? _fallback.billingTitle;
  @override
  String get billingManageSubtitle => _string('billingManageSubtitle') ?? _fallback.billingManageSubtitle;
  @override
  String get billingUpgradePlan => _string('billingUpgradePlan') ?? _fallback.billingUpgradePlan;
  @override
  String get billingUpgradeBody => _string('billingUpgradeBody') ?? _fallback.billingUpgradeBody;
  @override
  String get billingRenewBody => _string('billingRenewBody') ?? _fallback.billingRenewBody;
  @override
  String get billingUpgradeFooter => _string('billingUpgradeFooter') ?? _fallback.billingUpgradeFooter;
  @override
  String get billingChoosePlan => _string('billingChoosePlan') ?? _fallback.billingChoosePlan;
  @override
  String get billingMonthly => _string('billingMonthly') ?? _fallback.billingMonthly;
  @override
  String get billingYearly => _string('billingYearly') ?? _fallback.billingYearly;
  @override
  String get billingSubscribe => _string('billingSubscribe') ?? _fallback.billingSubscribe;
  @override
  String get billingActivateFree => _string('billingActivateFree') ?? _fallback.billingActivateFree;
  @override
  String get billingCurrentPlan => _string('billingCurrentPlan') ?? _fallback.billingCurrentPlan;
  @override
  String billingPayWith(String provider) {
    final raw = _string('billingPayWith');
    if (raw != null) {
      return _fill(raw, {'provider': provider});
    }
    return _fallback.billingPayWith(provider);
  }
  @override
  String get billingPaymentOff => _string('billingPaymentOff') ?? _fallback.billingPaymentOff;
  @override
  String get billingPaymentProvider => _string('billingPaymentProvider') ?? _fallback.billingPaymentProvider;
  @override
  String billingCoveredBody(String org) {
    final raw = _string('billingCoveredBody');
    if (raw != null) {
      return _fill(raw, {'org': org});
    }
    return _fallback.billingCoveredBody(org);
  }
  @override
  String get billingOrganization => _string('billingOrganization') ?? _fallback.billingOrganization;
  @override
  String get billingIvePaid => _string('billingIvePaid') ?? _fallback.billingIvePaid;
  @override
  String get billingReturnFromCheckout => _string('billingReturnFromCheckout') ?? _fallback.billingReturnFromCheckout;
  @override
  String get billingNoPlans => _string('billingNoPlans') ?? _fallback.billingNoPlans;
  @override
  String get billingFree => _string('billingFree') ?? _fallback.billingFree;
  @override
  String get billingPerMonth => _string('billingPerMonth') ?? _fallback.billingPerMonth;
  @override
  String get billingPerYear => _string('billingPerYear') ?? _fallback.billingPerYear;
  @override
  String get billingActivated => _string('billingActivated') ?? _fallback.billingActivated;
  @override
  String get billingPaymentPending => _string('billingPaymentPending') ?? _fallback.billingPaymentPending;
  @override
  String get contextBranch => _string('contextBranch') ?? _fallback.contextBranch;
  @override
  String get contextChooseLocation => _string('contextChooseLocation') ?? _fallback.contextChooseLocation;
  @override
  String get contextCurrentRestaurant => _string('contextCurrentRestaurant') ?? _fallback.contextCurrentRestaurant;
  @override
  String get contextDefaultBranch => _string('contextDefaultBranch') ?? _fallback.contextDefaultBranch;
  @override
  String get contextFooterNote => _string('contextFooterNote') ?? _fallback.contextFooterNote;
  @override
  String get contextNoOtherLocation =>
      _string('contextNoOtherLocation') ?? _fallback.contextNoOtherLocation;
  @override
  String get contextRestaurant => _string('contextRestaurant') ?? _fallback.contextRestaurant;
  @override
  String get contextSubtitle => _string('contextSubtitle') ?? _fallback.contextSubtitle;
  @override
  String get dietNonVeg => _string('dietNonVeg') ?? _fallback.dietNonVeg;
  @override
  String get dietVeg => _string('dietVeg') ?? _fallback.dietVeg;
  @override
  String get dietVegan => _string('dietVegan') ?? _fallback.dietVegan;
  @override
  String get dietEgg => _string('dietEgg') ?? _fallback.dietEgg;
  @override
  String get dietDrink => _string('dietDrink') ?? _fallback.dietDrink;
  @override
  String get discountAmount => _string('discountAmount') ?? _fallback.discountAmount;
  @override
  String get discountApply => _string('discountApply') ?? _fallback.discountApply;
  @override
  String get discountApplyTitle => _string('discountApplyTitle') ?? _fallback.discountApplyTitle;
  @override
  String get discountEditTitle => _string('discountEditTitle') ?? _fallback.discountEditTitle;
  @override
  String get discountLabel => _string('discountLabel') ?? _fallback.discountLabel;
  @override
  String get discountNewTaxableBase => _string('discountNewTaxableBase') ?? _fallback.discountNewTaxableBase;
  @override
  String discountOffSubtotal(String amount) {
    final raw = _string('discountOffSubtotal');
    if (raw != null) {
      return _fill(raw, {'amount': amount});
    }
    return _fallback.discountOffSubtotal(amount);
  }
  @override
  String get discountPercent => _string('discountPercent') ?? _fallback.discountPercent;
  @override
  String get discountReason => _string('discountReason') ?? _fallback.discountReason;
  @override
  String get discountReasonHint => _string('discountReasonHint') ?? _fallback.discountReasonHint;
  @override
  String get discountRemove => _string('discountRemove') ?? _fallback.discountRemove;
  @override
  String get discountTypeLabel => _string('discountTypeLabel') ?? _fallback.discountTypeLabel;
  @override
  String get discountUpdate => _string('discountUpdate') ?? _fallback.discountUpdate;
  @override
  String get menuAllItems => _string('menuAllItems') ?? _fallback.menuAllItems;
  @override
  String get menuBarcodeTooltip => _string('menuBarcodeTooltip') ?? _fallback.menuBarcodeTooltip;
  @override
  String get menuBrowseFull => _string('menuBrowseFull') ?? _fallback.menuBrowseFull;
  @override
  String get menuCategoryFallback => _string('menuCategoryFallback') ?? _fallback.menuCategoryFallback;
  @override
  String get menuCategoryItems => _string('menuCategoryItems') ?? _fallback.menuCategoryItems;
  @override
  String get menuChoose => _string('menuChoose') ?? _fallback.menuChoose;
  @override
  String get menuFrom => _string('menuFrom') ?? _fallback.menuFrom;
  @override
  String get menuNavLabel => _string('menuNavLabel') ?? _fallback.menuNavLabel;
  @override
  String get menuNoItemsSubtitle => _string('menuNoItemsSubtitle') ?? _fallback.menuNoItemsSubtitle;
  @override
  String get menuNoItemsTitle => _string('menuNoItemsTitle') ?? _fallback.menuNoItemsTitle;
  @override
  String get menuOptions => _string('menuOptions') ?? _fallback.menuOptions;
  @override
  String get menuNotAvailableBadge => _string('menuNotAvailableBadge') ?? _fallback.menuNotAvailableBadge;
  @override
  String get menuNotAvailableTitle => _string('menuNotAvailableTitle') ?? _fallback.menuNotAvailableTitle;
  @override
  String menuNotAvailableMessage(String name) {
    final raw = _string('menuNotAvailableMessage');
    if (raw != null) {
      return _fill(raw, {'name': name});
    }
    return _fallback.menuNotAvailableMessage(name);
  }
  @override
  String get menuNotAvailableConfirm => _string('menuNotAvailableConfirm') ?? _fallback.menuNotAvailableConfirm;
  @override
  String get menuOutsideScheduleBadge => _string('menuOutsideScheduleBadge') ?? _fallback.menuOutsideScheduleBadge;
  @override
  String get menuOutsideScheduleTitle => _string('menuOutsideScheduleTitle') ?? _fallback.menuOutsideScheduleTitle;
  @override
  String menuOutsideScheduleMessage(String name) {
    final raw = _string('menuOutsideScheduleMessage');
    if (raw != null) {
      return _fill(raw, {'name': name});
    }
    return _fallback.menuOutsideScheduleMessage(name);
  }
  @override
  String get menuOutsideScheduleConfirm => _string('menuOutsideScheduleConfirm') ?? _fallback.menuOutsideScheduleConfirm;
  @override
  String get menuPopularSubtitle => _string('menuPopularSubtitle') ?? _fallback.menuPopularSubtitle;
  @override
  String get menuPopularTitle => _string('menuPopularTitle') ?? _fallback.menuPopularTitle;
  @override
  String get menuScan => _string('menuScan') ?? _fallback.menuScan;
  @override
  String get menuSearchHint => _string('menuSearchHint') ?? _fallback.menuSearchHint;
  @override
  String menuSearchResults(String query) {
    final raw = _string('menuSearchResults');
    if (raw != null) {
      return _fill(raw, {'query': query});
    }
    return _fallback.menuSearchResults(query);
  }
  @override
  String get modifierAddToTicket => _string('modifierAddToTicket') ?? _fallback.modifierAddToTicket;
  @override
  String modifierChooseUpTo(int max, String name) {
    final raw = _string('modifierChooseUpTo');
    if (raw != null) {
      return _fill(raw, {'max': max, 'name': name});
    }
    return _fallback.modifierChooseUpTo(max, name);
  }
  @override
  String get modifierChooseVariant => _string('modifierChooseVariant') ?? _fallback.modifierChooseVariant;
  @override
  String get modifierNotesHint => _string('modifierNotesHint') ?? _fallback.modifierNotesHint;
  @override
  String get modifierOptional => _string('modifierOptional') ?? _fallback.modifierOptional;
  @override
  String modifierPleaseChoose(String name) {
    final raw = _string('modifierPleaseChoose');
    if (raw != null) {
      return _fill(raw, {'name': name});
    }
    return _fallback.modifierPleaseChoose(name);
  }
  @override
  String get modifierQuantity => _string('modifierQuantity') ?? _fallback.modifierQuantity;
  @override
  String get modifierRequired => _string('modifierRequired') ?? _fallback.modifierRequired;
  @override
  String get modifierSpecialInstructions => _string('modifierSpecialInstructions') ?? _fallback.modifierSpecialInstructions;
  @override
  String get netBlocked => _string('netBlocked') ?? _fallback.netBlocked;
  @override
  String netCannotConnect(String url) {
    final raw = _string('netCannotConnect');
    if (raw != null) {
      return _fill(raw, {'url': url});
    }
    return _fallback.netCannotConnect(url);
  }
  @override
  String netCannotReach(String url) {
    final raw = _string('netCannotReach');
    if (raw != null) {
      return _fill(raw, {'url': url});
    }
    return _fallback.netCannotReach(url);
  }
  @override
  String get errorGeneric => _string('errorGeneric') ?? _fallback.errorGeneric;
  @override
  String get errorNetwork => _string('errorNetwork') ?? _fallback.errorNetwork;
  @override
  String get offlineBanner => _string('offlineBanner') ?? _fallback.offlineBanner;
  @override
  String get offlineLabel => _string('offlineLabel') ?? _fallback.offlineLabel;
  @override
  String get offlineNotAvailable => _string('offlineNotAvailable') ?? _fallback.offlineNotAvailable;
  @override
  String offlinePending(int count) {
    final raw = _string('offlinePending');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.offlinePending(count);
  }
  @override
  String get offlineSyncing => _string('offlineSyncing') ?? _fallback.offlineSyncing;
  @override
  String offlineSyncFailed(int count) {
    final raw = _string('offlineSyncFailed');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.offlineSyncFailed(count);
  }
  @override
  String offlineSyncFailedBanner(int count) {
    final raw = _string('offlineSyncFailedBanner');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.offlineSyncFailedBanner(count);
  }
  @override
  String get offlinePaymentBlocked => _string('offlinePaymentBlocked') ?? _fallback.offlinePaymentBlocked;
  @override
  String get offlineHeldPayBlocked => _string('offlineHeldPayBlocked') ?? _fallback.offlineHeldPayBlocked;
  @override
  String get offlineHeldNotFound => _string('offlineHeldNotFound') ?? _fallback.offlineHeldNotFound;
  @override
  String get offlinePinNeedsNetwork => _string('offlinePinNeedsNetwork') ?? _fallback.offlinePinNeedsNetwork;
  @override
  String get offlineSyncNothingPending => _string('offlineSyncNothingPending') ?? _fallback.offlineSyncNothingPending;
  @override
  String offlineSyncPartial(int count) {
    final raw = _string('offlineSyncPartial');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.offlineSyncPartial(count);
  }
  @override
  String get opsNoShift => _string('opsNoShift') ?? _fallback.opsNoShift;
  @override
  String get opsOpenOptional => _string('opsOpenOptional') ?? _fallback.opsOpenOptional;
  @override
  String get opsOpenToTakeOrders => _string('opsOpenToTakeOrders') ?? _fallback.opsOpenToTakeOrders;
  @override
  String get opsRegShort => _string('opsRegShort') ?? _fallback.opsRegShort;
  @override
  String get opsRegisterReady => _string('opsRegisterReady') ?? _fallback.opsRegisterReady;
  @override
  String get opsShiftOpen => _string('opsShiftOpen') ?? _fallback.opsShiftOpen;
  @override
  String get opsShiftRequired => _string('opsShiftRequired') ?? _fallback.opsShiftRequired;
  @override
  String opsSince(String time) {
    final raw = _string('opsSince');
    if (raw != null) {
      return _fill(raw, {'time': time});
    }
    return _fallback.opsSince(time);
  }
  @override
  String orderPlaced(String label) {
    final raw = _string('orderPlaced');
    if (raw != null) {
      return _fill(raw, {'label': label});
    }
    return _fallback.orderPlaced(label);
  }
  @override
  String orderSavedOffline(String label) {
    final raw = _string('orderSavedOffline');
    if (raw != null) {
      return _fill(raw, {'label': label});
    }
    return _fallback.orderSavedOffline(label);
  }
  @override
  String get orderTypeDelivery => _string('orderTypeDelivery') ?? _fallback.orderTypeDelivery;
  @override
  String get orderTypeDineIn => _string('orderTypeDineIn') ?? _fallback.orderTypeDineIn;
  @override
  String get orderTypeTakeaway => _string('orderTypeTakeaway') ?? _fallback.orderTypeTakeaway;
  @override
  String get ordersAdvanceAccept => _string('ordersAdvanceAccept') ?? _fallback.ordersAdvanceAccept;
  @override
  String get ordersAdvanceDone => _string('ordersAdvanceDone') ?? _fallback.ordersAdvanceDone;
  @override
  String get ordersAdvanceKitchen => _string('ordersAdvanceKitchen') ?? _fallback.ordersAdvanceKitchen;
  @override
  String get ordersAdvanceReady => _string('ordersAdvanceReady') ?? _fallback.ordersAdvanceReady;
  @override
  String ordersItemCount(int count) {
    final raw = _string('ordersItemCount');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.ordersItemCount(count);
  }
  @override
  String ordersItemCountPlural(int count) {
    final raw = _string('ordersItemCountPlural');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.ordersItemCountPlural(count);
  }
  @override
  String ordersMoreItems(int count) {
    final raw = _string('ordersMoreItems');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.ordersMoreItems(count);
  }
  @override
  String get ordersNumberMissing => _string('ordersNumberMissing') ?? _fallback.ordersNumberMissing;
  @override
  String ordersPagination(int from, int to, int total) {
    final raw = _string('ordersPagination');
    if (raw != null) {
      return _fill(raw, {'from': from, 'to': to, 'total': total});
    }
    return _fallback.ordersPagination(from, to, total);
  }
  @override
  String ordersTokenLabel(String token) {
    final raw = _string('ordersTokenLabel');
    if (raw != null) {
      return _fill(raw, {'token': token});
    }
    return _fallback.ordersTokenLabel(token);
  }
  @override
  String get pairAdminHint => _string('pairAdminHint') ?? _fallback.pairAdminHint;
  @override
  String get pairCodeExpired => _string('pairCodeExpired') ?? _fallback.pairCodeExpired;
  @override
  String get pairThisTablet => _string('pairThisTablet') ?? _fallback.pairThisTablet;
  @override
  String get pairWaitingManager => _string('pairWaitingManager') ?? _fallback.pairWaitingManager;
  @override
  String get payCashTendered => _string('payCashTendered') ?? _fallback.payCashTendered;
  @override
  String get payChangeDue => _string('payChangeDue') ?? _fallback.payChangeDue;
  @override
  String payCharge(String amount) {
    final raw = _string('payCharge');
    if (raw != null) {
      return _fill(raw, {'amount': amount});
    }
    return _fallback.payCharge(amount);
  }
  @override
  String payConfirmMethod(String method) {
    final raw = _string('payConfirmMethod');
    if (raw != null) {
      return _fill(raw, {'method': method});
    }
    return _fallback.payConfirmMethod(method);
  }
  @override
  String get payExact => _string('payExact') ?? _fallback.payExact;
  @override
  String get payLaterHelp => _string('payLaterHelp') ?? _fallback.payLaterHelp;
  @override
  String get payMethodLabel => _string('payMethodLabel') ?? _fallback.payMethodLabel;
  @override
  String get payNotCompleted => _string('payNotCompleted') ?? _fallback.payNotCompleted;
  @override
  String get payPlaceOrder => _string('payPlaceOrder') ?? _fallback.payPlaceOrder;
  @override
  String get payPlaceWithout => _string('payPlaceWithout') ?? _fallback.payPlaceWithout;
  @override
  String get payQrHelp => _string('payQrHelp') ?? _fallback.payQrHelp;
  @override
  String get payReceived => _string('payReceived') ?? _fallback.payReceived;
  @override
  String get payShort => _string('payShort') ?? _fallback.payShort;
  @override
  String get payShortHelp => _string('payShortHelp') ?? _fallback.payShortHelp;
  @override
  String get payShowQr => _string('payShowQr') ?? _fallback.payShowQr;
  @override
  String get payTerminalHelp => _string('payTerminalHelp') ?? _fallback.payTerminalHelp;
  @override
  String get payTip => _string('payTip') ?? _fallback.payTip;
  @override
  String get payTipCustom => _string('payTipCustom') ?? _fallback.payTipCustom;
  @override
  String get payTipNone => _string('payTipNone') ?? _fallback.payTipNone;
  @override
  String get payUpi => _string('payUpi') ?? _fallback.payUpi;
  @override
  String get pinAccountPassword => _string('pinAccountPassword') ?? _fallback.pinAccountPassword;
  @override
  String get pinBannerBody => _string('pinBannerBody') ?? _fallback.pinBannerBody;
  @override
  String get pinBannerTitle => _string('pinBannerTitle') ?? _fallback.pinBannerTitle;
  @override
  String get pinChangeTitle => _string('pinChangeTitle') ?? _fallback.pinChangeTitle;
  @override
  String get pinConfirm => _string('pinConfirm') ?? _fallback.pinConfirm;
  @override
  String get pinCreateSubtitle => _string('pinCreateSubtitle') ?? _fallback.pinCreateSubtitle;
  @override
  String get pinIncorrect => _string('pinIncorrect') ?? _fallback.pinIncorrect;
  @override
  String get pinMismatch => _string('pinMismatch') ?? _fallback.pinMismatch;
  @override
  String get pinMustBeSix => _string('pinMustBeSix') ?? _fallback.pinMustBeSix;
  @override
  String get pinNeedPassword => _string('pinNeedPassword') ?? _fallback.pinNeedPassword;
  @override
  String get pinNew => _string('pinNew') ?? _fallback.pinNew;
  @override
  String get pinPasswordHelper => _string('pinPasswordHelper') ?? _fallback.pinPasswordHelper;
  @override
  String get pinPromptMessage => _string('pinPromptMessage') ?? _fallback.pinPromptMessage;
  @override
  String get pinPromptNotNow => _string('pinPromptNotNow') ?? _fallback.pinPromptNotNow;
  @override
  String get pinPromptSet => _string('pinPromptSet') ?? _fallback.pinPromptSet;
  @override
  String get pinPromptSetNow => _string('pinPromptSetNow') ?? _fallback.pinPromptSetNow;
  @override
  String get pinPromptTitle => _string('pinPromptTitle') ?? _fallback.pinPromptTitle;
  @override
  String get pinSave => _string('pinSave') ?? _fallback.pinSave;
  @override
  String get pinSaveFailed => _string('pinSaveFailed') ?? _fallback.pinSaveFailed;
  @override
  String get pinSaved => _string('pinSaved') ?? _fallback.pinSaved;
  @override
  String get pinSetTitle => _string('pinSetTitle') ?? _fallback.pinSetTitle;
  @override
  String get pinUpdate => _string('pinUpdate') ?? _fallback.pinUpdate;
  @override
  String get poweredBy => _string('poweredBy') ?? _fallback.poweredBy;
  @override
  String printCouldNot(String error) {
    final raw = _string('printCouldNot');
    if (raw != null) {
      return _fill(raw, {'error': error});
    }
    return _fallback.printCouldNot(error);
  }
  @override
  String printOrderNotFound(String label) {
    final raw = _string('printOrderNotFound');
    if (raw != null) {
      return _fill(raw, {'label': label});
    }
    return _fallback.printOrderNotFound(label);
  }
  @override
  String printPrinted(String label) {
    final raw = _string('printPrinted');
    if (raw != null) {
      return _fill(raw, {'label': label});
    }
    return _fallback.printPrinted(label);
  }
  @override
  String printReceiptConfirmMessage(String label) {
    final raw = _string('printReceiptConfirmMessage');
    if (raw != null) {
      return _fill(raw, {'label': label});
    }
    return _fallback.printReceiptConfirmMessage(label);
  }
  @override
  String get printReceiptConfirmTitle => _string('printReceiptConfirmTitle') ?? _fallback.printReceiptConfirmTitle;
  @override
  String get printerActive => _string('printerActive') ?? _fallback.printerActive;
  @override
  String get printerAutoPrintKot => _string('printerAutoPrintKot') ?? _fallback.printerAutoPrintKot;
  @override
  String get printerAutoPrintKotHelp => _string('printerAutoPrintKotHelp') ?? _fallback.printerAutoPrintKotHelp;
  @override
  String get printerAutoPrintKotOnSnack => _string('printerAutoPrintKotOnSnack') ?? _fallback.printerAutoPrintKotOnSnack;
  @override
  String get printerAutoPrintKotOffSnack => _string('printerAutoPrintKotOffSnack') ?? _fallback.printerAutoPrintKotOffSnack;
  @override
  String get printerTestPrint => _string('printerTestPrint') ?? _fallback.printerTestPrint;
  @override
  String get printerTestSent => _string('printerTestSent') ?? _fallback.printerTestSent;
  @override
  String get printerTestFailed => _string('printerTestFailed') ?? _fallback.printerTestFailed;
  @override
  String get printerTesting => _string('printerTesting') ?? _fallback.printerTesting;
  @override
  String get printerBluetoothHint => _string('printerBluetoothHint') ?? _fallback.printerBluetoothHint;
  @override
  String get printerBluetoothTitle => _string('printerBluetoothTitle') ?? _fallback.printerBluetoothTitle;
  @override
  String get printerConfirmBefore => _string('printerConfirmBefore') ?? _fallback.printerConfirmBefore;
  @override
  String printerConnectBt(String name) {
    final raw = _string('printerConnectBt');
    if (raw != null) {
      return _fill(raw, {'name': name});
    }
    return _fallback.printerConnectBt(name);
  }
  @override
  String printerConnectMac(String name) {
    final raw = _string('printerConnectMac');
    if (raw != null) {
      return _fill(raw, {'name': name});
    }
    return _fallback.printerConnectMac(name);
  }
  @override
  String printerConnectUsb(String name) {
    final raw = _string('printerConnectUsb');
    if (raw != null) {
      return _fill(raw, {'name': name});
    }
    return _fallback.printerConnectUsb(name);
  }
  @override
  String printerConnectWeb(String name) {
    final raw = _string('printerConnectWeb');
    if (raw != null) {
      return _fill(raw, {'name': name});
    }
    return _fallback.printerConnectWeb(name);
  }
  @override
  String printerCountFound(int count) {
    final raw = _string('printerCountFound');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.printerCountFound(count);
  }
  @override
  String get printerEmptyBt => _string('printerEmptyBt') ?? _fallback.printerEmptyBt;
  @override
  String get printerEmptyUsb => _string('printerEmptyUsb') ?? _fallback.printerEmptyUsb;
  @override
  String get printerEmptyWeb => _string('printerEmptyWeb') ?? _fallback.printerEmptyWeb;
  @override
  String get printerHelpAndroid => _string('printerHelpAndroid') ?? _fallback.printerHelpAndroid;
  @override
  String get printerHelpIos => _string('printerHelpIos') ?? _fallback.printerHelpIos;
  @override
  String get printerHelpMac => _string('printerHelpMac') ?? _fallback.printerHelpMac;
  @override
  String get printerHelpWin => _string('printerHelpWin') ?? _fallback.printerHelpWin;
  @override
  String printerConnectLan(String name, String endpoint) {
    final raw = _string('printerConnectLan');
    if (raw != null) {
      return _fill(raw, {'name': name, 'endpoint': endpoint});
    }
    return _fallback.printerConnectLan(name, endpoint);
  }
  @override
  String get printerLanTitle => _string('printerLanTitle') ?? _fallback.printerLanTitle;
  @override
  String get printerLanHint => _string('printerLanHint') ?? _fallback.printerLanHint;
  @override
  String get printerLanHost => _string('printerLanHost') ?? _fallback.printerLanHost;
  @override
  String get printerLanPort => _string('printerLanPort') ?? _fallback.printerLanPort;
  @override
  String get printerLanNameOptional => _string('printerLanNameOptional') ?? _fallback.printerLanNameOptional;
  @override
  String get printerLanNameHint => _string('printerLanNameHint') ?? _fallback.printerLanNameHint;
  @override
  String get printerLanSave => _string('printerLanSave') ?? _fallback.printerLanSave;
  @override
  String get printerLanHostRequired => _string('printerLanHostRequired') ?? _fallback.printerLanHostRequired;
  @override
  String get printerLanPortInvalid => _string('printerLanPortInvalid') ?? _fallback.printerLanPortInvalid;
  @override
  String get printerLoadFailed => _string('printerLoadFailed') ?? _fallback.printerLoadFailed;
  @override
  String get printerLooking => _string('printerLooking') ?? _fallback.printerLooking;
  @override
  String get printerMissing => _string('printerMissing') ?? _fallback.printerMissing;
  @override
  String get printerMissingWeb => _string('printerMissingWeb') ?? _fallback.printerMissingWeb;
  @override
  String get printerNoBluetooth => _string('printerNoBluetooth') ?? _fallback.printerNoBluetooth;
  @override
  String get printerNoneFound => _string('printerNoneFound') ?? _fallback.printerNoneFound;
  @override
  String get printerReceiptTitle => _string('printerReceiptTitle') ?? _fallback.printerReceiptTitle;
  @override
  String get printerScan => _string('printerScan') ?? _fallback.printerScan;
  @override
  String get printerScanAgain => _string('printerScanAgain') ?? _fallback.printerScanAgain;
  @override
  String get printerScanAskHelp => _string('printerScanAskHelp') ?? _fallback.printerScanAskHelp;
  @override
  String get printerScanAskSnack => _string('printerScanAskSnack') ?? _fallback.printerScanAskSnack;
  @override
  String get printerScanAutoHelp => _string('printerScanAutoHelp') ?? _fallback.printerScanAutoHelp;
  @override
  String get printerScanAutoSnack => _string('printerScanAutoSnack') ?? _fallback.printerScanAutoSnack;
  @override
  String get printerScanBluetooth => _string('printerScanBluetooth') ?? _fallback.printerScanBluetooth;
  @override
  String get printerScanToPrint => _string('printerScanToPrint') ?? _fallback.printerScanToPrint;
  @override
  String get statusPrinterReady => _string('statusPrinterReady') ?? _fallback.statusPrinterReady;
  @override
  String get statusPrinterNone => _string('statusPrinterNone') ?? _fallback.statusPrinterNone;
  @override
  String get statusPrinterMissing => _string('statusPrinterMissing') ?? _fallback.statusPrinterMissing;
  @override
  String get statusPrinterMissingHelp => _string('statusPrinterMissingHelp') ?? _fallback.statusPrinterMissingHelp;
  @override
  String get statusPrinterNeedsSetup => _string('statusPrinterNeedsSetup') ?? _fallback.statusPrinterNeedsSetup;
  @override
  String get statusPrinterNeedsSetupHelp => _string('statusPrinterNeedsSetupHelp') ?? _fallback.statusPrinterNeedsSetupHelp;
  @override
  String get statusPrinterAttentionHelp => _string('statusPrinterAttentionHelp') ?? _fallback.statusPrinterAttentionHelp;
  @override
  String get statusPrinterError => _string('statusPrinterError') ?? _fallback.statusPrinterError;
  @override
  String get statusPrinterErrorHelp => _string('statusPrinterErrorHelp') ?? _fallback.statusPrinterErrorHelp;
  @override
  String get statusPrinterUnsupported => _string('statusPrinterUnsupported') ?? _fallback.statusPrinterUnsupported;
  @override
  String get statusPrinterTapSetup => _string('statusPrinterTapSetup') ?? _fallback.statusPrinterTapSetup;
  @override
  String get statusPrinterRecheck => _string('statusPrinterRecheck') ?? _fallback.statusPrinterRecheck;
  @override
  String get printerScanning => _string('printerScanning') ?? _fallback.printerScanning;
  @override
  String get printerSelected => _string('printerSelected') ?? _fallback.printerSelected;
  @override
  String printerSelectedSnack(String connection, String name) {
    final raw = _string('printerSelectedSnack');
    if (raw != null) {
      return _fill(raw, {'connection': connection, 'name': name});
    }
    return _fallback.printerSelectedSnack(connection, name);
  }
  @override
  String get printerSetupTitle => _string('printerSetupTitle') ?? _fallback.printerSetupTitle;
  @override
  String get printerTabBluetooth => _string('printerTabBluetooth') ?? _fallback.printerTabBluetooth;
  @override
  String get printerTabLan => _string('printerTabLan') ?? _fallback.printerTabLan;
  @override
  String get printerTabUsb => _string('printerTabUsb') ?? _fallback.printerTabUsb;
  @override
  String get printerUnsupportedWeb => _string('printerUnsupportedWeb') ?? _fallback.printerUnsupportedWeb;
  @override
  String get printerUsbHint => _string('printerUsbHint') ?? _fallback.printerUsbHint;
  @override
  String get printerUsbTitle => _string('printerUsbTitle') ?? _fallback.printerUsbTitle;
  @override
  String get qrAskCustomer => _string('qrAskCustomer') ?? _fallback.qrAskCustomer;
  @override
  String get qrCancelConfirm => _string('qrCancelConfirm') ?? _fallback.qrCancelConfirm;
  @override
  String qrCancelMessage(String gateway) {
    final raw = _string('qrCancelMessage');
    if (raw != null) {
      return _fill(raw, {'gateway': gateway});
    }
    return _fallback.qrCancelMessage(gateway);
  }
  @override
  String get qrCancelTitle => _string('qrCancelTitle') ?? _fallback.qrCancelTitle;
  @override
  String get qrGenerateFailed => _string('qrGenerateFailed') ?? _fallback.qrGenerateFailed;
  @override
  String get qrGenerating => _string('qrGenerating') ?? _fallback.qrGenerating;
  @override
  String get qrHurry => _string('qrHurry') ?? _fallback.qrHurry;
  @override
  String get qrKeepWaiting => _string('qrKeepWaiting') ?? _fallback.qrKeepWaiting;
  @override
  String qrOrderLabel(String label) {
    final raw = _string('qrOrderLabel');
    if (raw != null) {
      return _fill(raw, {'label': label});
    }
    return _fallback.qrOrderLabel(label);
  }
  @override
  String get qrPrintSlip => _string('qrPrintSlip') ?? _fallback.qrPrintSlip;
  @override
  String get qrPrinting => _string('qrPrinting') ?? _fallback.qrPrinting;
  @override
  String get qrScanToPay => _string('qrScanToPay') ?? _fallback.qrScanToPay;
  @override
  String get qrSlipPrintFailed => _string('qrSlipPrintFailed') ?? _fallback.qrSlipPrintFailed;
  @override
  String get qrSlipPrinted => _string('qrSlipPrinted') ?? _fallback.qrSlipPrinted;
  @override
  String get qrTimeLeft => _string('qrTimeLeft') ?? _fallback.qrTimeLeft;
  @override
  String get qrTimedOut => _string('qrTimedOut') ?? _fallback.qrTimedOut;
  @override
  String get qrUnavailable => _string('qrUnavailable') ?? _fallback.qrUnavailable;
  @override
  String get qrWaiting => _string('qrWaiting') ?? _fallback.qrWaiting;
  @override
  String get reportsCategoryWise => _string('reportsCategoryWise') ?? _fallback.reportsCategoryWise;
  @override
  String get reportsCategoryWiseDesc => _string('reportsCategoryWiseDesc') ?? _fallback.reportsCategoryWiseDesc;
  @override
  String get reportsItemWise => _string('reportsItemWise') ?? _fallback.reportsItemWise;
  @override
  String get reportsItemWiseDesc => _string('reportsItemWiseDesc') ?? _fallback.reportsItemWiseDesc;
  @override
  String get reportsOrderType => _string('reportsOrderType') ?? _fallback.reportsOrderType;
  @override
  String get reportsOrderTypeDesc => _string('reportsOrderTypeDesc') ?? _fallback.reportsOrderTypeDesc;
  @override
  String reportsPrintFailed(String error) {
    final raw = _string('reportsPrintFailed');
    if (raw != null) {
      return _fill(raw, {'error': error});
    }
    return _fallback.reportsPrintFailed(error);
  }
  @override
  String get reportsSalesChannel => _string('reportsSalesChannel') ?? _fallback.reportsSalesChannel;
  @override
  String get reportsSalesChannelDesc => _string('reportsSalesChannelDesc') ?? _fallback.reportsSalesChannelDesc;
  @override
  String get reportsSalesSummary => _string('reportsSalesSummary') ?? _fallback.reportsSalesSummary;
  @override
  String get reportsSalesSummaryDesc => _string('reportsSalesSummaryDesc') ?? _fallback.reportsSalesSummaryDesc;
  @override
  String get reportsSentToPrinter => _string('reportsSentToPrinter') ?? _fallback.reportsSentToPrinter;
  @override
  String get reportsSubtitle => _string('reportsSubtitle') ?? _fallback.reportsSubtitle;
  @override
  String get reportsTaxSummary => _string('reportsTaxSummary') ?? _fallback.reportsTaxSummary;
  @override
  String get reportsTaxSummaryDesc => _string('reportsTaxSummaryDesc') ?? _fallback.reportsTaxSummaryDesc;
  @override
  String get reportsTerminalConsolidated => _string('reportsTerminalConsolidated') ?? _fallback.reportsTerminalConsolidated;
  @override
  String get reportsTerminalConsolidatedDesc => _string('reportsTerminalConsolidatedDesc') ?? _fallback.reportsTerminalConsolidatedDesc;
  @override
  String get reportsTitle => _string('reportsTitle') ?? _fallback.reportsTitle;
  @override
  String setupEnterUrl(String app) {
    final raw = _string('setupEnterUrl');
    if (raw != null) {
      return _fill(raw, {'app': app});
    }
    return _fallback.setupEnterUrl(app);
  }
  @override
  String get setupStep1 => _string('setupStep1') ?? _fallback.setupStep1;
  @override
  String get shellChangeRegister => _string('shellChangeRegister') ?? _fallback.shellChangeRegister;
  @override
  String get shellChangeLocation =>
      _string('shellChangeLocation') ?? _fallback.shellChangeLocation;
  @override
  String get shellClearPairing => _string('shellClearPairing') ?? _fallback.shellClearPairing;
  @override
  String get shellLockShort => _string('shellLockShort') ?? _fallback.shellLockShort;
  @override
  String get shellMenuDevice => _string('shellMenuDevice') ?? _fallback.shellMenuDevice;
  @override
  String get shellMenuRefreshed => _string('shellMenuRefreshed') ?? _fallback.shellMenuRefreshed;
  @override
  String get shellMenuSession => _string('shellMenuSession') ?? _fallback.shellMenuSession;
  @override
  String get shellMore => _string('shellMore') ?? _fallback.shellMore;
  @override
  String get shellMoreCustomize =>
      _string('shellMoreCustomize') ?? _fallback.shellMoreCustomize;
  @override
  String get shellMoreCustomizeHint =>
      _string('shellMoreCustomizeHint') ?? _fallback.shellMoreCustomizeHint;
  @override
  String get shellPairingCleared => _string('shellPairingCleared') ?? _fallback.shellPairingCleared;
  @override
  String get shellRefreshMenu => _string('shellRefreshMenu') ?? _fallback.shellRefreshMenu;
  @override
  String get shellSyncCompleted => _string('shellSyncCompleted') ?? _fallback.shellSyncCompleted;
  @override
  String get shellSyncOrders => _string('shellSyncOrders') ?? _fallback.shellSyncOrders;
  @override
  String get shellViewCart => _string('shellViewCart') ?? _fallback.shellViewCart;
  @override
  String get shiftBalanced => _string('shiftBalanced') ?? _fallback.shiftBalanced;
  @override
  String get shiftByMethodSection => _string('shiftByMethodSection') ?? _fallback.shiftByMethodSection;
  @override
  String get shiftCashCounted => _string('shiftCashCounted') ?? _fallback.shiftCashCounted;
  @override
  String get shiftCashDrawerSection => _string('shiftCashDrawerSection') ?? _fallback.shiftCashDrawerSection;
  @override
  String get shiftCashSales => _string('shiftCashSales') ?? _fallback.shiftCashSales;
  @override
  String get shiftChangeGiven => _string('shiftChangeGiven') ?? _fallback.shiftChangeGiven;
  @override
  String get shiftCloseNotesHint => _string('shiftCloseNotesHint') ?? _fallback.shiftCloseNotesHint;
  @override
  String get shiftCloseSubtitle => _string('shiftCloseSubtitle') ?? _fallback.shiftCloseSubtitle;
  @override
  String get shiftClosedSnack => _string('shiftClosedSnack') ?? _fallback.shiftClosedSnack;
  @override
  String get shiftClosing => _string('shiftClosing') ?? _fallback.shiftClosing;
  @override
  String get shiftCounted => _string('shiftCounted') ?? _fallback.shiftCounted;
  @override
  String get shiftExpectedDrawer => _string('shiftExpectedDrawer') ?? _fallback.shiftExpectedDrawer;
  @override
  String get shiftNoPaidSales => _string('shiftNoPaidSales') ?? _fallback.shiftNoPaidSales;
  @override
  String get shiftNotes => _string('shiftNotes') ?? _fallback.shiftNotes;
  @override
  String get shiftOpenNotesHint => _string('shiftOpenNotesHint') ?? _fallback.shiftOpenNotesHint;
  @override
  String get shiftOpenRequiredTitle => _string('shiftOpenRequiredTitle') ?? _fallback.shiftOpenRequiredTitle;
  @override
  String get shiftOpenSubtitle => _string('shiftOpenSubtitle') ?? _fallback.shiftOpenSubtitle;
  @override
  String get shiftOpenedSnack => _string('shiftOpenedSnack') ?? _fallback.shiftOpenedSnack;
  @override
  String get shiftOpening => _string('shiftOpening') ?? _fallback.shiftOpening;
  @override
  String get shiftOpeningFloat => _string('shiftOpeningFloat') ?? _fallback.shiftOpeningFloat;
  @override
  String shiftOpeningFloatFor(String branch) {
    final raw = _string('shiftOpeningFloatFor');
    if (raw != null) {
      return _fill(raw, {'branch': branch});
    }
    return _fallback.shiftOpeningFloatFor(branch);
  }
  @override
  String get shiftOpeningFloatHelp => _string('shiftOpeningFloatHelp') ?? _fallback.shiftOpeningFloatHelp;
  @override
  String get shiftOver => _string('shiftOver') ?? _fallback.shiftOver;
  @override
  String get shiftPaidOrderOne => _string('shiftPaidOrderOne') ?? _fallback.shiftPaidOrderOne;
  @override
  String shiftPaidOrders(int count) {
    final raw = _string('shiftPaidOrders');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.shiftPaidOrders(count);
  }
  @override
  String get shiftRequiredSubtitle => _string('shiftRequiredSubtitle') ?? _fallback.shiftRequiredSubtitle;
  @override
  String get shiftSalesSection => _string('shiftSalesSection') ?? _fallback.shiftSalesSection;
  @override
  String get shiftShort => _string('shiftShort') ?? _fallback.shiftShort;
  @override
  String get shiftSummaryLoadFailed => _string('shiftSummaryLoadFailed') ?? _fallback.shiftSummaryLoadFailed;
  @override
  String get shiftSummaryLoading => _string('shiftSummaryLoading') ?? _fallback.shiftSummaryLoading;
  @override
  String get shiftThisBranch => _string('shiftThisBranch') ?? _fallback.shiftThisBranch;
  @override
  String shiftTipsOnOrders(String amount) {
    final raw = _string('shiftTipsOnOrders');
    if (raw != null) {
      return _fill(raw, {'amount': amount});
    }
    return _fallback.shiftTipsOnOrders(amount);
  }
  @override
  String get shiftVariance => _string('shiftVariance') ?? _fallback.shiftVariance;
  @override
  String get shortcutsAll => _string('shortcutsAll') ?? _fallback.shortcutsAll;
  @override
  String get shortcutsBarcodeNote => _string('shortcutsBarcodeNote') ?? _fallback.shortcutsBarcodeNote;
  @override
  String get shortcutsClearCart => _string('shortcutsClearCart') ?? _fallback.shortcutsClearCart;
  @override
  String get shortcutsClearCartDesc => _string('shortcutsClearCartDesc') ?? _fallback.shortcutsClearCartDesc;
  @override
  String get shortcutsClearCartKeys => _string('shortcutsClearCartKeys') ?? _fallback.shortcutsClearCartKeys;
  @override
  String get shortcutsFocusSearch => _string('shortcutsFocusSearch') ?? _fallback.shortcutsFocusSearch;
  @override
  String get shortcutsFocusSearchDesc => _string('shortcutsFocusSearchDesc') ?? _fallback.shortcutsFocusSearchDesc;
  @override
  String get shortcutsGotIt => _string('shortcutsGotIt') ?? _fallback.shortcutsGotIt;
  @override
  String get shortcutsHeldOrders => _string('shortcutsHeldOrders') ?? _fallback.shortcutsHeldOrders;
  @override
  String get shortcutsHeldOrdersDesc => _string('shortcutsHeldOrdersDesc') ?? _fallback.shortcutsHeldOrdersDesc;
  @override
  String get shortcutsHoldTicket => _string('shortcutsHoldTicket') ?? _fallback.shortcutsHoldTicket;
  @override
  String get shortcutsHoldTicketDesc => _string('shortcutsHoldTicketDesc') ?? _fallback.shortcutsHoldTicketDesc;
  @override
  String get shortcutsLockRegister => _string('shortcutsLockRegister') ?? _fallback.shortcutsLockRegister;
  @override
  String get shortcutsLockRegisterDesc => _string('shortcutsLockRegisterDesc') ?? _fallback.shortcutsLockRegisterDesc;
  @override
  String get shortcutsLockAlt => _string('shortcutsLockAlt') ?? _fallback.shortcutsLockAlt;
  @override
  String get shortcutsLockAltDesc => _string('shortcutsLockAltDesc') ?? _fallback.shortcutsLockAltDesc;
  @override
  String get shortcutsPay => _string('shortcutsPay') ?? _fallback.shortcutsPay;
  @override
  String get shortcutsPayAlt => _string('shortcutsPayAlt') ?? _fallback.shortcutsPayAlt;
  @override
  String get shortcutsPayAltDesc => _string('shortcutsPayAltDesc') ?? _fallback.shortcutsPayAltDesc;
  @override
  String get shortcutsPayDesc => _string('shortcutsPayDesc') ?? _fallback.shortcutsPayDesc;
  @override
  String get shortcutsSubtitle => _string('shortcutsSubtitle') ?? _fallback.shortcutsSubtitle;
  @override
  String get shortcutsTitle => _string('shortcutsTitle') ?? _fallback.shortcutsTitle;
  @override
  String terminalCode(String code) {
    final raw = _string('terminalCode');
    if (raw != null) {
      return _fill(raw, {'code': code});
    }
    return _fallback.terminalCode(code);
  }
  @override
  String get terminalContinueWithout => _string('terminalContinueWithout') ?? _fallback.terminalContinueWithout;
  @override
  String get terminalEmptySubtitle => _string('terminalEmptySubtitle') ?? _fallback.terminalEmptySubtitle;
  @override
  String get terminalEmptyTitle => _string('terminalEmptyTitle') ?? _fallback.terminalEmptyTitle;
  @override
  String get terminalFooterNote => _string('terminalFooterNote') ?? _fallback.terminalFooterNote;
  @override
  String get terminalSelectSubtitle => _string('terminalSelectSubtitle') ?? _fallback.terminalSelectSubtitle;
  @override
  String terminalSelectSubtitleNamed(String branch) {
    final raw = _string('terminalSelectSubtitleNamed');
    if (raw != null) {
      return _fill(raw, {'branch': branch});
    }
    return _fallback.terminalSelectSubtitleNamed(branch);
  }
  @override
  String get terminalSelectTitle => _string('terminalSelectTitle') ?? _fallback.terminalSelectTitle;
  @override
  String timeDaysAgo(int count) {
    final raw = _string('timeDaysAgo');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.timeDaysAgo(count);
  }
  @override
  String timeHoursAgo(int count) {
    final raw = _string('timeHoursAgo');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.timeHoursAgo(count);
  }
  @override
  String get timeJustNow => _string('timeJustNow') ?? _fallback.timeJustNow;
  @override
  String timeMinutesAgo(int count) {
    final raw = _string('timeMinutesAgo');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.timeMinutesAgo(count);
  }
  @override
  String get updateAction => _string('updateAction') ?? _fallback.updateAction;
  @override
  String updateAvailableBody(String version) {
    final raw = _string('updateAvailableBody');
    if (raw != null) {
      return _fill(raw, {'version': version});
    }
    return _fallback.updateAvailableBody(version);
  }
  @override
  String updateAvailableSnack(String version) {
    final raw = _string('updateAvailableSnack');
    if (raw != null) {
      return _fill(raw, {'version': version});
    }
    return _fallback.updateAvailableSnack(version);
  }
  @override
  String updateAvailableTitle(String version) {
    final raw = _string('updateAvailableTitle');
    if (raw != null) {
      return _fill(raw, {'version': version});
    }
    return _fallback.updateAvailableTitle(version);
  }
  @override
  String get updateCancelled => _string('updateCancelled') ?? _fallback.updateCancelled;
  @override
  String get updateCheckFailed => _string('updateCheckFailed') ?? _fallback.updateCheckFailed;
  @override
  String get updateChecking => _string('updateChecking') ?? _fallback.updateChecking;
  @override
  String get updateDoneAndroid => _string('updateDoneAndroid') ?? _fallback.updateDoneAndroid;
  @override
  String get updateDoneGeneric => _string('updateDoneGeneric') ?? _fallback.updateDoneGeneric;
  @override
  String get updateDoneMac => _string('updateDoneMac') ?? _fallback.updateDoneMac;
  @override
  String get updateDoneWin => _string('updateDoneWin') ?? _fallback.updateDoneWin;
  @override
  String get updateDownload => _string('updateDownload') ?? _fallback.updateDownload;
  @override
  String get updateDownloadCancelled => _string('updateDownloadCancelled') ?? _fallback.updateDownloadCancelled;
  @override
  String updateDownloadFailed(String code) {
    final raw = _string('updateDownloadFailed');
    if (raw != null) {
      return _fill(raw, {'code': code});
    }
    return _fallback.updateDownloadFailed(code);
  }
  @override
  String get updateDownloading => _string('updateDownloading') ?? _fallback.updateDownloading;
  @override
  String updateDownloadingPct(int pct) {
    final raw = _string('updateDownloadingPct');
    if (raw != null) {
      return _fill(raw, {'pct': pct});
    }
    return _fallback.updateDownloadingPct(pct);
  }
  @override
  String get updateFailed => _string('updateFailed') ?? _fallback.updateFailed;
  @override
  String get updateInAppUnavailable => _string('updateInAppUnavailable') ?? _fallback.updateInAppUnavailable;
  @override
  String get updateInstallerOpened => _string('updateInstallerOpened') ?? _fallback.updateInstallerOpened;
  @override
  String get updateInstalling => _string('updateInstalling') ?? _fallback.updateInstalling;
  @override
  String get updateLater => _string('updateLater') ?? _fallback.updateLater;
  @override
  String get updateNoLink => _string('updateNoLink') ?? _fallback.updateNoLink;
  @override
  String get updateNoLinkDevice => _string('updateNoLinkDevice') ?? _fallback.updateNoLinkDevice;
  @override
  String get updateOpenBrowser => _string('updateOpenBrowser') ?? _fallback.updateOpenBrowser;
  @override
  String get updateOpeningAndroid => _string('updateOpeningAndroid') ?? _fallback.updateOpeningAndroid;
  @override
  String get updateOpeningGeneric => _string('updateOpeningGeneric') ?? _fallback.updateOpeningGeneric;
  @override
  String get updateOpeningMac => _string('updateOpeningMac') ?? _fallback.updateOpeningMac;
  @override
  String get updateOpeningWin => _string('updateOpeningWin') ?? _fallback.updateOpeningWin;
  @override
  String get updatePreparing => _string('updatePreparing') ?? _fallback.updatePreparing;
  @override
  String updateRequiredBody(String current, String latest) {
    final raw = _string('updateRequiredBody');
    if (raw != null) {
      return _fill(raw, {'current': current, 'latest': latest});
    }
    return _fallback.updateRequiredBody(current, latest);
  }
  @override
  String get updateRequiredSnack => _string('updateRequiredSnack') ?? _fallback.updateRequiredSnack;
  @override
  String get updateRequiredTitle => _string('updateRequiredTitle') ?? _fallback.updateRequiredTitle;
  @override
  String updateUpToDate(String version) {
    final raw = _string('updateUpToDate');
    if (raw != null) {
      return _fill(raw, {'version': version});
    }
    return _fallback.updateUpToDate(version);
  }
  @override
  String updateVersion(String version) {
    final raw = _string('updateVersion');
    if (raw != null) {
      return _fill(raw, {'version': version});
    }
    return _fallback.updateVersion(version);
  }
  @override
  String get updateWorking => _string('updateWorking') ?? _fallback.updateWorking;
  @override
  String get upsellAdd => _string('upsellAdd') ?? _fallback.upsellAdd;
  @override
  String get upsellSubtitle => _string('upsellSubtitle') ?? _fallback.upsellSubtitle;
  @override
  String get upsellTitle => _string('upsellTitle') ?? _fallback.upsellTitle;
  @override
  String shiftUnpaidSuffix(String amount, int count) {
    final raw = _string('shiftUnpaidSuffix');
    if (raw != null) {
      return _fill(raw, {'amount': amount, 'count': count});
    }
    return _fallback.shiftUnpaidSuffix(amount, count);
  }
  @override
  String payAmountWithTip(String tip, String total) {
    final raw = _string('payAmountWithTip');
    if (raw != null) {
      return _fill(raw, {'tip': tip, 'total': total});
    }
    return _fallback.payAmountWithTip(tip, total);
  }
  @override
  String get payStatusPartial => _string('payStatusPartial') ?? _fallback.payStatusPartial;
  @override
  String get payStatusRefunded => _string('payStatusRefunded') ?? _fallback.payStatusRefunded;
  @override
  String get payStatusPending => _string('payStatusPending') ?? _fallback.payStatusPending;
  @override
  String authStaffOrderingFooter(String app) {
    final raw = _string('authStaffOrderingFooter');
    if (raw != null) {
      return _fill(raw, {'app': app});
    }
    return _fallback.authStaffOrderingFooter(app);
  }
  @override
  String get modePickerTitle => _string('modePickerTitle') ?? _fallback.modePickerTitle;
  @override
  String get modePickerSubtitle => _string('modePickerSubtitle') ?? _fallback.modePickerSubtitle;
  @override
  String get modePickerRegisterTitle => _string('modePickerRegisterTitle') ?? _fallback.modePickerRegisterTitle;
  @override
  String get modePickerRegisterSubtitle => _string('modePickerRegisterSubtitle') ?? _fallback.modePickerRegisterSubtitle;
  @override
  String get modePickerWaiterTitle => _string('modePickerWaiterTitle') ?? _fallback.modePickerWaiterTitle;
  @override
  String get modePickerWaiterSubtitle => _string('modePickerWaiterSubtitle') ?? _fallback.modePickerWaiterSubtitle;
  @override
  String get modePickerFooter => _string('modePickerFooter') ?? _fallback.modePickerFooter;
  @override
  String get waiterNavTables => _string('waiterNavTables') ?? _fallback.waiterNavTables;
  @override
  String get waiterNavOrders => _string('waiterNavOrders') ?? _fallback.waiterNavOrders;
  @override
  String get waiterNavAlerts => _string('waiterNavAlerts') ?? _fallback.waiterNavAlerts;
  @override
  String get waiterNavProfile => _string('waiterNavProfile') ?? _fallback.waiterNavProfile;
  @override
  String get waiterConnectionLive => _string('waiterConnectionLive') ?? _fallback.waiterConnectionLive;
  @override
  String get waiterConnectionOffline => _string('waiterConnectionOffline') ?? _fallback.waiterConnectionOffline;
  @override
  String get waiterZoneAll => _string('waiterZoneAll') ?? _fallback.waiterZoneAll;
  @override
  String get waiterZoneOther => _string('waiterZoneOther') ?? _fallback.waiterZoneOther;
  @override
  String get waiterStatusAvailable => _string('waiterStatusAvailable') ?? _fallback.waiterStatusAvailable;
  @override
  String get waiterStatusOccupied => _string('waiterStatusOccupied') ?? _fallback.waiterStatusOccupied;
  @override
  String get waiterStatusBilling => _string('waiterStatusBilling') ?? _fallback.waiterStatusBilling;
  @override
  String get waiterStatusReserved => _string('waiterStatusReserved') ?? _fallback.waiterStatusReserved;
  @override
  String get waiterStatusCleaning => _string('waiterStatusCleaning') ?? _fallback.waiterStatusCleaning;
  @override
  String get waiterTableCleaningHint => _string('waiterTableCleaningHint') ?? _fallback.waiterTableCleaningHint;
  @override
  String waiterOpenTableTitle(String table) {
    final raw = _string('waiterOpenTableTitle');
    if (raw != null) {
      return _fill(raw, {'table': table});
    }
    return _fallback.waiterOpenTableTitle(table);
  }
  @override
  String get waiterOpenTableSubtitle => _string('waiterOpenTableSubtitle') ?? _fallback.waiterOpenTableSubtitle;
  @override
  String get waiterGuestsLabel => _string('waiterGuestsLabel') ?? _fallback.waiterGuestsLabel;
  @override
  String get waiterOpenTableConfirm => _string('waiterOpenTableConfirm') ?? _fallback.waiterOpenTableConfirm;
  @override
  String waiterTableSeatsCount(int count) {
    final raw = _string('waiterTableSeatsCount');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.waiterTableSeatsCount(count);
  }
  @override
  String waiterGuestsCount(int count) {
    final raw = _string('waiterGuestsCount');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.waiterGuestsCount(count);
  }
  @override
  String get waiterOrderTitle => _string('waiterOrderTitle') ?? _fallback.waiterOrderTitle;
  @override
  String get waiterCategoryAll => _string('waiterCategoryAll') ?? _fallback.waiterCategoryAll;
  @override
  String get waiterSendToKitchen => _string('waiterSendToKitchen') ?? _fallback.waiterSendToKitchen;
  @override
  String waiterAlreadySent(int count) {
    final raw = _string('waiterAlreadySent');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.waiterAlreadySent(count);
  }
  @override
  String get waiterNewItemsHint => _string('waiterNewItemsHint') ?? _fallback.waiterNewItemsHint;
  @override
  String get waiterChannelInHouse => _string('waiterChannelInHouse') ?? _fallback.waiterChannelInHouse;
  @override
  String waiterCaptainNamed(String name) {
    final raw = _string('waiterCaptainNamed');
    if (raw != null) {
      return _fill(raw, {'name': name});
    }
    return _fallback.waiterCaptainNamed(name);
  }
  @override
  String get waiterBillRequestedBadge => _string('waiterBillRequestedBadge') ?? _fallback.waiterBillRequestedBadge;
  @override
  String waiterKotRound(int round) {
    final raw = _string('waiterKotRound');
    if (raw != null) {
      return _fill(raw, {'round': round});
    }
    return _fallback.waiterKotRound(round);
  }
  @override
  String get ordersFilterFloor => _string('ordersFilterFloor') ?? _fallback.ordersFilterFloor;
  @override
  String get ordersFilterPartners => _string('ordersFilterPartners') ?? _fallback.ordersFilterPartners;
  @override
  String get ordersFilterZomato => _string('ordersFilterZomato') ?? _fallback.ordersFilterZomato;
  @override
  String get ordersFilterSwiggy => _string('ordersFilterSwiggy') ?? _fallback.ordersFilterSwiggy;
  @override
  String get ordersEmptyZomato => _string('ordersEmptyZomato') ?? _fallback.ordersEmptyZomato;
  @override
  String get ordersEmptySwiggy => _string('ordersEmptySwiggy') ?? _fallback.ordersEmptySwiggy;
  @override
  String get ordersSourceZomato => _string('ordersSourceZomato') ?? _fallback.ordersSourceZomato;
  @override
  String get ordersSourceSwiggy => _string('ordersSourceSwiggy') ?? _fallback.ordersSourceSwiggy;
  @override
  String waiterCartBanner(int count, String subtotal) {
    final raw = _string('waiterCartBanner');
    if (raw != null) {
      return _fill(raw, {'count': count, 'subtotal': subtotal});
    }
    return _fallback.waiterCartBanner(count, subtotal);
  }
  @override
  String get waiterKotSentTitle => _string('waiterKotSentTitle') ?? _fallback.waiterKotSentTitle;
  @override
  String get waiterKotSentSubtitle => _string('waiterKotSentSubtitle') ?? _fallback.waiterKotSentSubtitle;
  @override
  String waiterKotSent(String number) {
    final raw = _string('waiterKotSent');
    if (raw != null) {
      return _fill(raw, {'number': number});
    }
    return _fallback.waiterKotSent(number);
  }
  @override
  String get waiterOrdersEmptyTitle => _string('waiterOrdersEmptyTitle') ?? _fallback.waiterOrdersEmptyTitle;
  @override
  String get waiterOrdersEmptySubtitle => _string('waiterOrdersEmptySubtitle') ?? _fallback.waiterOrdersEmptySubtitle;
  @override
  String get waiterOrdersSubtitle => _string('waiterOrdersSubtitle') ?? _fallback.waiterOrdersSubtitle;
  @override
  String waiterOrdersSummary(int count) {
    final raw = _string('waiterOrdersSummary');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.waiterOrdersSummary(count);
  }
  @override
  String get waiterOrdersFilterAll => _string('waiterOrdersFilterAll') ?? _fallback.waiterOrdersFilterAll;
  @override
  String get waiterOrdersFilterPreparing => _string('waiterOrdersFilterPreparing') ?? _fallback.waiterOrdersFilterPreparing;
  @override
  String get waiterOrdersFilterReady => _string('waiterOrdersFilterReady') ?? _fallback.waiterOrdersFilterReady;
  @override
  String get waiterOrdersFilterBilling => _string('waiterOrdersFilterBilling') ?? _fallback.waiterOrdersFilterBilling;
  @override
  String get waiterOrdersFilterMine => _string('waiterOrdersFilterMine') ?? _fallback.waiterOrdersFilterMine;
  @override
  String get waiterOrdersSearchHint => _string('waiterOrdersSearchHint') ?? _fallback.waiterOrdersSearchHint;
  @override
  String get waiterOrdersNoFilterMatchesTitle => _string('waiterOrdersNoFilterMatchesTitle') ?? _fallback.waiterOrdersNoFilterMatchesTitle;
  @override
  String get waiterOrdersNoFilterMatchesSubtitle => _string('waiterOrdersNoFilterMatchesSubtitle') ?? _fallback.waiterOrdersNoFilterMatchesSubtitle;
  @override
  String waiterOrdersSummaryReady(int count) {
    final raw = _string('waiterOrdersSummaryReady');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.waiterOrdersSummaryReady(count);
  }
  @override
  String waiterOrdersSummaryBilling(int count) {
    final raw = _string('waiterOrdersSummaryBilling');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.waiterOrdersSummaryBilling(count);
  }
  @override
  String waiterOrdersSummaryMine(int count) {
    final raw = _string('waiterOrdersSummaryMine');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.waiterOrdersSummaryMine(count);
  }
  @override
  String waiterOrdersMoreItems(int count) {
    final raw = _string('waiterOrdersMoreItems');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.waiterOrdersMoreItems(count);
  }
  @override
  String get waiterOrdersTapToExpand => _string('waiterOrdersTapToExpand') ?? _fallback.waiterOrdersTapToExpand;
  @override
  String get waiterOrdersTapToCollapse => _string('waiterOrdersTapToCollapse') ?? _fallback.waiterOrdersTapToCollapse;
  @override
  String waiterOrdersReadyCount(int count) {
    final raw = _string('waiterOrdersReadyCount');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.waiterOrdersReadyCount(count);
  }
  @override
  String waiterOrdersPrepCount(int count) {
    final raw = _string('waiterOrdersPrepCount');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.waiterOrdersPrepCount(count);
  }
  @override
  String waiterOrdersSentCount(int count) {
    final raw = _string('waiterOrdersSentCount');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.waiterOrdersSentCount(count);
  }
  @override
  String get waiterOrdersShowItems => _string('waiterOrdersShowItems') ?? _fallback.waiterOrdersShowItems;
  @override
  String get waiterOrdersHideItems => _string('waiterOrdersHideItems') ?? _fallback.waiterOrdersHideItems;
  @override
  String waiterOrdersToken(String token) {
    final raw = _string('waiterOrdersToken');
    if (raw != null) {
      return _fill(raw, {'token': token});
    }
    return _fallback.waiterOrdersToken(token);
  }
  @override
  String waiterItemsCount(int count) {
    final raw = _string('waiterItemsCount');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.waiterItemsCount(count);
  }
  @override
  String get waiterPipelineSent => _string('waiterPipelineSent') ?? _fallback.waiterPipelineSent;
  @override
  String get waiterPipelinePreparing => _string('waiterPipelinePreparing') ?? _fallback.waiterPipelinePreparing;
  @override
  String get waiterPipelineReady => _string('waiterPipelineReady') ?? _fallback.waiterPipelineReady;
  @override
  String get waiterPipelineServed => _string('waiterPipelineServed') ?? _fallback.waiterPipelineServed;
  @override
  String get waiterMarkServed => _string('waiterMarkServed') ?? _fallback.waiterMarkServed;
  @override
  String get waiterMarkServedAll => _string('waiterMarkServedAll') ?? _fallback.waiterMarkServedAll;
  @override
  String get waiterMarkServedDone => _string('waiterMarkServedDone') ?? _fallback.waiterMarkServedDone;
  @override
  String waiterMarkServedDoneCount(int count) {
    final raw = _string('waiterMarkServedDoneCount');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.waiterMarkServedDoneCount(count);
  }
  @override
  String get waiterMarkServedNeedsOnline => _string('waiterMarkServedNeedsOnline') ?? _fallback.waiterMarkServedNeedsOnline;
  @override
  String get waiterRunFoodTitle => _string('waiterRunFoodTitle') ?? _fallback.waiterRunFoodTitle;
  @override
  String waiterRunFoodSubtitle(int count) {
    final raw = _string('waiterRunFoodSubtitle');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.waiterRunFoodSubtitle(count);
  }
  @override
  String get waiterRunFoodAction => _string('waiterRunFoodAction') ?? _fallback.waiterRunFoodAction;
  @override
  String get waiterKitchenWorkingTitle => _string('waiterKitchenWorkingTitle') ?? _fallback.waiterKitchenWorkingTitle;
  @override
  String waiterKitchenWorkingSubtitle(int prep, int sent) {
    final raw = _string('waiterKitchenWorkingSubtitle');
    if (raw != null) {
      return _fill(raw, {'prep': prep, 'sent': sent});
    }
    return _fallback.waiterKitchenWorkingSubtitle(prep, sent);
  }
  @override
  String get waiterAllServedTitle => _string('waiterAllServedTitle') ?? _fallback.waiterAllServedTitle;
  @override
  String get waiterAllServedSubtitle => _string('waiterAllServedSubtitle') ?? _fallback.waiterAllServedSubtitle;
  @override
  String get waiterCardNeedsYou => _string('waiterCardNeedsYou') ?? _fallback.waiterCardNeedsYou;
  @override
  String get waiterCardWaitingKitchen => _string('waiterCardWaitingKitchen') ?? _fallback.waiterCardWaitingKitchen;
  @override
  String get waiterCardBillPending => _string('waiterCardBillPending') ?? _fallback.waiterCardBillPending;
  @override
  String get waiterCardDelivered => _string('waiterCardDelivered') ?? _fallback.waiterCardDelivered;
  @override
  String get waiterCardItemsHeading => _string('waiterCardItemsHeading') ?? _fallback.waiterCardItemsHeading;
  @override
  String get waiterCardShowTicket => _string('waiterCardShowTicket') ?? _fallback.waiterCardShowTicket;
  @override
  String get waiterCardHideTicket => _string('waiterCardHideTicket') ?? _fallback.waiterCardHideTicket;
  @override
  String waiterCardMoreReady(int count) {
    final raw = _string('waiterCardMoreReady');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.waiterCardMoreReady(count);
  }
  @override
  String waiterCardAge(String age) {
    final raw = _string('waiterCardAge');
    if (raw != null) {
      return _fill(raw, {'age': age});
    }
    return _fallback.waiterCardAge(age);
  }
  @override
  String get waiterAddMore => _string('waiterAddMore') ?? _fallback.waiterAddMore;
  @override
  String get waiterRequestBill => _string('waiterRequestBill') ?? _fallback.waiterRequestBill;
  @override
  String waiterBillTitle(String table) {
    final raw = _string('waiterBillTitle');
    if (raw != null) {
      return _fill(raw, {'table': table});
    }
    return _fallback.waiterBillTitle(table);
  }
  @override
  String get waiterBillNoTicket => _string('waiterBillNoTicket') ?? _fallback.waiterBillNoTicket;
  @override
  String get waiterBillEmptyHint => _string('waiterBillEmptyHint') ?? _fallback.waiterBillEmptyHint;
  @override
  String get waiterBillDiscount => _string('waiterBillDiscount') ?? _fallback.waiterBillDiscount;
  @override
  String get waiterBillTax => _string('waiterBillTax') ?? _fallback.waiterBillTax;
  @override
  String get waiterBillRequestedToast => _string('waiterBillRequestedToast') ?? _fallback.waiterBillRequestedToast;
  @override
  String get waiterBillAlreadyRequestedHint => _string('waiterBillAlreadyRequestedHint') ?? _fallback.waiterBillAlreadyRequestedHint;
  @override
  String get waiterBillRequestedAlert => _string('waiterBillRequestedAlert') ?? _fallback.waiterBillRequestedAlert;
  @override
  String waiterOrderReadyAlert(String number, String table) {
    final raw = _string('waiterOrderReadyAlert');
    if (raw != null) {
      return _fill(raw, {'number': number, 'table': table});
    }
    return _fallback.waiterOrderReadyAlert(number, table);
  }
  @override
  String get waiterAlertsEmptyTitle => _string('waiterAlertsEmptyTitle') ?? _fallback.waiterAlertsEmptyTitle;
  @override
  String get waiterAlertsEmptySubtitle => _string('waiterAlertsEmptySubtitle') ?? _fallback.waiterAlertsEmptySubtitle;
  @override
  String get waiterNotificationsMarkAllRead => _string('waiterNotificationsMarkAllRead') ?? _fallback.waiterNotificationsMarkAllRead;
  @override
  String get waiterNotificationsAllCaughtUp => _string('waiterNotificationsAllCaughtUp') ?? _fallback.waiterNotificationsAllCaughtUp;
  @override
  String waiterNotificationsUnread(int count) {
    final raw = _string('waiterNotificationsUnread');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.waiterNotificationsUnread(count);
  }
  @override
  String get waiterNotificationsToday => _string('waiterNotificationsToday') ?? _fallback.waiterNotificationsToday;
  @override
  String get waiterNotificationsEarlier => _string('waiterNotificationsEarlier') ?? _fallback.waiterNotificationsEarlier;
  @override
  String get waiterNotificationReadyTitle => _string('waiterNotificationReadyTitle') ?? _fallback.waiterNotificationReadyTitle;
  @override
  String waiterNotificationReadyBody(String number, String table) {
    final raw = _string('waiterNotificationReadyBody');
    if (raw != null) {
      return _fill(raw, {'number': number, 'table': table});
    }
    return _fallback.waiterNotificationReadyBody(number, table);
  }
  @override
  String get waiterNotificationBillTitle => _string('waiterNotificationBillTitle') ?? _fallback.waiterNotificationBillTitle;
  @override
  String get waiterNotificationSplitBillTitle => _string('waiterNotificationSplitBillTitle') ?? _fallback.waiterNotificationSplitBillTitle;
  @override
  String waiterNotificationBillBody(String table) {
    final raw = _string('waiterNotificationBillBody');
    if (raw != null) {
      return _fill(raw, {'table': table});
    }
    return _fallback.waiterNotificationBillBody(table);
  }
  @override
  String registerNotificationBillBody(String table) {
    final raw = _string('registerNotificationBillBody');
    if (raw != null) {
      return _fill(raw, {'table': table});
    }
    return _fallback.registerNotificationBillBody(table);
  }
  @override
  String get registerNotificationNewOrderTitle => _string('registerNotificationNewOrderTitle') ?? _fallback.registerNotificationNewOrderTitle;
  @override
  String registerNotificationNewOrderBody(String number) {
    final raw = _string('registerNotificationNewOrderBody');
    if (raw != null) {
      return _fill(raw, {'number': number});
    }
    return _fallback.registerNotificationNewOrderBody(number);
  }
  @override
  String marketplacePriorityTitle(String partner) {
    final raw = _string('marketplacePriorityTitle');
    if (raw != null) {
      return _fill(raw, {'partner': partner});
    }
    return _fallback.marketplacePriorityTitle(partner);
  }
  @override
  String marketplacePriorityBody(String number) {
    final raw = _string('marketplacePriorityBody');
    if (raw != null) {
      return _fill(raw, {'number': number});
    }
    return _fallback.marketplacePriorityBody(number);
  }
  @override
  String marketplacePriorityBodyWithExternal(String number, String externalId) {
    final raw = _string('marketplacePriorityBodyWithExternal');
    if (raw != null) {
      return _fill(raw, {'number': number, 'externalId': externalId});
    }
    return _fallback.marketplacePriorityBodyWithExternal(number, externalId);
  }
  @override
  String get marketplacePriorityChip => _string('marketplacePriorityChip') ?? _fallback.marketplacePriorityChip;
  @override
  String get newOrderAlertDescription => _string('newOrderAlertDescription') ?? _fallback.newOrderAlertDescription;
  @override
  String get marketplacePriorityDescription => _string('marketplacePriorityDescription') ?? _fallback.marketplacePriorityDescription;
  @override
  String get newOrderAlertTotal => _string('newOrderAlertTotal') ?? _fallback.newOrderAlertTotal;
  @override
  String get newOrderAlertPlaced => _string('newOrderAlertPlaced') ?? _fallback.newOrderAlertPlaced;
  @override
  String newOrderAlertTitleOne(String number) {
    final raw = _string('newOrderAlertTitleOne');
    if (raw != null) {
      return _fill(raw, {'number': number});
    }
    return _fallback.newOrderAlertTitleOne(number);
  }
  @override
  String get newOrderAlertView => _string('newOrderAlertView') ?? _fallback.newOrderAlertView;
  @override
  String get newOrderAlertOpen => _string('newOrderAlertOpen') ?? _fallback.newOrderAlertOpen;
  @override
  String get newOrderAlertDismiss => _string('newOrderAlertDismiss') ?? _fallback.newOrderAlertDismiss;
  @override
  String newOrderAlertMore(int count) {
    final raw = _string('newOrderAlertMore');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.newOrderAlertMore(count);
  }
  @override
  String get newOrderAlertToken => _string('newOrderAlertToken') ?? _fallback.newOrderAlertToken;
  @override
  String get registerNotificationsEmptySubtitle => _string('registerNotificationsEmptySubtitle') ?? _fallback.registerNotificationsEmptySubtitle;
  @override
  String get waiterSwitchToRegister => _string('waiterSwitchToRegister') ?? _fallback.waiterSwitchToRegister;
  @override
  String get waiterSwitchToRegisterSubtitle => _string('waiterSwitchToRegisterSubtitle') ?? _fallback.waiterSwitchToRegisterSubtitle;
  @override
  String get waiterSwitchToRegisterConfirm => _string('waiterSwitchToRegisterConfirm') ?? _fallback.waiterSwitchToRegisterConfirm;
  @override
  String get waiterSwitchToWaiter => _string('waiterSwitchToWaiter') ?? _fallback.waiterSwitchToWaiter;
  @override
  String get waiterSwitchToWaiterSubtitle => _string('waiterSwitchToWaiterSubtitle') ?? _fallback.waiterSwitchToWaiterSubtitle;
  @override
  String get waiterSwitchToWaiterConfirm => _string('waiterSwitchToWaiterConfirm') ?? _fallback.waiterSwitchToWaiterConfirm;
  @override
  String get waiterChangeMode => _string('waiterChangeMode') ?? _fallback.waiterChangeMode;
  @override
  String get waiterChangeModeSubtitle => _string('waiterChangeModeSubtitle') ?? _fallback.waiterChangeModeSubtitle;
  @override
  String get waiterFilterAll => _string('waiterFilterAll') ?? _fallback.waiterFilterAll;
  @override
  String get waiterFilterMyTables => _string('waiterFilterMyTables') ?? _fallback.waiterFilterMyTables;
  @override
  String get waiterFilterZones => _string('waiterFilterZones') ?? _fallback.waiterFilterZones;
  @override
  String get waiterSearchTables => _string('waiterSearchTables') ?? _fallback.waiterSearchTables;
  @override
  String get waiterBillModeFull => _string('waiterBillModeFull') ?? _fallback.waiterBillModeFull;
  @override
  String get waiterBillModeSplitItems => _string('waiterBillModeSplitItems') ?? _fallback.waiterBillModeSplitItems;
  @override
  String get waiterBillModeSplitEqual => _string('waiterBillModeSplitEqual') ?? _fallback.waiterBillModeSplitEqual;
  @override
  String get waiterBillSplitParts => _string('waiterBillSplitParts') ?? _fallback.waiterBillSplitParts;
  @override
  String get waiterBillSplitNote => _string('waiterBillSplitNote') ?? _fallback.waiterBillSplitNote;
  @override
  String get waiterBillSplitNoteHint => _string('waiterBillSplitNoteHint') ?? _fallback.waiterBillSplitNoteHint;
  @override
  String get waiterBillRequestSplit => _string('waiterBillRequestSplit') ?? _fallback.waiterBillRequestSplit;
  @override
  String get waiterBillSplitSelectItemsRequired => _string('waiterBillSplitSelectItemsRequired') ?? _fallback.waiterBillSplitSelectItemsRequired;
  @override
  String waiterBillSplitSelected(int count, String amount) {
    final raw = _string('waiterBillSplitSelected');
    if (raw != null) {
      return _fill(raw, {'count': count, 'amount': amount});
    }
    return _fallback.waiterBillSplitSelected(count, amount);
  }
  @override
  String waiterBillSplitEqualPreview(int parts, String amount) {
    final raw = _string('waiterBillSplitEqualPreview');
    if (raw != null) {
      return _fill(raw, {'parts': parts, 'amount': amount});
    }
    return _fallback.waiterBillSplitEqualPreview(parts, amount);
  }
  @override
  String get registerSplitBillBadge => _string('registerSplitBillBadge') ?? _fallback.registerSplitBillBadge;
  @override
  String registerSplitBillEqualHint(int parts) {
    final raw = _string('registerSplitBillEqualHint');
    if (raw != null) {
      return _fill(raw, {'parts': parts});
    }
    return _fallback.registerSplitBillEqualHint(parts);
  }
  @override
  String get registerSplitBillItemsHint => _string('registerSplitBillItemsHint') ?? _fallback.registerSplitBillItemsHint;
  @override
  String get collectModeFull => _string('collectModeFull') ?? _fallback.collectModeFull;
  @override
  String get collectModeSplit => _string('collectModeSplit') ?? _fallback.collectModeSplit;
  @override
  String get splitBillQrFullOnly => _string('splitBillQrFullOnly') ?? _fallback.splitBillQrFullOnly;
  @override
  String get splitBillTitle => _string('splitBillTitle') ?? _fallback.splitBillTitle;
  @override
  String get splitBillCollectHint => _string('splitBillCollectHint') ?? _fallback.splitBillCollectHint;
  @override
  String get splitBillPayFullRemaining => _string('splitBillPayFullRemaining') ?? _fallback.splitBillPayFullRemaining;
  @override
  String get splitBillOrderTotal => _string('splitBillOrderTotal') ?? _fallback.splitBillOrderTotal;
  @override
  String get splitBillPaidSoFar => _string('splitBillPaidSoFar') ?? _fallback.splitBillPaidSoFar;
  @override
  String get splitBillRemaining => _string('splitBillRemaining') ?? _fallback.splitBillRemaining;
  @override
  String get splitBillPaidCheck => _string('splitBillPaidCheck') ?? _fallback.splitBillPaidCheck;
  @override
  String get splitBillPayments => _string('splitBillPayments') ?? _fallback.splitBillPayments;
  @override
  String get splitBillAddPayment => _string('splitBillAddPayment') ?? _fallback.splitBillAddPayment;
  @override
  String get splitBillAmount => _string('splitBillAmount') ?? _fallback.splitBillAmount;
  @override
  String get splitBillFillRemaining => _string('splitBillFillRemaining') ?? _fallback.splitBillFillRemaining;
  @override
  String get splitBillQuickHalf => _string('splitBillQuickHalf') ?? _fallback.splitBillQuickHalf;
  @override
  String get splitBillQuickThird => _string('splitBillQuickThird') ?? _fallback.splitBillQuickThird;
  @override
  String get splitBillNoteOptional => _string('splitBillNoteOptional') ?? _fallback.splitBillNoteOptional;
  @override
  String get splitBillNoteHint => _string('splitBillNoteHint') ?? _fallback.splitBillNoteHint;
  @override
  String splitBillRecordPayment(String method) {
    final raw = _string('splitBillRecordPayment');
    if (raw != null) {
      return _fill(raw, {'method': method});
    }
    return _fallback.splitBillRecordPayment(method);
  }
  @override
  String get splitBillRecording => _string('splitBillRecording') ?? _fallback.splitBillRecording;
  @override
  String splitBillPaymentRecorded(String amount) {
    final raw = _string('splitBillPaymentRecorded');
    if (raw != null) {
      return _fill(raw, {'amount': amount});
    }
    return _fallback.splitBillPaymentRecorded(amount);
  }
  @override
  String get splitBillFullyPaid => _string('splitBillFullyPaid') ?? _fallback.splitBillFullyPaid;
  @override
  String get splitBillInvalidAmount => _string('splitBillInvalidAmount') ?? _fallback.splitBillInvalidAmount;
  @override
  String get splitBillAmountExceeds => _string('splitBillAmountExceeds') ?? _fallback.splitBillAmountExceeds;
  @override
  String get splitBillLoadFailed => _string('splitBillLoadFailed') ?? _fallback.splitBillLoadFailed;
  @override
  String waiterTablesSummary(int total) {
    final raw = _string('waiterTablesSummary');
    if (raw != null) {
      return _fill(raw, {'total': total});
    }
    return _fallback.waiterTablesSummary(total);
  }
  @override
  String waiterTablesShowing(int count) {
    final raw = _string('waiterTablesShowing');
    if (raw != null) {
      return _fill(raw, {'count': count});
    }
    return _fallback.waiterTablesShowing(count);
  }
  @override
  String get waiterClearFilters => _string('waiterClearFilters') ?? _fallback.waiterClearFilters;
  @override
  String get waiterNoFilterMatchesTitle => _string('waiterNoFilterMatchesTitle') ?? _fallback.waiterNoFilterMatchesTitle;
  @override
  String get waiterNoFilterMatchesSubtitle => _string('waiterNoFilterMatchesSubtitle') ?? _fallback.waiterNoFilterMatchesSubtitle;
  @override
  String get waiterActionSeat => _string('waiterActionSeat') ?? _fallback.waiterActionSeat;
  @override
  String get waiterActionOrder => _string('waiterActionOrder') ?? _fallback.waiterActionOrder;
  @override
  String get waiterActionBill => _string('waiterActionBill') ?? _fallback.waiterActionBill;
  @override
  String get waiterActionClean => _string('waiterActionClean') ?? _fallback.waiterActionClean;
  @override
  String get waiterOpenTicketBadge => _string('waiterOpenTicketBadge') ?? _fallback.waiterOpenTicketBadge;
  @override
  String get waiterNoOrderBadge => _string('waiterNoOrderBadge') ?? _fallback.waiterNoOrderBadge;
  @override
  String get waiterTableActionStartOrder => _string('waiterTableActionStartOrder') ?? _fallback.waiterTableActionStartOrder;
  @override
  String get waiterTableActionStartOrderHint => _string('waiterTableActionStartOrderHint') ?? _fallback.waiterTableActionStartOrderHint;
  @override
  String get waiterTableActionAddMoreHint => _string('waiterTableActionAddMoreHint') ?? _fallback.waiterTableActionAddMoreHint;
  @override
  String get waiterTableActionViewBill => _string('waiterTableActionViewBill') ?? _fallback.waiterTableActionViewBill;
  @override
  String get waiterTableActionViewBillHint => _string('waiterTableActionViewBillHint') ?? _fallback.waiterTableActionViewBillHint;
  @override
  String get waiterTableActionRequestBillHint => _string('waiterTableActionRequestBillHint') ?? _fallback.waiterTableActionRequestBillHint;
  @override
  String get waiterTableActionClearBill => _string('waiterTableActionClearBill') ?? _fallback.waiterTableActionClearBill;
  @override
  String get waiterTableActionClearBillHint => _string('waiterTableActionClearBillHint') ?? _fallback.waiterTableActionClearBillHint;
  @override
  String get waiterTableActionClearBillDone => _string('waiterTableActionClearBillDone') ?? _fallback.waiterTableActionClearBillDone;
  @override
  String get waiterTableActionMarkCleaning => _string('waiterTableActionMarkCleaning') ?? _fallback.waiterTableActionMarkCleaning;
  @override
  String get waiterTableActionMarkCleaningHint => _string('waiterTableActionMarkCleaningHint') ?? _fallback.waiterTableActionMarkCleaningHint;
  @override
  String get waiterTableActionMarkAvailable => _string('waiterTableActionMarkAvailable') ?? _fallback.waiterTableActionMarkAvailable;
  @override
  String get waiterTableActionMarkAvailableHint => _string('waiterTableActionMarkAvailableHint') ?? _fallback.waiterTableActionMarkAvailableHint;
  @override
  String get waiterTableActionFreeTable => _string('waiterTableActionFreeTable') ?? _fallback.waiterTableActionFreeTable;
  @override
  String get waiterTableActionFreeTableHint => _string('waiterTableActionFreeTableHint') ?? _fallback.waiterTableActionFreeTableHint;
  @override
  String get waiterTableActionCancelReservation => _string('waiterTableActionCancelReservation') ?? _fallback.waiterTableActionCancelReservation;
  @override
  String get waiterTableActionCancelReservationHint => _string('waiterTableActionCancelReservationHint') ?? _fallback.waiterTableActionCancelReservationHint;
  @override
  String get waiterTableActionReserve => _string('waiterTableActionReserve') ?? _fallback.waiterTableActionReserve;
  @override
  String get waiterTableActionReserveHint => _string('waiterTableActionReserveHint') ?? _fallback.waiterTableActionReserveHint;
  @override
  String get waiterTableActionMarkedReserved => _string('waiterTableActionMarkedReserved') ?? _fallback.waiterTableActionMarkedReserved;
  @override
  String get waiterTableActionSeatGuests => _string('waiterTableActionSeatGuests') ?? _fallback.waiterTableActionSeatGuests;
  @override
  String get waiterTableActionSeatGuestsHint => _string('waiterTableActionSeatGuestsHint') ?? _fallback.waiterTableActionSeatGuestsHint;
  @override
  String get waiterTableActionReadyToSeat => _string('waiterTableActionReadyToSeat') ?? _fallback.waiterTableActionReadyToSeat;
  @override
  String get waiterTableActionReadyToSeatHint => _string('waiterTableActionReadyToSeatHint') ?? _fallback.waiterTableActionReadyToSeatHint;
  @override
  String get waiterTableActionMarkedCleaning => _string('waiterTableActionMarkedCleaning') ?? _fallback.waiterTableActionMarkedCleaning;
  @override
  String get waiterTableActionMarkedAvailable => _string('waiterTableActionMarkedAvailable') ?? _fallback.waiterTableActionMarkedAvailable;
  @override
  String get waiterTableActionsMore => _string('waiterTableActionsMore') ?? _fallback.waiterTableActionsMore;
  @override
  String get waiterTableStatusHintAvailable => _string('waiterTableStatusHintAvailable') ?? _fallback.waiterTableStatusHintAvailable;
  @override
  String get waiterTableStatusHintOccupied => _string('waiterTableStatusHintOccupied') ?? _fallback.waiterTableStatusHintOccupied;
  @override
  String get waiterTableStatusHintOccupiedEmpty => _string('waiterTableStatusHintOccupiedEmpty') ?? _fallback.waiterTableStatusHintOccupiedEmpty;
  @override
  String get waiterTableStatusHintBilling => _string('waiterTableStatusHintBilling') ?? _fallback.waiterTableStatusHintBilling;
  @override
  String get waiterTableStatusHintBillingDone => _string('waiterTableStatusHintBillingDone') ?? _fallback.waiterTableStatusHintBillingDone;
  @override
  String get waiterTableStatusHintReserved => _string('waiterTableStatusHintReserved') ?? _fallback.waiterTableStatusHintReserved;
  @override
  String get waiterTableStatusHintCleaning => _string('waiterTableStatusHintCleaning') ?? _fallback.waiterTableStatusHintCleaning;
}
