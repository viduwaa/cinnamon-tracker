import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/auth/auth_state.dart";

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

  int _indexFromLocation(String location) {
    if (location.startsWith("/batches")) return 1;
    if (location.startsWith("/qr")) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final activeRole = ref.watch(activeRoleProvider);
    final user = auth is SignedIn ? auth.user : null;
    final roles = user?.roles ?? const ["FARMER"];
    final location = GoRouterState.of(context).uri.path;
    final index = _indexFromLocation(location);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(name: user?.name ?? "", roles: roles, activeRole: activeRole),
            Expanded(child: child),
          ],
        ),
      ),
      floatingActionButton: activeRole == "FARMER" && index == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.go("/harvest"),
              backgroundColor: Ct.leaf,
              foregroundColor: Ct.paper,
              icon: const Icon(Icons.add),
              label: const Text("New Batch"),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go("/home");
            case 1:
              context.go("/batches");
            case 2:
              context.go("/qr");
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: "Home",
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: "Batches",
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: "QR",
          ),
        ],
      ),
    );
  }
}

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
              CircleAvatar(
                radius: 20,
                backgroundColor: Ct.cinnamon,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : "?",
                  style: text.titleMedium?.copyWith(color: Ct.paper),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Ayubowan, $name!", style: text.titleMedium),
                    Text(
                      "ආයුබෝවන්",
                      style: text.labelMedium?.copyWith(color: Ct.faded),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  ref.read(authProvider.notifier).signOut();
                  context.go("/register");
                },
                icon: const Icon(Icons.logout, color: Ct.faded),
              ),
            ],
          ),
          if (roles.length > 1) ...[
            const SizedBox(height: 12),
            Text("Acting as", style: text.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in roles)
                  _RoleTab(
                    label: _roleLabels[r]?.$1 ?? r,
                    selected: r == activeRole,
                    onTap: () =>
                        ref.read(activeRoleProvider.notifier).state = r,
                  ),
              ],
            ),
          ],
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

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
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: selected ? Ct.paper : Ct.ink,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
        ),
      ),
    );
  }
}
