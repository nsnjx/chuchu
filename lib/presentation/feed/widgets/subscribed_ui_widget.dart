import 'package:chuchu/core/relayGroups/model/relayGroupDB_isar.dart';
import 'package:chuchu/core/utils/widget_tool_utils.dart';
import 'package:chuchu/core/config/subscription_config.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart' show GoogleFonts;

import '../../../core/wallet/wallet.dart';
import '../../../core/widgets/common_toast.dart';
import '../../../core/account/account.dart';
import '../../../core/config/config.dart';
import '../../../core/relayGroups/relayGroup.dart';
import '../../../core/utils/log_utils.dart';
import '../../../core/relayGroups/relayGroup+info.dart';
import '../../../core/theme/app_theme.dart';
import '../../drawerMenu/subscription/widgets/subscription_payment_dialog.dart';

enum ESubscriptionStatus {
  unsubscribed('unsubscribed'),
  subscribed('subscribed'),
  free('free'),
  author('author');

  const ESubscriptionStatus(this.value);
  final String value;
}

class SubscribedOptionWidget extends StatefulWidget {
  final RelayGroupDBISAR relayGroup;
  final ESubscriptionStatus subscriptionStatus;
  final VoidCallback?
  onSubscriptionSuccess; // Callback for subscription success

  const SubscribedOptionWidget({
    super.key,
    required this.relayGroup,
    required this.subscriptionStatus,
    this.onSubscriptionSuccess,
  });

  @override
  State<SubscribedOptionWidget> createState() => SubscribedOptionWidgetState();
}

