import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../app/theme.dart";
import "../../core/auth/auth_state.dart";
import "../../core/auth/biometric_service.dart";
import "../../core/sync/sync_worker.dart";
import "../../core/widgets/ct_widgets.dart";

class RoleDefinition {
  const RoleDefinition({
    required this.code,
    required this.en,
    required this.si,
    required this.icon,
    required this.description,
    required this.color,
  });

  final String code;
  final String en;
  final String si;
  final IconData icon;
  final String description;
  final Color color;
}

const List<RoleDefinition> allRoleDefinitions = [
  RoleDefinition(
    code: "FARMER",
    en: "Farmer",
    si: "කුරුඳු ගොවියා",
    icon: Icons.grass_outlined,
    description: "Harvests cinnamon trees or quills from registered farms and originates root batches.",
    color: Ct.leaf,
  ),
  RoleDefinition(
    code: "PROCESSOR_L1",
    en: "Processor L1",
    si: "පළමු මට්ටමේ සකසන්නා",
    icon: Icons.precision_manufacturing_outlined,
    description: "Peeling, quilling, scraping, and field-level primary processing.",
    color: Ct.cinnamon,
  ),
  RoleDefinition(
    code: "COLLECTOR",
    en: "Collector",
    si: "එකතු කරන්නා / අතරමැදියා",
    icon: Icons.local_shipping_outlined,
    description: "Collects and aggregates cinnamon batches across farms for delivery to processors/exporters.",
    color: Ct.quill,
  ),
  RoleDefinition(
    code: "PROCESSOR_L2",
    en: "Processor L2",
    si: "දෙවන මට්ටමේ සකසන්නා",
    icon: Icons.factory_outlined,
    description: "Grading, value addition, packaging, oil extraction, and quality grading.",
    color: Ct.cinnamon,
  ),
  RoleDefinition(
    code: "EXPORTER",
    en: "Exporter",
    si: "නිර්යාතකයා",
    icon: Icons.flight_takeoff_outlined,
    description: "Merges candidate batches into export lots with international traceability certification.",
    color: Ct.bark,
  ),
];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _addingRole = false;

  Future<void> _addRole(RoleDefinition role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ct.radius)),
        title: Text("Add ${role.en} Role?", style: Theme.of(context).textTheme.titleLarge),
        content: Text(
          "This will grant your account permissions to perform actions as a ${role.en} (${role.si}).",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          CtButton(
            label: "Add Role",
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _addingRole = true);
    try {
      await ref.read(authProvider.notifier).addRole(role.code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Role '${role.en}' successfully added!"),
            backgroundColor: Ct.leaf,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not add role: ${e.toString()}"),
            backgroundColor: Ct.clay,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _addingRole = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ct.radius)),
        title: Text("Log Out?", style: Theme.of(context).textTheme.titleLarge),
        content: const Text(
          "Are you sure you want to log out of Cinnamon Trace on this device? Your offline drafts will be preserved.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          CtButton(
            label: "Log Out",
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).signOut();
      if (mounted) context.go("/register");
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final textTheme = Theme.of(context).textTheme;
    final user = auth is SignedIn ? auth.user : null;
    final userRoles = user?.roles ?? const <String>[];

    final unassignedRoles = allRoleDefinitions.where(
      (r) => !userRoles.contains(r.code),
    ).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Ct.ink),
          onPressed: () => context.pop(),
        ),
        title: Text("Settings & Account", style: textTheme.titleLarge),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Ct.pad),
          children: [
            // User Profile Card
            CtCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Ct.cinnamon,
                    child: Text(
                      user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : "?",
                      style: textTheme.headlineMedium?.copyWith(
                        color: Ct.paper,
                        fontFamily: Ct.display,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? "User",
                          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.verified, size: 16, color: Ct.leaf),
                            const SizedBox(width: 4),
                            Text(
                              user?.mobile ?? "",
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Ct.ink,
                              ),
                            ),
                          ],
                        ),
                        if (user?.email != null && user!.email!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            user.email!,
                            style: textTheme.labelMedium?.copyWith(color: Ct.faded),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Active Roles Section
            Text("Active Roles", style: textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              "You can switch between your active roles using the top banner on the Home screen.",
              style: textTheme.bodyMedium?.copyWith(color: Ct.faded),
            ),
            const SizedBox(height: 12),
            for (final roleCode in userRoles) ...[
              _ActiveRoleCard(
                role: allRoleDefinitions.firstWhere(
                  (r) => r.code == roleCode,
                  orElse: () => RoleDefinition(
                    code: roleCode,
                    en: roleCode,
                    si: "",
                    icon: Icons.badge_outlined,
                    description: "",
                    color: Ct.cinnamon,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            const SizedBox(height: 24),

            // Add Roles Section
            if (unassignedRoles.isNotEmpty) ...[
              Text("Add a Role", style: textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                "Expand your operation by adding roles to your existing account.",
                style: textTheme.bodyMedium?.copyWith(color: Ct.faded),
              ),
              const SizedBox(height: 12),
              if (_addingRole)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator(color: Ct.cinnamon)),
                )
              else
                for (final role in unassignedRoles) ...[
                  _UnassignedRoleCard(
                    role: role,
                    onAdd: () => _addRole(role),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 24),
            ],

            // Biometric Security Card
            const _BiometricSection(),
            const SizedBox(height: 24),

            // Offline Sync Card
            const _SyncSection(),
            const SizedBox(height: 24),

            // Logout Section
            CtCard(
              color: Ct.claySoft,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.logout, color: Ct.clay, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        "Account Security",
                        style: textTheme.titleMedium?.copyWith(color: Ct.clay),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Logging out requires verifying your mobile number with a new OTP code upon your next sign-in.",
                    style: textTheme.bodyMedium?.copyWith(color: Ct.faded),
                  ),
                  const SizedBox(height: 14),
                  CtButton(
                    label: "Log Out",
                    icon: Icons.exit_to_app,
                    secondary: true,
                    onPressed: _confirmLogout,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _ActiveRoleCard extends StatelessWidget {
  const _ActiveRoleCard({required this.role});
  final RoleDefinition role;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return CtCard(
      color: Ct.leafSoft,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: role.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(role.icon, color: role.color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(role.en, style: textTheme.titleMedium),
                    const SizedBox(width: 6),
                    Expanded(
                      child: CtMarqueeText(
                        text: "· ${role.si}",
                        style: textTheme.labelMedium?.copyWith(color: Ct.faded),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  role.description,
                  style: textTheme.bodySmall?.copyWith(color: Ct.faded),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Ct.leaf,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "Active",
              style: textTheme.labelSmall?.copyWith(
                color: Ct.paper,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnassignedRoleCard extends StatelessWidget {
  const _UnassignedRoleCard({required this.role, required this.onAdd});
  final RoleDefinition role;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return CtCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Ct.cream,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(role.icon, color: Ct.faded, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(role.en, style: textTheme.titleMedium),
                    const SizedBox(width: 6),
                    Expanded(
                      child: CtMarqueeText(
                        text: "· ${role.si}",
                        style: textTheme.labelMedium?.copyWith(color: Ct.faded),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  role.description,
                  style: textTheme.bodySmall?.copyWith(color: Ct.faded),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle, color: Ct.cinnamon, size: 30),
            tooltip: "Add ${role.en} role",
          ),
        ],
      ),
    );
  }
}

class _SyncSection extends ConsumerWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCountAsync = ref.watch(pendingSyncCountProvider);
    final count = pendingCountAsync.maybeWhen(data: (c) => c, orElse: () => 0);
    final textTheme = Theme.of(context).textTheme;

    return CtCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            count > 0 ? Icons.sync_problem : Icons.cloud_done,
            color: count > 0 ? Ct.quill : Ct.leaf,
            size: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Offline Sync Engine", style: textTheme.titleMedium),
                Text(
                  count > 0 ? "$count item(s) pending sync" : "All local data synchronized",
                  style: textTheme.bodySmall?.copyWith(color: Ct.faded),
                ),
              ],
            ),
          ),
          if (count > 0)
            TextButton(
              onPressed: () => ref.read(syncWorkerProvider).drain(),
              child: const Text("Sync Now"),
            ),
        ],
      ),
    );
  }
}

