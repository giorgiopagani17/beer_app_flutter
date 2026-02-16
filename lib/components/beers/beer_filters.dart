import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class BeerFilters extends StatefulWidget {
  final RangeValues alcoholRange;
  final int? selectedColorId;      // Cambiato da String? a int?
  final int? selectedCountryId;    // Cambiato da String? a int?
  final Function(RangeValues) onAlcoholRangeChanged;
  final Function(int?) onColorChanged;    // Cambiato da String? a int?
  final Function(int?) onCountryChanged;  // Cambiato da String? a int?
  final VoidCallback onClearFilters;

  const BeerFilters({
    super.key,
    required this.alcoholRange,
    required this.selectedColorId,
    required this.selectedCountryId,
    required this.onAlcoholRangeChanged,
    required this.onColorChanged,
    required this.onCountryChanged,
    required this.onClearFilters,
  });

  @override
  State<BeerFilters> createState() => _BeerFiltersState();
}

class _BeerFiltersState extends State<BeerFilters> {
  bool _isExpanded = false;
  late final Dio _dio;
  
  // Dati caricati dalle API - ora con Map per ID e nome
  List<Map<String, dynamic>> _beerColors = [];
  List<Map<String, dynamic>> _countries = [];
  double _minAlcoholContent = 0.0;
  double _maxAlcoholContent = 15.0;
  
  // Stati di caricamento
  bool _isLoadingColors = true;
  bool _isLoadingCountries = true;
  bool _isLoadingAlcoholRange = true;
  
