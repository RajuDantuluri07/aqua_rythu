import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/pricing_config.dart';

class PaymentService {
  final Razorpay _razorpay = Razorpay();

  void init({
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onError,
    required Function(ExternalWalletResponse) onExternalWallet,
  }) {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, onExternalWallet);
  }

  void startPayment() {
    var options = {
      'key':
          'rzp_live_SjmCT6Guwd0aZR', // TODO: Replace with actual Razorpay key
      'amount': PricingConfig.cropPrice,
      'name': 'AquaRythu',
      'description': 'Smart Crop Plan',
      'prefill': {
        'contact': '',
        'email': '',
      }
    };

    _razorpay.open(options);
  }

  void dispose() {
    _razorpay.clear();
  }
}
