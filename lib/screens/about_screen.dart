import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/audio_player_manager.dart';
import '../widgets/mini_player.dart';
import '../widgets/live_indicator.dart';

class AboutScreen extends StatelessWidget {
  final AudioPlayerManager audioManager;

  const AboutScreen({super.key, required this.audioManager});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: audioManager.playingStream,
      initialData: audioManager.isPlaying,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Text('Acerca de'),
                if (isPlaying) const LiveIndicator(),
              ],
            ),
            centerTitle: false,
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: 24,
                  left: 24,
                  right: 24,
                  bottom: isPlaying ? 100 : 24,
                ),
                child: Column(
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 32),
                    const Text(
                      'Ambient Stereo FM',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Radio sin fronteras',
                      style: TextStyle(fontSize: 16, color: Color(0xFFCBD5E1)),
                    ),
                    const SizedBox(height: 32),
                    _buildDescriptionCard(),
                    const SizedBox(height: 32),
                    _buildInfoCard('Versión', '1.0.0'),
                    const SizedBox(height: 16),
                    _buildInfoCard('Sitio Web', 'ambientestereo.fm'),
                    const SizedBox(height: 32),
                    _buildWebsiteButton(),
                  ],
                ),
              ),
              if (isPlaying)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: MiniPlayer(audioManager: audioManager),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
      ),
      child: const Icon(Icons.radio, size: 60, color: Colors.white),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Text(
            'Disfruta de la mejor música ambiental y contenido exclusivo las 24 horas del día. Ambient Stereo FM te conecta con sonidos únicos y las últimas noticias de nuestro sitio web.',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFFCBD5E1),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF374151).withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, color: Color(0xFFCBD5E1)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebsiteButton() {
    return ElevatedButton.icon(
      onPressed: () => _launchUrl('https://ambientestereo.fm'),
      icon: const Icon(Icons.web),
      label: const Text('Visitar sitio web'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
