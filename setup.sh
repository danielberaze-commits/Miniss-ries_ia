#!/bin/bash
set -e

mkdir -p lib/screens
mkdir -p .github/workflows

cat > pubspec.yaml <<'EOF'
name: miniseries_ia
description: Plataforma MiniSéries IA
publish_to: "none"
version: 1.0.0+1

environment:
  sdk: ">=3.3.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.8.0
  video_player: ^2.9.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
EOF

cat > lib/main.dart <<'EOF'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (url.isEmpty || key.isEmpty) {
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Supabase não configurado.')),
      ),
    ));
    return;
  }

  await Supabase.initialize(url: url, anonKey: key);
  runApp(const MiniSeriesApp());
}

class MiniSeriesApp extends StatelessWidget {
  const MiniSeriesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiniSéries IA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Supabase.instance.client.auth.currentSession == null
          ? const AuthScreen()
          : const HomeScreen(),
    );
  }
}
EOF

cat > lib/screens/auth_screen.dart <<'EOF'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool signup = false;
  bool loading = false;

  Future<void> submit() async {
    setState(() => loading = true);

    try {
      final auth = Supabase.instance.client.auth;

      if (signup) {
        await auth.signUp(
          email: email.text.trim(),
          password: password.text,
        );
      } else {
        await auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MiniSéries IA')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'MiniSéries IA',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 25),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: loading ? null : submit,
              child: Text(signup ? 'Criar conta' : 'Entrar'),
            ),
            TextButton(
              onPressed: () => setState(() => signup = !signup),
              child: Text(
                signup ? 'Já tenho conta' : 'Criar conta',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
EOF

cat > lib/screens/home_screen.dart <<'EOF'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'series_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = loadSeries();
  }

  Future<List<Map<String, dynamic>>> loadSeries() async {
    final data = await Supabase.instance.client
        .from('series')
        .select()
        .eq('published', true)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniSéries IA'),
        actions: [
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HomeScreen(),
                  ),
                );
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Erro: ${snapshot.error}'),
            );
          }

          final series =
              (snapshot.data as List<Map<String, dynamic>>?) ?? [];

          if (series.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma minissérie publicada ainda.',
              ),
            );
          }

          return ListView.builder(
            itemCount: series.length,
            itemBuilder: (context, index) {
              final item = series[index];

              return Card(
                child: ListTile(
                  leading: item['cover_url'] != null
                      ? Image.network(
                          item['cover_url'],
                          width: 60,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.movie),
                  title: Text('${item['title'] ?? ''}'),
                  subtitle: Text(
                    '${item['description'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SeriesDetailScreen(
                          series: item,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
EOF

cat > lib/screens/series_detail_screen.dart <<'EOF'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'player_screen.dart';

class SeriesDetailScreen extends StatelessWidget {
  final Map<String, dynamic> series;

  const SeriesDetailScreen({
    super.key,
    required this.series,
  });

  Future<List<Map<String, dynamic>>> episodes() async {
    final data = await Supabase.instance.client
        .from('episodes')
        .select()
        .eq('series_id', series['id'])
        .order('episode_number');

    return List<Map<String, dynamic>>.from(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${series['title'] ?? ''}'),
      ),
      body: FutureBuilder(
        future: episodes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Erro: ${snapshot.error}'),
            );
          }

          final eps =
              (snapshot.data as List<Map<String, dynamic>>?) ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (series['banner_url'] != null)
                Image.network(series['banner_url']),
              const SizedBox(height: 12),
              Text('${series['description'] ?? ''}'),
              const SizedBox(height: 20),
              ...eps.map(
                (episode) => ListTile(
                  leading: const Icon(Icons.play_circle),
                  title: Text(
                    'Episódio ${episode['episode_number'] ?? ''}: '
                    '${episode['title'] ?? ''}',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(
                          episode: episode,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
EOF

cat > lib/screens/player_screen.dart <<'EOF'
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class PlayerScreen extends StatefulWidget {
  final Map<String, dynamic> episode;

  const PlayerScreen({
    super.key,
    required this.episode,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? controller;

  @override
  void initState() {
    super.initState();

    final url =
        widget.episode['video_url']?.toString() ?? '';

    if (url.isNotEmpty) {
      controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
      )..initialize().then((_) {
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null) {
      return const Scaffold(
        body: Center(
          child: Text('Vídeo não disponível.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.episode['title'] ?? 'Episódio'}',
        ),
      ),
      body: controller!.value.isInitialized
          ? Column(
              children: [
                AspectRatio(
                  aspectRatio: controller!.value.aspectRatio,
                  child: VideoPlayer(controller!),
                ),
                VideoProgressIndicator(
                  controller!,
                  allowScrubbing: true,
                ),
                IconButton(
                  icon: Icon(
                    controller!.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  onPressed: () {
                    setState(() {
                      controller!.value.isPlaying
                          ? controller!.pause()
                          : controller!.play();
                    });
                  },
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}
EOF
