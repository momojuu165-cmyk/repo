import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/app_settings.dart';

class AppSettingsDao {
  SupabaseClient get _client => Supabase.instance.client;
  static const _table = 'app_settings';

  Future<AppSettings> getSettings() async {
    try {
      final rows = await _client.from(_table).select('*').limit(1);
      final list = rows as List;
      if (list.isEmpty) return const AppSettings();
      final row = list.first as Map<String, dynamic>;
      return AppSettings.fromMap(row);
    } catch (e) {
      print('AppSettingsDao.getSettings error: $e');
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    try {
      final map = settings.toMap();
      final existing = await _client.from(_table).select('id').limit(1);
      final list = existing as List;
      if (list.isEmpty) {
        await _client.from(_table).insert(map);
      } else {
        final id = list.first['id'];
        await _client.from(_table).update(map).eq('id', id);
      }
    } catch (e) {
      print('AppSettingsDao.saveSettings error: $e');
    }
  }

  Future<void> updateInstallmentRates({
    double? monthlyRate,
    Map<int, double>? ratesByMonths,
  }) async {
    try {
      final current = await getSettings();
      final updated = current.copyWith(
        monthlyInstallmentRate: monthlyRate,
        installmentRatesByMonths: ratesByMonths,
      );
      await saveSettings(updated);
    } catch (e) {
      print('AppSettingsDao.updateInstallmentRates error: $e');
    }
  }
}
