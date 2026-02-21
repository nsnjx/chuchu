import 'dart:async';
import 'package:chuchu/core/account/account.dart';
import 'package:chuchu/core/relayGroups/relayGroup+member.dart';
import 'package:flutter/material.dart';
import '../../../../core/config/config.dart';
import '../../../../core/relayGroups/model/relayGroupDB_isar.dart';
import '../../../../core/relayGroups/relayGroup.dart';
import '../../../../core/widgets/common_toast.dart';
import '../../../../core/wallet/wallet.dart';
import '../widgets/subscription_payment_dialog.dart';

class SubscriptionTier {
  final String name;
  final String duration;
  final int price;
  final bool isDefault;

  SubscriptionTier({
    required this.name,
    required this.duration,
    required this.price,
    required this.isDefault,
  });

  String get formattedPrice => '\$${(price / 100).toStringAsFixed(2)}';
  String get priceText => '$formattedPrice per $duration';
}

class SubscriptionSettingsPage extends StatefulWidget {
  const SubscriptionSettingsPage({super.key});

  @override
  State<SubscriptionSettingsPage> createState() => _SubscriptionSettingsPageState();
}

class _SubscriptionSettingsPageState extends State<SubscriptionSettingsPage> {
  final TextEditingController _priceController = TextEditingController();

  bool _isPaidSubscription = true;
  final Map<String, String> _customPrices = {};

  String _subscriptionRelay = Config.sharedInstance.recommendGroupRelayOrDefault;
  
  final List<SubscriptionTier> _subscriptionTiers = [
    SubscriptionTier(
      name: 'Monthly',
      duration: 'month',
      price: 999,
      isDefault: true,
    ),
    SubscriptionTier(
      name: '3 Months',
      duration: '3 months',
      price: 2499,
      isDefault: false,
    ),
    SubscriptionTier(
      name: '6 Months',
      duration: '6 months',
      price: 4499,
      isDefault: false,
    ),
    SubscriptionTier(
      name: '12 Months',
      duration: 'year',
      price: 7999,
      isDefault: false,
    ),
  ];
  
  SubscriptionTier? _selectedTier;

