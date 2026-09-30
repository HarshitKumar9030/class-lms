import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_components.dart';
import 'resource_library_screen.dart';
import 'resource_repository.dart';

class _ViewerSource {
  const _ViewerSource(this.local, this.url);
  final File? local;
  final String? url;
}

class ResourceViewerScreen extends ConsumerStatefulWidget {
  const ResourceViewerScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ResourceViewerScreen> createState() =>
      _ResourceViewerScreenState();
}

class _ResourceViewerScreenState extends ConsumerState<ResourceViewerScreen> {
  final pdf = PdfViewerController();
  Future<_ViewerSource>? source;
  bool fullscreen = false;
  bool downloading = false;
  double progress = 0;
  int currentPage = 1;
  int pageCount = 0;
  bool? bookmarked;

  Future<_ViewerSource> loadSource(LearningResource resource) async {
    if (resource.storagePath == null) {
      return _ViewerSource(null, resource.externalUrl);
    }
    final repository = ref.read(resourceRepositoryProvider);
    final local = await repository.localFile(resource);
    return _ViewerSource(
      local,
      local == null ? await repository.signedUrl(resource) : null,
    );
  }

  Future<void> toggleBookmark(LearningResource resource) async {
    final next = !(bookmarked ?? resource.isBookmarked);
    setState(() => bookmarked = next);
    try {
      await ref.read(resourceRepositoryProvider).setBookmark(resource.id, next);
      ref.invalidate(resourcesProvider);
      ref.invalidate(resourceProvider(resource.id));
    } catch (_) {
      if (mounted) {
        setState(() => bookmarked = !next);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t update bookmark. Try again.')),
        );
      }
    }
  }

  Future<void> download(LearningResource resource) async {
    setState(() {
      downloading = true;
      progress = 0;
    });
    try {
      await ref
          .read(resourceRepositoryProvider)
          .download(
            resource,
            onProgress: (value) {
              if (mounted) setState(() => progress = value);
            },
          );
      if (mounted) {
        setState(() => source = loadSource(resource));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved for offline reading.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Download failed. Check your connection and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(resourceProvider(widget.id));
    final resource = value.value;
    if (resource != null) source ??= loadSource(resource);
    return Scaffold(
      appBar: fullscreen
          ? null
          : AppBar(
              title: Text(resource?.title ?? 'Resource'),
              actions: [
                if (resource != null) ...[
                  IconButton(
                    tooltip: 'Bookmark',
                    onPressed: () => toggleBookmark(resource),
                    icon: Icon(
                      (bookmarked ?? resource.isBookmarked)
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                    ),
                  ),
                  if (resource.allowDownload && resource.storagePath != null)
                    IconButton(
                      tooltip: 'Download',
                      onPressed: downloading ? null : () => download(resource),
                      icon: const Icon(Icons.download_rounded),
                    ),
                  if (resource.externalUrl != null)
                    IconButton(
                      tooltip: 'Share link',
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(text: resource.externalUrl!),
                      ),
                      icon: const Icon(Icons.ios_share_rounded),
                    ),
                ],
              ],
            ),
      body: SafeArea(
        child: value.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: LoadingRows(count: 3),
          ),
          error: (_, _) => ErrorState(
            message: 'This resource may have been removed.',
            onRetry: () => ref.invalidate(resourceProvider(widget.id)),
          ),
          data: (item) => FutureBuilder<_ViewerSource>(
            future: source,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorState(
                  message: 'Couldn’t open this file. Check your connection.',
                  onRetry: () => setState(() => source = loadSource(item)),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: LoadingRows(count: 2),
                );
              }
              final media = snapshot.data!;
              return Column(
                children: [
                  if (!fullscreen)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.topicTitle ?? item.courseTitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  if (downloading)
                    LinearProgressIndicator(
                      value: progress == 0 ? null : progress,
                    ),
                  Expanded(child: _content(item, media)),
                  if (item.kind == ResourceKind.pdf)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Previous page',
                            onPressed: currentPage > 1
                                ? () =>
                                      pdf.goToPage(pageNumber: currentPage - 1)
                                : null,
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: Text(
                              'Page $currentPage${pageCount > 0 ? ' of $pageCount' : ''}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Next page',
                            onPressed: pageCount > currentPage
                                ? () =>
                                      pdf.goToPage(pageNumber: currentPage + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                          IconButton(
                            tooltip: fullscreen
                                ? 'Exit fullscreen'
                                : 'Fullscreen',
                            onPressed: () =>
                                setState(() => fullscreen = !fullscreen),
                            icon: Icon(
                              fullscreen
                                  ? Icons.fullscreen_exit_rounded
                                  : Icons.fullscreen_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _content(LearningResource resource, _ViewerSource media) {
    if (resource.kind == ResourceKind.pdf) {
      final params = PdfViewerParams(
        onViewerReady: (document, controller) {
          if (mounted) setState(() => pageCount = document.pages.length);
        },
        onPageChanged: (page) {
          if (page == null) return;
          if (mounted) setState(() => currentPage = page);
          unawaited(
            ref
                .read(resourceRepositoryProvider)
                .savePage(resource.id, page)
                .catchError((_) {}),
          );
        },
      );
      if (media.local != null) {
        return PdfViewer.file(
          media.local!.path,
          controller: pdf,
          initialPageNumber: resource.lastPage ?? 1,
          params: params,
        );
      }
      return PdfViewer.uri(
        Uri.parse(media.url!),
        controller: pdf,
        initialPageNumber: resource.lastPage ?? 1,
        params: params,
      );
    }
    if (resource.kind == ResourceKind.image) {
      if (media.local != null) {
        return InteractiveViewer(
          child: Center(child: Image.file(media.local!)),
        );
      }
      return InteractiveViewer(
        child: Center(
          child: CachedNetworkImage(
            imageUrl: media.url!,
            placeholder: (_, _) => const LoadingRows(count: 1),
            errorWidget: (_, _, _) => const EmptyState(
              title: 'Image unavailable',
              message: 'Try again later.',
            ),
          ),
        ),
      );
    }
    if (resource.kind == ResourceKind.audio) {
      return _AudioPlayer(
        url: media.url ?? media.local!.path,
        local: media.local != null,
      );
    }
    if (resource.externalUrl != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                resourceIcon(resource.kind),
                size: 40,
                color: context.palette.accent,
              ),
              const SizedBox(height: 20),
              Text(
                resource.title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (resource.description != null) ...[
                const SizedBox(height: 8),
                Text(resource.description!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Open link',
                onPressed: () => launchUrl(
                  Uri.parse(resource.externalUrl!),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              resourceIcon(resource.kind),
              size: 40,
              color: context.palette.accent,
            ),
            const SizedBox(height: 16),
            Text(
              'Download to open this file',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              resource.description ??
                  'This document can be opened with an app on your device.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (resource.allowDownload)
              PrimaryButton(
                label: 'Download',
                onPressed: () => download(resource),
              ),
          ],
        ),
      ),
    );
  }
}

class _AudioPlayer extends StatefulWidget {
  const _AudioPlayer({required this.url, required this.local});
  final String url;
  final bool local;
  @override
  State<_AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<_AudioPlayer> {
  final player = AudioPlayer();
  String? error;
  @override
  void initState() {
    super.initState();
    Future(() async {
      try {
        if (widget.local) {
          await player.setFilePath(widget.url);
        } else {
          await player.setUrl(widget.url);
        }
      } catch (_) {
        if (mounted) setState(() => error = 'Audio couldn’t be loaded.');
      }
    });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.headphones_rounded,
            size: 48,
            color: context.palette.accent,
          ),
          const SizedBox(height: 24),
          if (error != null)
            Text(error!)
          else
            StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, snapshot) => IconButton(
                tooltip: player.playing ? 'Pause' : 'Play',
                iconSize: 60,
                onPressed: () =>
                    player.playing ? player.pause() : player.play(),
                icon: Icon(
                  player.playing
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                ),
              ),
            ),
          StreamBuilder<Duration>(
            stream: player.positionStream,
            builder: (context, snapshot) {
              final duration = player.duration ?? Duration.zero;
              final position = snapshot.data ?? Duration.zero;
              return Column(
                children: [
                  Slider(
                    value: position.inMilliseconds
                        .clamp(0, duration.inMilliseconds)
                        .toDouble(),
                    max: duration.inMilliseconds == 0
                        ? 1
                        : duration.inMilliseconds.toDouble(),
                    onChanged: duration == Duration.zero
                        ? null
                        : (value) => player.seek(
                            Duration(milliseconds: value.round()),
                          ),
                  ),
                  Text(
                    '${position.inMinutes}:${(position.inSeconds % 60).toString().padLeft(2, '0')} / ${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
