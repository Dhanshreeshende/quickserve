import 'package:flutter_test/flutter_test.dart';
import 'package:quickserve/models/domain.dart';

void main() {
  test('lifecycle only advances one valid step', () {
    expect(isValidTransition(RequestStatus.created, RequestStatus.assigned), isTrue);
    expect(isValidTransition(RequestStatus.created, RequestStatus.completed), isFalse);
    expect(isValidTransition(RequestStatus.assigned, RequestStatus.cancelled), isTrue);
  });

  test('customer cannot view another customer request', () {
    final request = ServiceRequest(id: 'REQ-2026-000123', customerId: 'customer-a', service: ServiceType.ac, description: 'Issue', preferredDate: DateTime(2026, 9, 18), preferredTime: '4 PM', address: 'Address', priority: Priority.medium, status: RequestStatus.created);
    expect(canViewRequest(role: AppRole.customer, actorId: 'customer-b', request: request), isFalse);
    expect(canViewRequest(role: AppRole.customer, actorId: 'customer-a', request: request), isTrue);
    expect(canViewRequest(role: AppRole.admin, actorId: 'admin-a', request: request), isTrue);
  });
}
