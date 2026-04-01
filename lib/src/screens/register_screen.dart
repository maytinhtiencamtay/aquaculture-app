import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../routes.dart';
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
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _usePhone = false;

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
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _storeNameCtrl.dispose();
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
                          'Tạo tài khoản để quản lý nuôi trồng thủy sản',
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
