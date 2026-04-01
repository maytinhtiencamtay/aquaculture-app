import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../routes.dart';
import '../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _codeSent = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

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
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.forgotPassword(email: _emailCtrl.text.trim());

    if (!mounted) return;

    if (success) {
      setState(() => _codeSent = true);
      _showMessage('Mã xác nhận đã được gửi', isError: false);
    } else {
      _showMessage(auth.errorMessage ?? 'Không thể gửi mã xác nhận');
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.resetPassword(
      email: _emailCtrl.text.trim(),
      code: _codeCtrl.text.trim(),
      newPassword: _newPasswordCtrl.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      _showMessage('Đổi mật khẩu thành công! Vui lòng đăng nhập lại.', isError: false);
      Navigator.of(context).pushReplacementNamed(Routes.login);
    } else {
      _showMessage(auth.errorMessage ?? 'Đổi mật khẩu thất bại');
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
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
                    width: isWide ? 440 : double.infinity,
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
                          child: const Icon(Icons.lock_reset, size: 36, color: Colors.white),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Quên mật khẩu',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _codeSent
                              ? 'Nhập mã xác nhận và mật khẩu mới'
                              : 'Nhập email hoặc số điện thoại để lấy lại mật khẩu',
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Email / Phone
                              const Text(
                                'Email hoặc số điện thoại',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _emailCtrl,
                                enabled: !_codeSent,
                                decoration: InputDecoration(
                                  hintText: 'email@example.com hoặc 0901234567',
                                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                                  filled: true,
                                  fillColor: _codeSent ? AppColors.surfaceVariant.withAlpha(150) : AppColors.surfaceVariant,
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email hoặc số điện thoại';
                                  return null;
                                },
                              ),

                              if (_codeSent) ...[
                                const SizedBox(height: 16),
                                const Text(
                                  'Mã xác nhận',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _codeCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'Nhập mã 6 chữ số',
                                    prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                                    filled: true,
                                    fillColor: AppColors.surfaceVariant,
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Vui lòng nhập mã xác nhận';
                                    if (v.trim().length != 6) return 'Mã xác nhận phải có 6 chữ số';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Mật khẩu mới',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _newPasswordCtrl,
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
                                    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu mới';
                                    if (v.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Xác nhận mật khẩu mới',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
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
                                    if (v != _newPasswordCtrl.text) return 'Mật khẩu không khớp';
                                    return null;
                                  },
                                ),
                              ],
                              const SizedBox(height: 24),

                              // Action button
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
                                    onPressed: isLoading ? null : (_codeSent ? _resetPassword : _sendCode),
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
                                        : Text(
                                            _codeSent ? 'Đổi mật khẩu' : 'Gửi mã xác nhận',
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                                          ),
                                  ),
                                ),
                              ),

                              if (_codeSent) ...[
                                const SizedBox(height: 12),
                                Center(
                                  child: TextButton(
                                    onPressed: isLoading ? null : _sendCode,
                                    child: const Text('Gửi lại mã xác nhận', style: TextStyle(fontSize: 13)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).pushReplacementNamed(Routes.login),
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Quay lại đăng nhập', style: TextStyle(fontSize: 14)),
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
}
