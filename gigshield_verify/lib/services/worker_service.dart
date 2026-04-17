import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app/constants.dart';
import 'auth_service.dart';

/// Data models returned by the backend.

class Policy {
  final String id;
  final String status;
  final double coverageAmountInr;
  final double weeklyPremiumInr;
  final String startDate;
  final String? endDate;
  final String? planName;

  Policy.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String? ?? '',
        status = j['status'] as String? ?? 'inactive',
        coverageAmountInr = (j['coverage_amount_inr'] as num? ?? 0).toDouble(),
        weeklyPremiumInr = (j['weekly_premium_inr'] as num? ?? 0).toDouble(),
        startDate = j['start_date'] as String? ?? '',
        endDate = j['end_date'] as String?,
        planName = j['plan_name'] as String?;
}

class Claim {
  final String id;
  final String eventType;
  final double claimAmountInr;
  final String status;
  final String createdAt;

  Claim.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String? ?? '',
        eventType = j['event_type'] as String? ?? 'unknown',
        claimAmountInr = (j['payout_amount_inr'] as num? ?? 0).toDouble(),
        status = j['status'] as String? ?? 'pending',
        createdAt =
            j['triggered_at'] as String? ?? j['created_at'] as String? ?? '';
}

class Payout {
  final String id;
  final double amountInr;
  final String status;
  final String paidAt;

  Payout.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String? ?? '',
        amountInr = (j['amount_inr'] as num? ?? 0).toDouble(),
        status = j['status'] as String? ?? 'pending',
        paidAt =
            j['processed_at'] as String? ?? j['created_at'] as String? ?? '';
}

class DashboardData {
  final Policy? activePolicy;
  final Map<String, dynamic>? riskToday;
  final double incomeProtectedThisWeek;
  final int claimsThisMonth;
  final double payoutTotal;

  DashboardData.fromJson(Map<String, dynamic> j)
      : activePolicy = j['active_policy'] != null
            ? Policy.fromJson(j['active_policy'] as Map<String, dynamic>)
            : null,
        riskToday = j['risk_today'] as Map<String, dynamic>?,
        incomeProtectedThisWeek =
            (j['income_protected_this_week'] as num? ?? 0).toDouble(),
        claimsThisMonth = j['claims_this_month'] as int? ?? 0,
        payoutTotal = (j['payout_total'] as num? ?? 0).toDouble();
}

class PremiumBreakdown {
  final String planName;
  final double premium;
  final double maxPayout;
  final String whyRecommended;
  final double expectedPayout;
  final double valueScore;

  PremiumBreakdown.fromJson(Map<String, dynamic> j)
      : planName = j['plan_type'] as String,
        premium = (j['premium'] as num).toDouble(),
        maxPayout = (j['max_payout'] as num).toDouble(),
        whyRecommended = j['why_recommended'] as String,
        expectedPayout = (j['expected_payout'] as num).toDouble(),
        valueScore = (j['value_score'] as num).toDouble();

  // Compat getters for old UI code
  double get finalPremium => premium;
  double get coverageAmount => maxPayout;
  double get basePremium => expectedPayout / (valueScore == 0 ? 1 : valueScore);
  double get zoneMultiplier => valueScore;
  double get weatherFactor => 1.0;
}

/// Fetches all worker-facing data from the backend.
class WorkerService {
  final AuthService _auth = AuthService();

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${_auth.token}',
        'Content-Type': 'application/json',
      };

  // ── Dashboard ─────────────────────────────────────────────────────────────

  Future<DashboardData> getDashboard() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/v1/dashboard/worker'),
      headers: _headers,
    );
    _check(res);
    return DashboardData.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ── Policies ──────────────────────────────────────────────────────────────

  Future<List<Policy>> getPolicies() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/v1/policies/me'),
      headers: _headers,
    );
    _check(res);
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Policy.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Pricing ───────────────────────────────────────────────────────────────

  Future<List<PremiumBreakdown>> getPricing() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/v1/policies/recommendations'),
      headers: _headers,
    );
    _check(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['recommendations'] as List;
    return list
        .map((e) => PremiumBreakdown.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Policy> purchasePolicy(String planName) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/v1/policies'),
      headers: _headers,
      body: jsonEncode({'plan_name': planName}),
    );
    _check(res);
    return Policy.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ── Claims ────────────────────────────────────────────────────────────────

  Future<List<Claim>> getClaims() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/v1/claims/me'),
      headers: _headers,
    );
    _check(res);
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Claim.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Payouts ───────────────────────────────────────────────────────────────

  Future<List<Payout>> getPayouts() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/v1/payouts/me'),
      headers: _headers,
    );
    _check(res);
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Payout.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _check(http.Response res) {
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['detail'] ?? 'Request failed (${res.statusCode})');
    }
  }
}
