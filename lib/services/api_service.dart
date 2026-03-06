import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  Future<Map<String, dynamic>?> fetchData(String baseUrl) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/data')).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      // print("Error fetching data: $e");
    }
    return null;
  }

  Future<bool> sendCommand(String baseUrl, String endpoint) async {
    try {
      await http.get(Uri.parse('$baseUrl$endpoint')).timeout(const Duration(seconds: 1));
      return true;
    } catch (e) {
      return false;
    }
  }
}
