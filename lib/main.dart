import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'models/domain.dart';
import 'services/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
 } catch (e) {
  debugPrint('Failed to load .env: $e');
  debugPrint('SUPABASE_URL: ${dotenv.env['SUPABASE_URL']}');
}
  final state = AppState();
  await state.initialize();
  runApp(QuickServeApp(state: state));
}

class QuickServeApp extends StatelessWidget {
  const QuickServeApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (_, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'QuickServe',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFF26B4D),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFFBFAF8),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          home: !state.authenticated
    ? AuthScreen(state: state)
    : state.role == AppRole.customer
        ? HomeShell(state: state)
        : state.role == AppRole.agent
            ? AgentScreen(state: state)
            : AdminScreen(state: state),
        );
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.state});

  final AppState state;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AppRole selectedRole = AppRole.customer;
  bool register = false;
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (register) {
      await widget.state.register(
        name.text,
        email.text,
        password.text,
      );
    } else {
      await widget.state.signIn(
  email.text,
  password.text,
);
    }

    if (mounted && widget.state.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.state.errorMessage!)),
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFFF26B4D),
                    child: Icon(
                      Icons.home_repair_service,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'quickserve',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF26B4D),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    register ? 'Create your account.' : 'Welcome back.',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    register
                        ? 'Get trusted help for every room.'
                        : 'Sign in to keep your home running smoothly.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 26),
                  const Align(
  alignment: Alignment.centerLeft,
  child: Text(
    'Sign in as',
    style: TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 14,
    ),
  ),
),

const SizedBox(height: 10),

SegmentedButton<AppRole>(
  segments: const [
    ButtonSegment<AppRole>(
      value: AppRole.customer,
      label: Text('Customer'),
      icon: Icon(Icons.person_outline),
    ),
    ButtonSegment<AppRole>(
      value: AppRole.agent,
      label: Text('Agent'),
      icon: Icon(Icons.engineering_outlined),
    ),
    ButtonSegment<AppRole>(
      value: AppRole.admin,
      label: Text('Admin'),
      icon: Icon(Icons.admin_panel_settings_outlined),
    ),
  ],
  selected: {selectedRole},
  onSelectionChanged: (selection) {
    setState(() {
      selectedRole = selection.first;

      // Only Customer can register.
      if (selectedRole != AppRole.customer) {
        register = false;
      }
    });
  },
),

