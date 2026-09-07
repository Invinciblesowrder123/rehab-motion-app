import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exercise.dart';
import '../services/api_service.dart';
import 'chat_provider.dart';

/// 常用身体部位筛选（对应动作库 body_part 字段）
const bodyPartOptions = <String, String>{
  '全部': '',
  '腰背': 'waist',
  '肩部': 'shoulders',
  '上肢': 'upper arms',
  '下肢': 'upper legs',
  '小腿': 'lower legs',
  '胸部': 'chest',
  '背部': 'back',
  '腹部': 'waist',
};

/// 动作库状态
///
/// 数据库不可用时（Docker 未启动）会返回友好错误，而不是崩溃。
class ExerciseNotifier extends StateNotifier<AsyncValue<ExerciseListResponse>> {
  final ApiService _api;
  String _bodyPart = '';
  String _keyword = '';

  ExerciseNotifier(this._api) : super(const AsyncValue.loading()) {
    load();
  }

  String get bodyPart => _bodyPart;
  String get keyword => _keyword;

  Future<void> load({String? bodyPart, String? keyword}) async {
    if (bodyPart != null) _bodyPart = bodyPart;
    if (keyword != null) _keyword = keyword;

    state = const AsyncValue.loading();
    try {
      final json = await _api.getExercises(
        bodyPart: _bodyPart.isEmpty ? null : _bodyPart,
        keyword: _keyword.isEmpty ? null : _keyword,
        limit: 50,
      );
      state = AsyncValue.data(ExerciseListResponse.fromJson(json));
    } on DioException catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final exerciseProvider = StateNotifierProvider<ExerciseNotifier,
    AsyncValue<ExerciseListResponse>>(
  (ref) => ExerciseNotifier(ref.read(apiServiceProvider)),
);

/// 单个动作详情
final exerciseDetailProvider =
    FutureProvider.family<Exercise, String>((ref, id) async {
  final api = ref.read(apiServiceProvider);
  final json = await api.getExerciseDetail(id);
  return Exercise.fromJson(json);
});
