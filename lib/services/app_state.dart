import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/domain.dart';

class AppState extends ChangeNotifier {
  AppState({SharedPreferences? preferences}) : _preferences = preferences;

  SharedPreferences? _preferences;
  SupabaseClient? supabase;
  AppRole role = AppRole.customer;
  bool authenticated = false;
  String actorId = 'customer-demo';
  String actorName = '';
  String? errorMessage;
  bool loading = false;
  final requests = <ServiceRequest>[...demoRequests];
  final auditLogs = <AuditLog>[];

  bool get supabaseConfigured =>
      dotenv.isInitialized &&
      dotenv.env['SUPABASE_URL']?.isNotEmpty == true &&
      dotenv.env['SUPABASE_ANON_KEY']?.isNotEmpty == true;

  List<ServiceRequest> get visibleRequests =>
      requests.where((r) => canViewRequest(role: role, actorId: actorId, request: r)).toList();

  Future<void> initialize() async {
    _preferences ??= await SharedPreferences.getInstance();

    if (supabaseConfigured) {
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL']!,
        publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
      );
      supabase = Supabase.instance.client;
      final user = supabase!.auth.currentUser;
      if (user != null) {
        actorId = user.id;
      }
    }

    final savedRole = _preferences!.getString('quickserve.role');
    if (savedRole != null) {
      role = AppRole.values.byName(savedRole);
      authenticated = true;
    }

    _loadLocalRequests();
  }

Future<void> signIn(
  String email,
  String password,
  AppRole requestedRole,
) async {
  loading = true;
  errorMessage = null;
  notifyListeners();

  try {
    if (supabase == null) {
      throw Exception('Supabase is not configured.');
    }

    final response = await supabase!.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    final user = response.user;

    if (user == null) {
      throw Exception('Login failed. User not found.');
    }

    actorId = user.id;

    final profile = await supabase!
        .from('profiles')
        .select('full_name, role')
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null) {
      throw Exception('User profile not found.');
    }

    actorName = profile['full_name'] as String? ?? 'Customer';

    role = AppRole.values.firstWhere(
      (r) => r.name.toUpperCase() == profile['role'],
      orElse: () => AppRole.customer,
    );

    authenticated = true;

    await _persistSession();

    logEvent(
      'LOGIN_SUCCESS',
      actorId,
      '',
      'Signed in successfully',
    );
  } on AuthException catch (e) {
    errorMessage = e.message;
    logEvent(
      'AUTHORIZATION_FAILED',
      actorId,
      '',
      'Sign-in failed',
    );
  } catch (e) {
    errorMessage = e.toString();
    logEvent(
      'DATABASE_ERROR',
      actorId,
      '',
      'Authentication request failed',
    );
  }

  loading = false;
  notifyListeners();
}

  Future<void> register(String name, String email, String password) async {
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      if (supabase != null) {
        await supabase!.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': name, 'role': 'CUSTOMER'},
        );
      }

      actorName = name;
      actorId = 'customer-demo';
      role = AppRole.customer;
      authenticated = true;
      await _persistSession();
    } catch (e) {
  errorMessage = 'Registration failed: $e';
}

    loading = false;
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    if (supabase != null) {
      await supabase!.auth.resetPasswordForEmail(email);
    }
  }

  Future<void> signOut() async {
    if (supabase != null) {
      await supabase!.auth.signOut();
    }

    await _preferences?.remove('quickserve.role');
    role = AppRole.customer;
    actorId = 'customer-demo';
    authenticated = false;
    notifyListeners();
  }

  Future<ServiceRequest?> createRequest({
    required ServiceType service,
    required String description,
    required DateTime date,
    required String time,
    required String address,
    required Priority priority,
  }) async {
    if (role != AppRole.customer && role != AppRole.admin) {
      errorMessage = 'Only customers and administrators can create requests.';
      logEvent('AUTHORIZATION_FAILED', actorId, '', 'Create request denied');
      notifyListeners();
      return null;
    }

    final id = 'REQ-${date.year}-${(requests.length + 124).toString().padLeft(6, '0')}';
    final request = ServiceRequest(
      id: id,
      customerId: actorId,
      service: service,
      description: description,
      preferredDate: date,
      preferredTime: time,
      address: address,
      priority: priority,
      status: RequestStatus.created,
    );

    requests.insert(0, request);
    logEvent('REQUEST_CREATED', actorId, id, 'Created ${service.label} request');
    await _persistRequests();
    notifyListeners();
    return request;
  }

  Future<bool> updateStatus(ServiceRequest request, RequestStatus next,
      {String? note}) async {
    if (!canManageRequest(role: role, actorId: actorId, request: request) &&
        role != AppRole.customer) {
      logEvent('AUTHORIZATION_FAILED', actorId, request.id, 'Status update denied');
      errorMessage = 'You are not authorized to update this request.';
      notifyListeners();
      return false;
    }

    if (!isValidTransition(request.status, next) && next != RequestStatus.cancelled) {
      errorMessage = 'That status transition is not allowed.';
      notifyListeners();
      return false;
    }

    request.status = next;
    request.agentNote = note ?? request.agentNote;
    logEvent('REQUEST_UPDATED', actorId, request.id, 'Status changed to ${next.label}');
    await _persistRequests();
    notifyListeners();
    return true;
  }

  Future<bool> assignAgent(ServiceRequest request, String agent) async {
    if (role != AppRole.admin) {
      errorMessage = 'Only administrators can assign agents.';
      logEvent('AUTHORIZATION_FAILED', actorId, request.id, 'Assignment denied');
      notifyListeners();
      return false;
    }

    request.assignedAgent = agent;
    request.status = RequestStatus.assigned;
    logEvent('REQUEST_ASSIGNED', actorId, request.id, 'Assigned to $agent');
    await _persistRequests();
    notifyListeners();
    return true;
  }

  void logEvent(String type, String actor, String entity, String message) {
    auditLogs.insert(
      0,
      AuditLog(
        eventType: type,
        actorId: actor,
        entityId: entity,
        message: message,
      ),
    );
  }

  Future<void> _persistSession() async {
    await _preferences?.setString('quickserve.role', role.name);
  }

  Future<void> _persistRequests() async {
    await _preferences?.setString(
      'quickserve.requests',
      jsonEncode(
        requests
            .map(
              (r) => {
                'id': r.id,
                'service': r.service.name,
                'status': r.status.name,
              },
            )
            .toList(),
      ),
    );
  }

  void _loadLocalRequests() {
    // Seeded records remain available offline; Supabase sync can hydrate this list.
  }
}
