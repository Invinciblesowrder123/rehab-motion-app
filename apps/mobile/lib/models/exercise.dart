/// 康复动作数据模型
///
/// 对应后端 `v_rehab_exercises` 视图（该视图已硬性排除 rehab_level=3）。
/// 安全策略：App 永远不会收到 3 级高危动作。
class Exercise {
  final String id;
  final String? nameZh;
  final String? nameEn;
  final String? bodyPart;
  final String? equipment;
  final String? targetMuscle;
  final int? rehabLevel;
  final String? rehabLabel;
  final String? rehabReason;
  final List<String>? riskFlags;

  // 详情字段（列表查询时为 null）
  final String? instructionZh;
  final List<dynamic>? stepsZh;
  final int? difficulty;
  final String? doseRecommend;

  Exercise({
    required this.id,
    this.nameZh,
    this.nameEn,
    this.bodyPart,
    this.equipment,
    this.targetMuscle,
    this.rehabLevel,
    this.rehabLabel,
    this.rehabReason,
    this.riskFlags,
    this.instructionZh,
    this.stepsZh,
    this.difficulty,
    this.doseRecommend,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: (json['id'] ?? '').toString(),
        nameZh: json['name_zh'] as String?,
        nameEn: json['name_en'] as String?,
        bodyPart: json['body_part'] as String?,
        equipment: json['equipment'] as String?,
        targetMuscle: json['target_muscle'] as String?,
        rehabLevel: json['rehab_level'] as int?,
        rehabLabel: json['rehab_label'] as String?,
        rehabReason: json['rehab_reason'] as String?,
        riskFlags: (json['risk_flags'] as List<dynamic>?)?.cast<String>(),
        instructionZh: json['instruction_zh'] as String?,
        stepsZh: json['steps_zh'] as List<dynamic>?,
        difficulty: json['difficulty'] as int?,
        doseRecommend: json['dose_recommend'] as String?,
      );

  /// 显示名称：优先中文，没有则英文，再没有则 id
  String get displayName => nameZh ?? nameEn ?? '动作 $id';

  /// 等级标签文案
  String get levelLabel {
    switch (rehabLevel) {
      case 1:
        return '康复可用';
      case 2:
        return '需评估后使用';
      default:
        return '未知等级';
    }
  }
}

/// 动作列表响应
class ExerciseListResponse {
  final List<Exercise> items;
  final int total;
  final String? safetyPolicy;

  ExerciseListResponse({
    required this.items,
    required this.total,
    this.safetyPolicy,
  });

  factory ExerciseListResponse.fromJson(Map<String, dynamic> json) =>
      ExerciseListResponse(
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int? ?? 0,
        safetyPolicy: json['safetyPolicy'] as String?,
      );
}