const SizedBox(height: 18),
                  if (register)
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Full name'),
                    ),
                  if (register) const SizedBox(height: 12),
                  TextField(
                    controller: email,
                    decoration: const InputDecoration(labelText: 'Email address'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.state.loading ? null : submit,
                      child: Text(register ? 'Create account' : 'Sign in'),
                    ),
                  ),
                  if (selectedRole == AppRole.customer)
  TextButton(
    onPressed: () => setState(() => register = !register),
    child: Text(
      register
          ? 'Already have an account? Sign in'
          : 'New to QuickServe? Create an account',
    ),
  ),
                  TextButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      await widget.state.resetPassword(email.text);

                      if (!mounted) return;

                      if (messenger != null) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'If the email exists, a reset link has been sent.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Forgot password?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});

  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(state: widget.state),
      RequestsScreen(state: widget.state),
      ProfileScreen(state: widget.state),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }


  @override
  Widget build(BuildContext context) {
    final activeItems = state.visibleRequests
        .where(
          (r) => r.status != RequestStatus.completed &&
              r.status != RequestStatus.cancelled,
        )
        .toList();
    final active = activeItems.isEmpty ? null : activeItems.first;

    return AppPage(
      title: '${_greeting()}, ${state.actorName}',
      eyebrow: DateFormat('EEEE, d MMMM').format(DateTime.now()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateRequestScreen(state: state),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (active != null)
            RequestCard(
              request: active,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RequestDetailScreen(state: state, request: active),
                ),
              ),
            ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'What do you need help with?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ServicesScreen(state: state)),
                ),
                child: const Text('See all'),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ServiceType.values
                .map(
                  (s) => ServiceTile(
                    service: s,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CreateRequestScreen(state: state, initialService: s),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          Card(
            color: const Color(0xFFE4F7F2),
            child: const ListTile(
              leading: Icon(Icons.verified_user, color: Color(0xFF1E9E96)),
              title: Text(
                'Trusted professionals, every time',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Every agent is background-verified and rated by customers.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Services',
      eyebrow: 'HOME SERVICES, MADE EASY',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: ServiceType.values
            .map(
              (s) => SizedBox(
                width: 180,
                child: ServiceTile(
                  service: s,
                  large: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CreateRequestScreen(state: state, initialService: s),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({
    super.key,
    required this.state,
    this.initialService,
  });

  final AppState state;
  final ServiceType? initialService;

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  late ServiceType service = widget.initialService ?? ServiceType.ac;
  Priority priority = Priority.medium;
  DateTime date = DateTime.now();
  final description = TextEditingController();
  final time = TextEditingController(text: '4:00 PM ? 6:00 PM');
  final address = TextEditingController(
    text: 'Flat 402, Lotus Heights, Pratap Nagar',
  );

  @override
  void dispose() {
    description.dispose();
    time.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> create() async {
    debugPrint('SUBMIT BUTTON CLICKED');
  final request = await widget.state.createRequest(
    service: service,
    description: description.text,
    date: date,
    time: time.text,
    address: address.text,
    priority: priority,
  );

  if (!mounted) return;

  if (request != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Request submitted successfully'),
      ),
    );

    Navigator.pop(context);
  } else if (widget.state.errorMessage != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.state.errorMessage!),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Create request',
      eyebrow: 'NEW SERVICE REQUEST',
      child: ListView(
        shrinkWrap: true,
        children: [
          DropdownButtonFormField<ServiceType>(
            initialValue: service,
            decoration: const InputDecoration(labelText: 'Service type'),
            items: ServiceType.values
                .map(
                  (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                )
                .toList(),
            onChanged: (v) => setState(() => service = v ?? service),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: description,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Describe the issue'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: address,
            decoration: const InputDecoration(labelText: 'Address'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(DateFormat('d MMM yyyy').format(date)),
                  subtitle: const Text('Preferred date'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                      initialDate: date,
                    );
                    if (picked != null && mounted) {
                      setState(() => date = picked);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: time,
                  decoration: const InputDecoration(labelText: 'Time'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Priority>(
            initialValue: priority,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: Priority.values
                .map(
                  (p) => DropdownMenuItem(value: p, child: Text(p.label)),
                )
                .toList(),
            onChanged: (v) => setState(() => priority = v ?? priority),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: widget.state.loading ? null : create,
            icon: const Icon(Icons.send),
            label: const Text('Submit request'),
          ),
        ],
      ),
    );
  }
}

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  String search = '';
  ServiceType? filter;

  @override
  Widget build(BuildContext context) {
    final requests = widget.state.visibleRequests
        .where(
          (r) =>
              (filter == null || r.service == filter) &&
              ('${r.id} ${r.description} ${r.address}'
                  .toLowerCase()
                  .contains(search.toLowerCase())),
        )
        .toList();

    return AppPage(
      title: 'My requests',
      eyebrow: 'YOUR SERVICE HISTORY',
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search requests, addresses, agents?',
            ),
            onChanged: (v) => setState(() => search = v),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: filter == null,
                  onSelected: (_) => setState(() => filter = null),
                ),
                ...ServiceType.values.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      label: Text(s.label),
                      selected: filter == s,
                      onSelected: (_) => setState(() => filter = s),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...requests.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RequestCard(
                request: r,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RequestDetailScreen(
                      state: widget.state,
                      request: r,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({
    super.key,
    required this.state,
    required this.request,
  });

  final AppState state;
  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: request.id,
      eyebrow: request.service.label.toUpperCase(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: ListTile(
              title: Text(request.description),
              subtitle: Text(
                '${request.address}\n${DateFormat('d MMM yyyy').format(request.preferredDate)} · ${request.preferredTime}',
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Request progress',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...lifecycle.map(
            (status) => ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    lifecycle.indexOf(status) <= lifecycle.indexOf(request.status)
                        ? const Color(0xFF1E9E96)
                        : Colors.grey.shade200,
                child: Icon(
                  lifecycle.indexOf(status) <= lifecycle.indexOf(request.status)
                      ? Icons.check
                      : Icons.circle,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              title: Text(status.label),
              dense: true,
            ),
          ),
          if (request.assignedAgent != null)
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(request.assignedAgent!),
              subtitle: Text(request.agentNote ?? 'Assigned service professional'),
            ),
          if (request.status == RequestStatus.created ||
              request.status == RequestStatus.assigned)
            OutlinedButton.icon(
              onPressed: () async {
                await state.updateStatus(request, RequestStatus.cancelled);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.close),
              label: const Text('Cancel request'),
            ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Profile',
      eyebrow: 'ACCOUNT',
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            child: Text(state.actorName.isEmpty ? 'Q' : state.actorName[0]),
          ),
          const SizedBox(height: 10),
          Text(
            state.actorName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Text(state.role.label, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          if (state.role == AppRole.admin)
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Operations console'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminScreen(state: state)),
              ),
            ),
          if (state.role == AppRole.agent)
            ListTile(
              leading: const Icon(Icons.engineering),
              title: const Text('Assigned work'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AgentScreen(state: state)),
              ),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: () => state.signOut(),
          ),
        ],
      ),
    );
  }
}

class AgentScreen extends StatelessWidget {
  const AgentScreen({super.key, required this.state});

  final AppState state;
  Future<void> _addNote(
  BuildContext context,
  AppState state,
  ServiceRequest request,
) async {
  final controller = TextEditingController();

  final note = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Add note'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter a note about this service request...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();

              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Save note'),
          ),
        ],
      );
    },
  );

  if (note == null || note.isEmpty) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Note saved.'),
    ),
  );
}
  Future<void> _updateWithNote(
    BuildContext context,
    AppState state,
    ServiceRequest request,
    RequestStatus next,
  ) async {
    final controller = TextEditingController();

    final note = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Update to ${next.label}'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'Add a note about this work...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  controller.text.trim(),
                );
              },
              child: const Text('Update status'),
            ),
          ],
        );
      },
    );

    final success = await state.updateStatus(
      request,
      next,
      note: note?.isEmpty == true ? null : note,
    );

    if (!context.mounted) return;

    if (!success && state.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.errorMessage!)),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    final assignedRequests = state.visibleRequests
        .where((r) => r.assignedAgent == state.actorId)
        .toList();

    final accepted = assignedRequests
        .where((r) => r.status == RequestStatus.accepted)
        .length;

    final inProgress = assignedRequests
        .where((r) => r.status == RequestStatus.inProgress)
        .length;

    final completed = assignedRequests
        .where((r) => r.status == RequestStatus.completed)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F7F4),
        elevation: 0,
        title: const Text(
          'QuickServe',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: state.signOut,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
  await Future<void>.delayed(Duration.zero);
},
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            children: [
              Text(
                'Good morning, ${state.actorName}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Here is your assigned work.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 22),

              // Summary cards
              Row(
                children: [
                  Expanded(
                    child: _AgentStatCard(
                      value: '${assignedRequests.length}',
                      label: 'Assigned',
                      icon: Icons.assignment_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AgentStatCard(
                      value: '$accepted',
                      label: 'Accepted',
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AgentStatCard(
                      value: '$inProgress',
                      label: 'In progress',
                      icon: Icons.timelapse,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _AgentStatCard(
                value: '$completed',
                label: 'Completed work',
                icon: Icons.task_alt,
                wide: true,
              ),

              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Assigned requests',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${assignedRequests.length}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (assignedRequests.isEmpty)
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Icon(
                          Icons.assignment_turned_in_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No requests assigned yet',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'New assignments will appear here.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...assignedRequests.map(
                  (request) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AgentRequestCard(
                       request: request,
  onAccept: request.status == RequestStatus.assigned
    ? () => _updateWithNote(
        context,
        state,
        request,
        RequestStatus.accepted,
      )
    : null,
  onStart: request.status == RequestStatus.accepted
    ? () => _updateWithNote(
        context,
        state,
        request,
        RequestStatus.inProgress,
      )
    : null,
  onComplete: request.status == RequestStatus.inProgress
    ? () => _updateWithNote(
        context,
        state,
        request,
        RequestStatus.completed,
      )
    : null,
  onAddNote: () => _addNote(
    context,
    state,
    request,
  ),
),
                      
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentStatCard extends StatelessWidget {
  const _AgentStatCard({
    required this.value,
    required this.label,
    required this.icon,
    this.wide = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFFFE7DF),
              child: Icon(
                icon,
                color: const Color(0xFFF26B4D),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentRequestCard extends StatelessWidget {
  const _AgentRequestCard({
  required this.request,
  this.onAccept,
  this.onStart,
  this.onComplete,
  this.onAddNote,
});

  final ServiceRequest request;
  final VoidCallback? onAccept;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;
  final VoidCallback? onAddNote;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFFFE7DF),
                  child: Icon(
                    Icons.home_repair_service,
                    color: const Color(0xFFF26B4D),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.service.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        request.id,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: request.status),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              request.description,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    request.address,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (onAccept != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onAccept,
                  child: const Text('Accept request'),
                ),
              ),

            if (onStart != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onStart,
                  child: const Text('Start work'),
                ),
              ),
              if (onAddNote != null)
  SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: onAddNote,
      icon: const Icon(Icons.note_add_outlined),
      label: const Text('Add note'),
    ),
  ),

            if (onComplete != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onComplete,
                  child: const Text('Mark completed'),
                ),
              ),

            if (request.status == RequestStatus.completed)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Color(0xFF1E9E96),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Work completed',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE7DF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.state});

  final AppState state;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final TextEditingController _searchController = TextEditingController();

  String search = '';
  RequestStatus? statusFilter;

  AppState get state => widget.state;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final status in RequestStatus.values)
        status: state.requests.where((r) => r.status == status).length,
    };

    final query = search.trim().toLowerCase();

    final filteredRequests = state.requests.where((request) {
      final matchesSearch =
          query.isEmpty ||
          request.id.toLowerCase().contains(query) ||
          request.service.label.toLowerCase().contains(query) ||
          request.address.toLowerCase().contains(query);

      final matchesStatus =
          statusFilter == null || request.status == statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();

    return AppPage(
      title: 'Operations console',
      eyebrow: 'ADMIN PORTAL',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dashboard
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: RequestStatus.values.map((status) {
              return SizedBox(
                width: 145,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${counts[status] ?? 0}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(status.label),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),

          const Text(
            'Request management',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          // Search
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search by request ID, service or address',
              suffixIcon: search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => search = '');
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() => search = value);
            },
          ),

          const SizedBox(height: 12),

          // Status filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: statusFilter == null,
                  onSelected: (_) {
                    setState(() => statusFilter = null);
                  },
                ),
                ...RequestStatus.values.map(
                  (status) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      label: Text(status.label),
                      selected: statusFilter == status,
                      onSelected: (_) {
                        setState(() => statusFilter = status);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Text(
            '${filteredRequests.length} request${filteredRequests.length == 1 ? '' : 's'}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          if (filteredRequests.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 42,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No requests found',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try changing your search or filter.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...filteredRequests.map(
              (request) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    child: Icon(
                      request.status == RequestStatus.completed
                          ? Icons.check
                          : request.status == RequestStatus.cancelled
                              ? Icons.close
                              : Icons.build_outlined,
                    ),
                  ),
                  title: Text(
                    '${request.service.label} · ${request.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      '${request.status.label} · ${request.address}',
                    ),
                  ),
                  onTap: () => _showRequestDetails(context, request),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value.startsWith('assign:')) {
  state.assignAgent(
    request,
    value.substring(7),
  ).then((success) {
    if (!success && state.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage!),
        ),
      );
    }
  });
}
                      else {
                        state.updateStatus(
                          request,
                          RequestStatus.values.byName(value),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'assign:agent2@quickserve.com',
                        child: Text('Assign agent'),
                      ),
                      const PopupMenuDivider(),
                      ...lifecycle.map(
                        (status) => PopupMenuItem(
                          value: status.name,
                          child: Text('Set ${status.label}'),
                        ),
                      ),
                      ...state.agents.map(
  (agent) => PopupMenuItem(
    value: 'assign:${agent['email']}',
    child: Text(
      agent['full_name'] ?? agent['email'],
    ),
  ),
),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

const Text(
  'Customers',
  style: TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
  ),
),

const SizedBox(height: 8),

Card(
  child: Column(
    children: state.customers.isEmpty
        ? [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No customers found'),
            ),
          ]
        : state.customers.map(
            (customer) {
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person_outline),
                ),
                title: Text(
                  customer['full_name'] ?? 'Customer',
                ),
                subtitle: Text(
                  customer['email'] ?? '',
                ),
              );
            },
          ).toList(),
  ),
),


          const SizedBox(height: 28),

          const Text(
            'Audit activity',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Card(
            child: Column(
              children: state.auditLogs.take(20).map(
                (log) {
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.history),
                    title: Text(log.eventType),
                    subtitle: Text(
                      '${log.message} · ${log.actorId}',
                    ),
                  );
                },
              ).toList(),
            ),
          ),

          const SizedBox(height: 16),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: () => state.signOut(),
          ),
        ],
      ),
    );
  }

  void _showRequestDetails(
    BuildContext context,
    ServiceRequest request,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(request.id),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.service.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Status: ${request.status.label}'),
                const SizedBox(height: 6),
                Text('Priority: ${request.priority.label}'),
                const SizedBox(height: 6),
                Text('Address: ${request.address}'),
                const SizedBox(height: 6),
                Text('Description: ${request.description}'),
                const SizedBox(height: 6),
                Text(
                  'Preferred date: '
                  '${DateFormat('d MMM yyyy').format(request.preferredDate)}',
                ),
                const SizedBox(height: 6),
                Text('Preferred time: ${request.preferredTime}'),
                if (request.assignedAgent != null) ...[
                  const SizedBox(height: 6),
                  Text('Agent: ${request.assignedAgent}'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.eyebrow,
    required this.child,
  });

  final String title;
  final String eyebrow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  eyebrow,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.1,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(child: child),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF26B4D),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOME SERVICES, MADE EASY',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Your to-do list\nstarts here.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Book trusted help in just a few taps.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF20233A),
              ),
              child: const Text('Book a service'),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceTile extends StatelessWidget {
  const ServiceTile({
    super.key,
    required this.service,
    required this.onTap,
    this.large = false,
  });

  final ServiceType service;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: large ? 180 : 120,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFFFE7DF),
                  child: Icon(
                    switch (service) {
                      ServiceType.ac => Icons.ac_unit,
                      ServiceType.plumbing => Icons.plumbing,
                      ServiceType.electrical => Icons.bolt,
                      ServiceType.cleaning => Icons.cleaning_services,
                    },
                    color: const Color(0xFFF26B4D),
                    size: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  service.label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  'From ₹${switch (service) {
                    ServiceType.ac => '499',
                    ServiceType.plumbing => '299',
                    ServiceType.electrical => '249',
                    ServiceType.cleaning => '599',
                  }}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request, required this.onTap});

  final ServiceRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFECEBFF),
                child: Icon(
                  Icons.home_repair_service,
                  color: Colors.deepPurple.shade400,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.service.label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${request.id} · ${request.status.label}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: request.status == RequestStatus.completed
                          ? 1
                          : (lifecycle.indexOf(request.status) + 1) /
                              lifecycle.length,
                      color: const Color(0xFF1E9E96),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
