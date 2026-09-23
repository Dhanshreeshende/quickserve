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
  List<Map<String, dynamic>> agents = [];
  List<Map<String, dynamic>> customers = [];
  List<AuditLog> auditLogs = [];

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

    final user = supabase?.auth.currentUser;

if (user != null) {
  actorId = user.id;

  final profile = await supabase!
      .from('profiles')
      .select('full_name, role')
      .eq('id', user.id)
      .maybeSingle();

  if (profile != null) {
    actorName = profile['full_name'] as String? ?? '';
    role = AppRole.values.firstWhere(
      (r) => r.name.toUpperCase() == profile['role'],
      orElse: () => AppRole.customer,
    );
    authenticated = true;
  }
}

_loadLocalRequests();
  }

Future<void> signIn(
  String email,
  String password,
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

if (role == AppRole.admin) {
  await loadAdminRequests();
  await loadAgents();
  await loadCustomers();
  await loadAuditLogs();
} else if (role == AppRole.agent) {
  await loadAgentRequests();
} else if (role == AppRole.customer) {
  await loadCustomerRequests();
}

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
Future<void> loadAdminRequests() async {
  if (supabase == null || role != AppRole.admin) return;

  try {
    final rows = await supabase!
        .from('service_requests')
        .select()
        .order('created_at', ascending: false);

    final loadedRequests = rows.map<ServiceRequest>((row) {
      final service = switch (row['service_key'] as String) {
        'ac' => ServiceType.ac,
        'plumbing' => ServiceType.plumbing,
        'electrical' => ServiceType.electrical,
        'cleaning' => ServiceType.cleaning,
        _ => ServiceType.ac,
      };

      final priority = switch (row['priority'] as String) {
        'LOW' => Priority.low,
        'HIGH' => Priority.high,
        _ => Priority.medium,
      };

      final status = switch (row['status'] as String) {
        'ASSIGNED' => RequestStatus.assigned,
        'ACCEPTED' => RequestStatus.accepted,
        'IN_PROGRESS' => RequestStatus.inProgress,
        'COMPLETED' => RequestStatus.completed,
        'CANCELLED' => RequestStatus.cancelled,
        _ => RequestStatus.created,
      };

      return ServiceRequest(
        id: row['request_id'] as String,
        customerId: row['customer_id'] as String,
        service: service,
        description: row['description'] as String? ?? '',
        preferredDate: DateTime.parse(
          row['preferred_date'] as String,
        ),
        preferredTime: row['preferred_time'] as String? ?? '',
        address: row['address'] as String? ?? '',
        priority: priority,
        status: status,
        assignedAgent: row['agent_id'] as String?,
      );
    }).toList();

    requests
      ..clear()
      ..addAll(loadedRequests);

    debugPrint(
      'Admin loaded ${loadedRequests.length} requests from Supabase',
    );
  } catch (e) {
    errorMessage = 'Failed to load requests: $e';
    debugPrint('Admin request load error: $e');
  }

  notifyListeners();
}
Future<void> loadCustomerRequests() async {
  if (supabase == null || role != AppRole.customer) return;

  try {
    final rows = await supabase!
        .from('service_requests')
        .select()
        .eq('customer_id', actorId)
        .order('created_at', ascending: false);

    final loadedRequests = rows.map<ServiceRequest>((row) {
      final service = switch (row['service_key'] as String) {
        'ac' => ServiceType.ac,
        'plumbing' => ServiceType.plumbing,
        'electrical' => ServiceType.electrical,
        'cleaning' => ServiceType.cleaning,
        _ => ServiceType.ac,
      };

      final priority = switch (row['priority'] as String) {
        'LOW' => Priority.low,
        'HIGH' => Priority.high,
        _ => Priority.medium,
      };

      final status = switch (row['status'] as String) {
        'ASSIGNED' => RequestStatus.assigned,
        'ACCEPTED' => RequestStatus.accepted,
        'IN_PROGRESS' => RequestStatus.inProgress,
        'COMPLETED' => RequestStatus.completed,
        'CANCELLED' => RequestStatus.cancelled,
        _ => RequestStatus.created,
      };

      return ServiceRequest(
        id: row['request_id'] as String,
        customerId: row['customer_id'] as String,
        service: service,
        description: row['description'] as String? ?? '',
        preferredDate: DateTime.parse(row['preferred_date'] as String),
        preferredTime: row['preferred_time'] as String? ?? '',
        address: row['address'] as String? ?? '',
        priority: priority,
        status: status,
        assignedAgent: row['agent_id'] as String?,
      );
    }).toList();

    requests
      ..clear()
      ..addAll(loadedRequests);

    debugPrint(
      'Customer loaded ${loadedRequests.length} requests from Supabase',
    );
  } catch (e) {
    errorMessage = 'Failed to load customer requests: $e';
    debugPrint('Customer request load error: $e');
  }

  notifyListeners();
}
Future<void> loadAgentRequests() async {
  if (supabase == null || role != AppRole.agent) return;

  try {
    final rows = await supabase!
        .from('service_requests')
        .select()
        .eq('agent_id', actorId)
        .order('created_at', ascending: false);

    final loadedRequests = rows.map<ServiceRequest>((row) {
      final service = switch (row['service_key'] as String) {
        'ac' => ServiceType.ac,
        'plumbing' => ServiceType.plumbing,
        'electrical' => ServiceType.electrical,
        'cleaning' => ServiceType.cleaning,
        _ => ServiceType.ac,
      };

      final priority = switch (row['priority'] as String) {
        'LOW' => Priority.low,
        'HIGH' => Priority.high,
        _ => Priority.medium,
      };

      final status = switch (row['status'] as String) {
        'ASSIGNED' => RequestStatus.assigned,
        'ACCEPTED' => RequestStatus.accepted,
        'IN_PROGRESS' => RequestStatus.inProgress,
        'COMPLETED' => RequestStatus.completed,
        'CANCELLED' => RequestStatus.cancelled,
        _ => RequestStatus.created,
      };

      return ServiceRequest(
        id: row['request_id'] as String,
        customerId: row['customer_id'] as String,
        service: service,
        description: row['description'] as String? ?? '',
        preferredDate: DateTime.parse(row['preferred_date'] as String),
        preferredTime: row['preferred_time'] as String? ?? '',
        address: row['address'] as String? ?? '',
        priority: priority,
        status: status,
        assignedAgent: row['agent_id'] as String?,
      );
    }).toList();

    requests
      ..clear()
      ..addAll(loadedRequests);

    debugPrint(
      'Agent loaded ${loadedRequests.length} assigned requests from Supabase',
    );
  } catch (e) {
    errorMessage = 'Failed to load agent requests: $e';
    debugPrint('Agent request load error: $e');
  }

  notifyListeners();
}
Future<void> loadAgents() async {
  if (supabase == null || role != AppRole.admin) return;

  try {
    final rows = await supabase!
        .from('profiles')
        .select('id, full_name, email')
        .eq('role', 'AGENT')
        .order('full_name');

    agents = List<Map<String, dynamic>>.from(rows);

    debugPrint('Admin loaded ${agents.length} agents from Supabase');
  } catch (e) {
    errorMessage = 'Failed to load agents: $e';
    debugPrint('Agent load error: $e');
  }

  notifyListeners();
}
Future<void> loadCustomers() async {
  if (supabase == null || role != AppRole.admin) return;

  try {
    final rows = await supabase!
        .from('profiles')
        .select('id, full_name, email')
        .eq('role', 'CUSTOMER')
        .order('full_name');

    customers = List<Map<String, dynamic>>.from(rows);

    debugPrint('Admin loaded ${customers.length} customers from Supabase');
  } catch (e) {
    errorMessage = 'Failed to load customers: $e';
    debugPrint('Customer load error: $e');
  }

  notifyListeners();
}
Future<void> loadAuditLogs() async {
  if (supabase == null || role != AppRole.admin) return;

  try {
    final rows = await supabase!
        .from('audit_logs')
        .select()
        .order('created_at', ascending: false)
        .limit(20);

    auditLogs = rows.map((row) {
      return AuditLog(
        eventType: row['event_type'] as String,
        actorId: row['user_id']?.toString() ?? 'System',
        entityId: row['entity_id']?.toString() ?? '',
        message: row['metadata']?.toString() ?? '',
      );
    }).toList();

    debugPrint('Admin loaded ${auditLogs.length} audit logs from Supabase');
  } catch (e) {
    errorMessage = 'Failed to load audit logs: $e';
    debugPrint('Audit log load error: $e');
  }

  notifyListeners();
}

  Future<void> register(String name, String email, String password) async {
    loading = true;
    errorMessage = null;
    notifyListeners();

     try {
    if (supabase == null) {
      throw Exception('Supabase is not configured.');
    }

    final response = await supabase!.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': name.trim(),
        'role': 'CUSTOMER',
      },
    );

    final user = response.user;

    if (user == null) {
      throw Exception('Registration failed. User was not created.');
    }

    actorId = user.id;
    role = AppRole.customer;
    actorName = name.trim();

    if (response.session != null) {
      authenticated = true;
      await _persistSession();
    } else {
      authenticated = false;
      errorMessage =
          'Account created. Please verify your email before signing in.';
    }
  } on AuthException catch (e) {
    errorMessage = e.message;
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
  try {
    if (supabase != null) {
      await supabase!.auth.signOut();
    }
  } finally {
    await _preferences?.remove('quickserve.role');

    role = AppRole.customer;
    actorId = '';
    actorName = '';
    authenticated = false;
    errorMessage = null;

    notifyListeners();
  }
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
  debugPrint('ROLE: $role');
debugPrint('ACTOR ID: $actorId');
debugPrint('SUPABASE: ${supabase != null}');

  if (supabase == null) {
    errorMessage = 'Supabase is not configured.';
    notifyListeners();
    return null;
  }

  loading = true;
  errorMessage = null;
  notifyListeners();

  try {
    debugPrint('CREATING REQUEST IN SUPABASE...');
    final row = await supabase!
        .from('service_requests')
        .insert({
          'customer_id': actorId,
          'service_key': service.name,
          'description': description.trim(),
          'preferred_date':
              '${date.year.toString().padLeft(4, '0')}-'
              '${date.month.toString().padLeft(2, '0')}-'
              '${date.day.toString().padLeft(2, '0')}',
          'preferred_time': time,
          'address': address.trim(),
          'priority': priority.name.toUpperCase(),
          'status': 'CREATED',
        })
        .select()
        .single();

    final request = ServiceRequest(
      id: row['request_id'] as String,
      customerId: row['customer_id'] as String,
      service: service,
      description: row['description'] as String,
      preferredDate: DateTime.parse(row['preferred_date'] as String),
      preferredTime: row['preferred_time'] as String,
      address: row['address'] as String,
      priority: priority,
      status: RequestStatus.created,
    );

    requests.insert(0, request);

    logEvent(
      'REQUEST_CREATED',
      actorId,
      request.id,
      'Created ${service.label} request',
    );

    loading = false;
    notifyListeners();

    return request;
  } catch (e) {
    debugPrint('CREATE REQUEST ERROR: $e');
    errorMessage = 'Failed to create request: $e';

    logEvent(
      'DATABASE_ERROR',
      actorId,
      '',
      'Failed to create service request',
    );

    loading = false;
    notifyListeners();

    return null;
  }
}

  Future<bool> updateStatus(
  ServiceRequest request,
  RequestStatus next, {
  String? note,
}) async {
  if (supabase == null) {
    errorMessage = 'Supabase is not configured.';
    notifyListeners();
    return false;
  }

  if (!canManageRequest(
        role: role,
        actorId: actorId,
        request: request,
      ) &&
      role != AppRole.customer) {
    logEvent(
      'AUTHORIZATION_FAILED',
      actorId,
      request.id,
      'Status update denied',
    );
    errorMessage = 'You are not authorized to update this request.';
    notifyListeners();
    return false;
  }

  if (!isValidTransition(request.status, next) &&
      next != RequestStatus.cancelled) {
    errorMessage = 'That status transition is not allowed.';
    notifyListeners();
    return false;
  }

  try {
    await supabase!.rpc(
      'update_request_status',
      params: {
        'p_request_id': request.id,
        'p_new_status': next == RequestStatus.inProgress
    ? 'IN_PROGRESS'
    : next.name.toUpperCase(),
        'p_note': note,
      },
    );

    request.status = next;
    request.agentNote = note ?? request.agentNote;

    logEvent(
      'REQUEST_UPDATED',
      actorId,
      request.id,
      'Status changed to ${next.label}',
    );

    notifyListeners();
    return true;
  } catch (e) {
    errorMessage = 'Failed to update request status: $e';
    debugPrint('Status update error: $e');
    notifyListeners();
    return false;
  }
}
Future<bool> assignAgent(ServiceRequest request, String agent) async {
  if (role != AppRole.admin) {
    errorMessage = 'Only administrators can assign agents.';
    logEvent(
      'AUTHORIZATION_FAILED',
      actorId,
      request.id,
      'Assignment denied',
    );
    notifyListeners();
    return false;
  }

  if (supabase == null) {
    errorMessage = 'Supabase is not configured.';
    notifyListeners();
    return false;
  }

  try {
    final agentProfile = await supabase!
        .from('profiles')
        .select('id')
        .eq('email', agent)
        .eq('role', 'AGENT')
        .maybeSingle();

    if (agentProfile == null) {
      errorMessage = 'Agent not found.';
      notifyListeners();
      return false;
    }

    await supabase!.rpc(
      'assign_request_agent',
      params: {
        'p_request_id': request.id,
        'p_agent_id': agentProfile['id'],
      },
    );

    request.assignedAgent = agentProfile['id'] as String;
    request.status = RequestStatus.assigned;

    logEvent(
      'REQUEST_ASSIGNED',
      actorId,
      request.id,
      'Assigned to $agent',
    );

    notifyListeners();
    return true;
  } catch (e) {
    errorMessage = 'Failed to assign agent: $e';
    debugPrint('Agent assignment error: $e');
    notifyListeners();
    return false;
  }
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