  @override
  void initState() {
    super.initState();
    _selectedTier = _subscriptionTiers.firstWhere((tier) => tier.isDefault);
    _priceController.text = (_selectedTier!.price / 100).toStringAsFixed(2);
    init();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  bool _hasExistingGroup = false;
  
  void init(){
    Map<String, ValueNotifier<RelayGroupDBISAR>>? groups = RelayGroup.sharedInstance.myGroups;
    if(groups[Account.sharedInstance.currentPubkey] != null){
      _hasExistingGroup = true;
    }
  }

  Future<void> _createSettings() async {
    if (_isPaidSubscription && _priceController.text.isEmpty) {
      CommonToast.instance.show(context, 'Please set a subscription price', toastType:ToastType.failed);
      return;
    }

    try {
      double price = 0.0;
      String priceText = 'Free';
      
      if (_isPaidSubscription) {
        String cleanPriceText = _priceController.text.replaceAll(RegExp(r'[^\d.]'), '');
        if (cleanPriceText.isEmpty) {
          CommonToast.instance.show(context, 'Please enter a valid price',toastType:ToastType.failed);
          return;
        }
        
        price = double.parse(cleanPriceText);
        priceText = '\$${price.toStringAsFixed(2)}';
      }
      
      if (_hasExistingGroup) {
        // Update existing subscription settings
        int months = _getSelectedMonths();
        await _updateSubscriptionSettings(months);
      } else {
        // Create new subscription
        RelayGroupDBISAR? relayGroupDB = await RelayGroup.sharedInstance.createGroup(
          _subscriptionRelay,
          Account.sharedInstance.currentPubkey,
          about: _isPaidSubscription 
              ? 'Premium content subscription - $priceText per ${_selectedTier?.duration ?? 'month'}'
              : 'Free subscription content',
          closed: _isPaidSubscription,
        );

        if(relayGroupDB != null){
          // If it's a paid subscription, create subscription invoice
          if (_isPaidSubscription) {
            int months = _getSelectedMonths();
            await _createSubscriptionInvoice(relayGroupDB.id.toString(), months);
          }
          
          String message = _isPaidSubscription 
              ? 'Premium subscription created successfully at $priceText'
              : 'Free subscription created successfully';
          CommonToast.instance.show(context, message,toastType:ToastType.success);
          Navigator.pop(context);
        } else {
          CommonToast.instance.show(context, 'Failed to create subscription',toastType:ToastType.failed);
        }
      }
    } catch (e) {
      CommonToast.instance.show(context, 'Error ${_hasExistingGroup ? 'updating' : 'creating'} subscription: ${e.toString()}',toastType:ToastType.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Subscription'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor.withAlpha(60)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isPaidSubscription ? 'Premium Subscription' : 'Free Subscription',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isPaidSubscription 
                                      ? 'Users pay to access your content'
                                      : 'Users can access your content for free',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: _isPaidSubscription,
                              onChanged: (value) {
                                setState(() {
                                  _isPaidSubscription = value;
                                  if (_isPaidSubscription) {
                                    _selectedTier = _subscriptionTiers.firstWhere((tier) => tier.isDefault);
                                    if (_priceController.text.isEmpty) {
                                      _priceController.text = (_selectedTier!.price / 100).toStringAsFixed(2);
                                    }
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      if (_isPaidSubscription) ...[
                        Text(
                          'Set Subscription Price',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        Text(
                          'Subscription Duration',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        for (int i = 0; i < _subscriptionTiers.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildDurationOption(_subscriptionTiers[i]),
                          ),
                        
                        const SizedBox(height: 16),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Custom Price (USD)',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  if (_selectedTier != null) {
                                    String suggestedPrice = (_selectedTier!.price / 100).toStringAsFixed(2);
                                    _priceController.text = suggestedPrice;
                                    _customPrices[_selectedTier!.name] = suggestedPrice;
                                  }
                                });
                              },
                              child: Text(
                                'Use Suggested: \$${((_selectedTier?.price ?? 999) / 100).toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            setState(() {
                              if (_selectedTier != null) {
                                _customPrices[_selectedTier!.name] = value;
                              }
                            });
                          },
                          decoration: InputDecoration(
                            prefixText: '\$ ',
                            hintText: '0.00',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).dividerColor.withAlpha(60)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Free Subscription',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Users can access your content without payment',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Text(
                      //   'What subscribers get:',
                      //   style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      //     fontWeight: FontWeight.bold,
                      //   ),
                      // ),
                      // const SizedBox(height: 16),
                      //
                      // _buildBenefitItem('Exclusive content access'),
                      // _buildBenefitItem('Direct messaging with you'),
                      // _buildBenefitItem('Early access to new posts'),
                      // _buildBenefitItem('Cancel anytime'),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _createSettings,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _hasExistingGroup ? 'Update Subscription' : 'Create Subscription',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationOption(SubscriptionTier tier) {
    final isSelected = _selectedTier == tier;
    
    String displayPrice;
    if (_customPrices.containsKey(tier.name) && _customPrices[tier.name]!.isNotEmpty) {
      String customPrice = _customPrices[tier.name]!.replaceAll(RegExp(r'[^\d.]'), '');
      if (customPrice.isNotEmpty) {
        try {
          double price = double.parse(customPrice);
          displayPrice = '\$${price.toStringAsFixed(2)} per ${tier.duration}';
        } catch (e) {
          displayPrice = tier.priceText;
        }
      } else {
        displayPrice = tier.priceText;
      }
    } else {
      displayPrice = tier.priceText;
    }
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTier = tier;
          if (_customPrices.containsKey(tier.name)) {
            _priceController.text = _customPrices[tier.name]!;
          } else {
            _priceController.text = (tier.price / 100).toStringAsFixed(2);
          }
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              tier.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected 
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              displayPrice,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected 
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Create subscription invoice using NIP-47
  Future<void> _createSubscriptionInvoice(String groupId, int months) async {
    try {
      // Get wallet instance
      final wallet = Wallet();
      
      // Ensure wallet is connected
      if (!wallet.isConnected) {
        await wallet.connectToWallet();
      }
      
      if (!wallet.isConnected) {
        CommonToast.instance.show(context, 'Wallet not connected. Please try again.',toastType:ToastType.failed);
        return;
      }

      // Use the months parameter passed to the method

      // Get relay pubkey (using the subscription relay)
      final relayPubkey = _getRelayPubkey();
      
      // Create subscription invoice
      final result = await wallet.makeSubscriptionInvoice(
        groupId: groupId,
        month: months,
        relayPubkey: relayPubkey,
      );

      if (result != null && !result.containsKey('error')) {
        // Successfully created subscription invoice
        final bolt11 = result['invoice'] as String?;  // NIP-47 uses 'invoice' field
        final amount = result['amount'] as int?;
        final paymentHash = result['payment_hash'] as String?;
        final expiresAt = result['expires_at'] as int?;
        
        if (bolt11 != null && amount != null) {
          // Set up payment status callback
          wallet.onPaymentStatusChanged = (paymentHash, isPaid, details) {
            if (isPaid) {
              CommonToast.instance.show(context, 'Payment completed successfully!',toastType:ToastType.success);
              // Handle payment success - update UI, etc.
              _handlePaymentSuccess(groupId, months);
            }
          };
          
          // Show payment dialog
          if (mounted) {
            SubscriptionPaymentDialog.show(
              context: context,
              invoice: paymentHash ?? '',
              bolt11: bolt11,
              amount: amount,
              description: 'Subscription for $months month(s)',
              expiresAt: expiresAt != null 
                  ? DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
                  : DateTime.now().add(const Duration(minutes: 15)),
              onPaymentSuccess: () {
                Navigator.of(context).pop();
                _handlePaymentSuccess(groupId, months);
              },
            );
          }
        } else {
          CommonToast.instance.show(context, 'Invalid invoice data received',toastType:ToastType.failed);
        }
      } else {
        final errorMessage = result?['message'] ?? 'Failed to create subscription invoice';
        CommonToast.instance.show(context, errorMessage,toastType:ToastType.failed);
      }
    } catch (e) {
      print('Error creating subscription invoice: $e');
      CommonToast.instance.show(context, 'Error creating subscription invoice: ${e.toString()}',toastType:ToastType.failed);
    }
  }


  /// Update existing subscription settings
  Future<void> _updateSubscriptionSettings(int months) async {
    try {
      // Get the current group ID (assuming we have access to it)
      // In a real implementation, you would get this from the current subscription
      String groupId = _getCurrentGroupId();
      
      if (groupId.isEmpty) {
        CommonToast.instance.show(context, 'No active subscription found',toastType:ToastType.failed);
        return;
      }

      // If it's a paid subscription, create a new subscription invoice
      if (_isPaidSubscription) {
        await _createSubscriptionInvoice(groupId, months);
      } else {
        // For free subscription updates, just show success message
        String message = 'Subscription settings updated to free';
        CommonToast.instance.show(context, message,toastType:ToastType.info);
        Navigator.pop(context);
      }
    } catch (e) {
      CommonToast.instance.show(context, 'Error updating subscription: ${e.toString()}',toastType:ToastType.failed);
    }
  }

  /// Get selected months based on the current subscription tier
  int _getSelectedMonths() {
    if (_selectedTier != null) {
      if (_selectedTier!.duration.contains('3')) {
        return 3;
      } else if (_selectedTier!.duration.contains('6')) {
        return 6;
      } else if (_selectedTier!.duration.contains('12')) {
        return 12;
      }
    }
    return 1; // Default to 1 month
  }


  /// Get current group ID for the active subscription
  String _getCurrentGroupId() {
    // In a real implementation, you would get this from the current subscription state
    // For now, return a placeholder or get it from the UI state
    return 'current_group_id'; // This should be replaced with actual group ID
  }


  /// Handle successful payment
  void _handlePaymentSuccess(String groupId, int months) {
    // TODO: Update subscription status in database
    // TODO: Refresh UI to show active subscription
    print('Payment successful for group $groupId, months: $months');
    CommonToast.instance.show(context, 'Subscription payment successful!',toastType:ToastType.success);
  }

  /// Get relay pubkey for the selected subscription relay
  String _getRelayPubkey() {
    // For now, return a default relay pubkey
    // In a real implementation, you would get this from the relay configuration
    // Note: NIP-4 encryption expects pubkey without the '02' or '03' prefix
    return 'fb691ef0b4d12a0a650782936c401e3fed024f770cb21f32edd3c6429ed39e96';
  }
}
