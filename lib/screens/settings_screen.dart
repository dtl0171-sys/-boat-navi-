import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../services/route_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _speedController;
  late SpeedUnit _selectedUnit;

  @override
  void initState() {
    super.initState();
    final provider = context.read<NavigationProvider>();
    _speedController =
        TextEditingController(text: provider.boatSpeed.toStringAsFixed(0));
    _selectedUnit = provider.speedUnit;
  }

  @override
  void dispose() {
    _speedController.dispose();
    super.dispose();
  }

  void _saveSpeed() {
    final speed = double.tryParse(_speedController.text);
    if (speed == null || speed < 1 || speed > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('速度は1〜100の範囲で入力してください'),
          backgroundColor: const Color(0xFF0D1F3C),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }
    context.read<NavigationProvider>().setBoatSpeed(speed, _selectedUnit);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '船速を${speed.toStringAsFixed(0)} ${_selectedUnit == SpeedUnit.knots ? "kt" : "km/h"}に設定しました'),
        backgroundColor: const Color(0xFF0D1F3C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: const Color(0xFF0D1F3C),
        foregroundColor: const Color(0xFF00E5FF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF00E5FF)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '船速設定',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00E5FF),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _speedController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: '船速',
                      labelStyle: TextStyle(
                          color: const Color(0xFF00E5FF)
                              .withValues(alpha: 0.7)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: const Color(0xFF00E5FF)
                                .withValues(alpha: 0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: const Color(0xFF00E5FF)
                                .withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFF00E5FF)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0D1F3C),
                      hintText: '例: 15',
                      hintStyle: const TextStyle(color: Colors.white24),
                    ),
                    onChanged: (_) => _saveSpeed(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<SpeedUnit>(
                    value: _selectedUnit,
                    dropdownColor: const Color(0xFF0D1F3C),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: '単位',
                      labelStyle: TextStyle(
                          color: const Color(0xFF00E5FF)
                              .withValues(alpha: 0.7)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: const Color(0xFF00E5FF)
                                .withValues(alpha: 0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: const Color(0xFF00E5FF)
                                .withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFF00E5FF)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0D1F3C),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: SpeedUnit.knots,
                        child: Text('kt'),
                      ),
                      DropdownMenuItem(
                        value: SpeedUnit.kmh,
                        child: Text('km/h'),
                      ),
                    ],
                    onChanged: (unit) {
                      if (unit != null) {
                        setState(() => _selectedUnit = unit);
                        _saveSpeed();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1F3C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '速度の目安',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                  Divider(
                      color:
                          const Color(0xFF00E5FF).withValues(alpha: 0.2)),
                  _guideRow('漁船・小型船', '8-12 kt'),
                  _guideRow('プレジャーボート', '15-25 kt'),
                  _guideRow('高速船', '30-40 kt'),
                  _guideRow('水上バイク', '40-60 kt'),
                ],
              ),
            ),
            const Spacer(),
            Consumer<NavigationProvider>(
              builder: (context, provider, _) {
                if (provider.routeLegs.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A1628), Color(0xFF0D2847)],
                    ),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '現在のルート情報',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00E5FF),
                        ),
                      ),
                      Divider(
                          color: const Color(0xFF00E5FF)
                              .withValues(alpha: 0.2)),
                      Text(
                        '総距離: ${provider.totalDistanceKm.toStringAsFixed(1)} km',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        '総所要時間: ${provider.totalDurationText}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        '船速: ${provider.boatSpeed.toStringAsFixed(0)} ${provider.speedUnitLabel}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _guideRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, color: Color(0xFF00E5FF))),
        ],
      ),
    );
  }
}
