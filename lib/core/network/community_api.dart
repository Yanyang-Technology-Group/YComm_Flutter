import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'api_result.dart';

typedef Json = Map<String, dynamic>;
List<Json> jsonList(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Json.from(e)).toList()
    : [];
String str(dynamic value, [String fallback = '']) =>
    value?.toString() ?? fallback;

class RequestFailure implements Exception {
  const RequestFailure(this.message, [this.code]);
  final String message;
  final String? code;
  @override
  String toString() => message;
}

class CommunityApi {
  CommunityApi({ApiClient? client}) : client = client ?? ApiClient();
  final ApiClient client;
  static Json unwrap(ApiResult<dynamic> result) {
    if (!result.isSuccess) {
      throw RequestFailure(result.errorMessage ?? '请求失败', result.code);
    }
    return result.data is Map ? Json.from(result.data) : {};
  }

  Future<Json> get(String path, {Json? query}) async =>
      unwrap(await client.get(path, queryParameters: query));
  Future<Json> post(String path, [Json? data]) async =>
      unwrap(await client.post(path, data: data));
  Future<List<Json>> boards() async =>
      jsonList((await get('/forum/boards'))['boards']);
  Future<List<Json>> topics(String slug) async => jsonList(
    (await get(
      '/forum/boards/${Uri.encodeComponent(slug)}/topics',
      query: {'limit': 20},
    ))['topics'],
  );
  Future<List<Json>> categories() async =>
      jsonList((await get('/downloads/categories'))['categories']);
  Future<List<Json>> resources({String? categoryId}) async => jsonList(
    (await get(
      '/downloads/resources',
      query: {'categoryId': ?categoryId},
    ))['resources'],
  );
  Future<List<Json>> notifications() async =>
      jsonList((await get('/notifications'))['groups']);
}

final communityProvider = Provider<CommunityApi>((ref) => CommunityApi());
