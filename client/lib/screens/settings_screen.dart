import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _serverCtrl = TextEditingController();
  final TextEditingController _userCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverCtrl.text = prefs.getString('server_url') ?? ApiService.baseUrl;
      _userCtrl.text = prefs.getString('username') ?? ApiService.userId;
    });
  }

  void _saveSettings() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', _serverCtrl.text);
    await prefs.setString('username', _userCtrl.text);
    
    ApiService.baseUrl = _serverCtrl.text;
    ApiService.userId = _userCtrl.text;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved and applied successfully'),
          backgroundColor: accentEmerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  void _clearCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image cache cleared'),
        backgroundColor: Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Comfy Pro Max',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          color: accentEmerald,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
      ),
      children: [
        const Text(
          'Comfy Pro Max is a high-performance mobile client for ComfyUI. '
          'Generate high-quality images and music directly from your mobile device.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Settings",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          
          _sectionHeader("Server Configuration"),
          _buildCard([
            _buildTextField(
              controller: _serverCtrl,
              label: "API Server URL",
              hint: "http://127.0.0.1:8100",
              icon: Icons.lan_outlined,
            ),
            const Divider(color: Colors.white10, height: 32),
            _buildTextField(
              controller: _userCtrl,
              label: "Username / Client ID",
              hint: "guest",
              icon: Icons.person_outline,
            ),
          ]),
          
          const SizedBox(height: 32),
          _sectionHeader("Preferences"),
          _buildCard([
            _buildToggleItem(
              "Dark Mode",
              "Enabled by default",
              Icons.dark_mode_outlined,
              true,
            ),
            const Divider(color: Colors.white10, height: 32),
            _buildToggleItem(
              "High Quality Previews",
              "Uses more data",
              Icons.high_quality_outlined,
              true,
            ),
          ]),
          
          const SizedBox(height: 32),
          _sectionHeader("System"),
          _buildCard([
            _buildActionItem(
              "Clear Cache",
              "Free up memory by clearing image cache",
              Icons.delete_outline,
              _clearCache,
            ),
            const Divider(color: Colors.white10, height: 32),
            _buildActionItem(
              "About ComfyProMax",
              "Version 1.0.0",
              Icons.info_outline,
              _showAbout,
            ),
          ]),
          
          const SizedBox(height: 48),
          _buildSaveButton(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 12),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: Colors.white24,
        letterSpacing: 1.5,
      ),
    ),
  );

  Widget _buildCard(List<Widget> children) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: accentEmerald.withOpacity(0.05),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: glassBorder),
    ),
    child: Column(children: children),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 16, color: accentEmerald),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    ],
  );

  Widget _buildToggleItem(String title, String subtitle, IconData icon, bool value) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accentEmerald.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: accentEmerald, size: 20),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ],
        ),
      ),
      Switch(
        value: value,
        onChanged: (v) {},
        activeColor: accentEmerald,
      ),
    ],
  );

  Widget _buildActionItem(String title, String subtitle, IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentEmerald.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accentEmerald, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: Colors.white10),
      ],
    ),
  );

  Widget _buildSaveButton() => GestureDetector(
    onTap: _isLoading ? null : _saveSettings,
    child: Container(
      height: 56,
      width: double.infinity,
      decoration: BoxDecoration(
        color: accentEmerald,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accentEmerald.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                "Save Configuration",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    ),
  );
}
