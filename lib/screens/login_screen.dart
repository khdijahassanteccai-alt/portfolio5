import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _licenseCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _licenseCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final entered = _licenseCtrl.text.trim();
    if (entered.isEmpty) {
      _showError('الرجاء إدخال رمز الترخيص');
      return;
    }
    if (entered != AppConfig.licenseKey) {
      _showError('رمز غير صحيح');
      return;
    }

    setState(() => _loading = true);
    try {
      final auth = AuthService();
      final doctor = await auth.ensureConfigDoctor();
      auth.setDoctor(doctor);
      await auth.persistLogin(doctor.id!);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('حدث خطأ، حاول مجدداً');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.cairo(), textAlign: TextAlign.right),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryDark, AppTheme.primary, AppTheme.accent],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 40),
                    _buildLoginCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.local_hospital_rounded,
              size: 64, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(
          AppConfig.clinicName,
          style: GoogleFonts.cairo(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          AppConfig.doctorName,
          style: GoogleFonts.cairo(fontSize: 18, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تسجيل الدخول',
              style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'أدخل رمز الترخيص للدخول إلى التطبيق',
              style: GoogleFonts.cairo(
                  fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _licenseCtrl,
              obscureText: _obscure,
              style: GoogleFonts.cairo(),
              onSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: 'رمز الترخيص',
                labelStyle: GoogleFonts.cairo(color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.key_outlined),
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'دخول',
                        style: GoogleFonts.cairo(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
