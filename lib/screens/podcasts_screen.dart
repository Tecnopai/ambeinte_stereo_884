import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../models/podcast.dart';
import '../services/podcast_player.dart';
import '../services/podcast_service.dart';
import '../utils/responsive_helper.dart';
import '../widgets/podcast_widgets.dart';
import 'podcast_detail_screen.dart';

/// Pestaña "Podcast": lista de podcasts y "Continuar escuchando".
class PodcastsScreen extends StatefulWidget {
  const PodcastsScreen({super.key});

  @override
  State<PodcastsScreen> createState() => _PodcastsScreenState();
}

class _PodcastsScreenState extends State<PodcastsScreen>
    with AutomaticKeepAliveClientMixin {
  final _service = PodcastService.instance;

  List<PodcastSource>? _sources;
  final Map<String, Podcast> _podcasts = {};
  final Set<String> _failed = {};
  final List<StreamSubscription<Podcast>> _subscriptions = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    PodcastPlayer.instance.init();
    _load();
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final sources = await _service.loadSources();
    if (!mounted) return;
    setState(() => _sources = sources);
    for (final source in sources) {
      _watch(source);
    }
  }

  void _watch(PodcastSource source) {
    _failed.remove(source.key);
    _subscriptions.add(
      _service.watch(source).listen(
        (podcast) {
          if (mounted) setState(() => _podcasts[source.key] = podcast);
        },
        onError: (_) {
          if (mounted) setState(() => _failed.add(source.key));
        },
      ),
    );
  }

  Future<void> _refresh() async {
    final sources = _sources ?? await _service.loadSources();
    await Future.wait(
      sources.map((source) async {
        try {
          final podcast = await _service.refresh(source);
          if (podcast != null && mounted) {
            setState(() {
              _podcasts[source.key] = podcast;
              _failed.remove(source.key);
            });
          }
        } catch (_) {
          if (mounted && !_podcasts.containsKey(source.key)) {
            setState(() => _failed.add(source.key));
          }
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final responsive = ResponsiveHelper(context);
    final sources = _sources;

    return Scaffold(
      appBar: AppBar(
        title: Text('Podcast', style: TextStyle(fontSize: responsive.h2)),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsive.maxContentWidth),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                const _ContinueListening(),
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 14),
                  child: Text(
                    'Nuestros podcasts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (sources == null)
                  const _PodcastCardSkeleton()
                else
                  for (final source in sources)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildCard(source),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(PodcastSource source) {
    final podcast = _podcasts[source.key];
    if (podcast != null) return _PodcastCard(podcast: podcast);
    if (_failed.contains(source.key)) {
      final host = Uri.tryParse(source.url)?.host.toLowerCase() ?? '';
      return _PodcastCardError(
        spotifyUrl: host.endsWith('spotify.com') ? source.url : null,
        onRetry: () {
          setState(() => _failed.remove(source.key));
          _watch(source);
        },
      );
    }
    return const _PodcastCardSkeleton();
  }
}

// ============================================
// CONTINUAR ESCUCHANDO
// ============================================

class _ContinueListening extends StatelessWidget {
  const _ContinueListening();

  @override
  Widget build(BuildContext context) {
    final player = PodcastPlayer.instance;
    return ValueListenableBuilder<PodcastEpisode?>(
      valueListenable: player.lastEpisode,
      builder: (context, episode, _) {
        if (episode == null) return const SizedBox.shrink();
        return ValueListenableBuilder<Map<String, EpisodeProgress>>(
          valueListenable: player.progress,
          builder: (context, progress, _) {
            final p = progress[episode.id];
            if (p == null || p.finished || p.position.inSeconds == 0) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Material(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => playEpisode(context, episode),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        PodcastCover(
                          imageUrl: episode.imageUrl,
                          size: 64,
                          radius: 10,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CONTINUAR ESCUCHANDO',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                episode.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: p.fraction,
                                        minHeight: 3,
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.1),
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    formatRemaining(p),
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        EpisodePlayButton(
                          episode: episode,
                          size: 44,
                          filled: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================
// TARJETA DE PODCAST
// ============================================

class _PodcastCard extends StatelessWidget {
  final Podcast podcast;
  const _PodcastCard({required this.podcast});

  @override
  Widget build(BuildContext context) {
    final latest = podcast.latest;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PodcastDetailScreen(podcast: podcast),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    PodcastCover(
                      imageUrl: podcast.imageUrl,
                      size: 104,
                      radius: 14,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            podcast.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                          ),
                          if (podcast.author.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              podcast.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.headphones_rounded,
                                size: 15,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${podcast.episodes.length} episodios',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _NewBadge(sourceKey: podcast.source.key),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              if (latest != null) ...[
                Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ÚLTIMO · ${formatEpisodeDate(latest.pubDate).toUpperCase()}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.9,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              latest.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      EpisodePlayButton(episode: latest, size: 40),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta "N nuevos" mientras haya episodios sin ver.
class _NewBadge extends StatelessWidget {
  final String sourceKey;
  const _NewBadge({required this.sourceKey});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: PodcastService.instance.newCounts,
      builder: (context, counts, _) {
        final n = counts[sourceKey] ?? 0;
        if (n == 0) return const SizedBox.shrink();
        return NewPill(text: n == 1 ? '1 nuevo' : '$n nuevos');
      },
    );
  }
}

class _PodcastCardSkeleton extends StatelessWidget {
  const _PodcastCardSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          bar(104, 104),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(double.infinity, 16),
                const SizedBox(height: 8),
                bar(120, 14),
                const SizedBox(height: 14),
                bar(80, 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PodcastCardError extends StatelessWidget {
  final VoidCallback onRetry;

  /// Si el podcast solo está en Spotify (sin feed público), no se puede oír
  /// dentro de la app: se ofrece abrirlo en Spotify en vez de reintentar.
  final String? spotifyUrl;

  const _PodcastCardError({required this.onRetry, this.spotifyUrl});

  @override
  Widget build(BuildContext context) {
    final spotify = spotifyUrl;
    if (spotify != null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.podcasts, color: AppColors.textMuted),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Este podcast solo se puede escuchar en Spotify.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(spotify),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Abrir'),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.textMuted),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'No se pudo cargar este podcast.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