class _BiometricSection extends ConsumerStatefulWidget {
  const _BiometricSection();

  @override
  ConsumerState<_BiometricSection> createState() => _BiometricSectionState();
}

class _BiometricSectionState extends ConsumerState<_BiometricSection> {
  bool _toggling = false;

  Future<void> _onToggle(bool enable) async {
    setState(() => _toggling = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (enable) {
        final success = await ref.read(biometricProvider.notifier).enableBiometrics();
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? "Fingerprint login enabled / ඇඟිලි සලකුණු පිවිසුම සක්‍රිය කරන ලදී"
                    : "Biometric confirmation cancelled / ක්‍රියාවලිය අවලංගු විය",
              ),
              backgroundColor: success ? Ct.leaf : Ct.clay,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await ref.read(biometricProvider.notifier).disableBiometrics();
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text("Fingerprint login disabled / ඇඟිලි සලකුණු පිවිසුම අක්‍රිය කරන ලදී"),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bioState = ref.watch(biometricProvider);
    final textTheme = Theme.of(context).textTheme;

    return CtCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Ct.cinnamon.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  color: Ct.cinnamon,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Fingerprint Lock", style: textTheme.titleMedium),
                    Text(
                      "ඇඟිලි සලකුණු අගුල",
                      style: textTheme.labelSmall?.copyWith(color: Ct.faded),
                    ),
                  ],
                ),
              ),
              if (bioState.isSupported)
                _toggling
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Ct.cinnamon),
                      )
                    : Switch.adaptive(
                        value: bioState.isEnabled,
                        activeTrackColor: Ct.cinnamon,
                        onChanged: _onToggle,
                      )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Ct.faded.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "Unavailable",
                    style: textTheme.labelSmall?.copyWith(color: Ct.faded),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            bioState.isSupported
                ? "Prompt for fingerprint to unlock Cinnamon Trace on cold start."
                : "Biometric hardware is not available or no fingerprint is enrolled on this device.",
            style: textTheme.bodySmall?.copyWith(color: Ct.faded),
          ),
          Text(
            bioState.isSupported
                ? "යෙදුම විවෘත කිරීමේදී ඔබගේ ඇඟිලි සලකුණෙන් අගුළු හරින්න."
                : "මෙම දුරකථනයේ ඇඟිලි සලකුණු පහසුකම සක්‍රිය කර නොමැත.",
            style: textTheme.bodySmall?.copyWith(color: Ct.faded),
          ),
        ],
      ),
    );
  }
}
