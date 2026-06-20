import 'package:shared_preferences/shared_preferences.dart';

extension AuthServiceStaffToken on AuthService {
  Future<String?> getStaffSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('staff_session_token');
  }
}
