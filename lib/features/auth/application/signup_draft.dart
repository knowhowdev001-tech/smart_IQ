import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The name entered on the signup screen, held until the profile is created.
///
/// Signup collects the name, then OTP verification sits between that and
/// profile creation. Without somewhere to keep it, the profile screen has to
/// ask for the name a second time, which is exactly the kind of duplicated
/// field PRD 6.2 warns costs sign-ups.
///
/// Null when the user reached profile creation some other way — a first-time
/// number entered on the login screen, for instance — in which case the
/// profile screen still has to ask.
final signupNameProvider = StateProvider<String?>((ref) => null);
