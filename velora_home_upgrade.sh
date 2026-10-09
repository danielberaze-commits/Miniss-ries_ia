#!/usr/bin/env bash
set -euo pipefail
mkdir -p lib/screens
cat > lib/screens/home_screen.dart <<'DART'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';
import 'series_detail_screen.dart';

const _bg = Color(0xFF08070E);
const _surface = Color(0xFF17121F);
const _gold = Color(0xFFEBC58C);
const _purple = Color(0xFF8B2BEE);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> _series;
  final Set<String> _favorites = <String>{};
  int _tab = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _series = Supabase.instance.client
        .from('series')
        .select()
        .eq('published', true)
        .order('created_at', ascending: false)
        .then((data) => List<Map<String, dynamic>>.from(data));
  }

  String _value(Map<String, dynamic> item, String key) =>
      item[key]?.toString() ?? '';

  String _id(Map<String, dynamic> item) => _value(item, 'id');

  void _open(Map<String, dynamic> item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SeriesDetailScreen(series: item),
    ));
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Widget _cover(Map<String, dynamic> item, {double width = 134}) {
    final url = _value(item, 'cover_url');
    return InkWell(
      onTap: () => _open(item),
      borderRadius: BorderRadius.circular(13),
      child: SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Container(
              width: width,
              height: width * 1.42,
              color: _surface,
              child: url.isEmpty
                  ? const Icon(Icons.movie_creation_outlined, color: _gold, size: 42)
                  : Image.network(url, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined, color: _gold, size: 36)),
            ),
          ),
          const SizedBox(height: 7),
          Text(_value(item, 'title'), maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _shelf(String heading, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 13),
        child: Text(heading, style: const TextStyle(
          fontSize: 21, fontWeight: FontWeight.bold)),
      ),
      SizedBox(height: 230, child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _cover(items[i]),
      )),
    ]);
  }

  Widget _hero(Map<String, dynamic> item) {
    final image = _value(item, 'banner_url').isNotEmpty
        ? _value(item, 'banner_url') : _value(item, 'cover_url');
    return SizedBox(
      height: 395,
      child: Stack(fit: StackFit.expand, children: [
        if (image.isNotEmpty)
          Image.network(image, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: _surface))
        else
          Container(color: _surface),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0x4408070E), Color(0x5508070E), _bg],
        ))),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 30, 22, 25),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Spacer(),
            const Text('DESTAQUE VELORA', style: TextStyle(
              color: _gold, letterSpacing: 2, fontSize: 12,
              fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_value(item, 'title'), maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 33,
                  fontWeight: FontWeight.bold, height: 1.1)),
            const SizedBox(height: 8),
            Text(_value(item, 'description'), maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFDEDAE5))),
            const SizedBox(height: 17),
            Row(children: [
            FilledButton.icon(
              onPressed: () => _open(item),
              style: FilledButton.styleFrom(backgroundColor: _purple,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Ver episódios'),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'Salvar na Minha Lista',
              onPressed: () => setState(() {
                final id = _id(item);
                if (!_favorites.add(id)) _favorites.remove(id);
              }),
              icon: Icon(_favorites.contains(_id(item))
                  ? Icons.bookmark : Icons.bookmark_add_outlined, color: _gold),
            ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _empty() => Center(child: Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.movie_filter_outlined, color: _gold, size: 58),
      const SizedBox(height: 18),
      const Text('O próximo capítulo começa aqui', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      const Text('As minisséries aparecerão aqui assim que forem publicadas.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFBDB5C9))),
      const SizedBox(height: 20),
      OutlinedButton.icon(onPressed: () => setState(_reload),
          icon: const Icon(Icons.refresh), label: const Text('Atualizar catálogo')),
    ]),
  ));

  Widget _home(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return _empty();
    return RefreshIndicator(
      onRefresh: () async {
        setState(_reload);
        await _series;
      },
      child: ListView(children: [
        _hero(items.first),
        _shelf('Novidades', items),
        _shelf('Minisséries Velora', items.reversed.toList()),
        const SizedBox(height: 25),
      ]),
    );
  }

  Widget _explore(List<Map<String, dynamic>> items) {
    final found = items.where((item) =>
      _value(item, 'title').toLowerCase().contains(_query.toLowerCase()) ||
      _value(item, 'description').toLowerCase().contains(_query.toLowerCase())
    ).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.all(18), child: TextField(
        onChanged: (text) => setState(() => _query = text),
        decoration: InputDecoration(
          hintText: 'Buscar minisséries',
          prefixIcon: const Icon(Icons.search, color: _gold),
          filled: true, fillColor: _surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
        ),
      )),
      Expanded(child: found.isEmpty
          ? const Center(child: Text('Nenhuma minissérie encontrada.'))
          : GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: .62,
                crossAxisSpacing: 14, mainAxisSpacing: 16),
              itemCount: found.length,
              itemBuilder: (_, i) => _cover(found[i], width: 165),
            )),
    ]);
  }

  Widget _myList(List<Map<String, dynamic>> items) {
    final saved = items.where((item) => _favorites.contains(_id(item))).toList();
    if (saved.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24),
        child: Text('Sua lista está vazia. Salve uma minissérie para vê-la aqui.',
          textAlign: TextAlign.center)));
    }
    return ListView.builder(itemCount: saved.length, itemBuilder: (_, i) {
      final item = saved[i];
      return ListTile(
        leading: const Icon(Icons.movie, color: _gold),
        title: Text(_value(item, 'title')),
        onTap: () => _open(item),
        trailing: IconButton(icon: const Icon(Icons.bookmark_remove_outlined),
          onPressed: () => setState(() => _favorites.remove(_id(item)))),
      );
    });
  }

  Widget _profile() {
    final email = Supabase.instance.client.auth.currentUser?.email ?? 'Usuário Velora';
    return ListView(padding: const EdgeInsets.all(22), children: [
      const SizedBox(height: 18),
      const CircleAvatar(radius: 36, backgroundColor: _surface,
          child: Icon(Icons.person_outline, color: _gold, size: 38)),
      const SizedBox(height: 15),
      Text(email, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 32),
      Card(color: _surface, child: ListTile(
        leading: const Icon(Icons.logout, color: _gold),
        title: const Text('Sair da conta'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _signOut,
      )),
      const SizedBox(height: 14),
      const Text('Gerenciamento e exclusão de conta serão adicionados '
          'em uma próxima etapa, com proteção no servidor.',
          style: TextStyle(color: Color(0xFFBDB5C9), fontSize: 12)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(data: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.dark(primary: _purple, secondary: _gold,
          surface: _surface),
    ), child: Scaffold(
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text('VELORA', style: TextStyle(color: _gold,
            fontSize: 25, letterSpacing: 3, fontWeight: FontWeight.w700)),
        actions: [
          if (_tab != 1) IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _tab = 1)),
          IconButton(icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => setState(() => _tab = 3)),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _series,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _purple));
          }
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Não foi possível carregar o catálogo.'),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => setState(_reload),
                    child: const Text('Tentar novamente')),
              ])));
          }
          final items = snapshot.data ?? [];
          switch (_tab) {
            case 1: return _explore(items);
            case 2: return _myList(items);
            case 3: return _profile();
            default: return _home(items);
          }
        },
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: _surface,
        indicatorColor: _purple.withValues(alpha: .25),
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: _gold), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Explorar'),
          NavigationDestination(icon: Icon(Icons.bookmark_outline), label: 'Minha Lista'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    ));
  }
}
DART
