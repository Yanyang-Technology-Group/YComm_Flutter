import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/api_client.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/widgets/media_upload_button.dart';
import 'package:ycomm_client/core/design/adaptive.dart';
import 'package:ycomm_client/features/forum/compose_page.dart';

final class SelectedFile extends PlatformFile {
  SelectedFile(this.name, this.size);
  @override
  final String name;
  final int size;
  @override
  Future<int?> length() async => size;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(Uint8List(size));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class UploadApi extends CommunityApi {
  final response = Completer<Json>();
  bool? video;
  int calls = 0;
  @override
  Future<Json> uploadMedia(
    MultipartFile file, {
    required bool video,
    ProgressCallback? onSendProgress,
  }) {
    this.video = video;
    calls++;
    onSendProgress?.call(1, 2);
    return response.future;
  }
}

// Replace only the network transport; Dio still serializes the multipart body
// and reports progress while the adapter consumes the request stream.
class UploadAdapter implements HttpClientAdapter {
  final requests = <({RequestOptions options, String body})>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = await utf8.decoder.bind(requestStream!).join();
    requests.add((options: options, body: body));
    return ResponseBody.fromString(
      jsonEncode({
        'ok': true,
        'data': {'url': '/api/uploads/videos/test-file.mp4'},
      }),
      201,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'multipart upload uses the correct endpoint, file field and progress',
    () async {
      final adapter = UploadAdapter();
      final client = ApiClient()..dio.httpClientAdapter = adapter;
      addTearDown(() => client.dio.close(force: true));
      final api = CommunityApi(client: client);
      for (final video in [true, false]) {
        final progress = <(int, int)>[];
        await api.uploadMedia(
          MultipartFile.fromBytes(
            utf8.encode('test-video-bytes'),
            filename: 'test.mp4',
          ),
          video: video,
          onSendProgress: (count, total) => progress.add((count, total)),
        );
        expect(progress, isNotEmpty);
        expect(progress.last.$1, greaterThan(0));
        expect(progress.last.$1, progress.last.$2);
      }
      expect(adapter.requests.map((request) => request.options.uri.path), [
        '/api/uploads/videos',
        '/api/uploads/images',
      ]);
      for (final request in adapter.requests) {
        expect(request.options.method, 'POST');
        expect(
          request.options.contentType,
          startsWith('multipart/form-data; boundary='),
        );
        expect(request.body, contains('name="file"; filename="test.mp4"'));
        expect(request.body, contains('test-video-bytes'));
      }
    },
  );

  test('insertion replaces selected text and appends without selection', () {
    final controller = TextEditingController(text: 'before selected after');
    addTearDown(controller.dispose);
    controller.selection = const TextSelection(baseOffset: 7, extentOffset: 15);
    insertUploadedMedia(controller, '/api/uploads/images/test-file.png');
    expect(
      controller.text,
      'before \n![](/api/uploads/images/test-file.png)\n after',
    );
    expect(controller.selection.isCollapsed, true);
    controller.selection = const TextSelection.collapsed(offset: -1);
    insertUploadedMedia(controller, '/api/uploads/videos/test-file.mp4');
    expect(
      controller.text.endsWith('\n![](/api/uploads/videos/test-file.mp4)\n'),
      true,
    );
  });

  testWidgets('upload reports busy and inserts only after success', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'draft');
    addTearDown(controller.dispose);
    final api = UploadApi();
    final states = <bool>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityProvider.overrideWithValue(api),
          mediaPickerProvider.overrideWithValue(
            () async => SelectedFile('clip.MP4', 12),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MediaUploadButton(
              controller: controller,
              onBusyChanged: states.add,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('上传图片或视频'));
    await tester.pump();
    expect(states, [true]);
    expect(api.video, true);
    expect(controller.text, 'draft');
    expect(find.text('上传 50%'), findsOneWidget);
    api.response.complete({'url': '/api/uploads/videos/test-file.mp4'});
    await tester.pumpAndSettle();
    expect(states, [true, false]);
    expect(controller.text, 'draft\n![](/api/uploads/videos/test-file.mp4)\n');
  });

  for (final size in [0, maxMediaBytes + 1]) {
    testWidgets('invalid size $size keeps the draft without an API request', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'draft');
      addTearDown(controller.dispose);
      final api = UploadApi();
      final states = <bool>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            communityProvider.overrideWithValue(api),
            mediaPickerProvider.overrideWithValue(
              () async => SelectedFile('clip.mp4', size),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MediaUploadButton(
                controller: controller,
                onBusyChanged: states.add,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('上传图片或视频'));
      await tester.pumpAndSettle();
      expect(api.calls, 0);
      expect(controller.text, 'draft');
      expect(states, [true, false]);
    });
  }

  testWidgets('cancelled selection leaves the draft and releases busy state', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'draft');
    addTearDown(controller.dispose);
    final api = UploadApi();
    final states = <bool>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityProvider.overrideWithValue(api),
          mediaPickerProvider.overrideWithValue(() async => null),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MediaUploadButton(
              controller: controller,
              onBusyChanged: states.add,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('上传图片或视频'));
    await tester.pumpAndSettle();
    expect(api.calls, 0);
    expect(controller.text, 'draft');
    expect(states, [true, false]);
  });

  testWidgets('rejected upload preserves draft and displays server error', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'draft');
    addTearDown(controller.dispose);
    final api = UploadApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityProvider.overrideWithValue(api),
          mediaPickerProvider.overrideWithValue(
            () async => SelectedFile('photo.png', 12),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MediaUploadButton(
              controller: controller,
              onBusyChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('上传图片或视频'));
    await tester.pump();
    expect(api.video, false);
    api.response.completeError(const RequestFailure('请登录后上传'));
    await tester.pumpAndSettle();
    expect(controller.text, 'draft');
    expect(find.text('请登录后上传'), findsOneWidget);
    expect(find.text('上传图片或视频'), findsOneWidget);
  });

  testWidgets('compose page disables publishing until media upload completes', (
    tester,
  ) async {
    final api = UploadApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityProvider.overrideWithValue(api),
          mediaPickerProvider.overrideWithValue(
            () async => SelectedFile('clip.mp4', 12),
          ),
        ],
        child: const MaterialApp(
          home: ComposePage(
            boards: [
              {'slug': 'guest-a', 'name': '测试版块'},
            ],
            initialContent: 'draft',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('上传图片或视频'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上传图片或视频'));
    await tester.pump();
    expect(api.calls, 1);
    expect(
      tester.widget<AppFilledButton>(find.byType(AppFilledButton)).onPressed,
      isNull,
    );
    api.response.complete({'url': '/api/uploads/videos/test-file.mp4'});
    await tester.pumpAndSettle();
    expect(
      tester.widget<AppFilledButton>(find.byType(AppFilledButton)).onPressed,
      isNotNull,
    );
  });
}
