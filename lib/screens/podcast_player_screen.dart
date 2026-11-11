import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme/app_colors.dart';
import '../models/podcast.dart';
import '../services/podcast_player.dart';
import '../widgets/podcast_widgets.dart';

/// Reproductor de podcast a pantalla completa.
class PodcastPlayerScreen extends StatelessWidget {
  const PodcastPlayerScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => const PodcastPlayerScreen(),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  static const _speeds = [1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final player = PodcastPlayer.instance;
    return ValueListenableBuilder<PodcastEpisode?>(
      valueListenable: player.current,
      builder: (context, episode, _) {
        if (episode == null) {
          // Se cerró el episodio: volver atrás.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
          return const Scaffold(backgroundColor: AppColors.background);
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            fit: StackFit.expand,
            children: [
              _BlurredBackground(imageUrl: episode.imageUrl),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final coverSize = (constraints.maxWidth - 64).clamp(
                      160.0,
                      (constraints.maxHeight * 0.42).clamp(160.0, 360.0),
                    );
                    return Column(
                      children: [
                        _TopBar(episode: episode),
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 30,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: PodcastCover(
                            imageUrl: episode.imageUrl,
                            size: coverSize,
                            radius: 20,
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                episode.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                [
                                  episode.podcastTitle,
                                  formatEpisodeDate(episode.pubDate),
                                ].where((s) => s.isNotEmpty).join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _ProgressBar(episode: episode),
                        const SizedBox(height: 8),
                        _Controls(episode: episode),
                        const SizedBox(height: 12),
                        _BottomActions(episode: episode),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BlurredBackground extends StatelessWidget {
  final String? imageUrl;
  const _BlurredBackground({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null && url.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              memCacheWidth: 200,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background.withValues(alpha: 0.55),
                AppColors.background.withValues(alpha: 0.85),
                AppColors.background,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final PodcastEpisode episode;
  const _TopBar({required this.episode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 32,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Expanded(
            child: Text(
              'Reproduciendo podcast',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Compartir',
            icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
            onPressed: () {
              final box = context.findRenderObject() as RenderBox?;
              SharePlus.instance.share(
                ShareParams(
                  text:
                      '🎧 ${episode.title}\n${episode.podcastTitle}\n${episode.audioUrl}',
                  sharePositionOrigin: box == null
                      ? null
                      : box.localToGlobal(Offset.zero) & box.size,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatefulWidget {
  final PodcastEpisode episode;
  const _ProgressBar({required this.episode});

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final player = PodcastPlayer.instance;
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (context, durationSnap) {
        final total =
            durationSnap.data ?? player.duration ?? widget.episode.duration;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, posSnap) {
            final pos = posSnap.data ?? player.position;
            final max = (total?.inMilliseconds ?? 0).toDouble();
            final value = _dragValue ??
                (max <= 0 ? 0.0 : pos.inMilliseconds.clamp(0, max).toDouble());
            final shown = Duration(milliseconds: value.round());
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                      thumbColor: Colors.white,
                      overlayColor: AppColors.primary.withValues(alpha: 0.2),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                    ),
                    child: Slider(
                      value: value,
                      max: max <= 0 ? 1 : max,
                      onChanged: max <= 0
                          ? null
                          : (v) => setState(() => _dragValue = v),
                      onChangeEnd: max <= 0
                          ? null
                          : (v) async {
                              await player.seek(
                                Duration(milliseconds: v.round()),
                              );
                              if (mounted) setState(() => _dragValue = null);
                            },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatClock(shown), style: _timeStyle),
                        Text(
                          total == null
                              ? '--:--'
                              : '-${formatClock(total - shown)}',
                          style: _timeStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static const _timeStyle = TextStyle(
    color: AppColors.textMuted,
    fontSize: 12,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

class _Controls extends StatelessWidget {
  final PodcastEpisode episode;
  const _Controls({required this.episode});

  @override
  Widget build(BuildContext context) {
    final player = PodcastPlayer.instance;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Retroceder 10 segundos',
          iconSize: 36,
          color: Colors.white,
          icon: const Icon(Icons.replay_10_rounded),
          onPressed: () {
            HapticFeedback.selectionClick();
            player.seekBy(const Duration(seconds: -10));
          },
        ),
        const SizedBox(width: 24),
        EpisodePlayButton(episode: episode, size: 76, filled: true),
        const SizedBox(width: 24),
        IconButton(
          tooltip: 'Adelantar 30 segundos',
          iconSize: 36,
          color: Colors.white,
          icon: const Icon(Icons.forward_30_rounded),
          onPressed: () {
            HapticFeedback.selectionClick();
            player.seekBy(const Duration(seconds: 30));
          },
        ),
      ],
    );
  }
}

class _BottomActions extends StatelessWidget {
  final PodcastEpisode episode;
  const _BottomActions({required this.episode});

  @override
  Widget build(BuildContext context) {
    final player = PodcastPlayer.instance;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StreamBuilder<double>(
          stream: player.speedStream,
          builder: (context, snap) {
            final speed = snap.data ?? player.speed;
            final label = speed == speed.roundToDouble()
                ? '${speed.toInt()}×'
                : '$speed×';
            return TextButton.icon(
              style: _pillStyle,
              icon: const Icon(Icons.speed_rounded, size: 18),
              label: Text('Velocidad $label'),
              onPressed: () {
                HapticFeedback.selectionClick();
                final speeds = PodcastPlayerScreen._speeds;
                final i = speeds.indexWhere((s) => (s - speed).abs() < 0.01);
                player.setSpeed(speeds[(i + 1) % speeds.length]);
              },
            );
          },
        ),
        if (episode.description.isNotEmpty) ...[
          const SizedBox(width: 12),
          TextButton.icon(
            style: _pillStyle,
            icon: const Icon(Icons.notes_rounded, size: 18),
            label: const Text('Notas'),
            onPressed: () => showEpisodeNotes(context, episode),
          ),
        ],
      ],
    );
  }

  static final _pillStyle = TextButton.styleFrom(
    foregroundColor: Colors.white,
    backgroundColor: Colors.white.withValues(alpha: 0.08),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    shape: const StadiumBorder(),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );
}

/// Hoja inferior con las notas del episodio y botón para reproducirlo.
Future<void> showEpisodeNotes(BuildContext context, PodcastEpisode episode) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PodcastCover(imageUrl: episode.imageUrl, size: 64, radius: 10),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        formatEpisodeDate(episode.pubDate),
                        formatEpisodeLength(episode.duration),
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: _NotesPlayButton(episode: episode),
          ),
          const SizedBox(height: 20),
          SelectableText(
            episode.description.isEmpty
                ? 'Este episodio no tiene notas.'
                : episode.description,
            style: const TextStyle(
              color: Color(0xFFD7E0D7),
              fontSize: 15,
              height: 1.55,
            ),
          ),
        ],
      ),
    ),
  );
}

class _NotesPlayButton extends StatelessWidget {
  final PodcastEpisode episode;
  const _NotesPlayButton({required this.episode});

  @override
  Widget build(BuildContext context) {
    final player = PodcastPlayer.instance;
    return ValueListenableBuilder<PodcastEpisode?>(
      valueListenable: player.current,
      builder: (context, current, _) => StreamBuilder(
        stream: player.playerStateStream,
        builder: (context, snap) {
          final playing = current?.id == episode.id && (snap.data?.playing ?? false);
          return FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            ),
            icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            label: Text(playing ? 'Pausar' : 'Reproducir'),
            onPressed: () => playEpisode(context, episode),
          );
        },
      ),
    );
  }
}
