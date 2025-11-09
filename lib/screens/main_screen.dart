import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/anime.dart';
import '../services/anime_service.dart';
import 'anime_detail_screen.dart';
import 'my_list_screen.dart';
import 'profile_screen.dart';
import 'card_game_screen.dart';
import '../helpers/achievement_helper.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const MainScreenHome(),
    const MyListScreen(),
    const CardGameScreen(),
    const ProfileScreen(),
  ];

  void _onTabTapped(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _pages[_currentIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.85),
            Colors.black.withOpacity(0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 25, offset: const Offset(0, -5)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFFFF6B6B),
            unselectedItemColor: Colors.white60,
            showUnselectedLabels: true,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Главная'),
              BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'Мой список'),
              BottomNavigationBarItem(icon: Icon(Icons.style_rounded), label: 'AenimaCard'),
              BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Профиль'),
            ],
          ),
        ),
      ),
    );
  }
}

class MainScreenHome extends StatefulWidget {
  const MainScreenHome({super.key});
  @override
  State<MainScreenHome> createState() => _MainScreenHomeState();
}

class _MainScreenHomeState extends State<MainScreenHome> {
  late Future<List<Anime>> _topAnimeFuture;
  late Future<List<Anime>> _airingAnimeFuture;
  late Future<List<Anime>> _upcomingAnimeFuture;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<Anime> _suggestions = [];
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _topAnimeFuture = AnimeService.fetchAnimeList();
    _airingAnimeFuture = AnimeService.fetchAnimeList(filter: 'airing');
    _upcomingAnimeFuture = AnimeService.fetchAnimeList(filter: 'upcoming');

