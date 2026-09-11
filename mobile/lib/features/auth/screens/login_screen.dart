import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../marketplace/widgets/store_design.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.initialTab = 0});

  /// 0 = Sign In, 1 = Create Account / Register
  final int initialTab;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sign In fields
  final _signInFormKey = GlobalKey<FormState>();
  final _signInUserCtrl = TextEditingController();
  final _signInPassCtrl = TextEditingController();
  bool _obscureSignInPass = true;

  // Register fields
  final _registerFormKey = GlobalKey<FormState>();
  final _regNameCtrl = TextEditingController();
  final _regUserCtrl = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  bool _obscureRegPass = true;
  String _selectedRole = 'customer';

  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signInUserCtrl.dispose();
    _signInPassCtrl.dispose();
    _regNameCtrl.dispose();
    _regUserCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regPassCtrl.dispose();
    super.dispose();
  }

  void _onSuccessNavigate() {
    final nextPath =
        GoRouterState.of(context).uri.queryParameters['next'] ?? '/shop';
    if (mounted) {
      context.go(nextPath);
    }
  }

  Future<void> _handleSignIn() async {
    setState(() => _errorMessage = null);
    if (!_signInFormKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final success = await ref.read(authProvider.notifier).loginWithPassword(
            username: _signInUserCtrl.text.trim(),
            password: _signInPassCtrl.text,
          );
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: storeGreen,
              content: Text('Welcome back to Milterra!'),
            ),
          );
          _onSuccessNavigate();
        }
      } else {
        setState(() => _errorMessage = 'Invalid username or password.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Sign in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRegister() async {
    setState(() => _errorMessage = null);
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final success = await ref.read(authProvider.notifier).register(
            name: _regNameCtrl.text.trim(),
            username: _regUserCtrl.text.trim(),
            password: _regPassCtrl.text,
            phone: _regPhoneCtrl.text.trim(),
            role: _selectedRole,
          );
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: storeGreen,
              content: Text('Account created successfully! Welcome to Milterra.'),
            ),
          );
          _onSuccessNavigate();
        }
      } else {
        setState(() => _errorMessage = 'Registration could not be completed.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Registration failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _quickLogin(String username, String password, String name) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authProvider.notifier).loginWithPassword(
            username: username,
            password: password,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: storeGreen,
            content: Text('Logged in as $name'),
          ),
        );
        _onSuccessNavigate();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          // Store Header
          const StoreHeader(currentCategory: 'All'),
          const StoreCategoryNavigation(selected: 'Account'),

          // Form Body
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 36),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(StoreLayout.radius),
                            side: const BorderSide(color: storeBorder),
                          ),
                          color: storeWhite,
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Logo & Header
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: storeGreen.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.spa_outlined,
                                          color: storeGreen, size: 28),
                                    ),
                                    const SizedBox(width: 12),
                                    const Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Milterra Direct',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: storeGreen,
                                          ),
                                        ),
                                        Text(
                                          'Pure Dairy Marketplace & Farm Services',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: storeMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Tab Bar: Sign In vs Create Account
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xfff0eee6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: TabBar(
                                    controller: _tabController,
                                    indicator: BoxDecoration(
                                      color: storeGreen,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    indicatorSize: TabBarIndicatorSize.tab,
                                    labelColor: storeWhite,
                                    unselectedLabelColor: storeMuted,
                                    labelStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    tabs: const [
                                      Tab(text: 'Sign In'),
                                      Tab(text: 'Create Account'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                if (_errorMessage != null) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xfffff3f3),
                                      border: Border.all(
                                          color: const Color(0xffd9534f)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline,
                                            color: Color(0xffd9534f), size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: const TextStyle(
                                              color: Color(0xffd9534f),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Forms Container
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeInOut,
                                  height:
                                      _tabController.index == 0 ? 310.0 : 450.0,
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [
                                      // Tab 1: Sign In
                                      _buildSignInForm(),

                                      // Tab 2: Register / Create Account
                                      _buildRegisterForm(),
                                    ],
                                  ),
                                ),

                                const Divider(),
                                const SizedBox(height: 12),

                                // Quick Demo Credentials Bar
                                const Text(
                                  'Quick Demo Access:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: storeMuted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ActionChip(
                                      avatar: const Icon(Icons.person,
                                          size: 16, color: storeGreen),
                                      label: const Text('Customer Demo',
                                          style: TextStyle(fontSize: 12)),
                                      backgroundColor:
                                          storeGreen.withValues(alpha: 0.08),
                                      onPressed: _loading
                                          ? null
                                          : () => _quickLogin(
                                                'customer@milterra.in',
                                                'password123',
                                                'Milterra Customer',
                                              ),
                                    ),
                                    ActionChip(
                                      avatar: const Icon(Icons.agriculture,
                                          size: 16, color: storeGreen),
                                      label: const Text('Farmer Demo',
                                          style: TextStyle(fontSize: 12)),
                                      backgroundColor:
                                          storeGreen.withValues(alpha: 0.08),
                                      onPressed: _loading
                                          ? null
                                          : () => _quickLogin(
                                                'ramesh_farmer',
                                                'password123',
                                                'Ramesh Choudhary (Farmer)',
                                              ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  const StoreFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInForm() {
    return Form(
      key: _signInFormKey,
      child: ListView(
        children: [
          const Text(
            'Username or Email',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xff111111),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _signInUserCtrl,
            decoration: InputDecoration(
              hintText: 'Enter your username or email',
              prefixIcon: const Icon(Icons.person_outline, size: 20),
              filled: true,
              fillColor: storeWhite,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: storeBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: storeBorder),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your username or email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          const Text(
            'Password',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xff111111),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _signInPassCtrl,
            obscureText: _obscureSignInPass,
            decoration: InputDecoration(
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureSignInPass ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureSignInPass = !_obscureSignInPass),
              ),
              filled: true,
              fillColor: storeWhite,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: storeBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: storeBorder),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: storeAmber,
                foregroundColor: storeGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: _loading ? null : _handleSignIn,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: storeGreen),
                    )
                  : const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text(
                'New to Milterra? Create an account',
                style: TextStyle(
                  color: storeGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: ListView(
        children: [
          const Text(
            'Full Name',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xff111111),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _regNameCtrl,
            decoration: InputDecoration(
              hintText: 'First and last name',
              prefixIcon: const Icon(Icons.badge_outlined, size: 20),
              filled: true,
              fillColor: storeWhite,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: storeBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: storeBorder),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your full name';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          const Text(
            'Username or Email',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xff111111),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _regUserCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. yourname@gmail.com or username',
              prefixIcon: const Icon(Icons.person_outline, size: 20),
              filled: true,
              fillColor: storeWhite,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: storeBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: storeBorder),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter a username or email';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          const Text(
            'Mobile Number',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xff111111),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _regPhoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: '10-digit mobile number',
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              filled: true,
              fillColor: storeWhite,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: storeBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: storeBorder),
              ),
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'Password',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xff111111),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _regPassCtrl,
            obscureText: _obscureRegPass,
            decoration: InputDecoration(
              hintText: 'At least 6 characters',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureRegPass ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureRegPass = !_obscureRegPass),
              ),
              filled: true,
              fillColor: storeWhite,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: storeBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: storeBorder),
              ),
            ),
            validator: (val) {
              if (val == null || val.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          const Text(
            'Account Role',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xff111111),
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: storeWhite,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: storeBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: storeBorder),
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'customer',
                child: Text(
                  '🥛 Customer (Household & Gourmet)',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'farmer',
                child: Text(
                  '🌾 Dairy Farmer / Cattle Owner',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedRole = val);
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: storeAmber,
                foregroundColor: storeGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: _loading ? null : _handleRegister,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: storeGreen),
                    )
                  : const Text(
                      'Create Your Milterra Account',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => _tabController.animateTo(0),
              child: const Text(
                'Already have an account? Sign in',
                style: TextStyle(
                  color: storeGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
