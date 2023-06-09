import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutterfire_json_converters/flutterfire_json_converters.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../firestore/firestore_models/visitor_log.dart';
import '../../loading/ui/overlay_loading.dart';
import '../../scaffold_messenger_controller.dart';
import 'visitor_log_controller.dart';

part 'visitor_log_dialog.freezed.dart';

@freezed
class VisitorLogDialogType with _$VisitorLogDialogType {
  const factory VisitorLogDialogType.read({required VisitorLog visitorLog}) =
      Read;

  const factory VisitorLogDialogType.create() = Create;
}

/// 訪問記録詳細を表示する、または、画像を選択したり、名前やひとことを入力して、
/// 訪問記録を作成するための [AlertDialog]。
class VisitorLogDialog extends ConsumerWidget {
  const VisitorLogDialog({super.key, required this.visitorLogDialogType});

  /// 訪問記録詳細の表示と作成とのどちらの目的でこのウィジェットを使用するか。
  final VisitorLogDialogType visitorLogDialogType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        AlertDialog(
          insetPadding: const EdgeInsets.all(16),
          titlePadding: EdgeInsets.zero,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('投稿'),
                    ...visitorLogDialogType.when(
                      read: (visitorLog) => [
                        Text(
                          _toDateString(visitorLog.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      create: () => const [],
                    ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(90),
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: min(MediaQuery.of(context).size.width, 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...visitorLogDialogType.when(
                    read: (visitorLog) => [
                      SizedBox(
                        width: 96,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (context) => _ExpandedImage(
                                  imageProvider:
                                      NetworkImage(visitorLog.imageUrl),
                                ),
                                fullscreenDialog: true,
                              ),
                            );
                          },
                          child:
                              CachedNetworkImage(imageUrl: visitorLog.imageUrl),
                        ),
                      ),
                      const Gap(16),
                      _VisitorNameTextField.readOnly(
                        text: visitorLog.visitorName,
                      ),
                      const Gap(16),
                      _DescriptionTextField.readOnly(
                        text: visitorLog.description,
                      ),
                      const Gap(16),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final data = ClipboardData(
                            text:
                                'https://besso-log-book.web.app/share/?visitorLogId=${visitorLog.visitorLogId}',
                          );
                          await Clipboard.setData(data);
                          navigator.pop();
                          ref
                              .read(mainScaffoldMessengerControllerProvider)
                              // ignore: missing_whitespace_between_adjacent_strings
                              .showSnackBar('クリップボードに URL をコピーしました！\n'
                                  'SNS やメッセージアプリで友だちにシェアしよう！');
                        },
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('この投稿をシェアする！'),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: IconButton(
                          onPressed: () async {
                            await showDialog<void>(
                              context: context,
                              builder: (_) {
                                return _DeleteConfirmDialog(
                                  onConfirmed: () async {
                                    final navigator = Navigator.of(context);
                                    final isSucceeded = await ref
                                        .read(visitorLogControllerProvider)
                                        .delete(visitorLog: visitorLog);
                                    if (isSucceeded) {
                                      navigator.pop();
                                    }
                                  },
                                );
                              },
                            );
                          },
                          icon: const Icon(Icons.delete),
                        ),
                      ),
                    ],
                    create: () {
                      final pickedImageData =
                          ref.watch(pickedImageDataStateProvider);
                      return [
                        if (pickedImageData == null) ...[
                          const Icon(Icons.photo_outlined, size: 64),
                          const Gap(32),
                          ElevatedButton(
                            onPressed: () => ref
                                .read(visitorLogControllerProvider)
                                .pickImage(),
                            child: const Text('画像を選択する'),
                          ),
                          const Gap(16),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'キャンセル',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ] else ...[
                          SizedBox(
                            width: 96,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (context) => _ExpandedImage(
                                      imageProvider: MemoryImage(
                                        pickedImageData,
                                      ),
                                    ),
                                    fullscreenDialog: true,
                                  ),
                                );
                              },
                              child: Image.memory(pickedImageData),
                            ),
                          ),
                          const Gap(4),
                          TextButton(
                            onPressed: () => ref
                                .read(visitorLogControllerProvider)
                                .resetPickedImage(),
                            child: const Text(
                              '画像を選び直す',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                          const Gap(16),
                          const _VisitorNameTextField(),
                          const Gap(16),
                          const _DescriptionTextField(),
                          const Gap(16),
                          ElevatedButton(
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              await ref
                                  .read(visitorLogControllerProvider)
                                  .createVisitorLog(
                                    visitorName: ref
                                        .read(visitorNameTextEditingController)
                                        .text,
                                    description: ref
                                        .read(descriptionTextEditingController)
                                        .text,
                                    imageData: pickedImageData,
                                  );
                              navigator.pop();
                            },
                            child: const Text('投稿'),
                          ),
                        ],
                      ];
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        if (ref.watch(showOverlayLoadingOnVisitorLogCreateDialogStateProvider))
          const OverlayLoading(),
      ],
    );
  }

  String _toDateString(SealedTimestamp createdAt) {
    final dateTime = createdAt.dateTime;
    if (dateTime == null) {
      return '';
    }
    final year = createdAt.dateTime!.year;
    final month = createdAt.dateTime!.month;
    final day = createdAt.dateTime!.day;
    return '$year年$month月$day日';
  }
}