class SubscribedOptionWidgetState extends State<SubscribedOptionWidget> {
  bool _isBundlesExpanded = false;
  bool _isCreatingInvoice = false;
  String? _loadingButtonId; // Track which button is loading

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        _buildSubscriptionSection(context),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSubscriptionSection(BuildContext context) {
    int monthlyPrice = widget.relayGroup.subscriptionAmount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUBSCRIPTION',
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _buildSubscriptionButton(context, monthlyPrice),
          const SizedBox(height: 8),
          _buildSubscriptionInfo(context, monthlyPrice),
          if (widget.subscriptionStatus ==
              ESubscriptionStatus.unsubscribed) ...[
            const SizedBox(height: 8),
            _buildSubscriptionBundles(context, monthlyPrice),
          ],
        ],
      ),
    );
  }

  /// Build subscription button based on status
  Widget _buildSubscriptionButton(BuildContext context, int monthlyPrice) {
    final theme = Theme.of(context);
    switch (widget.subscriptionStatus) {
      case ESubscriptionStatus.unsubscribed:
        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color:
                _isCreatingInvoice
                    ? Colors.grey
                    : Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap:
                  _isCreatingInvoice
                      ? null
                      : () async {
                        await _updateSubscriptionSettings(
                          1,
                          buttonId: 'monthly',
                        );
                      },
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_isCreatingInvoice && _loadingButtonId == 'monthly') ...[
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Creating Invoice...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'SUBSCRIBE',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$monthlyPrice ${SubscriptionConfig.currencyUnit} per month',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ).setPadding(EdgeInsets.symmetric(horizontal: 16.0)),
            ),
          ),
        );
      case ESubscriptionStatus.subscribed:
        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SUBSCRIBED',
                  style: GoogleFonts.inter(
                    color: kTitleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$monthlyPrice ${SubscriptionConfig.currencyUnit} per month',
                  style: GoogleFonts.inter(
                    color: kTitleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ).setPadding(EdgeInsets.symmetric(horizontal: 16.0)),
          ),
        );
      case ESubscriptionStatus.free:
        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Material(
            color: Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SUBSCRIBE',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'FOR FREE',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ).setPadding(EdgeInsets.symmetric(horizontal: 16.0)),
          ),
        );
      case ESubscriptionStatus.author:
        return const SizedBox();
    }
  }

  Widget _buildSubscriptionInfo(BuildContext context, int monthlyPrice) {
    final theme = Theme.of(context);
    switch (widget.subscriptionStatus) {
      case ESubscriptionStatus.unsubscribed:
        return Row(
          children: [
            Text(
              'Renews for $monthlyPrice ${SubscriptionConfig.currencyUnit} / month',
              style: GoogleFonts.inter(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Text(
              _getNextMonthDate(),
              style: GoogleFonts.inter(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        );
      case ESubscriptionStatus.subscribed:
        return Row(
          children: [
            Text(
              'Renews for $monthlyPrice ${SubscriptionConfig.currencyUnit} / month',
              style: GoogleFonts.inter(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Text(
              _getNextMonthDate(),
              style: GoogleFonts.inter(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        );
      case ESubscriptionStatus.free:
        return const SizedBox();
      case ESubscriptionStatus.author:
        return const SizedBox();
    }
  }

  Widget _buildSubscriptionBundles(BuildContext context, int monthlyPrice) {
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            setState(() {
              _isBundlesExpanded = !_isBundlesExpanded;
            });
          },
          child: Row(
            children: [
              Text(
                'SUBSCRIPTION BUNDLES',
                style: GoogleFonts.inter(
                  color: kTitleColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Icon(
                _isBundlesExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_up,
                color: Colors.grey[600],
                size: 24,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_isBundlesExpanded) ...[
          ...SubscriptionConfig.availableDurations
              .where((duration) => duration != SubscriptionDuration.month)
              .map((duration) {
                final discountPercent =
                    SubscriptionConfig.getDiscountPercentage(duration);
                final totalPrice = SubscriptionConfig.calculatePriceForDuration(
                  monthlyPrice,
                  duration,
                );
                final displayName = _getDurationDisplayName(duration);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildBundleButton(
                    title:
                        '${displayName.toUpperCase()} ($discountPercent% off)',
                    price:
                        '$totalPrice ${SubscriptionConfig.currencyUnit} total',
                    buttonId: duration.name, // Use duration name as button ID
                    onTap: () async {
                      int? moths =
                          SubscriptionConfig.durationMultipliers[duration];
                      if (moths != null) {
                        await _updateSubscriptionSettings(
                          moths,
                          buttonId: duration.name,
                        );
                      }
                    },
                  ),
                );
              }),
        ],
      ],
    );
  }

  Widget _buildBundleButton({
    required String title,
    required String price,
    required String buttonId,
    required VoidCallback onTap,
  }) {
    final isThisButtonLoading =
        _isCreatingInvoice && _loadingButtonId == buttonId;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: _isCreatingInvoice ? Colors.grey : Theme.of(context).colorScheme.tertiary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isCreatingInvoice ? null : onTap,
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child:
                      isThisButtonLoading
                          ? Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Creating Invoice...',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                          : Text(
                            title,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
              if (!_isCreatingInvoice)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    price,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDurationDisplayName(SubscriptionDuration duration) {
    switch (duration) {
      case SubscriptionDuration.month:
        return 'Monthly';
      case SubscriptionDuration.threeMonths:
        return '3 Months';
      case SubscriptionDuration.sixMonths:
        return '6 Months';
      case SubscriptionDuration.year:
        return '12 Months';
    }
  }

  String _getNextMonthDate() {
    // Get current user's pubkey
    final currentPubkey = Account.sharedInstance.currentPubkey;

    // Get subscription expiry from memberSubscriptionExpiry
    final memberSubscriptionExpiry = widget.relayGroup.memberSubscriptionExpiry;

    if (memberSubscriptionExpiry != null &&
        memberSubscriptionExpiry.containsKey(currentPubkey)) {
      // Get timestamp for current user
      final timestamp = memberSubscriptionExpiry[currentPubkey];

      if (timestamp != null) {
        // Convert timestamp to DateTime
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(
          timestamp * 1000,
        );

        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];

        return '${months[expiryDate.month - 1]} ${expiryDate.day}, ${expiryDate.year}';
      }
    }

    // Fallback to next month calculation if no expiry data found
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, now.day);

    final adjustedNextMonth = DateTime(
      nextMonth.year + (nextMonth.month > 12 ? 1 : 0),
      nextMonth.month > 12 ? nextMonth.month - 12 : nextMonth.month,
      nextMonth.day,
    );

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[adjustedNextMonth.month - 1]} ${adjustedNextMonth.day}, ${adjustedNextMonth.year}';
  }

  Future<void> _updateSubscriptionSettings(
    int months, {
    String? buttonId,
  }) async {
    try {
      String groupId = widget.relayGroup.groupId;

      if (groupId.isEmpty) {
        CommonToast.instance.show(context, 'No active subscription found',toastType:ToastType.failed);
        return;
      }

      setState(() {
        _isCreatingInvoice = true;
        _loadingButtonId = buttonId;
      });

      await _createSubscriptionInvoice(groupId, months);
    } catch (e) {
      CommonToast.instance.show(
        context,
        'Error updating subscription: ${e.toString()}',
          toastType:ToastType.failed
      );
    } finally {
      // Clear loading state
      if (mounted) {
        setState(() {
          _isCreatingInvoice = false;
          _loadingButtonId = null;
        });
      }
    }
  }

  Future<void> _createSubscriptionInvoice(String groupId, int months) async {

    // return      SubscriptionPaymentDialog.show(
    //   context: context,
    //   invoice: '123' ?? '',
    //   bolt11: '123123123',
    //   amount: 1232,
    //   description: 'Subscription for $months month(s)',
    //   expiresAt:DateTime.now().add(const Duration(minutes: 15)),
    //   onPaymentSuccess: () {
    //     _handlePaymentSuccess(groupId, months);
    //   },
    // );
    try {
      final wallet = Wallet();

      if (!wallet.isConnected) {
        await wallet.connectToWallet();
      }

      if (!wallet.isConnected) {
        CommonToast.instance.show(
          context,
          'Wallet not connected. Please try again.',
            toastType:ToastType.failed
        );
        return;
      }

      final relayPubkey = SubscriptionConfig.relayPubkey;

      final result = await wallet.makeSubscriptionInvoice(
        groupId: groupId,
        month: months,
        relayPubkey: relayPubkey,
      );

      if (result != null && !result.containsKey('error')) {
        final bolt11 =
            result['invoice'] as String?; // NIP-47 uses 'invoice' field
        final amount = result['amount'] as int?;
        final paymentHash = result['payment_hash'] as String?;
        final expiresAt = result['expires_at'] as int?;

        if (bolt11 != null && amount != null) {
          // Show payment dialog
          if (mounted) {
            // Clear loading state before showing dialog
            setState(() {
              _isCreatingInvoice = false;
            });

            SubscriptionPaymentDialog.show(
              context: context,
              invoice: paymentHash ?? '',
              bolt11: bolt11,
              amount: amount,
              description: 'Subscription for $months month(s)',
              expiresAt:
                  expiresAt != null
                      ? DateTime.fromMillisecondsSinceEpoch(
                        expiresAt * 1000,
                      )
                      : DateTime.now().add(const Duration(minutes: 15)),
              onPaymentSuccess: () {
                _handlePaymentSuccess(groupId, months);
              },
            );
          }
        } else {
          CommonToast.instance.show(context, 'Invalid invoice data received', toastType:ToastType.failed);
        }
      } else {
        final errorMessage =
            result?['message'] ?? 'Failed to create subscription invoice';
        CommonToast.instance.show(context, errorMessage,toastType:ToastType.failed);
      }
    } catch (e) {
      LogUtils.w(() => 'SubscribedUI: Error creating subscription invoice: $e');
      CommonToast.instance.show(
        context,
        'Error creating subscription invoice: ${e.toString()}',
          toastType:ToastType.failed
      );
    }
  }

  /// Handle successful payment
  void _handlePaymentSuccess(String groupId, int months) async {
    try {
      LogUtils.d(() => 'SubscribedUI: Payment successful groupId=$groupId months=$months');

      // Sync my groups from relays to get the latest data
      await _syncMyGroupsFromRelays();

      CommonToast.instance.show(context, 'Subscription payment successful!',toastType:ToastType.success);

      if (widget.onSubscriptionSuccess != null) {
        widget.onSubscriptionSuccess!();
      }

      Navigator.pop(context);
    } catch (e) {
      LogUtils.w(() => 'SubscribedUI: Error handling payment success: $e');
      CommonToast.instance.show(
        context,
        'Payment successful but failed to sync groups',
          toastType:ToastType.failed
      );
      Navigator.pop(context);
    }
  }

  /// Sync my groups from relays
  Future<void> _syncMyGroupsFromRelays() async {
    try {
      // Get the recommend group relays
      final relays = Config.sharedInstance.recommendGroupRelays;

      if (relays.isNotEmpty) {
        // Call searchMyGroupsMetadataFromRelays to sync my groups
        // This method will automatically sync myGroups
        final groups = await RelayGroup.sharedInstance
            .searchMyGroupsMetadataFromRelays(relays, (groups) {
              LogUtils.d(() => 'SubscribedUI: Synced ${groups.length} groups from relays');
            });
        LogUtils.d(() => 'SubscribedUI: Successfully synced ${groups.length} groups from relays');
      }
    } catch (e) {
      LogUtils.w(() => 'SubscribedUI: Error syncing my groups from relays: $e');
      rethrow;
    }
  }
}
