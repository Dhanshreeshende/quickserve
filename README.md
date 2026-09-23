# QuickServe Flutter

QuickServe is a full-stack Service Request Management application built as a **Flutter mobile app for Android/iOS and Flutter Web admin portal**, backed by Supabase. It satisfies the Swasiq internship assignment requirements: customer request creation/tracking, agent work management, admin operations, authentication, RBAC, audit events, error handling, documentation, and tests.

## Technology

- Flutter/Dart, Material 3, responsive Flutter Web
- Supabase Auth and PostgreSQL with Row Level Security
- `shared_preferences` for offline/session persistence
- `supabase_flutter`, `flutter_dotenv`, `intl`, and `uuid`
- `flutter_test` for domain/widget tests

## Run locally

Install Flutter 3.24+ and Dart 3.5+, then:

```bash
flutter pub get
cp env.example .env
# Add SUPABASE_URL and SUPABASE_ANON_KEY for live backend mode.
flutter run
```

Run web admin mode:

```bash
flutter run -d chrome
```

Run tests and static analysis:

```bash
flutter test
flutter analyze
```

## Test accounts

The Supabase-backed demo includes the following test accounts:

| Role | Email |
|---|---|
| Customer | `dhanshree@gmail.com` |
| Agent | `agent@quickserve.com` |
| Agent | `agent2@quickserve.com` |
| Admin | `admin@quickserve.com` |

Passwords are provided separately to the evaluator and are not committed to the repository.

For local fallback mode, non-empty email/password values can be used for demonstration.

## Requirement coverage

Customer screens include splash/authentication, registration, password reset, home, service catalog, create request, request history, request details, cancellation, profile, and logout. Agents can view assigned work, accept/update statuses, add notes through the request state layer, and see completed work. Administrators have a responsive Flutter Web operations console with KPIs, request search/filtering, assignments, status management, customer/agent-visible data, and audit activity.

The request lifecycle is `CREATED → ASSIGNED → ACCEPTED → IN_PROGRESS → COMPLETED`; cancellation is limited to `CREATED` and `ASSIGNED`. Request IDs follow `REQ-YYYY-NNNNNN`. The Supabase schema in `supabase_schema.sql` contains profiles, services, service requests, status history, audit logs, device tokens, analytics events, indexes, RPC guards, and RLS policies.

## Architecture

`lib/models/domain.dart` contains the domain model and authorization rules. `lib/services/app_state.dart` is the application state/repository boundary: it manages session persistence, local fallback, Supabase Auth hooks, request mutations, lifecycle validation, and audit events. `lib/main.dart` contains the responsive route shell and customer/agent/admin screens. The production Supabase policies remain the final authorization boundary; UI visibility is not treated as security.

## Error handling and security

Invalid input, invalid lifecycle transitions, unauthorized mutations, auth errors, and backend failures return user-safe messages. Audit event types include `LOGIN_SUCCESS`, `REQUEST_CREATED`, `REQUEST_ASSIGNED`, `REQUEST_UPDATED`, `AUTHORIZATION_FAILED`, and `DATABASE_ERROR`. Passwords, auth tokens, API keys, and secrets are never logged.
