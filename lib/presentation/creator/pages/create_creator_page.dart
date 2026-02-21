import 'package:chuchu/core/relayGroups/relayGroup+member.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart' show GoogleFonts;
import '../../../../core/widgets/common_toast.dart';
import '../../../core/account/account.dart';
import '../../../core/config/config.dart';
import '../../../core/config/subscription_config.dart';
import '../../../core/relayGroups/model/relayGroupDB_isar.dart';
import '../../../core/relayGroups/relayGroup.dart';
import '../../../core/wallet/wallet.dart';
import '../../../core/widgets/chuchu_Loading.dart';
import '../../../core/utils/ui_refresh_mixin.dart';
import '../../../core/theme/app_theme.dart';
import '../../drawerMenu/subscription/widgets/subscription_settings_section.dart';

class CreateCreatorPage extends StatefulWidget {
  const CreateCreatorPage({super.key});

  @override
  State<CreateCreatorPage> createState() => CreateCreatorPageState();
}

class CreateCreatorPageState extends State<CreateCreatorPage>
    with ChuChuUIRefreshMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();

  bool _isPaidSubscription = true;
  int subscriptionPrice = SubscriptionConfig.defaultSubscriptionPrice;

  @override
  Widget buildBody(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            width: 40,
            height: 40,
            child: Icon(Icons.close, size: 20, color: kTitleColor),
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          'Create Poster',
          style: GoogleFonts.inter(
            color: kTitleColor,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            FocusScope.of(context).requestFocus(FocusNode());
          },
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Poster Name',
                        style: GoogleFonts.inter(
                          color: kTitleColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withAlpha(50),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _nameController,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: kTitleColor,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter your Poster name',
                            hintStyle: GoogleFonts.inter(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Introduction',
                        style: GoogleFonts.inter(
                          color: kTitleColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withAlpha(50),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _aboutController,
                          maxLines: 4,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: kTitleColor,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Tell us about your content...',
                            hintStyle: GoogleFonts.inter(
                              color:
                              Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isPaidSubscription
                                      ? 'Premium Subscription'
                                      : 'Free Subscription',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: kTitleColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isPaidSubscription
                                      ? 'Earn sats from your subscribers'
                                      : 'Users can access your content for free',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color:
                                        Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              padding: EdgeInsets.zero,
                              value: _isPaidSubscription,
                              onChanged: (value) {
                                setState(() {
                                  _isPaidSubscription = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_isPaidSubscription)
                        SubscriptionSettingsSection(
                          onPriceChanged: (monthlyPrice) {
                            subscriptionPrice = monthlyPrice;
                          },
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: getBrandGradientHorizontal(),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            onPressed: _createSettings,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Create Poster',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createSettings() async {
    try {
      if (_isPaidSubscription) {
        // Validate price: must be a positive integer
        if (subscriptionPrice <= 0) {
          CommonToast.instance.show(context, 'Please enter a valid price greater than 0',toastType:ToastType.failed);
          return;
        }
      }

      ChuChuLoading.show();
      // Get wallet instance
      final wallet = Wallet();

      // Ensure wallet is connected
      if (!wallet.isConnected) {
        await wallet.connectToWallet();
      }

      if (!wallet.isConnected) {
        CommonToast.instance.show(
          context,
          'Wallet not connected. Please try again.',
            toastType:ToastType.failed
        );
        ChuChuLoading.dismiss();

        return;
      }

      if (wallet.walletInfo?.walletId == null) {
        CommonToast.instance.show(context, 'Wallet id is not fund.',toastType:ToastType.failed);
        ChuChuLoading.dismiss();

        return;
      }

      // Create new subscription
      RelayGroupDBISAR? relayGroupDB = await RelayGroup.sharedInstance
          .createGroup(
            Config.sharedInstance.recommendGroupRelayOrDefault,
            Account.sharedInstance.currentPubkey,
            about: _aboutController.text,
            closed: _isPaidSubscription,
            name: _nameController.text.isNotEmpty ? _nameController.text : '',
            subscriptionAmount: _isPaidSubscription ? subscriptionPrice : 0,
            groupWalletId: wallet.walletInfo?.walletId ?? '',
          );
      //
      print('=====>relayGroupDB==$relayGroupDB');
      if (relayGroupDB != null) {
        CommonToast.instance.show(context, 'Create Successfully !',toastType:ToastType.success);
        ChuChuLoading.dismiss();

        Navigator.of(context).pop(true);
      }
    } catch (e) {
      CommonToast.instance.show(
        context,
        'Error creating subscription: ${e.toString()}',
          toastType:ToastType.failed
      );
      ChuChuLoading.dismiss();
    }
  }
}
