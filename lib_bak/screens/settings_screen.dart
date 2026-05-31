import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ListView(
            children: [
              const _SectionHeader('提醒设置'),
              SwitchListTile(
                title: const Text('课程提醒'),
                subtitle: const Text('上课前提醒你'),
                value: settings.notificationsEnabled,
                onChanged: (v) async {
                  if (v) {
                    final service = NotificationService();
                    await service.initialize();
                    final granted = await service.requestPermissions();
                    if (!granted) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请在系统设置中允许通知权限')),
                        );
                      }
                      return;
                    }
                  }
                  settings.setNotificationsEnabled(v);
                },
              ),
              if (settings.notificationsEnabled)
                ListTile(
                  title: const Text('提前提醒时间'),
                  subtitle: Text('${settings.reminderMinutes} 分钟'),
                  trailing: DropdownButton<int>(
                    value: settings.reminderMinutes,
                    items: [5, 10, 15, 30, 60]
                        .map((m) => DropdownMenuItem(value: m, child: Text('$m 分钟')))
                        .toList(),
                    onChanged: (v) => settings.setReminderMinutes(v!),
                  ),
                ),
              const Divider(),
              const _SectionHeader('外观'),
              SwitchListTile(
                title: const Text('深色模式'),
                subtitle: const Text('夜晚使用'),
                value: settings.darkMode,
                onChanged: (v) => settings.setDarkMode(v),
              ),
              const Divider(),
              const _SectionHeader('关于'),
              const ListTile(
                title: Text('版本'),
                subtitle: Text('1.0.0'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