class _VisitorNameTextField extends StatefulHookConsumerWidget {
  const _VisitorNameTextField()
      : enabled = true,
        text = '';

  const _VisitorNameTextField.readOnly({
    required this.text,
  }) : enabled = false;

  final bool enabled;
  final String? text;

  @override
  ConsumerState<_VisitorNameTextField> createState() =>
      _VisitorNameTextFieldState();
}

class _VisitorNameTextFieldState extends ConsumerState<_VisitorNameTextField> {
  @override
  void initState() {
    if (widget.text != null) {
      ref.read(visitorNameTextEditingController).text = widget.text!;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      enabled: widget.enabled,
      controller: ref.watch(visitorNameTextEditingController),
      decoration: InputDecoration(
        labelText: '訪問者の名前',
        fillColor: Colors.grey[200],
        border: InputBorder.none,
        filled: true,
      ),
    );
  }
}

class _DescriptionTextField extends StatefulHookConsumerWidget {
  const _DescriptionTextField()
      : enabled = true,
        text = '';

  const _DescriptionTextField.readOnly({
    required this.text,
  }) : enabled = false;

  final bool enabled;
  final String text;

  @override
  ConsumerState<_DescriptionTextField> createState() =>
      _DescriptionTextFieldState();
}

class _DescriptionTextFieldState extends ConsumerState<_DescriptionTextField> {
  @override
  void initState() {
    ref.read(descriptionTextEditingController).text = widget.text;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      enabled: widget.enabled,
      controller: ref.watch(descriptionTextEditingController),
      keyboardType: TextInputType.multiline,
      minLines: 2,
      maxLines: null,
      decoration: InputDecoration(
        labelText: '思い出やひとこと',
        fillColor: Colors.grey[200],
        border: InputBorder.none,
        filled: true,
      ),
    );
  }
}

class _DeleteConfirmDialog extends StatelessWidget {
  const _DeleteConfirmDialog({
    required this.onConfirmed,
  });

  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: min(MediaQuery.of(context).size.width, 440),
        height: 154,
        child: Column(
          children: [
            const Gap(24),
            SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  '投稿を削除しますか？',
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const Gap(20),
            Container(
              width: double.infinity,
              height: 1,
              color: Colors.grey,
            ),
            SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextButton(
                      child: Text(
                        'キャンセル',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall!
                            .copyWith(color: Colors.grey),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 48,
                    color: Colors.grey,
                  ),
                  Expanded(
                    child: TextButton(
                      child: Text(
                        '削除する',
                        style: Theme.of(context).textTheme.titleSmall!.copyWith(
                              color: Colors.red,
                            ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onConfirmed();
                      },
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _ExpandedImage extends StatefulWidget {
  const _ExpandedImage({
    required this.imageProvider,
  });

  final ImageProvider imageProvider;

  @override
  State<_ExpandedImage> createState() => _ExpandedImageState();
}

class _ExpandedImageState extends State<_ExpandedImage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
          },
          child: PhotoView(
            imageProvider: widget.imageProvider,
          ),
        ),
      ),
    );
  }
}
