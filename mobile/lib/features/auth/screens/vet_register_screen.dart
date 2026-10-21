import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';

class VetRegisterScreen extends ConsumerStatefulWidget {
  const VetRegisterScreen({super.key});

  @override
  ConsumerState<VetRegisterScreen> createState() => _VetRegisterScreenState();
}

class _VetRegisterScreenState extends ConsumerState<VetRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _qualificationCtrl = TextEditingController(text: 'MVSc Animal Reproduction');
  final _specializationCtrl = TextEditingController(text: 'Bovine Infertility & Mastitis Control');
  final _experienceCtrl = TextEditingController(text: '8');
  final _feeCtrl = TextEditingController(text: '250');
  final _cityCtrl = TextEditingController(text: 'Anand');
  final _districtCtrl = TextEditingController(text: 'Anand');
  final _bioCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _licenseCtrl.dispose();
    _qualificationCtrl.dispose();
    _specializationCtrl.dispose();
    _experienceCtrl.dispose();
    _feeCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register as Vet Doctor'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff064e3b), Color(0xff047857)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.medical_services, color: Color(0xff047857), size: 28),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Join Milterra Veterinary Panel',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Provide tele-consultations to dairy farmers, write digital prescriptions & verify community cattle cases.',
                            style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Personal & Account Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xff047857)),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Doctor Full Name',
                  hintText: 'e.g. Dr. Rajesh Sharma',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter doctor name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: '10 digit mobile number',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (val) => val == null || val.trim().length < 10 ? 'Enter valid 10-digit mobile number' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Minimum 6 characters',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
              ),
              const SizedBox(height: 20),

              const Text(
                'Clinical & Professional Credentials',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xff047857)),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _licenseCtrl,
                decoration: const InputDecoration(
                  labelText: 'Veterinary Council Reg / License No',
                  hintText: 'e.g. VCI-MH-2022-492',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter valid license number' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _qualificationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Highest Qualification Degree',
                  hintText: 'e.g. BVSc & AH, MVSc Surgery, PhD Genetics',
                  prefixIcon: Icon(Icons.school_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter qualification' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _specializationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Specialization(s)',
                  hintText: 'e.g. Bovine Infertility, Mastitis, Nutrition',
                  prefixIcon: Icon(Icons.health_and_safety_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _experienceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Experience (Years)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _feeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Consult Fee (₹)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Clinic City',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _districtCtrl,
                      decoration: const InputDecoration(
                        labelText: 'District',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Bio / Hospital details (Optional)',
                  hintText: 'e.g. Chief Surgeon at District Veterinary Polyclinic',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submitVetRegistration,
                  icon: const Icon(Icons.verified),
                  label: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Complete Doctor Registration & Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff047857),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitVetRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final dio = ref.read(dioProvider);

    try {
      final name = _nameCtrl.text.trim();
      final formattedName = name.startsWith('Dr.') ? name : 'Dr. $name';
      final phone = _phoneCtrl.text.trim();
      final password = _passwordCtrl.text.trim();

      // 1. Register customer account with role 'vet'
      await ref.read(authProvider.notifier).registerWithPassword(
        phone,
        password,
        displayName: formattedName,
      );

      // 2. Register veterinary clinical profile
      await dio.post('/vets/register', data: {
        'license_number': _licenseCtrl.text.trim(),
        'qualification': _qualificationCtrl.text.trim(),
        'specializations': _specializationCtrl.text.split(',').map((s) => s.trim()).toList(),
        'experience_years': int.tryParse(_experienceCtrl.text.trim()) ?? 5,
        'consultation_fee': double.tryParse(_feeCtrl.text.trim()) ?? 250.0,
        'city': _cityCtrl.text.trim(),
        'district': _districtCtrl.text.trim(),
        'bio': _bioCtrl.text.trim().isNotEmpty ? _bioCtrl.text.trim() : null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Doctor profile registered successfully! Welcome to Milterra Vet Panel.'),
          backgroundColor: Color(0xff047857),
        ),
      );

      // Navigate to Vet Doctor Dashboard
      context.go('/vet-dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
