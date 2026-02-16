import 'package:flutter/material.dart';
import 'dart:async';
import '../routes/routes.dart';
import '../models/beer.dart';
import '../components/beers/beer_list_card.dart';
import '../components/beers/beer_search_bar.dart';
import '../components/beers/beer_filters.dart';
import '../pages/beer_page.dart';
import '../services/api_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Beer> _beers = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String _currentQuery = '';
  int _currentPage = 1;
  bool _hasMoreData = true;

  RangeValues _alcoholRange = const RangeValues(0.0, 15.0);
  double _minAlcoholContent = 0.0;
  double _maxAlcoholContent = 15.0;
  int? _selectedColorId;
  int? _selectedCountryId;

  Timer? _debounceTimer;
  ApiService? _apiService;

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
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadAlcoholRange();
    await _loadBeers();
  }

  Future<void> _loadAlcoholRange() async {
    if (_apiService == null) return;
    final response = await _apiService!.getAlcoholRange();
    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      setState(() {
        _minAlcoholContent = (data['minAlcoholContent'] ?? 0.0).toDouble();
        _maxAlcoholContent = (data['maxAlcoholContent'] ?? 15.0).toDouble();
        _alcoholRange = RangeValues(_minAlcoholContent, _maxAlcoholContent);
      });
    } else {
      print('Errore nel caricamento del range alcolico: ${response.error}');
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

  Future<void> _loadBeers({bool isRefresh = false}) async {
    if (_isLoading || _apiService == null) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        if (isRefresh) {
          _beers.clear();
          _currentPage = 1;
          _hasMoreData = true;
        }
      });

      final apiResponse = await _apiService!.getBeers(
        page: _currentPage,
        limit: 5,
        query: _currentQuery.isNotEmpty ? _currentQuery : null,
        minAlcohol: (_alcoholRange.start > _minAlcoholContent) ? _alcoholRange.start : null,
        maxAlcohol: (_alcoholRange.end < _maxAlcoholContent) ? _alcoholRange.end : null,
        colorId: _selectedColorId,
        countryId: _selectedCountryId,
      );
      debugPrint('apiResponse: $apiResponse');
      debugPrint('apiResponse.data: ${apiResponse.data}');
      debugPrint('apiResponse.error: ${apiResponse.error}');

      if (apiResponse.isSuccess && apiResponse.data != null) {
        _handleSuccessfulResponse(apiResponse.data, isRefresh);
      } else {
        setState(() {
          _errorMessage = apiResponse.error ?? 'Errore sconosciuto';
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

      final apiResponse = await _apiService!.getBeers(
        page: _currentPage,
        limit: 5,
        query: _currentQuery.isNotEmpty ? _currentQuery : null,
        minAlcohol: (_alcoholRange.start > _minAlcoholContent) ? _alcoholRange.start : null,
        maxAlcohol: (_alcoholRange.end < _maxAlcoholContent) ? _alcoholRange.end : null,
        colorId: _selectedColorId,
        countryId: _selectedCountryId,
      );

      if (apiResponse.isSuccess && apiResponse.data != null) {
        _handleSuccessfulResponse(apiResponse.data, false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel caricamento: ${apiResponse.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _handleSuccessfulResponse(dynamic responseData, bool isRefresh) {
  List<dynamic> beersJson = [];
  debugPrint('Response dataaaa');

  // Se la risposta è una mappa, estrai la lista dalla chiave 'data'
  if (responseData is Map<String, dynamic>) {
    final dynamic dataField = responseData['data'];
    if (dataField is List) {
      beersJson = dataField;
    } else {
      beersJson = [];
    }
  }
  // Se la risposta è già una lista
  else if (responseData is List) {
    beersJson = responseData;
  }

  // Parsing sicuro
  final newBeers = beersJson
      .whereType<Map<String, dynamic>>()
      .map((json) => Beer.fromJson(json))
      .toList();

  setState(() {
    if (isRefresh) {
      _beers = newBeers;
    } else {
      _beers.addAll(newBeers);
    }
    _hasMoreData = newBeers.length == 5;
  });
}

  void _searchBeers(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _currentQuery = query.trim();
        _currentPage = 1;
      });
      _loadBeers(isRefresh: true);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _debounceTimer?.cancel();
    setState(() {
      _currentQuery = '';
      _currentPage = 1;
    });
    _loadBeers(isRefresh: true);
  }

  void _onAlcoholRangeChanged(RangeValues range) {
    setState(() {
      _alcoholRange = range;
    });
    _applyFilters();
  }

  void _onColorChanged(int? colorId) {
    setState(() {
      _selectedColorId = colorId;
    });
    _applyFilters();
  }

  void _onCountryChanged(int? countryId) {
    setState(() {
      _selectedCountryId = countryId;
    });
    _applyFilters();
  }

  void _clearFilters() async {
    await _loadAlcoholRange();
    setState(() {
      _selectedColorId = null;
      _selectedCountryId = null;
    });
    _applyFilters();
  }

  void _applyFilters() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _currentPage = 1;
      });
      _loadBeers(isRefresh: true);
    });
  }

  void _showBeerDetails(Beer beer) {
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
                    onFavoriteChanged: _onFavoriteChanged, // <--- aggiungi qui
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

    void _onFavoriteChanged(Beer beer, bool isFavorite) {
    debugPrint('onFavoriteChanged: beer.id=${beer.id}, isFavorite=$isFavorite');
    setState(() {
      final index = _beers.indexWhere((b) => b.id == beer.id);
      if (index != -1) {
        debugPrint('Modifico isFavorite per birra ${beer.id} in posizione $index');
        _beers[index] = Beer(
          id: beer.id,
          name: beer.name,
          subtitle: beer.subtitle,
          imageUrl: beer.imageUrl,
          description: beer.description,
          alcoholContent: beer.alcoholContent,
          color: beer.color,
          foam: beer.foam,
          origin: beer.origin,
          brewery: beer.brewery,
          tastingNotes: beer.tastingNotes,
          servingTemperature: beer.servingTemperature,
          pouringInstructions: beer.pouringInstructions,
          isFavorite: isFavorite,
        );
      }
      debugPrint('_beers attuale: ${_beers.map((b) => '[${b.id}:${b.isFavorite}]').join(', ')}');
    });
  }
  Future<void> _refreshBeers() async {
    await _loadBeers(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          BeerSearchBar(
            controller: _searchController,
            onChanged: _searchBeers,
            onClear: _clearSearch,
          ),
          BeerFilters(
            alcoholRange: _alcoholRange,
            selectedColorId: _selectedColorId,
            selectedCountryId: _selectedCountryId,
            onAlcoholRangeChanged: _onAlcoholRangeChanged,
            onColorChanged: _onColorChanged,
            onCountryChanged: _onCountryChanged,
            onClearFilters: _clearFilters,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildBeersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBeersList() {
    if (_isLoading && _beers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Caricamento birre...'),
          ],
        ),
      );
    }

    if (_errorMessage != null && _beers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadBeers(isRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      );
    }

    if (_beers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Nessuna birra trovata',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Prova a cambiare i filtri o i termini di ricerca',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                _clearSearch();
                _clearFilters();
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Cancella tutto'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshBeers,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _beers.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _beers.length) {
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

          final beer = _beers[index];
          return BeerListCard(
            beer: beer,
            onTap: () => _showBeerDetails(beer),
            onFavoriteChanged: _onFavoriteChanged,
          );
        },
      ),
    );
  }
}