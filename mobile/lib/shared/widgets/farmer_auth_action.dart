import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/shared/widgets/farmer_responsive.dart';

/// Responsive authentication action button for AppBars across the portal.
///
/// Behavior:
/// - **When Unauthenticated**:
///   - On Desktop/Tablet (>= 640px): Prominent button labeled 'लॉगिन / Sign In'.
///   - On Mobile (< 640px): Compact, thumb-friendly chip labeled 'Sign In' with login icon.
///   - On tap: routes to `/login?next=<current_route>`.
/// - **When Authenticated**:
///   - Displays the farmer's initial/avatar badge with name.
///   - Tapping opens a sleek popup menu with farmer details, direct Profile navigation,
///     and a 1-tap Sign Out confirmation dialog.
class FarmerAuthAction extends ConsumerWidget {
  final String? nextRoute;
  final Color? color;

  const FarmerAuthAction({
    super.key,
    this.nextRoute,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = ref.watch(currentUserProvider);
    final isAuthenticated = authState.maybeWhen(
      authenticated: (_) => true,
      orElse: () => false,
    );

    final isMobile = FarmerBreakpoints.isMobile(context);
    final targetRoute = nextRoute ?? '/home';

    if (!isAuthenticated) {
      final isDarkBg = color != null && color == Colors.white;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            backgroundColor: isDarkBg
                ? Colors.white.withValues(alpha: 0.18)
                : const Color(0xff064e3b).withValues(alpha: 0.12),
            foregroundColor: color ?? const Color(0xff064e3b),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 14,
              vertical: isMobile ? 4 : 8,
            ),
            minimumSize: Size(0, isMobile ? 34 : 38),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          icon: Icon(
            Icons.login_rounded,
            size: isMobile ? 15 : 16,
            color: color ?? const Color(0xff064e3b),
          ),
          label: Text(
            isMobile ? 'Sign In' : 'लॉगिन / Sign In',
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              fontWeight: FontWeight.bold,
              color: color ?? const Color(0xff064e3b),
            ),
          ),
          onPressed: () => context.push('/login?next=$targetRoute'),
        ),
      );
    }

    // Authenticated Farmer Avatar + Popup
    final displayName = user?.name?.trim().isNotEmpty == true
        ? user!.name!.trim()
        : (user?.phone.isNotEmpty == true ? user!.phone : 'Farmer');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'F';

    return PopupMenuButton<String>(
      tooltip: 'खाता / Account ($displayName)',
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: isMobile ? 14 : 16,
              backgroundColor: color == Colors.white
                  ? Colors.white
                  : const Color(0xff064e3b),
              foregroundColor: color == Colors.white
                  ? const Color(0xff064e3b)
                  : Colors.white,
              child: Text(
                initial,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 12 : 13,
                ),
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  displayName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: color ?? Colors.black87,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: color ?? Colors.black54,
              ),
            ],
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xff064e3b),
                ),
              ),
              if (user?.phone.isNotEmpty == true)
                Text(
                  user!.phone,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              const Divider(height: 16),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 20, color: Color(0xff064e3b)),
              SizedBox(width: 10),
              Text('किसान प्रोफ़ाइल (Profile)'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20, color: Color(0xffdc2626)),
              SizedBox(width: 10),
              Text(
                'लॉग आउट (Sign Out)',
                style: TextStyle(
                  color: Color(0xffdc2626),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        if (value == 'profile') {
          context.push('/more/profile');
        } else if (value == 'logout') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('साइन आउट करें? / Sign Out?'),
              content: const Text(
                'क्या आप वाकई इस डिवाइस से लॉग आउट करना चाहते हैं?\n(Are you sure you want to sign out?)',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('रद्द करें / Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffdc2626),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('लॉग आउट / Sign Out'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('सफलतापूर्वक लॉग आउट किया गया (Signed out)'),
                ),
              );
              context.go('/home');
            }
          }
        }
      },
    );
  }
}
