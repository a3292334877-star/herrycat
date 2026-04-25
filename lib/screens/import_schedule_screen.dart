import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';
import '../models/course_model.dart';
import '../services/school_login_service.dart';

class ImportScheduleScreen extends StatefulWidget {
  const ImportScheduleScreen({super.key});

  @override
  State<ImportScheduleScreen> createState() => _ImportScheduleScreenState();
}

class _ImportScheduleScreenState extends State<ImportScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;
  String? _successMsg;
  List<Map<String, dynamic>>? _previewCourses;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _previewSchedule() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
      _successMsg = null;
      _previewCourses = null;
    });

    try {
      final service = SchoolLoginService();
      await _login(service);
      final courses = await service.fetchSchedule();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _previewCourses = courses;
        if (courses.isEmpty) {
          _errorMsg = '课表为空，请确认当前学期有课程';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _importSchedule() async {
    if (_previewCourses == null || _previewCourses!.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final provider = context.read<CourseProvider>();
      int imported = 0;
      final random = Random();

      for (final raw in _previewCourses!) {
        final kcm = raw['KCM'] as String? ?? '未知课程';
        final skxq = int.tryParse('${raw['SKXQ'] ?? '1'}') ?? 1;
        final skjc = raw['SKJC'] as String? ?? '1-2节';
        final skzc = raw['SKZC'] as String? ?? '1-16周';
        final jasmc = raw['JASMC'] as String? ?? '';
        final skjs = raw['SKJS'] as String? ?? '';

        final (startSec, endSec) = parseSectionRange(skjc);
        final (startTime, endTime) = _sectionsToTime(startSec, endSec);
        final weekInfo = parseWeekInfo(skzc);

        // 生成唯一 ID
        final courseId = '${kcm}_${skxq}_$startSec\_${DateTime.now().millisecondsSinceEpoch}_$random';

        // 随机颜色
        final colors = [
          0xFF5C6BC0, 0xFF26A69A, 0xFFEF5350, 0xFFAB47BC,
          0xFF42A5F5, 0xFFFFA726, 0xFF66BB6A, 0xFF8D6E63,
          0xFFEC407A, 0xFF7E57C2,
        ];
        final color = Color(colors[random.nextInt(colors.length)]);

        final course = Course(
          id: courseId,
          name: kcm,
          teacher: skjs,
          dayOfWeek: skxq,
          startTime: startTime,
          endTime: endTime,
          location: jasmc,
          color: color,
          weekCycle: weekInfo.isOddWeek == null
              ? WeekCycle.all
              : (weekInfo.isOddWeek! ? WeekCycle.odd : WeekCycle.even),
        );

        await provider.addCourse(course);
        imported++;
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successMsg = '成功导入 $imported 门课程！';
      });

      // 延迟返回
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context, true); // 返回 true 表示导入成功
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMsg = '导入失败: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Future<void> _login(SchoolLoginService service) async {
    await service.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );
  }

  String _getSectionTime(int section) {
    const schedule = {
      1: '08:00', 2: '08:50', 3: '09:55', 4: '10:45',
      5: '11:35', 6: '14:00', 7: '14:50', 8: '15:55',
      9: '16:45', 10: '17:35', 11: '19:00', 12: '19:50',
      13: '20:40', 14: '21:30',
    };
    return schedule[section] ?? '00:00';
  }

  (String, String) _sectionsToTimeTuple(int start, int end) {
    return (_getSectionTime(start), _getEndTime(end));
  }

  String _getEndTime(int section) {
    const endTimes = {
      1: '08:45', 2: '09:35', 3: '10:40', 4: '11:30',
      5: '12:20', 6: '14:45', 7: '15:35', 8: '16:40',
      9: '17:30', 10: '18:20', 11: '19:45', 12: '20:35',
      13: '21:25', 14: '22:15',
    };
    return endTimes[section] ?? '00:00';
  }

  (String, String) _sectionsToTime(int start, int end) {
    return (_getSectionTime(start), _getEndTime(end));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入课表'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题区域
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.school, size: 48, color: Colors.white),
                    const SizedBox(height: 12),
                    const Text(
                      '深圳职业技术大学',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '从教务系统自动导入课程',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 账号密码表单
              if (_previewCourses == null) ...[
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: '学号',
                          hintText: '请输入教务系统账号',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return '请输入学号';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: '密码',
                          hintText: '请输入教务系统密码',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                        ),
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return '请输入密码';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber.shade700, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '密码将使用 RSA 加密传输，仅用于登录教务系统',
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 错误提示
                      if (_errorMsg != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMsg!,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _previewSchedule,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.search),
                          label: Text(_isLoading ? '登录中...' : '查询课表'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 预览区域
              if (_previewCourses != null && _previewCourses!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '找到 ${_previewCourses!.length} 门课程，确认导入？',
                          style: TextStyle(color: Colors.green.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ..._previewCourses!.take(20).map((c) => _buildPreviewCard(c)),
                if (_previewCourses!.length > 20)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '... 还有 ${_previewCourses!.length - 20} 门课程',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                const SizedBox(height: 16),
                if (_errorMsg != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_errorMsg!, style: TextStyle(color: Colors.red.shade700)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _previewCourses = null;
                                  _errorMsg = null;
                                });
                              },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('重新输入'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _importSchedule,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download),
                        label: Text(_isLoading ? '导入中...' : '确认导入'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // 成功提示
              if (_successMsg != null && _previewCourses == null)
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        _successMsg!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard(Map<String, dynamic> course) {
    final name = course['KCM'] ?? '未知课程';
    final day = int.tryParse('${course['SKXQ'] ?? 1}') ?? 1;
    final section = course['SKJC'] ?? '1-2节';
    final room = course['JASMC'] ?? '';
    final teacher = course['SKJS'] ?? '';
    final week = course['SKZC'] ?? '1-16周';

    const dayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(
            '$day',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${dayNames[day]} $section  $week${teacher.isNotEmpty ? '  $teacher' : ''}${room.isNotEmpty ? '  $room' : ''}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
}
