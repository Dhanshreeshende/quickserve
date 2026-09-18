enum AppRole { customer, agent, admin }
enum Priority { low, medium, high }
enum RequestStatus { created, assigned, accepted, inProgress, completed, cancelled }

enum ServiceType { ac, plumbing, electrical, cleaning }

extension AppRoleLabel on AppRole { String get label => name[0].toUpperCase() + name.substring(1); }
extension PriorityLabel on Priority { String get label => name[0].toUpperCase() + name.substring(1); }
extension RequestStatusLabel on RequestStatus {
  String get label => switch (this) { RequestStatus.inProgress => 'In progress', _ => name[0].toUpperCase() + name.substring(1) };
}
extension ServiceTypeLabel on ServiceType {
  String get label => switch (this) { ServiceType.ac => 'AC servicing', ServiceType.plumbing => 'Plumbing', ServiceType.electrical => 'Electrical', ServiceType.cleaning => 'Cleaning' };
}

const lifecycle = [RequestStatus.created, RequestStatus.assigned, RequestStatus.accepted, RequestStatus.inProgress, RequestStatus.completed];

bool isValidTransition(RequestStatus from, RequestStatus to) {
  if (to == RequestStatus.cancelled) return from == RequestStatus.created || from == RequestStatus.assigned;
  final fromIndex = lifecycle.indexOf(from), toIndex = lifecycle.indexOf(to);
  return fromIndex >= 0 && toIndex == fromIndex + 1;
}

class ServiceRequest {
  ServiceRequest({required this.id, required this.customerId, required this.service, required this.description, required this.preferredDate, required this.preferredTime, required this.address, required this.priority, required this.status, this.assignedAgent, this.agentNote, DateTime? createdAt}) : createdAt = createdAt ?? DateTime.now();
  final String id;
  final String customerId;
  final ServiceType service;
  final String description;
  final DateTime preferredDate;
  final String preferredTime;
  final String address;
  final Priority priority;
  RequestStatus status;
  String? assignedAgent;
  String? agentNote;
  final DateTime createdAt;

  ServiceRequest copyWith({RequestStatus? status, String? assignedAgent, String? agentNote}) => ServiceRequest(id: id, customerId: customerId, service: service, description: description, preferredDate: preferredDate, preferredTime: preferredTime, address: address, priority: priority, status: status ?? this.status, assignedAgent: assignedAgent ?? this.assignedAgent, agentNote: agentNote ?? this.agentNote, createdAt: createdAt);
}

class AuditLog {
  AuditLog({required this.eventType, required this.actorId, required this.entityId, required this.message, DateTime? createdAt}) : createdAt = createdAt ?? DateTime.now();
  final String eventType;
  final String actorId;
  final String entityId;
  final String message;
  final DateTime createdAt;
}

final demoRequests = <ServiceRequest>[
  ServiceRequest(id: 'REQ-2026-000123', customerId: 'customer-demo', service: ServiceType.ac, description: 'AC is making a light rattling sound when switched on.', preferredDate: DateTime.now(), preferredTime: '4:00 PM – 6:00 PM', address: 'Flat 402, Lotus Heights, Pratap Nagar', priority: Priority.medium, status: RequestStatus.inProgress, assignedAgent: 'Rohan Mehta', agentNote: 'Technician is on the way.'),
  ServiceRequest(id: 'REQ-2026-000118', customerId: 'customer-demo', service: ServiceType.plumbing, description: 'Kitchen sink drain is slow and needs a quick check.', preferredDate: DateTime.now().subtract(const Duration(days: 2)), preferredTime: '11:00 AM – 1:00 PM', address: 'Flat 402, Lotus Heights, Pratap Nagar', priority: Priority.low, status: RequestStatus.completed, assignedAgent: 'Ankit Pawar'),
  ServiceRequest(id: 'REQ-2026-000111', customerId: 'customer-demo', service: ServiceType.cleaning, description: 'Two-bedroom deep cleaning before family visits.', preferredDate: DateTime.now().subtract(const Duration(days: 10)), preferredTime: '10:00 AM – 12:00 PM', address: 'Flat 402, Lotus Heights, Pratap Nagar', priority: Priority.high, status: RequestStatus.cancelled, assignedAgent: 'Priya Sharma'),
];

bool canViewRequest({required AppRole role, required String actorId, required ServiceRequest request}) => role == AppRole.admin || (role == AppRole.customer && request.customerId == actorId) || (role == AppRole.agent && request.assignedAgent == actorId);
bool canManageRequest({required AppRole role, required String actorId, required ServiceRequest request}) => role == AppRole.admin || (role == AppRole.agent && request.assignedAgent == actorId);
