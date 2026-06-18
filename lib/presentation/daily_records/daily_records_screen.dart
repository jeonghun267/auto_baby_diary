import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/error_mapper.dart';
import '../../data/repositories/daily_record_repository.dart';
import 'timer_widget.dart';

enum RecordType { feeding, sleep, diaper, babyFood }

extension RecordTypeExtension on RecordType {
  String get label {
    switch (this) {
      case RecordType.feeding:
        return '수유';
      case RecordType.sleep:
        return '수면';
      case RecordType.diaper:
        return '기저귀';
      case RecordType.babyFood:
        return '이유식';
    }
  }

  String get icon {
    switch (this) {
      case RecordType.feeding:
        return '🍼';
      case RecordType.sleep:
        return '😴';
      case RecordType.diaper:
        return '🧷';
      case RecordType.babyFood:
        return '🥣';
    }
  }
}

class _DailyRecord {
  final String id;
  final String type;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationMinutes;
  final String? subType;
  final double? amount;
  final String? note;

  _DailyRecord({
    required this.id,
    required this.type,
    required this.startTime,
    this.endTime,
    this.durationMinutes,
    this.subType,
    this.amount,
    this.note,
  });

  factory _DailyRecord.fromJson(Map<String, dynamic> json) {
    return _DailyRecord(
      id: json['id'] as String,
      type: json['type'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      durationMinutes: json['duration_minutes'] as int?,
      subType: json['sub_type'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      note: json['note'] as String?,
    );
  }
}

class DailyRecordsScreen extends ConsumerStatefulWidget {
  const DailyRecordsScreen({super.key});

  @override
  ConsumerState<DailyRecordsScreen> createState() => _DailyRecordsScreenState();
}

class _DailyRecordsScreenState extends ConsumerState<DailyRecordsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  Map<RecordType, List<_DailyRecord>> _records = {
    RecordType.feeding: [],
    RecordType.sleep: [],
    RecordType.diaper: [],
    RecordType.babyFood: [],
  };
  bool _isLoading = true;
  RecordType? _activeTimerType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecords());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final child = ref.read(currentChildProvider);
    if (child == null) return;

    setState(() => _isLoading = true);

