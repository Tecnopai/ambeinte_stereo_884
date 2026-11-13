import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../core/theme/app_colors.dart';
import '../models/podcast.dart';
import '../screens/podcast_player_screen.dart';
import '../services/audio_player_manager.dart';
import '../services/podcast_player.dart';

// ============================================
// FORMATOS
// ============================================

const _monthsShort = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// "Hoy", "Ayer", "Hace 3 días" o "8 nov 2026".
String formatEpisodeDate(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  if (diff > 1 && diff < 7) return 'Hace $diff días';
  final month = _monthsShort[local.month - 1];
  return local.year == now.year
      ? '${local.day} $month'
      : '${local.day} $month ${local.year}';
}

/// "9 min", "1 h 05 min".
String formatEpisodeLength(Duration? d) {
  if (d == null || d.inSeconds <= 0) return '';
  if (d.inMinutes < 1) return '${d.inSeconds} s';
  if (d.inHours == 0) return '${d.inMinutes} min';
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '${d.inHours} h $m min';
}

/// "4:05" o "1:02:30" para la barra de avance.
String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// "Quedan 6 min".
String formatRemaining(EpisodeProgress p) {
  final total = p.duration;
  if (total == null) return '';
  final left = total - p.position;
  if (left.inMinutes < 1) return 'Queda menos de 1 min';
  return 'Quedan ${formatEpisodeLength(left)}';
}

// ============================================
// ETIQUETA "NUEVO"
// ============================================

/// Pastilla verde pequeña para marcar novedades.
class NewPill extends StatelessWidget {
  final String text;
  const NewPill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ============================================
// PORTADA
// ============================================

/// Portada cuadrada con esquinas redondeadas y respaldo si no carga.
class PodcastCover extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double radius;

  const PodcastCover({
    super.key,
    required this.imageUrl,
    required this.size,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.buttonGradient,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(Icons.podcasts, color: Colors.white, size: size * 0.45),
    );
    final url = imageUrl;
    if (url == null || url.isEmpty) return fallback;
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: pixels,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, _) => Container(
          width: size,
          height: size,
          color: AppColors.surfaceVariant,
        ),
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

// ============================================
// BOTÓN REPRODUCIR DE UN EPISODIO
// ============================================

/// Botón circular que refleja si [episode] está sonando, cargando o en pausa.
class EpisodePlayButton extends StatelessWidget {
  final PodcastEpisode episode;
  final double size;
  final bool filled;

  const EpisodePlayButton({
    super.key,
    required this.episode,
    this.size = 40,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final player = PodcastPlayer.instance;
    return ValueListenableBuilder<PodcastEpisode?>(
      valueListenable: player.current,
      builder: (context, current, _) {
        final isCurrent = current?.id == episode.id;
        if (!isCurrent) return _button(context, Icons.play_arrow_rounded);
        return StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snap) {
            final state = snap.data;
            final loading =
                state?.processingState == ProcessingState.loading ||
                state?.processingState == ProcessingState.buffering;
            // Un episodio terminado no está "sonando" aunque just_audio
            // siga reportando playing.
            final playing =
                (state?.playing ?? false) &&
                state?.processingState != ProcessingState.completed;
            if (playing && loading) {
              return _button(context, null, loading: true);
            }
            return _button(
              context,
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            );
          },
        );
      },
    );
  }

  Widget _button(BuildContext context, IconData? icon, {bool loading = false}) {
    final background = filled
        ? AppColors.primary
        : AppColors.primary.withValues(alpha: 0.15);
    final foreground = filled ? Colors.white : AppColors.primary;
    return Semantics(
      button: true,
      label: icon == Icons.pause_rounded ? 'Pausar' : 'Reproducir',
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => playEpisode(context, episode),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: size * 0.45,
                      height: size * 0.45,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: foreground,
                      ),
                    )
                  : Icon(icon, color: foreground, size: size * 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reproduce o pausa [episode]; muestra un aviso si el audio no carga.
Future<void> playEpisode(BuildContext context, PodcastEpisode episode) async {
  HapticFeedback.lightImpact();
  final player = PodcastPlayer.instance;
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    if (player.current.value?.id == episode.id && player.playing) {
      await player.pause();
    } else {
      await player.play(episode);
    }
  } catch (_) {
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('No se pudo cargar el episodio. Revisa tu conexión.'),
      ),
    );
  }
}

// ============================================
// MINI REPRODUCTOR
// ============================================

/// Barra compacta del episodio actual. Se oculta si no hay episodio o si la
/// radio está sonando (para no mostrar dos reproductores a la vez).
class PodcastMiniPlayer extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const PodcastMiniPlayer({
    super.key,
    this.margin = const EdgeInsets.fromLTRB(20, 0, 20, 4),
  });

  @override
  Widget build(BuildContext context) {
    final player = PodcastPlayer.instance;
    final radio = AudioPlayerManager();
    return ValueListenableBuilder<PodcastEpisode?>(
      valueListenable: player.current,
      builder: (context, episode, _) {
        if (episode == null) return const SizedBox.shrink();
        return StreamBuilder<bool>(
          stream: radio.playingStream,
          initialData: radio.isPlaying,
          builder: (context, radioSnap) {
            if (radioSnap.data ?? false) return const SizedBox.shrink();
            return Padding(
              padding: margin,
              child: _MiniBar(episode: episode),
            );
          },
        );
      },
    );
  }
}

class _MiniBar extends StatelessWidget {
  final PodcastEpisode episode;
  const _MiniBar({required this.episode});

  @override
  Widget build(BuildContext context) {
    final player = PodcastPlayer.instance;
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => PodcastPlayerScreen.open(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 6),
              child: Row(
                children: [
                  PodcastCover(
                    imageUrl: episode.imageUrl,
                    size: 44,
                    radius: 8,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          episode.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          episode.podcastTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  EpisodePlayButton(episode: episode, size: 40),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: player.stop,
                  ),
                ],
              ),
            ),
            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snap) {
                final total = player.duration ?? episode.duration;
                final pos = snap.data ?? Duration.zero;
                final value = (total == null || total.inMilliseconds == 0)
                    ? 0.0
                    : (pos.inMilliseconds / total.inMilliseconds).clamp(
                        0.0,
                        1.0,
                      );
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 2,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  color: AppColors.primary,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