  // Stati di errore
  bool _hasColorsError = false;
  bool _hasCountriesError = false;

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:4000',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
    ));
    
    _loadFilterData();
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  Future<void> _loadFilterData() async {
    await Future.wait([
      _loadBeerColors(),
      _loadCountries(),
      _loadAlcoholRange(),
    ]);
  }

  Future<void> _loadBeerColors() async {
    try {
      final response = await _dio.get('/beer-colors');
      if (response.statusCode == 200) {
        final List<dynamic> colorData = response.data;
        setState(() {
          _beerColors = colorData.cast<Map<String, dynamic>>();
          _isLoadingColors = false;
          _hasColorsError = false;
        });
      }
    } catch (e) {
      print('Errore nel caricamento dei colori: $e');
      setState(() {
        _beerColors = [];
        _isLoadingColors = false;
        _hasColorsError = true;
      });
    }
  }

  Future<void> _loadCountries() async {
    try {
      final response = await _dio.get('/countries');
      if (response.statusCode == 200) {
        final List<dynamic> countryData = response.data;
        setState(() {
          _countries = countryData.cast<Map<String, dynamic>>();
          _isLoadingCountries = false;
          _hasCountriesError = false;
        });
      }
    } catch (e) {
      print('Errore nel caricamento dei paesi: $e');
      setState(() {
        _countries = [];
        _isLoadingCountries = false;
        _hasCountriesError = true;
      });
    }
  }

  Future<void> _loadAlcoholRange() async {
    try {
      final response = await _dio.get('/alcohol-content/range');
      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          _minAlcoholContent = (data['minAlcoholContent'] ?? 0.0).toDouble();
          _maxAlcoholContent = (data['maxAlcoholContent'] ?? 15.0).toDouble();
          _isLoadingAlcoholRange = false;
        });
      }
    } catch (e) {
      print('Errore nel caricamento del range alcolico: $e');
      setState(() {
        _isLoadingAlcoholRange = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = widget.selectedColorId != null || 
                           widget.selectedCountryId != null ||
                           (widget.alcoholRange.start > _minAlcoholContent || 
                            widget.alcoholRange.end < _maxAlcoholContent);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // Header dei filtri
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              behavior: HitTestBehavior.opaque,
              //borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Filtri',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (hasActiveFilters)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getActiveFiltersCount().toString(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Contenuto filtri espandibile
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isExpanded ? null : 0,
            child: _isExpanded ? _buildFiltersContent() : null,
          ),
        ],
      ),
    );
  }

  // Resto del codice uguale...
  Widget _buildFiltersContent() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          
          // Filtro gradazione alcolica
          _buildSectionTitle('Gradazione Alcolica'),
          const SizedBox(height: 8),
          _buildAlcoholRangeFilter(),
          
          const SizedBox(height: 20),
          
          // Filtro colore
          _buildSectionTitle('Colore'),
          const SizedBox(height: 8),
          _buildColorFilter(),
          
          const SizedBox(height: 20),
          
          // Filtro paese
          _buildSectionTitle('Paese di Origine'),
          const SizedBox(height: 8),
          _buildCountryFilter(),
          
          const SizedBox(height: 20),
          
          // Bottoni azioni
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onClearFilters,
                  child: const Text('Cancella Filtri'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlcoholRangeFilter() {
    if (_isLoadingAlcoholRange) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          RangeSlider(
            values: RangeValues(
              widget.alcoholRange.start.clamp(_minAlcoholContent, _maxAlcoholContent),
              widget.alcoholRange.end.clamp(_minAlcoholContent, _maxAlcoholContent),
            ),
            min: _minAlcoholContent,
            max: _maxAlcoholContent,
            divisions: ((_maxAlcoholContent - _minAlcoholContent) * 10).round(),
            labels: RangeLabels(
              '${widget.alcoholRange.start.toStringAsFixed(1)}%',
              '${widget.alcoholRange.end.toStringAsFixed(1)}%',
            ),
            onChanged: widget.onAlcoholRangeChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_minAlcoholContent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              Text(
                '${_maxAlcoholContent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildColorFilter() {
    if (_isLoadingColors) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_hasColorsError || _beerColors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _hasColorsError ? Icons.error_outline : Icons.info_outline,
              color: _hasColorsError 
                  ? Theme.of(context).colorScheme.error 
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _hasColorsError 
                    ? 'Errore nel caricamento dei colori'
                    : 'Nessun colore disponibile',
                style: TextStyle(
                  color: _hasColorsError 
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ),
            if (_hasColorsError)
              IconButton(
                onPressed: _loadBeerColors,
                icon: Icon(
                  Icons.refresh,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                tooltip: 'Riprova',
              ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _beerColors.map((color) {
        final int colorId = color['id'];
        final String colorName = color['name'];
        final isSelected = widget.selectedColorId == colorId;

        return Theme(
          data: Theme.of(context).copyWith(
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
          ),
          child: FilterChip(
            label: Text(colorName),
            selected: isSelected,
            onSelected: (selected) {
              widget.onColorChanged(selected ? colorId : null);
            },
            backgroundColor: Theme.of(context).colorScheme.surface,
            selectedColor: Theme.of(context).colorScheme.primaryContainer,
            checkmarkColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            side: BorderSide(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
            showCheckmark: true,
            autofocus: false,
            visualDensity: VisualDensity.compact,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCountryFilter() {
    if (_isLoadingCountries) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_hasCountriesError || _countries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _hasCountriesError ? Icons.error_outline : Icons.info_outline,
              color: _hasCountriesError 
                  ? Theme.of(context).colorScheme.error 
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _hasCountriesError 
                    ? 'Errore nel caricamento dei paesi'
                    : 'Nessun paese disponibile',
                style: TextStyle(
                  color: _hasCountriesError 
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ),
            if (_hasCountriesError)
              IconButton(
                onPressed: _loadCountries,
                icon: Icon(
                  Icons.refresh,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                tooltip: 'Riprova',
              ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<int>(
      value: widget.selectedCountryId,
      decoration: InputDecoration(
        hintText: 'Seleziona un paese',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: _countries.map((country) {
        final int countryId = country['id'];
        final String countryName = country['name'];
        
        return DropdownMenuItem<int>(
          value: countryId,
          child: Text(countryName),
        );
      }).toList(),
      onChanged: widget.onCountryChanged,
    );
  }

  int _getActiveFiltersCount() {
    int count = 0;
    if (widget.selectedColorId != null) count++;
    if (widget.selectedCountryId != null) count++;
    if (widget.alcoholRange.start > _minAlcoholContent || 
        widget.alcoholRange.end < _maxAlcoholContent) count++;
    return count;
  }
}