    try {
      final startOfDay =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await SupabaseService.client
          .from('daily_records')
          .select()
          .eq('child_id', child.id)
          .gte('start_time', startOfDay.toIso8601String())
          .lt('start_time', endOfDay.toIso8601String())
          .order('start_time', ascending: false);

      final allRecords = (response as List)
          .map((e) => _DailyRecord.fromJson(e as Map<String, dynamic>))
          .toList();

      final grouped = <RecordType, List<_DailyRecord>>{
        RecordType.feeding: [],
        RecordType.sleep: [],
        RecordType.diaper: [],
        RecordType.babyFood: [],
      };

      for (final record in allRecords) {
        switch (record.type) {
          case 'feeding':
            grouped[RecordType.feeding]!.add(record);
            break;
          case 'sleep':
            grouped[RecordType.sleep]!.add(record);
            break;
          case 'diaper':
            grouped[RecordType.diaper]!.add(record);
            break;
          case 'babyFood':
            grouped[RecordType.babyFood]!.add(record);
            break;
        }
      }

      if (mounted) {
        setState(() {
          _records = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteRecord(String id) async {
    try {
      await ref.read(dailyRecordRepositoryProvider).deleteDailyRecord(id);
      _loadRecords();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제에 실패했습니다')),
        );
      }
    }
  }

  String _getSummary(RecordType type) {
    final records = _records[type] ?? [];
    switch (type) {
      case RecordType.feeding:
        final totalMl =
            records.fold<double>(0, (sum, r) => sum + (r.amount ?? 0));
        return '오늘 ${records.length}회, 총 ${totalMl.toInt()}ml';
      case RecordType.sleep:
        final totalMinutes =
            records.fold<int>(0, (sum, r) => sum + (r.durationMinutes ?? 0));
        final hours = totalMinutes ~/ 60;
        final minutes = totalMinutes % 60;
        return '오늘 총 ${hours}시간 ${minutes}분';
      case RecordType.diaper:
        return '오늘 ${records.length}회';
      case RecordType.babyFood:
        return '오늘 ${records.length}회';
    }
  }

  Future<void> _saveTimerRecord(RecordType type, Duration elapsed) async {
    final child = ref.read(currentChildProvider);
    if (child == null) return;

    final now = DateTime.now();
    final startTime = now.subtract(elapsed);
    final durationMinutes = elapsed.inMinutes;

    try {
      await ref.read(dailyRecordRepositoryProvider).addDailyRecord({
        'child_id': child.id,
        'type': type.name,
        'start_time': startTime.toIso8601String(),
        'end_time': now.toIso8601String(),
        'duration_minutes': durationMinutes,
        'note': '타이머로 기록됨',
      });
      _loadRecords();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${type.label} ${durationMinutes ~/ 60}시간 ${durationMinutes % 60}분 기록 완료',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했습니다')),
        );
      }
    }
  }

  void _showAddRecordSheet() {
    final currentType = RecordType.values[_tabController.index];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // 키보드가 올라와도 시트가 자동으로 위로 올라감
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddRecordSheet(
        type: currentType,
        selectedDate: _selectedDate,
        onSaved: _loadRecords,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy년 M월 d일').format(_selectedDate);
    final isToday = _isToday(_selectedDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          '일상 기록',
          style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Date selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left,
                      color: AppColors.textPrimary),
                  onPressed: () => _changeDate(-1),
                ),
                Text(
                  isToday ? '$dateStr (오늘)' : dateStr,
                  style: AppTextStyles.h3,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right,
                      color: AppColors.textPrimary),
                  onPressed: () => _changeDate(1),
                ),
              ],
            ),
          ),

          // Category tabs
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: RecordType.values.map((type) {
              return Tab(
                child: Text(
                  '${type.icon} ${type.label}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
          ),

          // Tab content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
                    controller: _tabController,
                    children: RecordType.values.map((type) {
                      return _buildRecordList(type);
                    }).toList(),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _showAddRecordSheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildRecordList(RecordType type) {
    final records = _records[type] ?? [];
    final showTimerButton =
        type == RecordType.feeding || type == RecordType.sleep;

    return Column(
      children: [
        // Summary card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            _getSummary(type),
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
            textAlign: TextAlign.center,
          ),
        ),

        // Timer section
        if (showTimerButton && _activeTimerType == type)
          TimerWidget(
            recordType: type.name,
            onStop: (elapsed) {
              setState(() => _activeTimerType = null);
              _saveTimerRecord(type, elapsed);
            },
            onCancel: () {
              setState(() => _activeTimerType = null);
            },
          )
        else if (showTimerButton && _activeTimerType == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() => _activeTimerType = type);
              },
              icon: const Icon(Icons.timer_outlined, size: 18),
              label: const Text('타이머로 기록'),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    type == RecordType.feeding ? Colors.orange : Colors.indigo,
                side: BorderSide(
                  color: type == RecordType.feeding
                      ? Colors.orange.withValues(alpha: 0.5)
                      : Colors.indigo.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 42),
              ),
            ),
          ),

        const SizedBox(height: 8),

        // Records list
        Expanded(
          child: records.isEmpty
              ? Center(
                  child: Text(
                    '기록이 없습니다',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return _buildRecordCard(record, type);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRecordCard(_DailyRecord record, RecordType type) {
    final timeStr = DateFormat('HH:mm').format(record.startTime);
    String subtitle = '';

    switch (type) {
      case RecordType.feeding:
        final subLabel = record.subType ?? '';
        final amountStr =
            record.amount != null ? '${record.amount!.toInt()}ml' : '';
        subtitle = [subLabel, amountStr].where((s) => s.isNotEmpty).join(' / ');
        break;
      case RecordType.sleep:
        if (record.durationMinutes != null) {
          final h = record.durationMinutes! ~/ 60;
          final m = record.durationMinutes! % 60;
          subtitle = '${h}시간 ${m}분';
        }
        if (record.endTime != null) {
          subtitle +=
              ' (${DateFormat('HH:mm').format(record.startTime)}~${DateFormat('HH:mm').format(record.endTime!)})';
        }
        break;
      case RecordType.diaper:
        subtitle = record.subType ?? '';
        break;
      case RecordType.babyFood:
        final foodName = record.subType ?? '';
        final amountStr =
            record.amount != null ? '${record.amount!.toInt()}g' : '';
        subtitle = [foodName, amountStr].where((s) => s.isNotEmpty).join(' / ');
        break;
    }

    return Dismissible(
      key: Key(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('삭제'),
            content: const Text('이 기록을 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child:
                    const Text('삭제', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => _deleteRecord(record.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(type.icon, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(timeStr, style: AppTextStyles.labelLarge),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTextStyles.bodySmall),
                    ],
                    if (record.note != null && record.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        record.note!,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

// ─── Add Record Bottom Sheet ──────────────────────────────

class _AddRecordSheet extends ConsumerStatefulWidget {
  final RecordType type;
  final DateTime selectedDate;
  final VoidCallback onSaved;

  const _AddRecordSheet({
    required this.type,
    required this.selectedDate,
    required this.onSaved,
  });

  @override
  ConsumerState<_AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends ConsumerState<_AddRecordSheet> {
  static const TextStyle _inputTextStyle = TextStyle(
    fontSize: 15,
    color: AppColors.textPrimary,
  );

  // Common
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay? _endTime;
  final _noteController = TextEditingController();
  bool _isSaving = false;

  // Feeding
  String _feedingType = '모유';
  final _amountController = TextEditingController();

  // Diaper
  String _diaperType = '소변';

  // Baby food
  final _foodNameController = TextEditingController();
  final _foodAmountController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    _foodNameController.dispose();
    _foodAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : (_endTime ?? TimeOfDay.now()),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  int? _calculateDuration() {
    if (_endTime == null) return null;
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    var diff = endMinutes - startMinutes;
    if (diff < 0) diff += 24 * 60;
    return diff;
  }

  DateTime _combineDateTime(TimeOfDay time) {
    return DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _save() async {
    if (_isSaving) return; // 중복 탭 방지

    final child = ref.read(currentChildProvider);
    if (child == null) return;

    setState(() => _isSaving = true);

    try {
      final startDateTime = _combineDateTime(_startTime);
      DateTime? endDateTime;
      int? duration;
      String? subType;
      double? amount;

      switch (widget.type) {
        case RecordType.feeding:
          subType = _feedingType;
          final parsedAmount = double.tryParse(_amountController.text.trim());
          amount = parsedAmount;
          break;
        case RecordType.sleep:
          if (_endTime != null) {
            endDateTime = _combineDateTime(_endTime!);
            duration = _calculateDuration();
          }
          break;
        case RecordType.diaper:
          subType = _diaperType;
          break;
        case RecordType.babyFood:
          subType = _foodNameController.text.trim().isNotEmpty
              ? _foodNameController.text.trim()
              : null;
          final parsedAmount =
              double.tryParse(_foodAmountController.text.trim());
          amount = parsedAmount;
          break;
      }

      // id는 repository에서 자동 생성됨
      final data = <String, dynamic>{
        'child_id': child.id,
        'type': widget.type.name,
        'start_time': startDateTime.toIso8601String(),
        'note': _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
      };

      if (endDateTime != null) data['end_time'] = endDateTime.toIso8601String();
      if (duration != null) data['duration_minutes'] = duration;
      if (subType != null) data['sub_type'] = subType;
      if (amount != null) data['amount'] = amount;

      await ref.read(dailyRecordRepositoryProvider).addDailyRecord(data);

      widget.onSaved();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.type.icon} ${widget.type.label} 기록 완료'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMapper.map(e, fallback: '저장에 실패했습니다.'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textHint.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              '${widget.type.icon} ${widget.type.label} 기록',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Type-specific fields
            _buildTypeSpecificFields(),

            const SizedBox(height: 16),

            // Note
            Text('메모', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 2,
              style: _inputTextStyle,
              decoration: _inputDecoration('메모를 입력해주세요'),
            ),

            const SizedBox(height: 24),

            // Save button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('저장',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSpecificFields() {
    switch (widget.type) {
      case RecordType.feeding:
        return _buildFeedingFields();
      case RecordType.sleep:
        return _buildSleepFields();
      case RecordType.diaper:
        return _buildDiaperFields();
      case RecordType.babyFood:
        return _buildBabyFoodFields();
    }
  }

  Widget _buildFeedingFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('종류', style: AppTextStyles.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: ['모유', '분유', '혼합'].map((type) {
            final selected = _feedingType == type;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _feedingType = type),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.primaryLight.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _buildTimeField('시간', _startTime, () => _pickTime(isStart: true)),
        const SizedBox(height: 16),
        Text('양 (ml)', style: AppTextStyles.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: _inputTextStyle,
          decoration: _inputDecoration('예: 120'),
        ),
      ],
    );
  }

  Widget _buildSleepFields() {
    final duration = _calculateDuration();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimeField('시작 시간', _startTime, () => _pickTime(isStart: true)),
        const SizedBox(height: 16),
        _buildTimeField('종료 시간', _endTime ?? TimeOfDay.now(),
            () => _pickTime(isStart: false)),
        if (duration != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined,
                    size: 18, color: AppColors.secondaryDark),
                const SizedBox(width: 8),
                Text(
                  '${duration ~/ 60}시간 ${duration % 60}분',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.secondaryDark),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDiaperFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('종류', style: AppTextStyles.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: ['소변', '대변', '둘다'].map((type) {
            final selected = _diaperType == type;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _diaperType = type),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.primaryLight.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _buildTimeField('시간', _startTime, () => _pickTime(isStart: true)),
      ],
    );
  }

  Widget _buildBabyFoodFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('음식 이름', style: AppTextStyles.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _foodNameController,
          style: _inputTextStyle,
          decoration: _inputDecoration('예: 쌀미음'),
        ),
        const SizedBox(height: 16),
        _buildTimeField('시간', _startTime, () => _pickTime(isStart: true)),
        const SizedBox(height: 16),
        Text('양', style: AppTextStyles.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _foodAmountController,
          keyboardType: TextInputType.number,
          style: _inputTextStyle,
          decoration: _inputDecoration('예: 50'),
        ),
      ],
    );
  }

  Widget _buildTimeField(String label, TimeOfDay time, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time,
                    color: AppColors.primary.withValues(alpha: 0.6), size: 20),
                const SizedBox(width: 12),
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textHint),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            BorderSide(color: AppColors.primaryLight.withValues(alpha: 0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}
