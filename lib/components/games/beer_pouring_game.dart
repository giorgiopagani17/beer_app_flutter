import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter_application/services/api_service.dart';

enum GuinnessPhase { start, firstPour, settle, secondPour, finished }

class BeerPouringGame extends StatefulWidget {
  const BeerPouringGame({super.key});

  @override
  State<BeerPouringGame> createState() => _BeerPouringGameState();
}

class _BeerPouringGameState extends State<BeerPouringGame>
    with TickerProviderStateMixin {
  GuinnessPhase _phase = GuinnessPhase.start;
  bool _isPouring = false;
  bool _isSettling = false;
  bool _gameFinished = false;
  bool _hasOverflowed = false;
  double _beerLevel = 0.0;
  double _foamLevel = 0.0;
  int _finalScore = 0;
  Timer? _pouringTimer;
  Timer? _settleTimer;
  int _settleSecondsLeft = 0;

  double _tiltAngle = 45.0; // 0 = verticale, 60 = max inclinazione
  double? _firstPourAngle;
  double? _secondPourAngle;

  final double _glassHeight = 220.0;
  final double _glassWidth = 90.0;
  final double _firstPourTarget = 0.75;
  final double _secondPourTarget = 1.0;
  final double _foamTarget = 0.18;
  final double _maxLevel = 1.05;

  bool _waiting = false;
  bool _canContinue = false;
  bool _waitedAtRightTime = false;

  @override
  void dispose() {
    _pouringTimer?.cancel();
    _settleTimer?.cancel();
    super.dispose();
  }

  void _onPourStart() {
    if (_phase == GuinnessPhase.firstPour || _phase == GuinnessPhase.secondPour) {
      setState(() {
        _isPouring = true;
        if (_phase == GuinnessPhase.firstPour) _firstPourAngle = _tiltAngle;
        if (_phase == GuinnessPhase.secondPour) _secondPourAngle = _tiltAngle;
      });
      _pouringTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
        setState(() {
          if (_phase == GuinnessPhase.firstPour) {
            _beerLevel += 0.012 + Random().nextDouble() * 0.004;
            _foamLevel += 0.002 + Random().nextDouble() * 0.001;
          } else if (_phase == GuinnessPhase.secondPour) {
            _beerLevel += 0.006 + Random().nextDouble() * 0.002;
            _foamLevel += 0.004 + Random().nextDouble() * 0.001;
          }
          if (_beerLevel + _foamLevel > _maxLevel) {
            _triggerOverflow();
          }
        });
      });
    }
  }

  void _onPourEnd() {
    setState(() {
      _isPouring = false;
    });
    _pouringTimer?.cancel();
    if (_phase == GuinnessPhase.firstPour) {
      _startSettle();
    }
  }

  void _onWaitPressed() {
    if (_phase == GuinnessPhase.settle && !_isSettling) {
      setState(() {
        _isSettling = true;
        _waitedAtRightTime = true;
      });
      _settleTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _settleSecondsLeft--;
          if (_settleSecondsLeft <= 0) {
            _settleTimer?.cancel();
            _isSettling = false;
            _waiting = false;
            _canContinue = false;
            _phase = GuinnessPhase.secondPour;
          }
        });
      });
    }
  }

  void _startFirstPour() {
    if (_phase != GuinnessPhase.start) return;
    setState(() {
      _phase = GuinnessPhase.firstPour;
      _isPouring = false;
      _firstPourAngle = null;
      _secondPourAngle = null;
      _waitedAtRightTime = false;
    });
    HapticFeedback.lightImpact();
  }

  void _startSettle() {
    setState(() {
      _phase = GuinnessPhase.settle;
      _waiting = true;
      _canContinue = false;
      _settleSecondsLeft = 3;
    });
  }

  void _triggerOverflow() async {
    setState(() {
      _hasOverflowed = true;
      _gameFinished = true;
      _isPouring = false;
      _phase = GuinnessPhase.finished;
    });

    _pouringTimer?.cancel();
    _settleTimer?.cancel();
    HapticFeedback.heavyImpact();

    _finalScore = 0; // Assicurati che il punteggio sia zero per overflow

    final api = await ApiService.getInstance();
    await api.postScore(_finalScore);

    Future.delayed(const Duration(milliseconds: 300), _showResultDialog);
  }

  void _finishGame() async {
    setState(() {
      _gameFinished = true;
      _phase = GuinnessPhase.finished;
    });
    _calculateScore();

    final api = await ApiService.getInstance();
    await api.postScore(_finalScore);

    _showResultDialog();
  }

  void _calculateScore() {
    if (_hasOverflowed) {
      _finalScore = 0;
      return;
    }
    double beerScore = 100 * (1 - ((_beerLevel - 1.0).abs() / 1.0));
    double foamScore = 100 * (1 - ((_foamLevel - _foamTarget).abs() / _foamTarget));


    debugPrint('Beer level: $_firstPourAngle, Foam level: $_secondPourAngle');
    // Penalità inclinazione proporzionale
    double tiltPenalty = 0;
    if (_firstPourAngle != null) {
      double diff = 0;
      if (_firstPourAngle! < 40) diff = 40 - _firstPourAngle!;
      if (_firstPourAngle! > 50) diff = _firstPourAngle! - 50;
      tiltPenalty += (diff * 1).clamp(0, 15);
    } else {
      tiltPenalty += 10; // penalità ridotta
    }
    if (_secondPourAngle != null) {
      double diff = _secondPourAngle!.abs() - 5;
      if (diff > 0) tiltPenalty += (diff * 1).clamp(0, 15);
    } else {
      tiltPenalty += 10; // penalità ridotta
    }

    // Penalità se non ha fatto entrambe le fasi
    bool missingFirst = _firstPourAngle == null;
    bool missingSecond = _secondPourAngle == null;
    int phasePenalty = (missingFirst || missingSecond) ? 40 : 0;

    int waitBonus = _waitedAtRightTime ? 10 : 0;

    double bonus = (beerScore > 85 && foamScore > 85)
        ? 25
        : (beerScore > 75 && foamScore > 75)
            ? 15
            : 0;
    double rawScore = (beerScore * 0.7 + foamScore * 0.3 + bonus + waitBonus - tiltPenalty - phasePenalty);
    _finalScore = rawScore.clamp(0, 100).round();
  }

  void _resetGame() {
    setState(() {
      _isPouring = false;
      _isSettling = false;
      _gameFinished = false;
      _beerLevel = 0.0;
      _foamLevel = 0.0;
      _finalScore = 0;
      _hasOverflowed = false;
      _phase = GuinnessPhase.start;
      _settleSecondsLeft = 0;
      _tiltAngle = 45.0;
      _waiting = false;
      _canContinue = false;
      _firstPourAngle = null;
      _secondPourAngle = null;
      _waitedAtRightTime = false;
    });
    _pouringTimer?.cancel();
    _settleTimer?.cancel();
  }

  void _showResultDialog() {
    String title;
    String message;
    IconData icon;
    Color iconColor;

    if (_hasOverflowed) {
      title = 'TRABOCCATA!';
      message = 'Hai versato troppo! Il bicchiere è traboccato!';
      icon = Icons.warning_amber_rounded;
      iconColor = Colors.red;
    } else if (_finalScore >= 90) {
      title = 'SPILLATURA PERFETTA!';
      message = 'Hai seguito il metodo Guinness alla perfezione!';
      icon = Icons.emoji_events;
      iconColor = Colors.yellow.shade700;
    } else if (_finalScore >= 75) {
      title = 'OTTIMO!';
      message = 'Quasi perfetto! Complimenti!';
      icon = Icons.star_rounded;
      iconColor = Colors.green;
    } else if (_finalScore >= 60) {
      title = 'BUONO!';
      message = 'Non male! Continua a praticare!';
      icon = Icons.thumb_up_rounded;
      iconColor = Colors.blue;
    } else {
      title = 'RIPROVA!';
      message = 'Serve più pratica! Segui bene i due tempi!';
      icon = Icons.school_rounded;
      iconColor = Colors.red;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(inherit: true, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: const TextStyle(inherit: true)),
            const SizedBox(height: 10),
            if (!_hasOverflowed)
              Text('Punteggio: $_finalScore/100', style: const TextStyle(inherit: true, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetGame();
            },
            child: const Text('Riprova', style: TextStyle(inherit: true)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Esci', style: TextStyle(inherit: true)),
          ),
        ],
      ),
    );
  }

  Color get _backgroundColor => Colors.brown.shade900;

  @override
  Widget build(BuildContext context) {
    final bool canConfirm =
        (_beerLevel > 0.01) && !_gameFinished && _phase != GuinnessPhase.finished;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spilla la Guinness'),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 2,
      ),
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildInstructions(),
            const SizedBox(height: 100),
            _buildGlassSimple(),
            const SizedBox(height: 10),
            _buildTiltSlider(),
            const SizedBox(height: 10),
            _buildControls(),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: AnimatedOpacity(
                opacity: canConfirm ? 1 : 0.5,
                duration: const Duration(milliseconds: 300),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text(
                    'Conferma la Spillatura',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    minimumSize: const Size.fromHeight(54),
                    elevation: 4,
                    shadowColor: Colors.black45,
                  ),
                  onPressed: canConfirm
                      ? () {
                          _finishGame();
                        }
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    String? subtitle;
    IconData? icon;
    Color? iconColor;
    switch (_phase) {
      case GuinnessPhase.start:
        subtitle = 'Inclina il bicchiere e premi "Spilla" per iniziare!';
        icon = Icons.sports_bar;
        iconColor = Colors.amber.shade200;
        break;
      case GuinnessPhase.firstPour:
        subtitle = 'Spillatura in corso... (${_tiltAngle.round()}°)';
        icon = Icons.water_drop;
        iconColor = Colors.amber;
        break;
      case GuinnessPhase.settle:
        subtitle = 'Attendi che la schiuma si assesti premendo "Aspetta".';
        icon = Icons.hourglass_bottom;
        iconColor = Colors.amber;
        break;
      case GuinnessPhase.secondPour:
        subtitle = 'Scegli l\'inclinazione e premi "Spilla" per completare!';
        icon = Icons.water_drop;
        iconColor = Colors.amber;
        break;
      case GuinnessPhase.finished:
        subtitle = 'Spillatura terminata! 🍺';
        icon = Icons.celebration;
        iconColor = Colors.green;
        break;
    }
    return Card(
      color: Colors.black.withOpacity(0.7),
      margin: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                subtitle ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTiltSlider() {
    if (_phase == GuinnessPhase.finished) return const SizedBox();
    final int tilt = _tiltAngle.isNaN ? 0 : _tiltAngle.round();
    final bool sliderEnabled = !_isPouring && _phase != GuinnessPhase.finished;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          Slider(
            value: _tiltAngle,
            min: 0,
            max: 60,
            divisions: 60,
            label: '$tilt°',
            activeColor: Colors.amber,
            inactiveColor: Colors.amber.shade100,
            onChanged: sliderEnabled
                ? (v) {
                    setState(() {
                      _tiltAngle = v;
                    });
                  }
                : null, // Disabilita lo slider se non abilitato
          ),
          Text(
            'Inclinazione: $tilt°',
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSimple() {
    final double tiltTurns = _tiltAngle.isNaN ? 0 : -_tiltAngle / 360;
    return Center(
      child: AnimatedRotation(
        turns: tiltTurns,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: CustomPaint(
            size: Size(_glassWidth + 10, _glassHeight + 10),
            painter: SimpleGlassPainter(
              beerLevel: _beerLevel,
              foamLevel: _foamLevel,
              glassWidth: _glassWidth,
              glassHeight: _glassHeight,
              overflow: _hasOverflowed,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.local_drink, color: Colors.white),
            label: const Text('Spilla', style: TextStyle(inherit: true)),
            onPressed: (_phase == GuinnessPhase.settle)
                ? null
                : () {
                    if (_phase == GuinnessPhase.start) {
                      _startFirstPour();
                      _onPourStart(); // Avvia subito la spillatura!
                    } else if (_phase == GuinnessPhase.firstPour && !_isPouring) {
                      _onPourStart();
                    } else if (_phase == GuinnessPhase.firstPour && _isPouring) {
                      _onPourEnd();
                    } else if (_phase == GuinnessPhase.secondPour && !_isPouring) {
                      _onPourStart();
                    } else if (_phase == GuinnessPhase.secondPour && _isPouring) {
                      _onPourEnd();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isPouring ? Colors.green : Colors.blue.shade900,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              textStyle: const TextStyle(inherit: true, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.hourglass_bottom, color: Colors.amber),
            label: const Text('Aspetta', style: TextStyle(inherit: true)),
            onPressed: (_phase == GuinnessPhase.settle && !_isSettling) ? _onWaitPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              textStyle: const TextStyle(inherit: true, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
          ),
          if (_phase == GuinnessPhase.settle && _isSettling)
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 3),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Attendi... ($_settleSecondsLeft s)',
                    style: const TextStyle(inherit: true, color: Colors.amber, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          if (_gameFinished)
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: ElevatedButton.icon(
                onPressed: _resetGame,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Riprova', style: TextStyle(inherit: true)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SimpleGlassPainter extends CustomPainter {
  final double beerLevel;
  final double foamLevel;
  final double glassWidth;
  final double glassHeight;
  final bool overflow;

  SimpleGlassPainter({
    required this.beerLevel,
    required this.foamLevel,
    required this.glassWidth,
    required this.glassHeight,
    this.overflow = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = glassWidth;
    final double h = glassHeight;
    final double x = (size.width - w) / 2;
    final double y = (size.height - h);

    // Bicchiere: rettangolo con angoli inferiori smussati
    RRect glassRRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(x, y, w, h),
      bottomLeft: const Radius.circular(22),
      bottomRight: const Radius.circular(22),
      topLeft: Radius.zero,
      topRight: Radius.zero,
    );

    // Corpo bicchiere (rettangolo trasparente)
    canvas.drawRRect(
      glassRRect,
      Paint()
        ..color = Colors.white.withOpacity(0.10)
        ..style = PaintingStyle.fill,
    );

    // Bordo bicchiere
    canvas.drawRRect(
      glassRRect,
      Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Birra (rettangolo)
    double beerH = beerLevel * h;
    double beerTop = y + h - beerH;
    double beerBottom = beerTop + beerH;
    double glassBottom = y + h;
    bool toccaFondo = (beerBottom >= glassBottom);

    // Se la birra non tocca il fondo, allarghiamo leggermente la base
    double beerX = x + (toccaFondo ? 2 : 0);
    double beerW = w - (toccaFondo ? 4 : 0);

    RRect beerRRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(beerX, beerTop, beerW, beerH),
      bottomLeft: toccaFondo ? const Radius.circular(22) : Radius.zero,
      bottomRight: toccaFondo ? const Radius.circular(22) : Radius.zero,
      topLeft: Radius.zero,
      topRight: Radius.zero,
    );
    canvas.drawRRect(
      beerRRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF7A3B17),
            const Color(0xFF5B2E13),
            const Color(0xFF3E2212),
            const Color(0xFF2D1B0E),
          ],
        ).createShader(Rect.fromLTWH(beerX, beerTop, beerW, beerH)),
    );

    // Schiuma (rettangolo + ovale sopra)
    double foamH = foamLevel * (h - 8);
    if (foamH > 2) {
      Rect foamRect = Rect.fromLTWH(x + 2, y + h - beerH - foamH, w - 4, foamH);
      canvas.drawRect(
        foamRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.amber.shade50.withOpacity(0.85),
            ],
          ).createShader(foamRect),
      );
      // Ovale sopra la schiuma
      Rect foamOval = Rect.fromLTWH(x + 2, y + h - beerH - foamH - 8, w - 4, 16);
      canvas.drawOval(
        foamOval,
        Paint()..color = Colors.white.withOpacity(0.85),
      );
    }

    // Overflow rosso
    if (overflow) {
      canvas.drawRRect(
        glassRRect,
        Paint()
          ..color = Colors.red.withOpacity(0.18)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(x + w / 2, y + h / 2),
        w * 0.28,
        Paint()..color = Colors.red.withOpacity(0.18),
      );
    }
  }

  @override
  bool shouldRepaint(covariant SimpleGlassPainter oldDelegate) =>
      beerLevel != oldDelegate.beerLevel ||
      foamLevel != oldDelegate.foamLevel ||
      overflow != oldDelegate.overflow;
}