    _searchController.addListener(() {
      final text = _searchController.text.trim();
      if (text.isEmpty) {
        setState(() => _suggestions.clear());
        _removeOverlay();
      } else {
        _updateSuggestions(text);
      }
    });

    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) _removeOverlay();
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      AchievementHelper.checkAndShowAchievements();
    });
  }

  Future<void> _updateSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions.clear());
      _removeOverlay();
      return;
    }
    try {
      final results = await AnimeService.fetchAnimeList(query: query);
      setState(() => _suggestions = results.take(7).toList());
      if (_suggestions.isNotEmpty && _searchFocus.hasFocus) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    } catch (e) {
      setState(() => _suggestions.clear());
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: 20,
        width: MediaQuery.of(context).size.width - 40,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(-60, 58),
          child: Material(
            elevation: 16,
            shadowColor: const Color(0xFFFF6B6B).withOpacity(0.3),
            borderRadius: BorderRadius.circular(24),
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 450),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.92), Colors.black.withOpacity(0.88)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.2), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFFF6B6B).withOpacity(0.1), blurRadius: 20, spreadRadius: 2),
                    ],
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final anime = _suggestions[index];
                      return InkWell(
                        onTap: () {
                          _searchController.clear();
                          _removeOverlay();
                          _searchFocus.unfocus();
                          setState(() => _showSearchBar = false);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AnimeDetailScreen(anime: anime)),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  anime.imageUrl,
                                  width: 55,
                                  height: 75,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) {
                                    return Container(
                                      width: 55,
                                      height: 75,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.broken_image, color: Colors.white30),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      anime.title,
                                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (anime.isFranchise && anime.franchiseSeasons != null) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF6B6B).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.4)),
                                        ),
                                        child: Text(
                                          '${anime.franchiseSeasons!.length} сезонов',
                                          style: const TextStyle(
                                            color: Color(0xFFFF6B6B),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (anime.score != null) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [const Color(0xFFFFD93D).withOpacity(0.2), const Color(0xFFFF6B6B).withOpacity(0.2)]),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFFFD93D).withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star_rounded, color: Color(0xFFFFD93D), size: 16),
                                            const SizedBox(width: 4),
                                            Text('${anime.score}', style: const TextStyle(color: Color(0xFFFFD93D), fontSize: 13, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [const Color(0xFFFF6B6B).withOpacity(0.2), const Color(0xFFFFD93D).withOpacity(0.2)]),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 350.ms, delay: (index * 40).ms).slideX(begin: -0.15, end: 0, duration: 350.ms, curve: Curves.easeOutCubic);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_showSearchBar) {
          setState(() {
            _showSearchBar = false;
            _searchController.clear();
            _suggestions.clear();
          });
          _removeOverlay();
          _searchFocus.unfocus();
          return false;
        }
        return true;
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PreferredSize(preferredSize: const Size.fromHeight(70), child: _buildAppBar()),
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: FutureBuilder<List<Anime>>(
                  future: _topAnimeFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) return _HeroBanner(anime: snapshot.data!.first);
                    return const SizedBox.shrink();
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _CategorySection(title: '🔥 Популярное сейчас', future: _airingAnimeFuture),
                    const SizedBox(height: 24),
                    _CategorySection(title: '⭐ Топ аниме', future: _topAnimeFuture),
                    const SizedBox(height: 24),
                    _CategorySection(title: '🎬 Скоро выйдет', future: _upcomingAnimeFuture),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.black.withOpacity(0.9), Colors.black.withOpacity(0.7)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: _showSearchBar ? 60 : 70,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                if (!_showSearchBar) ...[
                  GestureDetector(
                    onTap: () {
                      setState(() => _showSearchBar = true);
                      Future.delayed(const Duration(milliseconds: 100), () => _searchFocus.requestFocus());
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFFD93D)]),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: const Color(0xFFFF6B6B).withOpacity(0.5), blurRadius: 12, offset: const Offset(0, 3))],
                      ),
                      child: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
                    ),
                  ).animate(onPlay: (c) => c.repeat())
                    .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.12, 1.12), duration: 600.ms, curve: Curves.easeInOut)
                    .then()
                    .scale(begin: const Offset(1.12, 1.12), end: const Offset(1.0, 1.0), duration: 600.ms, curve: Curves.easeInOut),
                  const Spacer(),
                  const Text('Aenima', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFFD93D)]), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.movie_filter, color: Colors.white, size: 22),
                  ),
                ] else ...[
                  Expanded(
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _showSearchBar = false;
                              _searchController.clear();
                              _suggestions.clear();
                            });
                            _removeOverlay();
                            _searchFocus.unfocus();
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CompositedTransformTarget(
                            link: _layerLink,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: TextField(
                                  focusNode: _searchFocus,
                                  controller: _searchController,
                                  style: const TextStyle(color: Colors.white, fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: 'Поиск аниме...',
                                    hintStyle: const TextStyle(color: Colors.white60),
                                    filled: true,
                                    fillColor: Colors.black.withOpacity(0.4),
                                    prefixIcon: const Icon(Icons.search, color: Color(0xFFFF6B6B), size: 22),
                                    suffixIcon: _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() => _suggestions.clear());
                                              _removeOverlay();
                                            },
                                          )
                                        : null,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final Anime anime;
  const _HeroBanner({required this.anime});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnimeDetailScreen(anime: anime))),
      child: Container(
        height: 400,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 15))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(child: Image.network(anime.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.white.withOpacity(0.1)))),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.7), Colors.black.withOpacity(0.95)], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.3, 0.7, 1.0]),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFFD93D)]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: const Color(0xFFFF6B6B).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [Icon(Icons.trending_up, color: Colors.white, size: 16), SizedBox(width: 6), Text('TOP 1', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2))],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(anime.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      if (anime.genres != null)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: anime.genres!.take(3).map((g) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.3))), child: Text(g, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)))).toList(),
                        ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFFD93D)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFFFF6B6B).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.play_arrow, color: Colors.white, size: 20), SizedBox(width: 8), Text('Подробнее', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOut),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String title;
  final Future<List<Anime>> future;
  const _CategorySection({required this.title, required this.future});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
        const SizedBox(height: 12),
        FutureBuilder<List<Anime>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 280,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: 5,
                  itemBuilder: (_, i) => Container(width: 160, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20))),
                ),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) return const SizedBox.shrink();
            final animes = snapshot.data!.take(10).toList();
            return SizedBox(
              height: 280,
              child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: animes.length, itemBuilder: (_, i) => _AnimeCard(anime: animes[i], index: i)),
            );
          },
        ),
      ],
    );
  }
}

class _AnimeCard extends StatelessWidget {
  final Anime anime;
  final int index;
  const _AnimeCard({required this.anime, required this.index});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnimeDetailScreen(anime: anime))),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(child: Image.network(anime.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.white.withOpacity(0.1)))),
              Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.8)], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.5, 1.0])))),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(anime.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      if (anime.score != null) Row(children: [const Icon(Icons.star, color: Color(0xFFFFD93D), size: 14), const SizedBox(width: 4), Text('${anime.score}', style: const TextStyle(color: Color(0xFFFFD93D), fontSize: 12, fontWeight: FontWeight.bold))]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 400.ms, delay: (index * 80).ms).slideX(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOut),
    );
  }
}