import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/chat/models/chat_models.dart';

/// User profile screen with personal info, language preferences,
/// notification settings, and logout.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  bool _notifyHealth = true;
  bool _notifyVaccination = true;
  bool _notifyConsultation = true;
  bool _notifyPayment = true;

  late TextEditingController _nameController;
  late TextEditingController _villageController;
  late TextEditingController _districtController;
  late TextEditingController _stateController;
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _villageController = TextEditingController();
    _districtController = TextEditingController();
    _stateController = TextEditingController();

    // Populate from current user data.
    Future.microtask(() {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        _nameController.text = user.name ?? '';
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _villageController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit profile',
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user == null) ...[
              Card(
                color: const Color(0xfffbf7ee),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xffe8e4da)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.account_circle_outlined,
                          size: 52, color: DairyTheme.primaryGreen),
                      const SizedBox(height: 12),
                      const Text(
                        'Welcome to Milterra',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: DairyTheme.primaryGreen),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in or create an account to view your orders, addresses, and wishlist.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: DairyTheme.subtleGrey),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DairyTheme.primaryGreen,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => context.go('/login'),
                            child: const Text('Sign In'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: DairyTheme.primaryGreen,
                              side: const BorderSide(
                                  color: DairyTheme.primaryGreen),
                            ),
                            onPressed: () => context.go('/register'),
                            child: const Text('Create Account'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              // Profile header.
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor:
                          DairyTheme.primaryGreen.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.person_outline,
                        size: 48,
                        color: DairyTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.name ?? 'Customer',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.phone,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: DairyTheme.subtleGrey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: DairyTheme.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user.role.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: DairyTheme.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Account & Commerce Hub shortcuts
            _buildAccountQuickHub(context),
            const SizedBox(height: 24),

            // Personal information section.
            const _SectionHeader(title: 'Personal Information'),
            const SizedBox(height: 12),
            _isEditing
                ? _buildEditableFields()
                : _buildReadOnlyFields(user),

            const SizedBox(height: 24),

            // Language preference.
            const _SectionHeader(title: 'Language Preference'),
            const SizedBox(height: 12),
            _buildLanguageSelector(theme),

            const SizedBox(height: 24),

            // Notification settings.
            const _SectionHeader(title: 'Notification Settings'),
            const SizedBox(height: 12),
            _buildNotificationSettings(),

            const SizedBox(height: 24),

            // App info.
            const _SectionHeader(title: 'About'),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('App Version'),
                    trailing: Text(
                      '1.0.0',
                      style: TextStyle(color: DairyTheme.subtleGrey),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms & Conditions'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: Navigate to terms screen.
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: Navigate to privacy policy screen.
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout button.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: DairyTheme.errorRed),
                label: const Text(
                  'Logout',
                  style: TextStyle(color: DairyTheme.errorRed),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: DairyTheme.errorRed),
                ),
                onPressed: () => _showLogoutConfirmation(context),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountQuickHub(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Milterra Account & Commerce'),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: DairyTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long_outlined,
                      color: DairyTheme.primaryGreen),
                ),
                title: const Text('Your Orders',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Track packages, review past dairy & feed orders'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/marketplace/orders'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xfffef3d6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_balance_wallet_outlined,
                      color: Color(0xffb7791f)),
                ),
                title: const Text('Milterra Wallet & Milk Payouts',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('₹4,850 Available · Milk earnings & store credit'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/balance'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.location_on_outlined,
                      color: Colors.blue),
                ),
                title: const Text('Delivery Addresses',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Edit saved home & farm addresses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/marketplace/addresses'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.favorite_border,
                      color: Colors.redAccent),
                ),
                title: const Text('Your Wishlist',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Saved items, favorites & price alerts'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/wishlist'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.help_outline, color: Colors.teal),
                ),
                title: const Text('Help & Customer Support',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('FAQs, order returns & helpline'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/help'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.storefront_outlined,
                      color: Colors.purple),
                ),
                title: const Text('Continue Shopping',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle:
                    const Text('Explore gourmet dairy, feed & farm machinery'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/shop'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyFields(dynamic user) {
    return Card(
      child: Column(
        children: [
          _InfoTile(
            icon: Icons.person_outline,
            label: 'Name',
            value: user?.name ?? 'Not set',
          ),
          const Divider(height: 1),
          _InfoTile(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: user?.phone ?? 'Not set',
          ),
          const Divider(height: 1),
          _InfoTile(
            icon: Icons.location_on_outlined,
            label: 'Village',
            value: _villageController.text.isEmpty
                ? 'Not set'
                : _villageController.text,
          ),
          const Divider(height: 1),
          _InfoTile(
            icon: Icons.map_outlined,
            label: 'District',
            value: _districtController.text.isEmpty
                ? 'Not set'
                : _districtController.text,
          ),
          const Divider(height: 1),
          _InfoTile(
            icon: Icons.flag_outlined,
            label: 'State',
            value: _stateController.text.isEmpty
                ? 'Not set'
                : _stateController.text,
          ),
        ],
      ),
    );
  }

  Widget _buildEditableFields() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _villageController,
              decoration: const InputDecoration(
                labelText: 'Village',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _districtController,
              decoration: const InputDecoration(
                labelText: 'District',
                prefixIcon: Icon(Icons.map_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stateController,
              decoration: const InputDecoration(
                labelText: 'State',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ChatLanguage.supported.map((lang) {
            final isSelected = lang.code == _selectedLanguage;
            return ChoiceChip(
              label: Text(lang.nativeName),
              selected: isSelected,
              selectedColor: DairyTheme.primaryGreen.withValues(alpha: 0.2),
              checkmarkColor: DairyTheme.primaryGreen,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedLanguage = lang.code);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.warning_amber_rounded,
                color: DairyTheme.errorRed),
            title: const Text('Health Alerts'),
            subtitle: const Text('Cattle health warnings'),
            value: _notifyHealth,
            activeTrackColor: DairyTheme.primaryGreen.withValues(alpha: 0.5),
            onChanged: (v) => setState(() => _notifyHealth = v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.vaccines_outlined,
                color: DairyTheme.accentOrange),
            title: const Text('Vaccination Reminders'),
            subtitle: const Text('Upcoming and overdue vaccinations'),
            value: _notifyVaccination,
            activeTrackColor: DairyTheme.primaryGreen.withValues(alpha: 0.5),
            onChanged: (v) => setState(() => _notifyVaccination = v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.video_call_outlined,
                color: DairyTheme.primaryGreen),
            title: const Text('Consultation Updates'),
            subtitle: const Text('Vet call and prescription updates'),
            value: _notifyConsultation,
            activeTrackColor: DairyTheme.primaryGreen.withValues(alpha: 0.5),
            onChanged: (v) => setState(() => _notifyConsultation = v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.currency_rupee,
                color: Color(0xFF1565C0)),
            title: const Text('Payment Notifications'),
            subtitle: const Text('Transaction and payment alerts'),
            value: _notifyPayment,
            activeTrackColor: DairyTheme.primaryGreen.withValues(alpha: 0.5),
            onChanged: (v) => setState(() => _notifyPayment = v),
          ),
        ],
      ),
    );
  }

  void _saveProfile() {
    // TODO: Call PATCH /farmers/{id} to update profile.
    setState(() => _isEditing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: DairyTheme.errorRed),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header.
// ---------------------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Read-only info tile.
// ---------------------------------------------------------------------------
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: DairyTheme.primaryGreen),
      title: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: DairyTheme.subtleGrey,
        ),
      ),
      subtitle: Text(
        value,
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}
