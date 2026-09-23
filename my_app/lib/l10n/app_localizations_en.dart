// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageName => 'English';

  @override
  String get languagePickerTitle => 'Language';

  @override
  String get languagePickerHint => 'Choose a language for this register';

  @override
  String get appearancePickerTitle => 'Appearance';

  @override
  String get appearancePickerHint => 'Choose how this app looks';

  @override
  String get themeModeSystem => 'System';

  @override
  String get themeModeSystemHint => 'Match the device light or dark setting';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeLightHint => 'Always use the light theme';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get themeModeDarkHint => 'Always use the dark theme';

  @override
  String get shellAppearance => 'Appearance';

  @override
  String get shellAutoLock => 'Auto-lock';

  @override
  String get autoLockPickerTitle => 'Auto-lock';

  @override
  String get autoLockPickerHint =>
      'Choose whether this register locks itself when idle';

  @override
  String get autoLockEnabled => 'On';

  @override
  String get autoLockEnabledHint => 'Lock after 2 minutes of inactivity';

  @override
  String get autoLockDisabled => 'Off';

  @override
  String get autoLockDisabledHint => 'Stay unlocked until you lock manually';

  @override
  String get adminManage => 'Manage';

  @override
  String get adminManageSubtitle => 'Menu, tables, orders, and reports';

  @override
  String get adminMenu => 'Menu';

  @override
  String get adminTables => 'Tables';

  @override
  String get adminOrders => 'Orders';

  @override
  String get adminOrdersPeriodToday => 'Today';

  @override
  String get adminOrdersPeriodYesterday => 'Yesterday';

  @override
  String get adminOrdersPeriodLast7Days => 'Last 7 days';

  @override
  String get adminOrdersPeriodAll => 'All time';

  @override
  String get adminOrdersPaymentAll => 'All payments';

  @override
  String get adminOrdersPaymentUnpaid => 'Unpaid';

  @override
  String get adminOrdersPaymentPaid => 'Paid';

  @override
  String get adminOrdersChannelCaptain => 'POS - Captain';

  @override
  String get adminOrdersChannelPos => 'POS';

  @override
  String get adminOrdersChannelRegister => 'POS';

  @override
  String get adminOrdersChannelKiosk => 'Kiosk';

  @override
  String get adminOrdersChannelOnline => 'Online';

  @override
  String get adminOrdersChannelApp => 'Mobile app';

  @override
  String get adminOrdersChannelApi => 'API';

  @override
  String get adminOrdersChannelUnknown => 'Order';

  @override
  String adminOrdersTableMeta(String name) {
    return 'Table $name';
  }

  @override
  String get adminTokenShort => 'Token';

  @override
  String adminOrdersAutoRefresh(String time) {
    return 'Auto-refresh · $time';
  }

  @override
  String get adminModifiers => 'Modifiers';

  @override
  String get adminTimeSlots => 'Time slots';

  @override
  String get adminHours => 'Hours & availability';

  @override
  String get adminHoursSubtitle => 'Store open/close and weekly schedule';

  @override
  String get storeOpen => 'Open';

  @override
  String get storeClosed => 'Closed';

  @override
  String get storeOutsideHours => 'Outside hours';

  @override
  String get storePaused => 'Paused';

  @override
  String get storeCloseTitle => 'Close store to guests?';

  @override
  String get storeCloseMessage =>
      'Storefront and kiosk will stop taking new orders. POS stays available.';

  @override
  String get storeCloseConfirm => 'Close to guests';

  @override
  String get storeOpenTitle => 'Open store to guests?';

  @override
  String get storeOpenMessage =>
      'Storefront and kiosk can accept new orders again (subject to weekly hours).';

  @override
  String get storeOpenConfirm => 'Open to guests';

  @override
  String get storeGuestStatusOpen => 'Guest ordering is open';

  @override
  String get storeGuestStatusPaused => 'Guest ordering is paused';

  @override
  String get storeGuestStatusOutsideHours => 'Outside weekly hours';

  @override
  String get storeGuestStatusOther => 'Guest ordering is unavailable';

  @override
  String get storeAcceptOnlineOrders => 'Restaurant is open';

  @override
  String get storeAcceptOnlineOrdersHelp =>
      'When off, storefront and kiosk pause. POS keeps working.';

  @override
  String get storeScheduleEnabled => 'Use weekly hours';

  @override
  String get storeScheduleEnabledHelp =>
      'When on, guest channels close outside the schedule below.';

  @override
  String get storeTimezone => 'Timezone';

  @override
  String get storeClosedMessage => 'Closed message';

  @override
  String get storeClosedMessageHint => 'Shown when guests cannot order';

  @override
  String get storeScheduleTitle => 'Weekly hours';

  @override
  String get storeAddShift => 'Add shift';

  @override
  String get storeCopyWeekdays => 'Copy Mon to weekdays';

  @override
  String get storeDayClosed => 'Closed';

  @override
  String get storePosNote =>
      'POS register keeps working when guest orders are closed.';

  @override
  String get storeHoursSaved => 'Hours saved';

  @override
  String storeOpensAt(String when) {
    return 'Opens $when';
  }

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDone => 'Done';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonPleaseWait => 'Please wait';

  @override
  String get commonSomethingWentWrong => 'Something went wrong';

  @override
  String get commonChangeServer => 'Change server';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonPrint => 'Print';

  @override
  String get commonSignOut => 'Sign out';

  @override
  String get commonTotal => 'Total';

  @override
  String get commonSubtotal => 'Subtotal';

  @override
  String get commonPaid => 'Paid';

  @override
  String get commonUnpaid => 'Unpaid';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get authStaffSignIn => 'Staff sign in';

  @override
  String get authSignInOnce => 'Sign in once, then unlock with your POS PIN';

  @override
  String get authUseStaffEmail => 'Use your staff email and password';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authPairDeviceFirst => 'Optional: bind this register';

  @override
  String get authChangePairedRegister => 'Change paired register';

  @override
  String get authRegisterPaired => 'Register paired';

  @override
  String get authStaffPos => 'Staff POS';

  @override
  String get authReadyForCashier => 'Ready for staff sign-in';

  @override
  String get authPairThenSignIn => 'Sign in with your staff account';

  @override
  String get authThisRegisterPaired =>
      'Register is set — staff still sign in with email & password';

  @override
  String get setupServerTitle => 'Server setup';

  @override
  String setupConnectRegister(String app) {
    return 'Connect this register to your $app server, then sign in and start taking orders.';
  }

  @override
  String get setupServerUrl => 'Server URL';

  @override
  String get pairDeviceTitle => 'Optional register bind';

  @override
  String get pairBindTerminal => 'Remember which register this tablet is';

  @override
  String get pairFooterNote =>
      'Pairing does not sign you in. It only remembers this register so staff skip picking a terminal after login.';

  @override
  String get pairNewCode => 'New code';

  @override
  String get pairSkipToSignIn => 'Skip — just sign in';

  @override
  String get lockRegisterLocked => 'Register locked';

  @override
  String get lockWelcomeBack => 'Welcome back';

  @override
  String lockWelcomeBackNamed(String name) {
    return 'Welcome back, $name';
  }

  @override
  String lockSignedInAs(String name) {
    return 'Signed in as $name';
  }

  @override
  String get lockEnterPin => 'Enter your 6-digit POS PIN';

  @override
  String get lockUnlock => 'Unlock';

  @override
  String get lockUnlocking => 'Unlocking…';

  @override
  String get lockUnlockWithPin => 'Unlock with your POS PIN to continue';

  @override
  String get shellOrders => 'Orders';

  @override
  String get shellReports => 'Reports';

  @override
  String get shellHeld => 'Held';

  @override
  String get shellLanguage => 'Language';

  @override
  String get shellCheckForUpdates => 'Check for updates';

  @override
  String get shellKeyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get shellLockRegister => 'Lock register';

  @override
  String get opsOpenShift => 'Open shift';

  @override
  String get opsCloseShift => 'Close shift';

  @override
  String get cartHold => 'Hold';

  @override
  String get cartPay => 'Pay';

  @override
  String get cartClear => 'Clear cart';

  @override
  String get cartEmptyTitle => 'Cart is empty';

  @override
  String get cartEmptySubtitle => 'Tap menu items to start a ticket';

  @override
  String cartHeldTicket(String label) {
    return 'Held ticket $label';
  }

  @override
  String get cartReplaceTitle => 'Replace current ticket?';

  @override
  String get cartReplaceMessage =>
      'Resuming this held order will overwrite the items currently on the cart.';

  @override
  String get cartResume => 'Resume';

  @override
  String get ordersTitle => 'Orders';

  @override
  String get ordersHeldTab => 'Held';

  @override
  String get ordersOrdersTab => 'Orders';

  @override
  String get ordersHeldSubtitle => 'Parked drafts waiting to be resumed';

  @override
  String ordersHeldCountSubtitle(int count) {
    return '$count parked ticket ready to resume';
  }

  @override
  String ordersHeldCountSubtitlePlural(int count) {
    return '$count parked tickets ready to resume';
  }

  @override
  String get ordersBranchActivity => 'Branch activity on this register';

  @override
  String get ordersHeldHint =>
      'Hold parks the current cart. Resume loads it back so you can keep editing or pay.';

  @override
  String get ordersSearchHint => 'Search order #, customer, table…';

  @override
  String get ordersFilterToday => 'Today';

  @override
  String get ordersFilterUnpaid => 'Unpaid';

  @override
  String get ordersFilterSevenDays => '7 days';

  @override
  String get ordersNoHeldTitle => 'No held tickets';

  @override
  String get ordersNoHeldSubtitle =>
      'Tap Hold on the cart to park a draft, then resume it here.';

  @override
  String get ordersNoOrdersTitle => 'No orders found';

  @override
  String get ordersNoOrdersSubtitle => 'Try another filter or search term.';

  @override
  String get ordersCouldNotLoad => 'Couldn’t load orders';

  @override
  String get ordersResumeTicket => 'Resume ticket';

  @override
  String get ordersAlreadyOnCart => 'Already on cart';

  @override
  String get ordersOnCart => 'On cart';

  @override
  String get ordersHeldTicket => 'Held ticket';

  @override
  String ordersCollect(String amount) {
    return 'Collect $amount';
  }

  @override
  String get ordersPrintReceipt => 'Print receipt';

  @override
  String get ordersPrintKot => 'Print KOT';

  @override
  String get ordersDetailTitle => 'Order details';

  @override
  String get ordersDetailLoading => 'Loading order…';

  @override
  String get ordersDetailItems => 'Items';

  @override
  String get ordersDetailNoItems => 'No line items';

  @override
  String get ordersDetailPaid => 'Paid';

  @override
  String get ordersDetailDue => 'Amount due';

  @override
  String printKotPrinted(String label) {
    return 'KOT printed for $label';
  }

  @override
  String ordersPaymentRecorded(String label) {
    return 'Payment recorded for $label';
  }

  @override
  String ordersPaymentReceived(String label) {
    return 'Payment received for $label';
  }

  @override
  String ordersPaymentNotCompleted(String label) {
    return 'Payment not completed for $label';
  }

  @override
  String ordersLoaded(String label) {
    return 'Loaded $label';
  }

  @override
  String get ordersUpdated => 'Order updated';

  @override
  String get ordersCancelTitle => 'Cancel this order?';

  @override
  String get ordersCancelMessage =>
      'This removes the order from the kitchen flow. You can’t undo this.';

  @override
  String ordersCancelPaidMessage(String amount) {
    return 'This order is marked paid ($amount). Cancel only keeps the payment on record, or cancel and refund to mark it refunded (return cash/card manually).';
  }

  @override
  String get ordersCancelConfirm => 'Cancel order';

  @override
  String get ordersCancelAndRefund => 'Cancel & refund';

  @override
  String get ordersCancelKeep => 'Keep order';

  @override
  String get ordersCancelled => 'Order cancelled';

  @override
  String get ordersCancelledRefunded => 'Order cancelled and marked refunded';

  @override
  String get ordersCancelAction => 'Cancel order';

  @override
  String get payTakePayment => 'Take payment';

  @override
  String get payCollectPayment => 'Collect payment';

  @override
  String get payAmountDue => 'AMOUNT DUE';

  @override
  String get payCash => 'Cash';

  @override
  String get payCashSubtitle => 'Tender & change';

  @override
  String get payCard => 'Card';

  @override
  String get payCardSubtitle => 'Terminal';

  @override
  String get payWallet => 'Wallet';

  @override
  String get payWalletSubtitle => 'Digital pay';

  @override
  String get payOther => 'Other';

  @override
  String get payOtherSubtitle => 'Voucher, etc.';

  @override
  String get payLater => 'Pay later';

  @override
  String get payLaterSubtitle => 'Open tab';

  @override
  String get payUpiQr => 'UPI QR';

  @override
  String get payConfirm => 'Confirm payment';

  @override
  String get shiftOpenTitle => 'Open shift';

  @override
  String get shiftCloseTitle => 'Close shift';

  @override
  String get authAccountLoadFailed =>
      'Could not load account data from server. Try again.';

  @override
  String get authLoginNoToken => 'Login did not return a token.';

  @override
  String get authNoRestaurantBranch =>
      'No restaurant or branch assigned to this account.';

  @override
  String get authNotSignedIn => 'Not signed in';

  @override
  String get authSessionExpired => 'Session expired. Please sign in again.';

  @override
  String get authSignOutFromLock =>
      'You will need email and password to sign in again. Cancel to stay on PIN unlock.';

  @override
  String get authSignOutMessageNoPin =>
      'You will need your email and password to sign in again.';

  @override
  String get authSignOutMessageWithPin =>
      'You will need your email and password, or POS PIN, to sign in again.';

  @override
  String get authSignOutTitle => 'Sign out?';

  @override
  String get brandTagline =>
      'Fast staff ordering — sign in, open a shift, and take payments.';

  @override
  String get cartAddCustomer => 'Add customer';

  @override
  String get cartClearCustomer => 'Clear customer';

  @override
  String get cartClearMessage =>
      'Remove all items and reset customer, table, notes, and discount.';

  @override
  String get cartClearTitle => 'Clear ticket?';

  @override
  String get cartClearTooltip => 'Clear ticket';

  @override
  String get cartCurrentTicket => 'Current ticket';

  @override
  String get cartCustomerFallback => 'Customer';

  @override
  String get cartCustomerNameHint => 'Or type a name';

  @override
  String get cartCustomerSearchHint => 'Search name, phone, email';

  @override
  String get cartEmptyPanelSubtitle => 'Tap menu items to build this order.';

  @override
  String get cartEmptyPanelTitle => 'Empty ticket';

  @override
  String cartHeldSnack(String label) {
    return 'Ticket $label held — open Orders → Held to resume';
  }

  @override
  String get cartIsEmptyError => 'Cart is empty.';

  @override
  String cartItemCount(int count) {
    return '$count item';
  }

  @override
  String cartItemCountPlural(int count) {
    return '$count items';
  }

  @override
  String get cartNoItemsYet => 'No items yet';

  @override
  String get cartNoTable => 'No table';

  @override
  String get cartNoTablesSubtitle => 'Ask your manager to add tables in Admin.';

  @override
  String get cartNoTablesTitle => 'No tables configured';

  @override
  String get cartPayable => 'Payable';

  @override
  String get cartRemoveLine => 'Remove';

  @override
  String get cartSaveName => 'Save name';

  @override
  String get cartSelectTable => 'Select table';

  @override
  String get cartServiceCharge => 'Service charge';

  @override
  String get cartTable => 'Table';

  @override
  String cartTableNamed(String name) {
    return 'Table $name';
  }

  @override
  String get cartTableOccupied => 'Occupied';

  @override
  String get cartTablesLegend =>
      'Available tables are green · occupied are red';

  @override
  String get cartTablesOther => 'OTHER';

  @override
  String get cartTax => 'Tax';

  @override
  String get cartTicketNotes => 'Ticket notes';

  @override
  String get cartTicketNotesHint => 'Ticket notes';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String get confirmDestructiveSubtitle => 'This cannot be undone easily';

  @override
  String get connIssueFooter => 'Check the server URL and try again.';

  @override
  String get connIssueTitle => 'Connection issue';

  @override
  String get connUnableToReach => 'Unable to reach the server.';

  @override
  String get subscriptionEndedTitle => 'Subscription ended';

  @override
  String get subscriptionTrialEndedTitle => 'Trial ended';

  @override
  String get subscriptionEndedBody =>
      'This restaurant\'s subscription is inactive. Ask an owner to renew billing to keep using POS.';

  @override
  String get subscriptionTrialEndedBody =>
      'This restaurant\'s free trial has ended. Ask an owner to choose a plan to continue.';

  @override
  String get subscriptionEndedFooter =>
      'POS stays locked until billing is active again.';

  @override
  String get billingTitle => 'Billing';

  @override
  String get billingManageSubtitle => 'Plans, trial, and subscription';

  @override
  String get billingUpgradePlan => 'Upgrade plan';

  @override
  String get billingUpgradeBody =>
      'Choose a plan to restore POS access for this restaurant.';

  @override
  String get billingRenewBody =>
      'Your subscription is inactive. Choose a plan to restore POS access.';

  @override
  String get billingUpgradeFooter => 'POS unlocks as soon as a plan is active.';

  @override
  String get billingChoosePlan => 'Pick a plan for this restaurant.';

  @override
  String get billingMonthly => 'Monthly';

  @override
  String get billingYearly => 'Yearly';

  @override
  String get billingSubscribe => 'Subscribe';

  @override
  String get billingActivateFree => 'Activate free plan';

  @override
  String get billingCurrentPlan => 'Current plan';

  @override
  String billingPayWith(String provider) {
    return 'Pay with $provider';
  }

  @override
  String get billingPaymentOff =>
      'Online checkout is not enabled. Activate a free plan, or ask support to enable payments.';

  @override
  String get billingPaymentProvider => 'the payment provider';

  @override
  String billingCoveredBody(String org) {
    return 'Billing for this restaurant is managed by $org. Ask that organization to renew the plan.';
  }

  @override
  String get billingOrganization => 'the organization';

  @override
  String get billingIvePaid => 'I\'ve paid — continue';

  @override
  String get billingReturnFromCheckout =>
      'Finish payment in the browser, then tap below to unlock POS.';

  @override
  String get billingNoPlans => 'No plans are available right now.';

  @override
  String get billingFree => 'Free';

  @override
  String get billingPerMonth => 'month';

  @override
  String get billingPerYear => 'year';

  @override
  String get billingActivated => 'Plan activated';

  @override
  String get billingPaymentPending =>
      'Payment is not confirmed yet. Finish checkout, then try again.';

  @override
  String get contextBranch => 'Branch';

  @override
  String get contextChooseLocation => 'Choose location';

  @override
  String get contextCurrentRestaurant => 'Current restaurant';

  @override
  String get contextDefaultBranch => 'Default branch';

  @override
  String get contextFooterNote =>
      'Pick where this register will take orders today.';

  @override
  String get contextNoOtherLocation =>
      'No other restaurant or branch is available for this account.';

  @override
  String get contextRestaurant => 'Restaurant';

  @override
  String get contextSubtitle =>
      'Select the restaurant and branch for this register session.';

  @override
  String get dietNonVeg => 'Non-veg';

  @override
  String get dietVeg => 'Veg';

  @override
  String get dietVegan => 'Vegan';

  @override
  String get dietEgg => 'Egg';

  @override
  String get dietDrink => 'Drink';

  @override
  String get discountAmount => 'Amount';

  @override
  String get discountApply => 'Apply';

  @override
  String get discountApplyTitle => 'Apply discount';

  @override
  String get discountEditTitle => 'Edit discount';

  @override
  String get discountLabel => 'Discount';

  @override
  String get discountNewTaxableBase => 'New taxable base';

  @override
  String discountOffSubtotal(String amount) {
    return 'Off cart subtotal · $amount';
  }

  @override
  String get discountPercent => 'Percent';

  @override
  String get discountReason => 'Reason';

  @override
  String get discountReasonHint => 'Optional — staff note for the ticket';

  @override
  String get discountRemove => 'Remove discount';

  @override
  String get discountTypeLabel => 'Discount type';

  @override
  String get discountUpdate => 'Update';

  @override
  String get menuAllItems => 'All items';

  @override
  String get menuBarcodeTooltip =>
      'USB barcode scanners work here automatically';

  @override
  String get menuBrowseFull => 'Browse the full menu';

  @override
  String get menuCategoryFallback => 'Category';

  @override
  String get menuCategoryItems => 'Items in this category';

  @override
  String get menuChoose => 'Choose';

  @override
  String get menuFrom => 'FROM';

  @override
  String get menuNavLabel => 'Menu';

  @override
  String get menuNoItemsSubtitle => 'Try another category or search term.';

  @override
  String get menuNoItemsTitle => 'No items found';

  @override
  String get menuOptions => 'Options';

  @override
  String get menuNotAvailableBadge => 'Not available';

  @override
  String get menuNotAvailableTitle => 'Not available?';

  @override
  String menuNotAvailableMessage(String name) {
    return '$name is marked not available. Add it to this ticket anyway?';
  }

  @override
  String get menuNotAvailableConfirm => 'Add anyway';

  @override
  String get menuOutsideScheduleBadge => 'Outside schedule';

  @override
  String get menuOutsideScheduleTitle => 'Outside schedule?';

  @override
  String menuOutsideScheduleMessage(String name) {
    return '$name is outside its menu time slot. Add it to this ticket anyway?';
  }

  @override
  String get menuOutsideScheduleConfirm => 'Add anyway';

  @override
  String get menuPopularSubtitle => 'Fast picks for this register';

  @override
  String get menuPopularTitle => 'Popular items';

  @override
  String get menuScan => 'Scan';

  @override
  String get menuSearchHint => 'Search menu or scan barcode…';

  @override
  String menuSearchResults(String query) {
    return 'Results for \"$query\"';
  }

  @override
  String get modifierAddToTicket => 'Add to ticket';

  @override
  String modifierChooseUpTo(int max, String name) {
    return 'Choose up to $max for $name';
  }

  @override
  String get modifierChooseVariant => 'Choose Variant';

  @override
  String get modifierNotesHint => 'Add a note or special request…';

  @override
  String get modifierOptional => 'Optional';

  @override
  String modifierPleaseChoose(String name) {
    return 'Please choose $name';
  }

  @override
  String get modifierQuantity => 'Quantity';

  @override
  String get modifierRequired => 'Required';

  @override
  String get modifierSpecialInstructions => 'Special Instructions';

  @override
  String get netBlocked =>
      'Network access blocked. Check permissions and try again.';

  @override
  String netCannotConnect(String url) {
    return 'Could not connect to the server. Is it running?';
  }

  @override
  String netCannotReach(String url) {
    return 'Could not reach the server. Check your connection and try again.';
  }

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNetwork =>
      'Could not reach the server. Check your connection and try again.';

  @override
  String get offlineBanner =>
      'Offline — cash & external payments still work; orders sync when connected';

  @override
  String get offlineLabel => 'Offline';

  @override
  String get offlineNotAvailable => 'Offline mode not available';

  @override
  String offlinePending(int count) {
    return 'Offline ($count pending)';
  }

  @override
  String get offlineSyncing => 'Syncing…';

  @override
  String offlineSyncFailed(int count) {
    return '$count need sync';
  }

  @override
  String offlineSyncFailedBanner(int count) {
    return '$count offline order(s) failed to sync — open Sync from the menu or check shift status';
  }

  @override
  String get offlinePaymentBlocked =>
      'This payment method needs a network connection. Use cash or another offline method.';

  @override
  String get offlineHeldPayBlocked =>
      'Server held tickets need a network connection to settle. Local offline holds can be paid with cash or another offline method.';

  @override
  String get offlineHeldNotFound =>
      'That held ticket is no longer on this device.';

  @override
  String get offlinePinNeedsNetwork =>
      'Unlock once while online to enable offline PIN unlock on this device.';

  @override
  String get offlineSyncNothingPending => 'No pending offline orders';

  @override
  String offlineSyncPartial(int count) {
    return 'Synced with $count still pending';
  }

  @override
  String get opsNoShift => 'No shift';

  @override
  String get opsOpenOptional => 'Optional — open when ready';

  @override
  String get opsOpenToTakeOrders => 'Open a shift to take orders';

  @override
  String get opsRegShort => 'Reg';

  @override
  String get opsRegisterReady => 'Register is ready';

  @override
  String get opsShiftOpen => 'Shift open';

  @override
  String get opsShiftRequired => 'Shift required';

  @override
  String opsSince(String time) {
    return 'since $time';
  }

  @override
  String orderPlaced(String label) {
    return 'Order $label placed';
  }

  @override
  String orderSavedOffline(String label) {
    return 'Order $label saved (offline)';
  }

  @override
  String get orderTypeDelivery => 'Delivery';

  @override
  String get orderTypeDineIn => 'Dine in';

  @override
  String get orderTypeTakeaway => 'Takeaway';

  @override
  String get ordersAdvanceAccept => 'Accept';

  @override
  String get ordersAdvanceDone => 'Done';

  @override
  String get ordersAdvanceKitchen => 'Kitchen';

  @override
  String get ordersAdvanceReady => 'Ready';

  @override
  String ordersItemCount(int count) {
    return '$count item';
  }

  @override
  String ordersItemCountPlural(int count) {
    return '$count items';
  }

  @override
  String ordersMoreItems(int count) {
    return '+$count more';
  }

  @override
  String get ordersNumberMissing => 'Order number missing';

  @override
  String ordersPagination(int from, int to, int total) {
    return '$from–$to of $total';
  }

  @override
  String ordersTokenLabel(String token) {
    return 'Token $token';
  }

  @override
  String get pairAdminHint =>
      'Optional. In Admin → POS terminals, tap Pair tablet on this register, then enter the code shown there. You will still sign in afterward.';

  @override
  String get pairCodeExpired =>
      'Pairing code expired. Tap New code to try again.';

  @override
  String get pairThisTablet => 'Bind this tablet to a register';

  @override
  String get pairWaitingManager => 'Waiting for manager to confirm…';

  @override
  String get payCashTendered => 'Cash tendered';

  @override
  String get payChangeDue => 'Change due';

  @override
  String payCharge(String amount) {
    return 'Charge $amount';
  }

  @override
  String payConfirmMethod(String method) {
    return 'Confirm $method';
  }

  @override
  String get payExact => 'Exact';

  @override
  String get payLaterHelp =>
      'Order is saved as an open tab — charge when ready.';

  @override
  String get payMethodLabel => 'Payment method';

  @override
  String get payNotCompleted => 'Payment not completed';

  @override
  String get payPlaceOrder => 'Place order';

  @override
  String get payPlaceWithout => 'Place without payment';

  @override
  String get payQrHelp => 'Customer scans and pays with UPI on their phone.';

  @override
  String get payReceived => 'Received';

  @override
  String get payShort => 'Short of total';

  @override
  String get payShortHelp => 'Amount received is less than total due.';

  @override
  String get payShowQr => 'Show QR for customer';

  @override
  String get payTerminalHelp =>
      'Complete on the terminal or record the payment.';

  @override
  String get payTip => 'Tip';

  @override
  String get payTipCustom => 'Custom tip';

  @override
  String get payTipNone => 'None';

  @override
  String get payUpi => 'UPI';

  @override
  String get pinAccountPassword => 'Account password';

  @override
  String get pinBannerBody =>
      'Set a 6-digit PIN to unlock this register after relaunch. Prefer Lock between shifts.';

  @override
  String get pinBannerTitle => 'Unlock with a POS PIN';

  @override
  String get pinChangeTitle => 'Change POS PIN';

  @override
  String get pinConfirm => 'Confirm PIN';

  @override
  String get pinCreateSubtitle =>
      'Create a 6-digit PIN to unlock this register';

  @override
  String get pinIncorrect => 'Incorrect PIN';

  @override
  String get pinMismatch => 'PINs do not match.';

  @override
  String get pinMustBeSix => 'PIN must be exactly 6 digits.';

  @override
  String get pinNeedPassword => 'Enter your account password.';

  @override
  String get pinNew => 'New PIN';

  @override
  String get pinPasswordHelper => 'Required to save your PIN';

  @override
  String get pinPromptMessage =>
      'Unlock this register with a short PIN instead of email and password. Recommended after pairing.';

  @override
  String get pinPromptNotNow => 'Not now';

  @override
  String get pinPromptSet => 'Set PIN';

  @override
  String get pinPromptSetNow => 'Set PIN now';

  @override
  String get pinPromptTitle => 'Set a POS PIN?';

  @override
  String get pinSave => 'Save PIN';

  @override
  String get pinSaveFailed => 'Could not save PIN';

  @override
  String get pinSaved => 'POS PIN saved.';

  @override
  String get pinSetTitle => 'Set POS PIN';

  @override
  String get pinUpdate => 'Update PIN';

  @override
  String get poweredBy => 'Powered by';

  @override
  String printCouldNot(String error) {
    return 'Could not print: $error';
  }

  @override
  String printOrderNotFound(String label) {
    return 'Order $label not found';
  }

  @override
  String printPrinted(String label) {
    return 'Printed $label';
  }

  @override
  String printReceiptConfirmMessage(String label) {
    return 'Print a duplicate receipt for $label?';
  }

  @override
  String get printReceiptConfirmTitle => 'Print receipt?';

  @override
  String get printerActive => 'Active';

  @override
  String get printerAutoPrintKot => 'Auto-print KOT on new orders';

  @override
  String get printerAutoPrintKotHelp =>
      'When a guest, kiosk, online, or partner order arrives, print kitchen tickets on this device’s printer.';

  @override
  String get printerAutoPrintKotOnSnack => 'New orders will auto-print KOT';

  @override
  String get printerAutoPrintKotOffSnack =>
      'New orders will not auto-print KOT';

  @override
  String get printerTestPrint => 'Test print';

  @override
  String get printerTestSent => 'Test print sent';

  @override
  String get printerTestFailed => 'Test print failed';

  @override
  String get printerTesting => 'Printing test…';

  @override
  String get printerBluetoothHint =>
      'Put the printer in pairing mode, then scan';

  @override
  String get printerBluetoothTitle => 'Bluetooth printers';

  @override
  String get printerConfirmBefore => 'Confirm before scan-to-print';

  @override
  String printerConnectBt(String name) {
    return 'Could not connect to Bluetooth printer \"$name\". Keep the printer powered on and nearby, then try again.';
  }

  @override
  String printerConnectMac(String name) {
    return 'Could not print to \"$name\". Confirm the printer is online in System Settings and supports raw ESC/POS via CUPS.';
  }

  @override
  String printerConnectUsb(String name) {
    return 'Could not connect to USB printer \"$name\". Unplug and replug the printer, then try again.';
  }

  @override
  String printerConnectWeb(String name) {
    return 'Could not print to \"$name\" in the browser. Run the native POS app with a USB or Bluetooth thermal printer.';
  }

  @override
  String printerCountFound(int count) {
    return '$count found';
  }

  @override
  String get printerEmptyBt => 'No Bluetooth printers found nearby.';

  @override
  String get printerEmptyUsb => 'No USB / system printers found.';

  @override
  String get printerEmptyWeb => 'Printing is not supported in the browser.';

  @override
  String get printerHelpAndroid =>
      'Use USB, LAN (IP:9100 on the same network), or Bluetooth for an ESC/POS printer. Allow USB / nearby devices when Android prompts.';

  @override
  String get printerHelpIos =>
      'iOS supports Bluetooth or LAN (same Wi‑Fi) ESC/POS printers. For LAN, enter the printer IP and port 9100.';

  @override
  String get printerHelpMac =>
      'Choose USB / system, LAN (IP:9100), or Bluetooth ESC/POS. macOS CUPS printers appear under USB — use a raw/ESC-POS queue when available.';

  @override
  String get printerHelpWin =>
      'Connect USB, enter a LAN printer IP (port 9100), or pair Bluetooth in Windows Settings, then select it below.';

  @override
  String printerConnectLan(String name, String endpoint) {
    return 'Could not reach LAN printer \"$name\" at $endpoint. Check power, Wi‑Fi/Ethernet, and that raw TCP port 9100 is open.';
  }

  @override
  String get printerLanTitle => 'Network printer';

  @override
  String get printerLanHint =>
      'Same Wi‑Fi/Ethernet as this device. Most ESC/POS printers use port 9100.';

  @override
  String get printerLanHost => 'IP address or hostname';

  @override
  String get printerLanPort => 'Port';

  @override
  String get printerLanNameOptional => 'Name (optional)';

  @override
  String get printerLanNameHint => 'Front counter';

  @override
  String get printerLanSave => 'Save LAN printer';

  @override
  String get printerLanHostRequired =>
      'Enter the printer IP address or hostname.';

  @override
  String get printerLanPortInvalid => 'Port must be between 1 and 65535.';

  @override
  String get printerLoadFailed => 'Could not load printers';

  @override
  String get printerLooking => 'Looking for printers…';

  @override
  String get printerMissing => 'No receipt printer selected.';

  @override
  String get printerMissingWeb =>
      'Receipt printing requires the native POS app.';

  @override
  String get printerNoBluetooth => 'No Bluetooth printers';

  @override
  String get printerNoneFound => 'No printers found';

  @override
  String get printerReceiptTitle => 'Receipt printer';

  @override
  String get printerScan => 'Scan';

  @override
  String get printerScanAgain => 'Scan again';

  @override
  String get printerScanAskHelp =>
      'Ask before printing when an order QR is scanned';

  @override
  String get printerScanAskSnack => 'Scan-to-print will ask before printing';

  @override
  String get printerScanAutoHelp =>
      'Print automatically when an order QR is scanned';

  @override
  String get printerScanAutoSnack => 'Scan-to-print will print automatically';

  @override
  String get printerScanBluetooth => 'Scan for Bluetooth printers';

  @override
  String get printerScanToPrint => 'Scan to print';

  @override
  String get statusPrinterReady => 'Printer ready';

  @override
  String get statusPrinterNone => 'No printer';

  @override
  String get statusPrinterMissing => 'Printer disconnected';

  @override
  String get statusPrinterMissingHelp =>
      'The receipt printer is disconnected or not responding. Check USB, Bluetooth, or the LAN cable, then tap Recheck.';

  @override
  String get statusPrinterNeedsSetup => 'Printer needs setup';

  @override
  String get statusPrinterNeedsSetupHelp =>
      'This device isn’t ready for raw ESC/POS yet. Open Printer setup and choose a printable queue.';

  @override
  String get statusPrinterAttentionHelp =>
      'The printer reported a problem (paper, cover, or pause). Fix it, then recheck.';

  @override
  String get statusPrinterError => 'Printer error';

  @override
  String get statusPrinterErrorHelp =>
      'The last check failed. Confirm the printer is online, then open Printer setup if it persists.';

  @override
  String get statusPrinterUnsupported => 'No printing';

  @override
  String get statusPrinterTapSetup => 'Tap to open Printer setup';

  @override
  String get statusPrinterRecheck => 'Recheck';

  @override
  String get printerScanning => 'Scanning…';

  @override
  String get printerSelected => 'Selected';

  @override
  String printerSelectedSnack(String connection, String name) {
    return '$connection printer \"$name\" selected';
  }

  @override
  String get printerSetupTitle => 'Printer setup';

  @override
  String get printerTabBluetooth => 'Bluetooth';

  @override
  String get printerTabLan => 'LAN';

  @override
  String get printerTabUsb => 'USB / System';

  @override
  String get printerUnsupportedWeb =>
      'ESC/POS receipt printing is not available in the browser. Run the native POS app on Android, iOS, macOS, or Windows.';

  @override
  String get printerUsbHint => 'Plug in or add the printer, then refresh';

  @override
  String get printerUsbTitle => 'USB / system printers';

  @override
  String get qrAskCustomer => 'Ask the customer to scan with their UPI app';

  @override
  String get qrCancelConfirm => 'Cancel payment';

  @override
  String qrCancelMessage(String gateway) {
    return 'Stop waiting for this $gateway payment? The order stays unpaid.';
  }

  @override
  String get qrCancelTitle => 'Cancel payment?';

  @override
  String get qrGenerateFailed =>
      'Could not generate QR. Check PhonePe/Paytm settings.';

  @override
  String get qrGenerating => 'Generating secure QR…';

  @override
  String get qrHurry => 'Hurry';

  @override
  String get qrKeepWaiting => 'Keep waiting';

  @override
  String qrOrderLabel(String label) {
    return 'Order $label';
  }

  @override
  String get qrPrintSlip => 'Print slip';

  @override
  String get qrPrinting => 'Printing…';

  @override
  String get qrScanToPay => 'Scan to pay';

  @override
  String get qrSlipPrintFailed => 'Could not print QR slip';

  @override
  String get qrSlipPrinted => 'QR slip sent to printer';

  @override
  String get qrTimeLeft => 'Left';

  @override
  String get qrTimedOut => 'Payment timed out or failed';

  @override
  String get qrUnavailable => 'QR unavailable';

  @override
  String get qrWaiting => 'Waiting for payment confirmation…';

  @override
  String get reportsCategoryWise => 'Category wise';

  @override
  String get reportsCategoryWiseDesc =>
      'Quantity and sales total by menu category.';

  @override
  String get reportsItemWise => 'Item wise report';

  @override
  String get reportsItemWiseDesc =>
      'Item codes, quantities sold, and sales amount.';

  @override
  String get reportsOrderType => 'Order type';

  @override
  String get reportsOrderTypeDesc =>
      'Dine-in, takeaway, and delivery sales with order counts.';

  @override
  String reportsPrintFailed(String error) {
    return 'Could not print report: $error';
  }

  @override
  String get reportsSalesChannel => 'Sales channel';

  @override
  String get reportsSalesChannelDesc =>
      'POS, kiosk, online, and other channel totals.';

  @override
  String get reportsSalesSummary => 'Sales summary';

  @override
  String get reportsSalesSummaryDesc =>
      'Orders, items sold, average ticket, tax, tips, and discounts.';

  @override
  String get reportsSentToPrinter => 'Report sent to printer';

  @override
  String get reportsSubtitle =>
      'Print today’s sales for this branch to the thermal printer.';

  @override
  String get reportsTaxSummary => 'Tax summary';

  @override
  String get reportsTaxSummaryDesc =>
      'Collected tax by rate/name with period totals.';

  @override
  String get reportsTerminalConsolidated => 'Terminal bill consolidated';

  @override
  String get reportsTerminalConsolidatedDesc =>
      'Payment method totals with grand total for today.';

  @override
  String get reportsTitle => 'Day-end reports';

  @override
  String setupEnterUrl(String app) {
    return 'Enter your $app server URL to continue.';
  }

  @override
  String get setupStep1 => 'STEP 1 OF SETUP';

  @override
  String get shellChangeRegister => 'Change register';

  @override
  String get shellChangeLocation => 'Change location';

  @override
  String get shellClearPairing => 'Clear device pairing';

  @override
  String get shellLockShort => 'Lock';

  @override
  String get shellMenuDevice => 'Device';

  @override
  String get shellMenuRefreshed => 'Menu refreshed';

  @override
  String get shellMenuSession => 'Session';

  @override
  String get shellMore => 'More';

  @override
  String get shellMoreCustomize => 'Customize';

  @override
  String get shellMoreCustomizeHint =>
      'Uncheck options to hide them from the menu.';

  @override
  String get shellPairingCleared => 'Device pairing cleared';

  @override
  String get shellRefreshMenu => 'Refresh menu';

  @override
  String get shellSyncCompleted => 'Sync completed';

  @override
  String get shellSyncOrders => 'Sync orders';

  @override
  String get shellViewCart => 'View cart';

  @override
  String get shiftBalanced => 'Balanced';

  @override
  String get shiftByMethodSection => 'BY PAYMENT METHOD';

  @override
  String get shiftCashCounted => 'Cash counted';

  @override
  String get shiftCashDrawerSection => 'CASH DRAWER';

  @override
  String get shiftCashSales => 'Cash sales';

  @override
  String get shiftChangeGiven => 'Change given';

  @override
  String get shiftCloseNotesHint => 'Optional — e.g. variance explained';

  @override
  String get shiftCloseSubtitle =>
      'Count the drawer and confirm against expected cash';

  @override
  String get shiftClosedSnack => 'Shift closed';

  @override
  String get shiftClosing => 'Closing…';

  @override
  String get shiftCounted => 'Counted';

  @override
  String get shiftExpectedDrawer => 'Expected in drawer';

  @override
  String get shiftNoPaidSales => 'No paid sales yet';

  @override
  String get shiftNotes => 'Notes';

  @override
  String get shiftOpenNotesHint => 'Optional — e.g. counted with manager';

  @override
  String get shiftOpenRequiredTitle => 'Open shift to continue';

  @override
  String get shiftOpenSubtitle => 'Count the drawer, then start selling';

  @override
  String get shiftOpenedSnack => 'Shift opened';

  @override
  String get shiftOpening => 'Opening…';

  @override
  String get shiftOpeningFloat => 'Opening float';

  @override
  String shiftOpeningFloatFor(String branch) {
    return 'Opening float for $branch';
  }

  @override
  String get shiftOpeningFloatHelp =>
      'Cash in the drawer before the first sale';

  @override
  String get shiftOver => 'Over';

  @override
  String get shiftPaidOrderOne => '1 paid order';

  @override
  String shiftPaidOrders(int count) {
    return '$count paid orders';
  }

  @override
  String get shiftRequiredSubtitle =>
      'A shift is required before taking orders';

  @override
  String get shiftSalesSection => 'SALES THIS SHIFT';

  @override
  String get shiftShort => 'Short';

  @override
  String get shiftSummaryLoadFailed => 'Could not load shift summary.';

  @override
  String get shiftSummaryLoading => 'Loading shift summary…';

  @override
  String get shiftThisBranch => 'this branch';

  @override
  String shiftTipsOnOrders(String amount) {
    return 'Tips on orders: $amount';
  }

  @override
  String get shiftVariance => 'Variance';

  @override
  String get shortcutsAll => 'All shortcuts';

  @override
  String get shortcutsBarcodeNote =>
      '/ search  ·  F2 hold  ·  F3 pay  ·  F4 orders  ·  F6 lock';

  @override
  String get shortcutsClearCart => 'Clear cart';

  @override
  String get shortcutsClearCartDesc => 'Asks for confirmation';

  @override
  String get shortcutsClearCartKeys => '⇧ Delete / ⇧ ⌫';

  @override
  String get shortcutsFocusSearch => 'Focus search';

  @override
  String get shortcutsFocusSearchDesc => 'Type to filter the menu';

  @override
  String get shortcutsGotIt => 'Got it';

  @override
  String get shortcutsHeldOrders => 'Held orders';

  @override
  String get shortcutsHeldOrdersDesc => 'Open parked tickets';

  @override
  String get shortcutsHoldTicket => 'Hold ticket';

  @override
  String get shortcutsHoldTicketDesc => 'Park the current cart';

  @override
  String get shortcutsLockRegister => 'Lock register';

  @override
  String get shortcutsLockRegisterDesc => 'Requires a POS PIN';

  @override
  String get shortcutsLockAlt => '⌘ L / Ctrl L';

  @override
  String get shortcutsLockAltDesc => 'Same as F6';

  @override
  String get shortcutsPay => 'Pay';

  @override
  String get shortcutsPayAlt => '⇧ Enter';

  @override
  String get shortcutsPayAltDesc => 'Same as F3';

  @override
  String get shortcutsPayDesc => 'Open the payment flow';

  @override
  String get shortcutsSubtitle => 'Faster register workflow with a keyboard';

  @override
  String get shortcutsTitle => 'Keyboard shortcuts';

  @override
  String terminalCode(String code) {
    return 'Code $code';
  }

  @override
  String get terminalContinueWithout => 'Continue without terminal';

  @override
  String get terminalEmptySubtitle =>
      'Ask your manager to add POS terminals in Admin, then try again.';

  @override
  String get terminalEmptyTitle => 'No terminals yet';

  @override
  String get terminalFooterNote =>
      'This device will stay bound to the register you pick.';

  @override
  String get terminalSelectSubtitle => 'Which POS terminal is this device?';

  @override
  String terminalSelectSubtitleNamed(String branch) {
    return 'Which POS terminal is this device? ($branch)';
  }

  @override
  String get terminalSelectTitle => 'Select register';

  @override
  String timeDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String get updateAction => 'Update';

  @override
  String updateAvailableBody(String version) {
    return 'Running $version. Tap Update to download and install.';
  }

  @override
  String updateAvailableSnack(String version) {
    return 'Update available · v$version';
  }

  @override
  String updateAvailableTitle(String version) {
    return 'Update available · v$version';
  }

  @override
  String get updateCancelled => 'Cancelled';

  @override
  String get updateCheckFailed => 'Could not check for updates';

  @override
  String get updateChecking => 'Checking for updates…';

  @override
  String get updateDoneAndroid =>
      'Complete the system install prompt, then reopen this POS app.';

  @override
  String get updateDoneGeneric =>
      'Finish installing, then reopen this POS app.';

  @override
  String get updateDoneMac =>
      'Install from the opened package (DMG/app), then reopen this POS app.';

  @override
  String get updateDoneWin =>
      'Finish the installer wizard, then reopen this POS app.';

  @override
  String get updateDownload => 'Download update';

  @override
  String get updateDownloadCancelled => 'Download cancelled.';

  @override
  String updateDownloadFailed(String code) {
    return 'Download failed ($code).';
  }

  @override
  String get updateDownloading => 'Downloading update';

  @override
  String updateDownloadingPct(int pct) {
    return 'Downloading… $pct%';
  }

  @override
  String get updateFailed => 'Update failed';

  @override
  String get updateInAppUnavailable =>
      'In-app install is not available on this platform.';

  @override
  String get updateInstallerOpened => 'Installer opened';

  @override
  String get updateInstalling => 'Installing the latest POS build';

  @override
  String get updateLater => 'Later';

  @override
  String get updateNoLink =>
      'No download link is published yet. Contact your platform administrator.';

  @override
  String get updateNoLinkDevice =>
      'No download link is available for this device.';

  @override
  String get updateOpenBrowser => 'Open in browser';

  @override
  String get updateOpeningAndroid => 'Opening the Android installer…';

  @override
  String get updateOpeningGeneric => 'Opening the installer…';

  @override
  String get updateOpeningMac => 'Opening the macOS installer…';

  @override
  String get updateOpeningWin => 'Opening the Windows installer…';

  @override
  String get updatePreparing => 'Preparing download…';

  @override
  String updateRequiredBody(String current, String latest) {
    return 'This POS is on $current. Install $latest to continue.';
  }

  @override
  String get updateRequiredSnack => 'A required update is available';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String updateUpToDate(String version) {
    return 'You are up to date ($version)';
  }

  @override
  String updateVersion(String version) {
    return 'Version $version';
  }

  @override
  String get updateWorking => 'Working…';

  @override
  String get upsellAdd => 'Add';

  @override
  String get upsellSubtitle =>
      'Popular extras for this ticket. Optional — continue when ready.';

  @override
  String get upsellTitle => 'Add anything else?';

  @override
  String shiftUnpaidSuffix(String amount, int count) {
    return ' · $count unpaid ($amount)';
  }

  @override
  String payAmountWithTip(String tip, String total) {
    return '$total + $tip tip';
  }

  @override
  String get payStatusPartial => 'Partially paid';

  @override
  String get payStatusRefunded => 'Refunded';

  @override
  String get payStatusPending => 'Payment pending';

  @override
  String authStaffOrderingFooter(String app) {
    return '$app · staff ordering';
  }

  @override
  String get modePickerTitle => 'How are you working?';

  @override
  String get modePickerSubtitle =>
      'Choose register POS for the counter, or Waiter for phone floor service.';

  @override
  String get modePickerRegisterTitle => 'Register POS';

  @override
  String get modePickerRegisterSubtitle =>
      'Full cashier: payments, shifts, printers';

  @override
  String get modePickerWaiterTitle => 'Waiter / Captain';

  @override
  String get modePickerWaiterSubtitle =>
      'Tables, KOT, and bill requests on the floor';

  @override
  String get modePickerFooter => 'You can switch modes later from Profile';

  @override
  String get waiterNavTables => 'Tables';

  @override
  String get waiterNavOrders => 'Orders';

  @override
  String get waiterNavAlerts => 'Notifications';

  @override
  String get waiterNavProfile => 'Profile';

  @override
  String get waiterConnectionLive => 'Live · floor updating';

  @override
  String get waiterConnectionOffline => 'Offline · showing last floor';

  @override
  String get waiterZoneAll => 'All tables';

  @override
  String get waiterZoneOther => 'Other';

  @override
  String get waiterStatusAvailable => 'Available';

  @override
  String get waiterStatusOccupied => 'Occupied';

  @override
  String get waiterStatusBilling => 'Billing';

  @override
  String get waiterStatusReserved => 'Reserved';

  @override
  String get waiterStatusCleaning => 'Needs cleaning';

  @override
  String get waiterTableCleaningHint =>
      'This table needs cleaning before seating.';

  @override
  String waiterOpenTableTitle(String table) {
    return 'Open $table';
  }

  @override
  String get waiterOpenTableSubtitle =>
      'Set guest count, then start taking the order.';

  @override
  String get waiterGuestsLabel => 'Number of guests';

  @override
  String get waiterOpenTableConfirm => 'Open table';

  @override
  String waiterTableSeatsCount(int count) {
    return '$count seats';
  }

  @override
  String waiterGuestsCount(int count) {
    return '$count guests';
  }

  @override
  String get waiterOrderTitle => 'Order';

  @override
  String get waiterCategoryAll => 'All';

  @override
  String get waiterSendToKitchen => 'Send to Kitchen';

  @override
  String waiterAlreadySent(int count) {
    return 'Already sent · $count';
  }

  @override
  String get waiterNewItemsHint => 'Add new items below, then send to kitchen.';

  @override
  String get waiterChannelInHouse => 'In-house';

  @override
  String waiterCaptainNamed(String name) {
    return 'Captain · $name';
  }

  @override
  String get waiterBillRequestedBadge => 'Bill requested';

  @override
  String waiterKotRound(int round) {
    return 'KOT $round';
  }

  @override
  String get ordersFilterFloor => 'Floor';

  @override
  String get ordersFilterPartners => 'Delivery partners';

  @override
  String get ordersFilterZomato => 'Zomato';

  @override
  String get ordersFilterSwiggy => 'Swiggy';

  @override
  String get ordersEmptyZomato => 'No Zomato orders today.';

  @override
  String get ordersEmptySwiggy => 'No Swiggy orders today.';

  @override
  String get ordersSourceZomato => 'Zomato';

  @override
  String get ordersSourceSwiggy => 'Swiggy';

  @override
  String waiterCartBanner(int count, String subtotal) {
    return '$count items · $subtotal';
  }

  @override
  String get waiterKotSentTitle => 'Order Sent to Kitchen!';

  @override
  String get waiterKotSentSubtitle =>
      'Kitchen has the ticket — keep serving this table or open another.';

  @override
  String waiterKotSent(String number) {
    return 'KOT sent · $number';
  }

  @override
  String get waiterOrdersEmptyTitle => 'No active orders';

  @override
  String get waiterOrdersEmptySubtitle =>
      'Open a table and send items to the kitchen.';

  @override
  String get waiterOrdersSubtitle => 'Live floor tickets and KOT progress';

  @override
  String waiterOrdersSummary(int count) {
    return '$count active';
  }

  @override
  String get waiterOrdersFilterAll => 'All';

  @override
  String get waiterOrdersFilterPreparing => 'Preparing';

  @override
  String get waiterOrdersFilterReady => 'Ready to serve';

  @override
  String get waiterOrdersFilterBilling => 'Bill ready';

  @override
  String get waiterOrdersFilterMine => 'Mine';

  @override
  String get waiterOrdersSearchHint => 'Search table or ticket…';

  @override
  String get waiterOrdersNoFilterMatchesTitle => 'No orders match';

  @override
  String get waiterOrdersNoFilterMatchesSubtitle =>
      'Try another filter or clear search.';

  @override
  String waiterOrdersSummaryReady(int count) {
    return '$count ready';
  }

  @override
  String waiterOrdersSummaryBilling(int count) {
    return '$count bill ready';
  }

  @override
  String waiterOrdersSummaryMine(int count) {
    return '$count mine';
  }

  @override
  String waiterOrdersMoreItems(int count) {
    return '+$count more';
  }

  @override
  String get waiterOrdersTapToExpand => 'Tap for full ticket';

  @override
  String get waiterOrdersTapToCollapse => 'Tap to collapse';

  @override
  String waiterOrdersReadyCount(int count) {
    return '$count ready';
  }

  @override
  String waiterOrdersPrepCount(int count) {
    return '$count prep';
  }

  @override
  String waiterOrdersSentCount(int count) {
    return '$count sent';
  }

  @override
  String get waiterOrdersShowItems => 'Show items';

  @override
  String get waiterOrdersHideItems => 'Hide items';

  @override
  String waiterOrdersToken(String token) {
    return 'T$token';
  }

  @override
  String waiterItemsCount(int count) {
    return '$count items';
  }

  @override
  String get waiterPipelineSent => 'Sent';

  @override
  String get waiterPipelinePreparing => 'Prep';

  @override
  String get waiterPipelineReady => 'Ready';

  @override
  String get waiterPipelineServed => 'Served';

  @override
  String get waiterMarkServed => 'Mark served';

  @override
  String get waiterMarkServedAll => 'Mark all ready served';

  @override
  String get waiterMarkServedDone => 'Marked served';

  @override
  String waiterMarkServedDoneCount(int count) {
    return 'Marked $count ready as served';
  }

  @override
  String get waiterMarkServedNeedsOnline =>
      'Connect to the server to mark food served.';

  @override
  String get waiterRunFoodTitle => 'Run food now';

  @override
  String waiterRunFoodSubtitle(int count) {
    return '$count ready at the pass';
  }

  @override
  String get waiterRunFoodAction => 'Mark served';

  @override
  String get waiterKitchenWorkingTitle => 'Kitchen cooking';

  @override
  String waiterKitchenWorkingSubtitle(int prep, int sent) {
    return '$prep cooking · $sent in queue';
  }

  @override
  String get waiterAllServedTitle => 'Food delivered';

  @override
  String get waiterAllServedSubtitle => 'Ready when guests want the bill';

  @override
  String get waiterCardNeedsYou => 'Needs you';

  @override
  String get waiterCardWaitingKitchen => 'In kitchen';

  @override
  String get waiterCardBillPending => 'Bill out';

  @override
  String get waiterCardDelivered => 'Delivered';

  @override
  String get waiterCardItemsHeading => 'Items';

  @override
  String get waiterCardShowTicket => 'Show full ticket';

  @override
  String get waiterCardHideTicket => 'Hide ticket';

  @override
  String waiterCardMoreReady(int count) {
    return '+$count more ready';
  }

  @override
  String waiterCardAge(String age) {
    return 'Open $age';
  }

  @override
  String get waiterAddMore => 'Add more';

  @override
  String get waiterRequestBill => 'Request bill';

  @override
  String waiterBillTitle(String table) {
    return 'Bill · $table';
  }

  @override
  String get waiterBillNoTicket => 'No open ticket on this table yet';

  @override
  String get waiterBillEmptyHint =>
      'Totals appear when a ticket is linked to this table.';

  @override
  String get waiterBillDiscount => 'Discount';

  @override
  String get waiterBillTax => 'Tax';

  @override
  String get waiterBillRequestedToast => 'Checkout requested for this table';

  @override
  String get waiterBillAlreadyRequestedHint =>
      'Register already has this bill — waiting for payment.';

  @override
  String get waiterBillRequestedAlert => 'Bill requested for table';

  @override
  String waiterOrderReadyAlert(String number, String table) {
    return 'Order $number is ready$table';
  }

  @override
  String get waiterAlertsEmptyTitle => 'You\'re all caught up';

  @override
  String get waiterAlertsEmptySubtitle =>
      'Kitchen ready alerts and bill requests will show up here.';

  @override
  String get waiterNotificationsMarkAllRead => 'Mark all read';

  @override
  String get waiterNotificationsAllCaughtUp => 'No unread notifications';

  @override
  String waiterNotificationsUnread(int count) {
    return '$count unread';
  }

  @override
  String get waiterNotificationsToday => 'Today';

  @override
  String get waiterNotificationsEarlier => 'Earlier';

  @override
  String get waiterNotificationReadyTitle => 'Order ready';

  @override
  String waiterNotificationReadyBody(String number, String table) {
    return '$number is ready for pickup$table';
  }

  @override
  String get waiterNotificationBillTitle => 'Bill requested';

  @override
  String get waiterNotificationSplitBillTitle => 'Split bill requested';

  @override
  String waiterNotificationBillBody(String table) {
    return '$table is waiting for checkout';
  }

  @override
  String registerNotificationBillBody(String table) {
    return 'Captain requested checkout for $table';
  }

  @override
  String get registerNotificationNewOrderTitle => 'New order';

  @override
  String registerNotificationNewOrderBody(String number) {
    return 'Order $number received';
  }

  @override
  String marketplacePriorityTitle(String partner) {
    return 'Priority · $partner';
  }

  @override
  String marketplacePriorityBody(String number) {
    return 'Partner order $number needs attention';
  }

  @override
  String marketplacePriorityBodyWithExternal(String number, String externalId) {
    return 'Partner order $number · $externalId';
  }

  @override
  String get marketplacePriorityChip => 'Priority';

  @override
  String get newOrderAlertDescription =>
      'A fresh order just landed — here are the details.';

  @override
  String get marketplacePriorityDescription =>
      'Partner delivery order needs quick attention.';

  @override
  String get newOrderAlertTotal => 'Total';

  @override
  String get newOrderAlertPlaced => 'Placed';

  @override
  String newOrderAlertTitleOne(String number) {
    return 'New order $number';
  }

  @override
  String get newOrderAlertView => 'View order';

  @override
  String get newOrderAlertOpen => 'Open order';

  @override
  String get newOrderAlertDismiss => 'Dismiss';

  @override
  String newOrderAlertMore(int count) {
    return '+$count more';
  }

  @override
  String get newOrderAlertToken => 'Token';

  @override
  String get registerNotificationsEmptySubtitle =>
      'New guest orders and captain bill requests show up here.';

  @override
  String get waiterSwitchToRegister => 'Switch to Register POS';

  @override
  String get waiterSwitchToRegisterSubtitle =>
      'Open the full cashier experience';

  @override
  String get waiterSwitchToRegisterConfirm =>
      'Switch this device to Register POS mode?';

  @override
  String get waiterSwitchToWaiter => 'Switch to Waiter / Captain';

  @override
  String get waiterSwitchToWaiterSubtitle =>
      'Phone floor: tables, KOT, and bill requests';

  @override
  String get waiterSwitchToWaiterConfirm =>
      'Switch this device to Waiter / Captain mode?';

  @override
  String get waiterChangeMode => 'Change work mode';

  @override
  String get waiterChangeModeSubtitle => 'Pick Register or Waiter again';

  @override
  String get waiterFilterAll => 'All';

  @override
  String get waiterFilterMyTables => 'My tables';

  @override
  String get waiterFilterZones => 'Zones';

  @override
  String get waiterSearchTables => 'Search tables…';

  @override
  String get waiterBillModeFull => 'Full bill';

  @override
  String get waiterBillModeSplitItems => 'Split items';

  @override
  String get waiterBillModeSplitEqual => 'Equal split';

  @override
  String get waiterBillSplitParts => 'Ways to split';

  @override
  String get waiterBillSplitNote => 'Note for register (optional)';

  @override
  String get waiterBillSplitNoteHint => 'e.g. Guest A pays drinks';

  @override
  String get waiterBillRequestSplit => 'Request split bill';

  @override
  String get waiterBillSplitSelectItemsRequired =>
      'Select at least one item to split';

  @override
  String waiterBillSplitSelected(int count, String amount) {
    return '$count items selected · $amount';
  }

  @override
  String waiterBillSplitEqualPreview(int parts, String amount) {
    return '$parts ways · ~$amount each';
  }

  @override
  String get registerSplitBillBadge => 'Split';

  @override
  String registerSplitBillEqualHint(int parts) {
    return 'Split equally · $parts ways';
  }

  @override
  String get registerSplitBillItemsHint => 'Split selected items';

  @override
  String get collectModeFull => 'Full amount';

  @override
  String get collectModeSplit => 'Split payments';

  @override
  String get splitBillQrFullOnly => 'QR only for full remaining';

  @override
  String get splitBillTitle => 'Split / multi-pay';

  @override
  String get splitBillCollectHint =>
      'Charge the full remaining balance at once, or record multiple payments toward this bill.';

  @override
  String get splitBillPayFullRemaining => 'Pay remaining in full';

  @override
  String get splitBillOrderTotal => 'Order total';

  @override
  String get splitBillPaidSoFar => 'Paid so far';

  @override
  String get splitBillRemaining => 'Remaining';

  @override
  String get splitBillPaidCheck => 'Paid ✓';

  @override
  String get splitBillPayments => 'Payments';

  @override
  String get splitBillAddPayment => 'Add payment';

  @override
  String get splitBillAmount => 'Amount';

  @override
  String get splitBillFillRemaining => 'Full remaining';

  @override
  String get splitBillQuickHalf => '½';

  @override
  String get splitBillQuickThird => '⅓';

  @override
  String get splitBillNoteOptional => 'Note (optional)';

  @override
  String get splitBillNoteHint => 'e.g. Guest 2 · Card';

  @override
  String splitBillRecordPayment(String method) {
    return 'Record $method payment';
  }

  @override
  String get splitBillRecording => 'Recording…';

  @override
  String splitBillPaymentRecorded(String amount) {
    return 'Recorded $amount';
  }

  @override
  String get splitBillFullyPaid => 'Order fully paid';

  @override
  String get splitBillInvalidAmount => 'Enter a valid amount';

  @override
  String get splitBillAmountExceeds => 'Amount exceeds remaining balance';

  @override
  String get splitBillLoadFailed => 'Couldn’t load payments';

  @override
  String waiterTablesSummary(int total) {
    return '$total tables';
  }

  @override
  String waiterTablesShowing(int count) {
    return 'Showing $count';
  }

  @override
  String get waiterClearFilters => 'Clear filters';

  @override
  String get waiterNoFilterMatchesTitle => 'No tables match';

  @override
  String get waiterNoFilterMatchesSubtitle =>
      'Try another status, zone, or search.';

  @override
  String get waiterActionSeat => 'Tap to seat';

  @override
  String get waiterActionOrder => 'Tap to order';

  @override
  String get waiterActionBill => 'Tap for bill';

  @override
  String get waiterActionClean => 'Needs clean';

  @override
  String get waiterOpenTicketBadge => 'Ticket';

  @override
  String get waiterNoOrderBadge => 'No order';

  @override
  String get waiterTableActionStartOrder => 'Start order';

  @override
  String get waiterTableActionStartOrderHint =>
      'Open the menu and send items to kitchen.';

  @override
  String get waiterTableActionAddMoreHint =>
      'Add new items to this table’s ticket.';

  @override
  String get waiterTableActionViewBill => 'View bill';

  @override
  String get waiterTableActionViewBillHint =>
      'See totals and hand off to register.';

  @override
  String get waiterTableActionRequestBillHint =>
      'Ask register to collect payment.';

  @override
  String get waiterTableActionClearBill => 'Cancel bill request';

  @override
  String get waiterTableActionClearBillHint => 'Guests want to keep ordering.';

  @override
  String get waiterTableActionClearBillDone => 'Bill request cleared';

  @override
  String get waiterTableActionMarkCleaning => 'Needs cleaning';

  @override
  String get waiterTableActionMarkCleaningHint =>
      'Guests have left — clear the table before the next party.';

  @override
  String get waiterTableActionMarkAvailable => 'Mark as available';

  @override
  String get waiterTableActionMarkAvailableHint => 'Ready for the next guests.';

  @override
  String get waiterTableActionFreeTable => 'Free table';

  @override
  String get waiterTableActionFreeTableHint =>
      'Guests left without an order — open this table again.';

  @override
  String get waiterTableActionCancelReservation => 'Cancel reservation';

  @override
  String get waiterTableActionCancelReservationHint =>
      'Release this hold so others can be seated.';

  @override
  String get waiterTableActionReserve => 'Reserve table';

  @override
  String get waiterTableActionReserveHint =>
      'Hold this table for an upcoming party.';

  @override
  String get waiterTableActionMarkedReserved => 'Table reserved';

  @override
  String get waiterTableActionSeatGuests => 'Seat guests';

  @override
  String get waiterTableActionSeatGuestsHint =>
      'Set party size and start their visit.';

  @override
  String get waiterTableActionReadyToSeat => 'Ready to seat';

  @override
  String get waiterTableActionReadyToSeatHint =>
      'Cleaning done — open for the next party.';

  @override
  String get waiterTableActionMarkedCleaning => 'Table marked as cleaning';

  @override
  String get waiterTableActionMarkedAvailable => 'Table is available';

  @override
  String get waiterTableActionsMore => 'More actions';

  @override
  String get waiterTableStatusHintAvailable =>
      'Open — start an order, reserve, or mark cleaning.';

  @override
  String get waiterTableStatusHintOccupied =>
      'Guests are dining — add items or request the bill.';

  @override
  String get waiterTableStatusHintOccupiedEmpty =>
      'Seated with no ticket yet — start an order or free the table.';

  @override
  String get waiterTableStatusHintBilling =>
      'Bill requested — show totals or clear the request if they keep ordering.';

  @override
  String get waiterTableStatusHintBillingDone =>
      'Ticket closed — mark cleaning or free the table.';

  @override
  String get waiterTableStatusHintReserved =>
      'Held for a reservation — start an order or cancel the hold.';

  @override
  String get waiterTableStatusHintCleaning =>
      'Being reset — mark available when the table is ready.';
}
