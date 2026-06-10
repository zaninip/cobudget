import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adatta uno [Stream] a [Listenable], per usarlo come
/// `refreshListenable` di [GoRouter] (es. cambi di stato auth).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
