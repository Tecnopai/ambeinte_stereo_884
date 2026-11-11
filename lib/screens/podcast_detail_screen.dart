import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../models/podcast.dart';
import '../services/podcast_player.dart';
import '../services/podcast_service.dart';
import '../widgets/podcast_widgets.dart';
import 'podcast_player_screen.dart';

/// Detalle de un podcast: encabezado, buscador y lista de episodios.
class PodcastDetailScreen extends StatefulWidget {
  final Podcast podcast;
  const PodcastDetailScreen({super.key, required this.podcast});

  @override
  State<PodcastDetailScreen> createState() => _PodcastDetailScreenState();
}

class _PodcastDetailScreenState extends State<PodcastDetailScreen> {
  static const _pageSize = 30;

  final _scroll = ScrollController();
  final _searchController = TextEditingController();
  String _query = '';
  int _visible = _pageSize;
  bool _descriptionExpanded = false;

  /// Fecha de la visita anterior: lo publicado después se marca "Nuevo".
  DateTime? _seenBefore;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _seenBefore = PodcastService.instance.markSeen(widget.podcast);
  }

  bool _isNew(PodcastEpisode e) {
    final before = _seenBefore;
    return before != null && e.pubDate != null && e.pubDate!.isAfter(before);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 600 &&
        _visible < _filtered.length) {
      setState(() => _visible += _pageSize);
    }
  }

  List<PodcastEpisode> get _filtered {
    final q = _normalize(_query);
    if (q.isEmpty) return widget.podcast.episodes;
    return widget.podcast.episodes
        .where((e) => _normalize(e.title).contains(q))
        .toList();
  }

  static String _normalize(String s) {
    const from = 'áéíóúüñÁÉÍÓÚÜÑ';
    const to = 'aeiouunAEIOUUN';
    final buffer = StringBuffer();
    for (final ch in s.trim().split('')) {
      final i = from.indexOf(ch);
      buffer.write(i >= 0 ? to[i] : ch);
    }
    return buffer.toString().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final podcast = widget.podcast;
    final episodes = _filtered;
    final shown = episodes.take(_visible).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: 300,
            backgroundColor: AppColors.background,
            title: _CollapsedTitle(scroll: _scroll, title: podcast.title),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: _Header(podcast: podcast),
            ),
          ),
          SliverToBoxAdapter(child: _buildIntro(podcast)),
          SliverToBoxAdapter(child: _buildSearch(episodes.length)),
          if (episodes.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'No hay episodios con ese nombre.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            ),
          ValueListenableBuilder<Map<String, EpisodeProgress>>(
            valueListenable: PodcastPlayer.instance.progress,
            builder: (context, progress, _) => SliverList.separated(
              itemCount: shown.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              itemBuilder: (context, i) => EpisodeTile(
                episode: shown[i],
                progress: progress[shown[i].id],
                isNew: _isNew(shown[i]),
              ),
            ),
          ),
          if (shown.length < episodes.length)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: PodcastMiniPlayer(margin: EdgeInsets.fromLTRB(12, 0, 12, 8)),
      ),
    );
  }

  Widget _buildIntro(Podcast podcast) {
    final latest = podcast.latest;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (latest != null)
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      'Último episodio',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: () async {
                      final player = PodcastPlayer.instance;
                      final alreadyPlaying =
                          player.current.value?.id == latest.id &&
                          player.playing;
                      if (!alreadyPlaying) await playEpisode(context, latest);
                      if (!mounted) return;
                      if (player.current.value != null) {
                        PodcastPlayerScreen.open(context);
                      }
                    },
                  ),
                ),
              if (podcast.source.externalUrl != null) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 18,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(_externalLabel(podcast.source.externalUrl!)),
                  onPressed: () => launchUrl(
                    Uri.parse(podcast.source.externalUrl!),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ],
          ),
          if (podcast.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(
                () => _descriptionExpanded = !_descriptionExpanded,
              ),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      podcast.description,
                      maxLines: _descriptionExpanded ? null : 3,
                      overflow: _descriptionExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _descriptionExpanded ? 'Ver menos' : 'Ver más',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _externalLabel(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.contains('spotify')) return 'Spotify';
    if (host.contains('apple')) return 'Apple';
    if (host.contains('youtube')) return 'YouTube';
    return 'Abrir';
  }

  Widget _buildSearch(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _query.isEmpty ? '$count episodios' : '$count resultados',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar episodio',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Borrar búsqueda',
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                          _visible = _pageSize;
                        });
                      },
                    ),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() {
              _query = value;
              _visible = _pageSize;
            }),
          ),
        ],
      ),
    );
  }
}

/// Título de la barra que aparece solo cuando el encabezado se colapsa.
class _CollapsedTitle extends StatelessWidget {
  final ScrollController scroll;
  final String title;
  const _CollapsedTitle({required this.scroll, required this.title});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scroll,
      builder: (context, _) {
        final offset = scroll.hasClients ? scroll.offset : 0.0;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: offset > 220 ? 1 : 0,
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final Podcast podcast;
  const _Header({required this.podcast});

  @override
  Widget build(BuildContext context) {
    final url = podcast.imageUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
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
                AppColors.background.withValues(alpha: 0.35),
                AppColors.background.withValues(alpha: 0.75),
                AppColors.background,
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: PodcastCover(imageUrl: url, size: 140, radius: 16),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PODCAST',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        podcast.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      if (podcast.author.isNotEmpty) ...[
                        const SizedBox(height: 6),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Fila de un episodio en la lista.
class EpisodeTile extends StatelessWidget {
  final PodcastEpisode episode;
  final EpisodeProgress? progress;

  /// Publicado después de la visita anterior.
  final bool isNew;

  const EpisodeTile({
    super.key,
    required this.episode,
    this.progress,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final started = p != null && !p.finished && p.position.inSeconds > 0;
    final meta = <String>[
      formatEpisodeDate(episode.pubDate),
      if (p?.finished ?? false)
        'Escuchado'
      else if (started)
        formatRemaining(p)
      else
        formatEpisodeLength(episode.duration),
    ].where((s) => s.isNotEmpty).join(' · ');

    return InkWell(
      onTap: () => showEpisodeNotes(context, episode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            PodcastCover(imageUrl: episode.imageUrl, size: 56, radius: 10),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: (p?.finished ?? false)
                          ? AppColors.textMuted
                          : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (isNew && p == null) ...[
                        const NewPill(text: 'Nuevo'),
                        const SizedBox(width: 8),
                      ],
                      if (p?.finished ?? false) ...[
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (started && p.fraction != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: p.fraction,
                        minHeight: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            EpisodePlayButton(episode: episode, size: 42),
          ],
        ),
      ),
    );
  }
}
