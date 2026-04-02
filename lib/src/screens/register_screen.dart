import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../routes.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _storeNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _usePhone = false;
  String _suggestedUsername = '';
  Timer? _debounce;
  final _authService = AuthService();

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
    _storeNameCtrl.addListener(_onStoreNameChanged);
  }

  void _onStoreNameChanged() {
    _debounce?.cancel();
    final name = _storeNameCtrl.text.trim();
    if (name.length < 2) {
      setState(() => _suggestedUsername = '');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final suggested = await _authService.suggestUsername(name);
      if (mounted && _storeNameCtrl.text.trim() == name) {
        setState(() {
          _suggestedUsername = suggested;
          if (_usernameCtrl.text.isEmpty || _usernameCtrl.text == _suggestedUsername) {
            _usernameCtrl.text = suggested;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _animCtrl.dispose();
    _storeNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.signUp(
      storeName: _storeNameCtrl.text.trim(),
      username: _usernameCtrl.text.trim().isEmpty ? null : _usernameCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacementNamed(Routes.home);
    } else {
      _showError(auth.errorMessage ?? 'Đăng ký thất bại');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.gradientPrimary),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
                    width: isWide ? 480 : double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            gradient: AppColors.gradientPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.store, size: 36, color: Colors.white),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Đăng ký cửa hàng',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tạo tài khoản dùng thử miễn phí 30 ngày',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        // Toggle email/phone
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _usePhone = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !_usePhone ? AppColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Email',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: !_usePhone ? Colors.white : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _usePhone = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _usePhone ? AppColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Số điện thoại',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: _usePhone ? Colors.white : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Store name
                              _buildLabel('Tên cửa hàng *'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _storeNameCtrl,
                                decoration: InputDecoration(
                                  hintText: 'VD: Trang trại cá ABC',
                                  prefixIcon: const Icon(Icons.store_outlined, size: 20),
                                  filled: true,
                                  fillColor: AppColors.surfaceVariant,
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập tên cửa hàng';
                                  if (v.trim().length < 2) return 'Tên cửa hàng quá ngắn';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // Suggested username
                              _buildLabel('Tên đăng nhập'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _usernameCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Tên đăng nhập cửa hàng',
                                  prefixIcon: const Icon(Icons.alternate_email, size: 20),
                                  filled: true,
                                  fillColor: AppColors.surfaceVariant,
                                  helperText: _suggestedUsername.isNotEmpty ? 'Gợi ý: $_suggestedUsername' : null,
                                  helperStyle: const TextStyle(color: AppColors.primary, fontSize: 12),
                                  suffixIcon: _suggestedUsername.isNotEmpty && _usernameCtrl.text != _suggestedUsername
                                      ? IconButton(
                                          icon: const Icon(Icons.auto_fix_high, size: 18, color: AppColors.primary),
                                          onPressed: () => setState(() => _usernameCtrl.text = _suggestedUsername),
                                          tooltip: 'Dùng gợi ý',
                                        )
                                      : null,
                                ),
                                validator: (v) {
                                  if (v != null && v.isNotEmpty && v.trim().length < 3) return 'Tên đăng nhập quá ngắn';
                                  return null;
                                },
                              ),
                              if (_suggestedUsername.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Dùng tên đăng nhập hoặc email/SĐT để đăng nhập',
                                    style: TextStyle(fontSize: 11, color: AppColors.textHint),
                                  ),
                                ),
                              const SizedBox(height: 16),

                              // Email or phone depending on toggle
                              if (!_usePhone) ...[
                                _buildLabel('Email *'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _emailCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'email@example.com',
                                    prefixIcon: const Icon(Icons.email_outlined, size: 20),
                                    filled: true,
                                    fillColor: AppColors.surfaceVariant,
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                                    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                                    if (!emailRegex.hasMatch(v.trim())) return 'Email không hợp lệ';
                                    return null;
                                  },
                                ),
                              ] else ...[
                                _buildLabel('Số điện thoại *'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _phoneCtrl,
                                  decoration: InputDecoration(
                                    hintText: '0901234567',
                                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                                    filled: true,
                                    fillColor: AppColors.surfaceVariant,
                                  ),
                                  keyboardType: TextInputType.phone,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số điện thoại';
                                    final phoneRegex = RegExp(r'^(0|\+84)[0-9]{9,10}$');
                                    if (!phoneRegex.hasMatch(v.trim())) return 'Số điện thoại không hợp lệ';
                                    return null;
                                  },
                                ),
                              ],
                              const SizedBox(height: 16),

                              // Address
                              _buildLabel('Địa chỉ'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _addressCtrl,
                                decoration: InputDecoration(
                                  hintText: 'VD: Huyện Cần Giờ, TP.HCM',
                                  prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                                  filled: true,
                                  fillColor: AppColors.surfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Password
                              _buildLabel('Mật khẩu *'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _passwordCtrl,
                                decoration: InputDecoration(
                                  hintText: '••••••',
                                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      size: 20,
                                      color: AppColors.textHint,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.surfaceVariant,
                                ),
                                obscureText: _obscurePassword,
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                                  if (v.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Confirm password
                              _buildLabel('Xác nhận mật khẩu *'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _confirmPasswordCtrl,
                                decoration: InputDecoration(
                                  hintText: '••••••',
                                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      size: 20,
                                      color: AppColors.textHint,
                                    ),
                                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.surfaceVariant,
                                ),
                                obscureText: _obscureConfirm,
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                                  if (v != _passwordCtrl.text) return 'Mật khẩu không khớp';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              // Trial info banner
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withAlpha(15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.info.withAlpha(40)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.card_giftcard, color: AppColors.info, size: 20),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Đăng ký miễn phí, dùng thử 30 ngày đầy đủ tính năng!',
                                        style: TextStyle(fontSize: 13, color: AppColors.info, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Submit button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: isLoading ? null : AppColors.gradientPrimary,
                                    borderRadius: BorderRadius.circular(12),
                                    color: isLoading ? AppColors.primary.withAlpha(100) : null,
                                  ),
                                  child: FilledButton(
                                    onPressed: isLoading ? null : _submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                          )
                                        : const Text(
                                            'Đăng ký',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Đã có tài khoản? ',
                              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pushReplacementNamed(Routes.login),
                              child: const Text(
                                'Đăng nhập',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    );
  }
}
