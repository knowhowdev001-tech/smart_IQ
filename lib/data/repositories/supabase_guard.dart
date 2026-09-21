import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'repositories.dart';

/// Maps transport and auth failures from PostgREST onto the exceptions the
/// screens already branch on, so no screen has to know Supabase is there.
Future<T> supabaseGuard<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on SocketException {
    throw const OfflineException();
  } on PostgrestException catch (error) {
    // 42501 is what the RPCs raise when there is no `sub` claim, which
    // means the token expired or was never there.
    if (error.code == '42501' || error.code == 'PGRST301') {
      throw const UnauthenticatedException();
    }

    // Every refusal the RPCs raise deliberately shares one error code and
    // differs only by hint (see supabase/README.md), so the hint is what the
    // client branches on. `quota_exceeded` is absent here: it needs the
    // tier and the limit, which only the caller can supply.
    switch (error.hint) {
      case 'upgrade_required':
        throw const UpgradeRequiredException();
      case 'empty_set':
        throw const EmptyPracticeSetException();
      case 'already_submitted':
        throw const AlreadySubmittedException();
    }
    rethrow;
  }
}
