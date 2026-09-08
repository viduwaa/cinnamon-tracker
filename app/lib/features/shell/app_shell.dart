import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/auth/auth_state.dart";
import "../../core/widgets/ct_widgets.dart";
import "../inbox/inbox_screen.dart";

const _roleLabels = {
  "FARMER": ("Farmer", "ගොවියා"),
  "PROCESSOR_L1": ("Processor L1", "සකසන 1"),
  "COLLECTOR": ("Collector", "එකතු"),
  "PROCESSOR_L2": ("Processor L2", "සකසන 2"),
  "EXPORTER": ("Exporter", "නිර්යාත"),
};

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final activeRole = ref.watch(activeRoleProvider);
    final user = auth is SignedIn ? auth.user : null;
    final roles = user?.roles ?? const ["FARMER"];
    // The acting role decides which tabs exist at all — switching tabs up
    // top reshapes the bottom bar to that role's workflow.
    final role =
        roles.contains(activeRole) ? activeRole : (roles.firstOrNull ?? "FARMER");
    final tabs = _tabsForRole(role);
    final location = GoRouterState.of(context).uri.path;
    var index = tabs.indexWhere((t) => location.startsWith(t.route));
    if (index < 0) index = 0;

    // Root of the app after sign-in: back must not quit on the first press.
    return CtDoubleBackExit(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _Header(name: user?.name ?? "", roles: roles, activeRole: activeRole),
              Expanded(child: child),
            ],
          ),
        ),
        floatingActionButton: role == "FARMER" && index == 0
            ? FloatingActionButton.extended(
                onPressed: () => context.push("/harvest"),
                backgroundColor: Ct.leaf,
                foregroundColor: Ct.paper,
                icon: const Icon(Icons.add),
                label: const Text("New Batch"),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => context.go(tabs[i].route),
          destinations: [
            for (final t in tabs)
              NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.selectedIcon),
                label: t.label,
              ),
          ],
        ),
      ),
    );
  }
}

/// One bottom-bar destination.
class _TabSpec {
  const _TabSpec(this.route, this.icon, this.selectedIcon, this.label);

  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Role → tabs, mirroring what each role can do server-side today:
/// farmers produce and never receive (nobody transfers TO a farmer), every
/// downstream role lives out of their inbox first.
const _farmerTabs = [
  _TabSpec("/home", Icons.home_outlined, Icons.home, "Home"),
  _TabSpec("/batches", Icons.inventory_2_outlined, Icons.inventory_2, "Batches"),
  _TabSpec("/qr", Icons.qr_code_scanner_outlined, Icons.qr_code_scanner, "QR"),
];

const _downstreamTabs = [
  _TabSpec("/home", Icons.home_outlined, Icons.home, "Home"),
  _TabSpec("/inbox", Icons.move_to_inbox_outlined, Icons.move_to_inbox, "Inbox"),
  _TabSpec("/batches", Icons.inventory_2_outlined, Icons.inventory_2, "Batches"),
  _TabSpec("/qr", Icons.qr_code_scanner_outlined, Icons.qr_code_scanner, "QR"),
];

List<_TabSpec> _tabsForRole(String role) =>
    role == "FARMER" ? _farmerTabs : _downstreamTabs;

class _Header extends ConsumerWidget {
  const _Header({
    required this.name,
    required this.roles,
    required this.activeRole,
  });

  final String name;
  final List<String> roles;
  final String activeRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final inbox = ref.watch(inboxProvider);
    final inboxItems = inbox.asData?.value ?? const <Map<String, dynamic>>[];
    final incomingRoles = inboxItems
        .map((e) => e["to_role"]?.toString())
        .whereType<String>()
        .toSet();
    return Container(
      padding: const EdgeInsets.fromLTRB(Ct.pad, 12, Ct.pad, 12),
      decoration: const BoxDecoration(
        color: Ct.cream,
        border: Border(bottom: BorderSide(color: Ct.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push("/settings"),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Ct.cinnamon,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : "?",
                    style: text.titleMedium?.copyWith(color: Ct.paper),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push("/settings"),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Ayubowan, $name!", style: text.titleMedium),
                      Text(
                        "ආයුබෝවන් · Settings & Roles",
                        style: text.labelMedium?.copyWith(color: Ct.cinnamon),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: "Settings & Account",
                onPressed: () => context.push("/settings"),
                icon: const Icon(Icons.settings_outlined, color: Ct.ink),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(roles.length > 1 ? "Acting as" : "Role:", style: text.labelMedium),
              const Spacer(),
              InkWell(
                onTap: () => context.push("/settings"),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_circle_outline, size: 14, color: Ct.cinnamon),
                    const SizedBox(width: 4),
                    Text(
                      "Add Role",
                      style: text.labelMedium?.copyWith(
                        color: Ct.cinnamon,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in roles)
                _RoleTab(
                  label: _roleLabels[r]?.$1 ?? r,
                  selected: r == activeRole,
                  hasIncoming: incomingRoles.contains(r),
                  onTap: () =>
                      ref.read(activeRoleProvider.notifier).state = r,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleTab extends StatelessWidget {
  const _RoleTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.hasIncoming = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool hasIncoming;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Ct.cinnamon : Ct.paper,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Ct.cinnamon : Ct.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected ? Ct.paper : Ct.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
            ),
            if (hasIncoming) ...[
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: selected ? Ct.quillSoft : Ct.cinnamon,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
