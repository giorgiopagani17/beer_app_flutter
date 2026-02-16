import 'package:flutter/material.dart';
import 'package:flutter_application/components/beers/beer_recommended_list_card.dart';
import 'dart:async';
import '../models/beer.dart';
import '../components/beers/beer_list_card.dart';
import '../pages/beer_page.dart';
import '../services/api_service.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  final ScrollController _scrollController = ScrollController();

  List<Beer> _savedBeers = [];
  List<Beer> _recommendedBeers = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isLoadingRecommended = false;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMoreData = true;

  ApiService? _apiService;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _initializeApiService();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initializeApiService() async {
    _apiService = await ApiService.getInstance();
    await _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadRecommendedBeers(),
      _loadSavedBeers(),
    ]);
  }

  Future<void> _loadRecommendedBeers() async {
    if (_apiService == null) return;
    try {
      setState(() {
        _isLoadingRecommended = true;
      });

      final response = await _apiService!.getRecommendedBeers(limit: 3);

      if (response.isSuccess && response.data != null) {
        final beersJson = response.data!;
        final newBeers = beersJson
            .whereType<Map<String, dynamic>>()
            .map((json) => Beer.fromJson(json))
            .toList();

        setState(() {
          _recommendedBeers = newBeers;
        });
      }
    } catch (e) {
      // Puoi gestire eventuali errori qui se vuoi
    } finally {
      setState(() {
        _isLoadingRecommended = false;
      });
    }
  }

  Future<void> _loadSavedBeers({bool isRefresh = false}) async {
    if (_isLoading || _apiService == null) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        if (isRefresh) {
          _savedBeers.clear();
          _currentPage = 1;
          _hasMoreData = true;
        }
      });

      final response = await _apiService!.getBeers(
        page: _currentPage,
        limit: 5,
        isFavorite: true,
      );

      if (response.isSuccess && response.data != null) {
        final beersJson = response.data!;
        final newBeers = beersJson
            .whereType<Map<String, dynamic>>()
            .map((json) => Beer.fromJson(json))
            .toList();

        setState(() {
          if (isRefresh) {
            _savedBeers = newBeers;
          } else {
            _savedBeers.addAll(newBeers);
          }
          _hasMoreData = newBeers.length == 5;
        });
      } else {
        setState(() {
          _errorMessage = 'Errore nel caricamento delle birre salvate: ${response.error}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore imprevisto: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreBeers() async {
    if (_isLoadingMore || !_hasMoreData || _apiService == null) return;

    try {
      setState(() {
        _isLoadingMore = true;
      });

      _currentPage++;

      final response = await _apiService!.getBeers(
        page: _currentPage,
        limit: 5,
        isFavorite: true,
      );

      if (response.isSuccess && response.data != null) {
        final beersJson = response.data!;
        final newBeers = beersJson
            .whereType<Map<String, dynamic>>()
            .map((json) => Beer.fromJson(json))
            .toList();

        setState(() {
          _savedBeers.addAll(newBeers);
          _hasMoreData = newBeers.length == 5;
        });
      }
    } catch (e) {
      // Puoi gestire eventuali errori qui se vuoi
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreBeers();
      }
    }
  }

  void _onFavoriteChanged(Beer beer, bool isFavorite) {
    setState(() {
      if (isFavorite) {
        if (!_savedBeers.any((b) => b.id == beer.id)) {
          _savedBeers.insert(0, beer);
        }
        _recommendedBeers.removeWhere((b) => b.id == beer.id);
      } else {
        _savedBeers.removeWhere((b) => b.id == beer.id);
      }
    });
  }

  void _removeBeerFromFavorites(Beer beer) async {
    if (_apiService == null) return;
    try {
      setState(() {
        _savedBeers.removeWhere((b) => b.id == beer.id);
      });

      final response = await _apiService!.deleteFavorite(beer.id);

      if (!response.isSuccess) {
        setState(() {
          _savedBeers.insert(0, beer);
        });
      }
    } catch (e) {
      setState(() {
        if (!_savedBeers.any((b) => b.id == beer.id)) {
          _savedBeers.insert(0, beer);
        }
      });
    }
  }

  void _addBeerToFavorites(Beer beer) async {
    if (_apiService == null) return;
    try {
      final response = await _apiService!.addToFavorite(beer.id);

      if (response.isSuccess) {
        setState(() {
          _savedBeers.insert(0, beer);
        });
      }
    } catch (e) {
      // Puoi gestire eventuali errori qui se vuoi
    }
  }

  void _addRecommendedBeerToFavorites(Beer beer) async {
    if (_apiService == null) return;
    try {
      final response = await _apiService!.addToFavorite(beer.id);

      if (response.isSuccess) {
        await Future.wait([
          _loadSavedBeers(isRefresh: true),
          _loadRecommendedBeers(),
        ]);
      }
    } catch (e) {
      // Puoi gestire eventuali errori qui se vuoi
    }
  }

  void _showBeerDetails(Beer beer, {bool isFromRecommended = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: BeerPage(
                    beer: beer,
                    onFavoriteChanged: _onFavoriteChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      _loadSavedBeers(isRefresh: true);
      _loadRecommendedBeers();
    });
  }

  Future<void> _refreshBeers() async {
    await Future.wait([
      _loadRecommendedBeers(),
      _loadSavedBeers(isRefresh: true),
    ]);
  }

  void _removeRecommendedBeer(int index) {
    setState(() {
      _recommendedBeers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshBeers,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildRecommendedSection(),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Le tue birre salvate',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  _buildSavedBeersList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Consigliate per te',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!_recommendedBeers.isNotEmpty)
                TextButton(
                  onPressed: _loadRecommendedBeers,
                  child: const Text('Altre'),
                ),
            ],
          ),
        ),
        if (_isLoadingRecommended)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_recommendedBeers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Text(
                'Nessuna birra consigliata al momento',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: _recommendedBeers.length,
              itemBuilder: (context, index) {
                final beer = _recommendedBeers[index];
                return RecommendedBeerCard(
                  beer: beer,
                  onTap: () => _showBeerDetails(beer, isFromRecommended: true),
                  onFavorite: () => _addRecommendedBeerToFavorites(beer),
                  onRemove: () => _removeRecommendedBeer(index),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSavedBeersList() {
    if (_isLoading && _savedBeers.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Caricamento birre salvate...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null && _savedBeers.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  '$_errorMessage',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _loadSavedBeers(isRefresh: true),
                icon: Icon(Icons.refresh),
                label: Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    if (_savedBeers.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.collections_bookmark_outlined,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'Nessuna birra salvata',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Salva le tue birre preferite per trovarle qui',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == _savedBeers.length) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text(
                      'Caricamento altre birre...',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }

          final beer = _savedBeers[index];
          return Dismissible(
            key: Key(beer.id.toString()),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(
                Icons.delete,
                color: Colors.white,
                size: 30,
              ),
            ),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) {
              _removeBeerFromFavorites(beer);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: BeerListCard(
                beer: beer,
                onTap: () => _showBeerDetails(beer),
                onFavoriteChanged: _onFavoriteChanged,
              ),
            ),
          );
        },
        childCount: _savedBeers.length + (_isLoadingMore ? 1 : 0),
      ),
    );
  }
}