import 'dart:math';
import 'package:flutter/material.dart';
import 'user_name.dart';

// ---------- HISTORY (kept in memory while the app is open) ----------
class GameRecord {
  final String type; // 'Simple Match' or 'Tournament'
  final String result; // 'win', 'lose', 'draw'
  final String level;
  final String score;
  final DateTime time;

  GameRecord({
    required this.type,
    required this.result,
    required this.level,
    required this.score,
    required this.time,
  });
}

final List<GameRecord> gameHistory = [];

// ---------- HOME PAGE ----------
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.userName,
    required this.mode,
    required this.rounds,
    this.playerSign = 'X',
  });

  final String userName;
  final String mode; // 'Simple Match' or 'Tournament'
  final int rounds; // 1 for simple, 3/5/7 for tournament
  final String playerSign; // 'X' or 'O'

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _bg = Color(0xFF0F172A);
  static const _card = Color(0xFF1E293B);
  static const _cyan = Color(0xFF22D3EE);
  static const _pink = Color(0xFFF472B6);
  static const _green = Color(0xFF4ADE80);

  final Random _rand = Random();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _boardKey = GlobalKey();

  String _level = 'Normal'; // Normal, Medium, Hard

  // ----- board size per level -----
  // Normal: 3x3 (3 in a row), Medium: 9x9 (4 in a row), Hard: 12x12 (5 in a row)
  int get _n => _level == 'Normal' ? 3 : (_level == 'Medium' ? 9 : 12);
  int get _k => _level == 'Normal' ? 3 : (_level == 'Medium' ? 4 : 5);

  String get _me => widget.playerSign;
  String get _robot => _me == 'X' ? 'O' : 'X';
  Color _colorOf(String m) => m == 'X' ? _cyan : _pink;

  late List<String> _board = List.filled(_n * _n, '');
  List<int> _winLine = [];
  late bool _playerTurn = _me == 'X'; // X moves first
  bool _gameOver = false;
  int _gameId = 0; // ignores old delayed callbacks after a reset

  // tournament state
  int _playerWins = 0;
  int _robotWins = 0;
  int _played = 0;

  bool get _isTournament => widget.mode == 'Tournament';
  int get _target => widget.rounds ~/ 2 + 1;
  bool get _levelLocked =>
      _isTournament && (_played > 0 || _board.any((c) => c.isNotEmpty));

  @override
  void initState() {
    super.initState();
    _robotStartsIfFirst();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ---------- AUTO SCROLL ----------
  void _showFullBoard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _boardKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // ---------- GAME LOGIC ----------
  List<int> _emptyCells(List<String> b) =>
      [for (int i = 0; i < b.length; i++) if (b[i].isEmpty) i];

  /// Returns the winning cells (k in a row) or an empty list
  List<int> _findWin(List<String> b) {
    final n = _n, k = _k;
    const dirs = [
      [0, 1], [1, 0], [1, 1], [1, -1],
    ];
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final m = b[r * n + c];
        if (m.isEmpty) continue;
        for (final d in dirs) {
          final line = <int>[r * n + c];
          int rr = r + d[0], cc = c + d[1];
          while (line.length < k &&
              rr >= 0 && rr < n && cc >= 0 && cc < n &&
              b[rr * n + cc] == m) {
            line.add(rr * n + cc);
            rr += d[0];
            cc += d[1];
          }
          if (line.length == k) return line;
        }
      }
    }
    return [];
  }

  void _playerMove(int i) {
    if (!_playerTurn || _gameOver || _board[i].isNotEmpty) return;
    setState(() {
      _board[i] = _me;
      _playerTurn = false;
    });
    _showFullBoard();
    if (_checkEnd()) return;

    final id = _gameId;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || id != _gameId || _gameOver) return;
      _robotMove();
    });
  }

  void _robotStartsIfFirst() {
    if (_me != 'O') return; // player is X, so the player starts
    final id = _gameId;
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted || id != _gameId || _gameOver) return;
      _robotMove();
    });
  }

  void _robotMove() {
    final idx = _pickRobotMove();
    setState(() {
      _board[idx] = _robot;
      _playerTurn = true;
    });
    _showFullBoard();
    _checkEnd();
  }

  int _pickRobotMove() {
    final empty = _emptyCells(_board);

    // Normal (3x3): random moves
    if (_level == 'Normal') {
      return empty[_rand.nextInt(empty.length)];
    }

    // first move on a big board: take the center
    if (empty.length == _board.length) {
      return (_n ~/ 2) * _n + (_n ~/ 2);
    }

    // Medium (9x9): smart 60% of the time, otherwise random near marks
    if (_level == 'Medium') {
      if (_rand.nextDouble() < 0.6) return _bestCell(empty, 0.8);
      return _randomNear(empty);
    }

    // Hard (12x12): always attacks and blocks
    return _bestCell(empty, 1.0);
  }

  int _randomNear(List<int> empty) {
    final near = <int>[];
    for (final i in empty) {
      final r = i ~/ _n, c = i % _n;
      bool close = false;
      for (int dr = -1; dr <= 1 && !close; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          final rr = r + dr, cc = c + dc;
          if (rr < 0 || rr >= _n || cc < 0 || cc >= _n) continue;
          if (_board[rr * _n + cc].isNotEmpty) {
            close = true;
            break;
          }
        }
      }
      if (close) near.add(i);
    }
    final pool = near.isEmpty ? empty : near;
    return pool[_rand.nextInt(pool.length)];
  }

  int _bestCell(List<int> empty, double defenseWeight) {
    double best = -1e18;
    int bestIdx = empty.first;
    final mid = (_n - 1) / 2;
    for (final i in empty) {
      final r = i ~/ _n, c = i % _n;
      double s = _cellScore(r, c, _robot) +
          defenseWeight * _cellScore(r, c, _me);
      s -= (sqrt((r - mid) * (r - mid) + (c - mid) * (c - mid))) * 0.5;
      s += _rand.nextDouble(); // small randomness for ties
      if (s > best) {
        best = s;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  /// How good would it be for [mark] to play at (r, c)?
  double _cellScore(int r, int c, String mark) {
    const dirs = [
      [0, 1], [1, 0], [1, 1], [1, -1],
    ];
    double total = 0;
    for (final d in dirs) {
      int count = 1;
      int open = 0;
      for (final sign in [1, -1]) {
        int rr = r + d[0] * sign, cc = c + d[1] * sign;
        while (rr >= 0 && rr < _n && cc >= 0 && cc < _n &&
            _board[rr * _n + cc] == mark) {
          count++;
          rr += d[0] * sign;
          cc += d[1] * sign;
        }
        if (rr >= 0 && rr < _n && cc >= 0 && cc < _n &&
            _board[rr * _n + cc].isEmpty) {
          open++;
        }
      }
      total += _pattern(count, open);
    }
    return total;
  }

  double _pattern(int count, int open) {
    if (count >= _k) return 1000000;
    if (open == 0) return 0;
    if (count == _k - 1) return open == 2 ? 50000 : 5000;
    if (count == _k - 2) return open == 2 ? 2000 : 200;
    return count * open * 10.0;
  }

  /// Returns true if the game ended
  bool _checkEnd() {
    final line = _findWin(_board);
    String? result;

    if (line.isNotEmpty) {
      final w = _board[line[0]];
      result = w == _me ? 'win' : 'lose';
      _winLine = line;
    } else if (_emptyCells(_board).isEmpty) {
      result = 'draw';
    }

    if (result == null) return false;

    setState(() => _gameOver = true);
    final r = result;
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _finishGame(r);
    });
    return true;
  }

  void _resetBoard() {
    setState(() {
      _board = List.filled(_n * _n, '');
      _winLine = [];
      _playerTurn = _me == 'X';
      _gameOver = false;
      _gameId++;
    });
    _showFullBoard();
    _robotStartsIfFirst();
  }

  void _newTournament() {
    setState(() {
      _playerWins = 0;
      _robotWins = 0;
      _played = 0;
    });
    _resetBoard();
  }

  void _changeLevel(String level) {
    if (_levelLocked) return;
    setState(() => _level = level);
    _resetBoard();
  }

  // ---------- RESULT HANDLING ----------
  String get _levelLabel => '$_level (${_n}x$_n)';

  void _finishGame(String result) {
    if (!_isTournament) {
      gameHistory.add(GameRecord(
        type: 'Simple Match',
        result: result,
        level: _levelLabel,
        score: result == 'win'
            ? '1 - 0'
            : result == 'lose'
                ? '0 - 1'
                : '0 - 0',
        time: DateTime.now(),
      ));
      _showResultDialog(result: result);
      return;
    }

    // tournament
    if (result == 'win') _playerWins++;
    if (result == 'lose') _robotWins++;
    _played++;

    final finished = _playerWins >= _target ||
        _robotWins >= _target ||
        _played >= widget.rounds;

    if (!finished) {
      _showResultDialog(result: result, tournamentOver: false);
      return;
    }

    final finalResult = _playerWins > _robotWins
        ? 'win'
        : _robotWins > _playerWins
            ? 'lose'
            : 'draw';

    gameHistory.add(GameRecord(
      type: 'Tournament',
      result: finalResult,
      level: _levelLabel,
      score: '$_playerWins - $_robotWins (Best of ${widget.rounds})',
      time: DateTime.now(),
    ));
    _showResultDialog(result: finalResult, tournamentOver: true);
  }

  void _showResultDialog({required String result, bool? tournamentOver}) {
    final isFinal = tournamentOver ?? true;
    final emoji = result == 'win'
        ? '🏆'
        : result == 'lose'
            ? '🤖'
            : '🤝';
    String title;
    if (isFinal && _isTournament) {
      title = result == 'win'
          ? 'Tournament Won!'
          : result == 'lose'
              ? 'Tournament Lost'
              : 'Tournament Draw';
    } else {
      title = result == 'win'
          ? 'You Win!'
          : result == 'lose'
              ? 'You Lose'
              : "It's a Draw";
    }
    final color = result == 'win'
        ? _green
        : result == 'lose'
            ? Colors.redAccent
            : Colors.amber;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text(title,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: color)),
              const SizedBox(height: 8),
              if (_isTournament)
                Text(
                  '${widget.userName} $_playerWins  -  $_robotWins ROBOT',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                )
              else
                Text(
                  result == 'win'
                      ? 'Great job, ${widget.userName}!'
                      : result == 'lose'
                          ? 'ROBOT won this time'
                          : 'Nobody wins this round',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              const SizedBox(height: 24),
              _dialogButton(
                !_isTournament
                    ? 'Play Again'
                    : isFinal
                        ? 'New Tournament'
                        : 'Next Round',
                color,
                () {
                  Navigator.pop(ctx);
                  if (_isTournament && isFinal) {
                    _newTournament();
                  } else {
                    _resetBoard();
                  }
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _goMenu();
                },
                child: const Text('Menu',
                    style: TextStyle(color: Colors.white60, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogButton(String text, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(text,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _goMenu() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const UserNamePage()),
    );
  }

  // ---------- HISTORY ----------
  void _showHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text('History',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: _cyan,
                tabs: [Tab(text: 'Simple'), Tab(text: 'Tournament')],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _historyList('Simple Match'),
                    _historyList('Tournament'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyList(String type) {
    final items =
        gameHistory.where((g) => g.type == type).toList().reversed.toList();

    if (items.isEmpty) {
      return const Center(
        child: Text('No matches yet',
            style: TextStyle(color: Colors.white54, fontSize: 16)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final g = items[i];
        final color = g.result == 'win'
            ? _green
            : g.result == 'lose'
                ? Colors.redAccent
                : Colors.amber;
        final label = g.result == 'win'
            ? 'Win'
            : g.result == 'lose'
                ? 'Lose'
                : 'Draw';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$label vs ROBOT',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('${g.level}  •  ${g.score}',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              Text(_formatTime(g.time),
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}\n${two(d.hour)}:${two(d.minute)}';
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _goMenu,
        ),
        title: Column(
          children: [
            Text(widget.userName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: (_isTournament ? _pink : _cyan).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _isTournament
                    ? 'Tournament • Best of ${widget.rounds}'
                    : 'Simple Match',
                style: TextStyle(
                    color: _isTournament ? _pink : _cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: _showHistory,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _scoreBoard(),
                        const SizedBox(height: 16),
                        _levelSelector(),
                        const SizedBox(height: 8),
                        Text(
                          '${_n}x$_n board  •  get $_k in a row to win',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        _statusText(),
                        const SizedBox(height: 16),
                        _boardGrid(),
                        const SizedBox(height: 20),
                        TextButton.icon(
                          onPressed: _resetBoard,
                          icon: const Icon(Icons.refresh,
                              color: Colors.white70),
                          label: const Text('Restart game',
                              style: TextStyle(color: Colors.white70)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _scoreBoard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _playerBadge(widget.userName, _me, _colorOf(_me), _playerWins),
              const Text('VS',
                  style: TextStyle(
                      color: Colors.white38, fontWeight: FontWeight.bold)),
              _playerBadge('ROBOT', _robot, _colorOf(_robot), _robotWins),
            ],
          ),
          if (_isTournament) ...[
            const SizedBox(height: 10),
            Text(
              'Round ${min(_played + 1, widget.rounds)} of ${widget.rounds}',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _playerBadge(String name, String mark, Color color, int wins) {
    return Expanded(
      child: Column(
        children: [
          Text(mark,
              style: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold, color: color)),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
          if (_isTournament)
            Text('$wins',
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _levelSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ['Normal', 'Medium', 'Hard'].map((l) {
        final active = _level == l;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: ChoiceChip(
            label: Text(l),
            selected: active,
            selectedColor: _cyan,
            backgroundColor: _card,
            disabledColor: _card,
            labelStyle: TextStyle(
              color: active ? Colors.black : Colors.white,
              fontWeight: FontWeight.w600,
            ),
            onSelected: _levelLocked ? null : (_) => _changeLevel(l),
          ),
        );
      }).toList(),
    );
  }

  Widget _statusText() {
    String text;
    Color color = Colors.white70;
    if (_gameOver) {
      text = 'Game over';
    } else if (_playerTurn) {
      text = 'Your turn ($_me)';
      color = _colorOf(_me);
    } else {
      text = 'ROBOT is thinking...';
      color = _colorOf(_robot);
    }
    return Text(text,
        style: TextStyle(
            color: color, fontSize: 18, fontWeight: FontWeight.w600));
  }

  Widget _boardGrid() {
    final n = _n;
    final gap = n == 3 ? 12.0 : (n == 9 ? 4.0 : 3.0);
    final radius = n == 3 ? 18.0 : (n == 9 ? 8.0 : 6.0);

    return LayoutBuilder(
      key: _boardKey,
      builder: (context, c) {
        final cell = (c.maxWidth - gap * (n - 1)) / n;
        return AspectRatio(
          aspectRatio: 1,
          child: GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: n * n,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: n,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
            ),
            itemBuilder: (_, i) {
              final mark = _board[i];
              final isWin = _winLine.contains(i);
              final markColor = _colorOf(mark);

              return GestureDetector(
                onTap: () => _playerMove(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    color:
                        isWin ? markColor.withValues(alpha: 0.25) : _card,
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: isWin ? markColor : Colors.white10,
                      width: isWin ? 2 : 1,
                    ),
                    boxShadow: isWin
                        ? [
                            BoxShadow(
                                color: markColor.withValues(alpha: 0.5),
                                blurRadius: 10)
                          ]
                        : [],
                  ),
                  child: Center(
                    child: AnimatedScale(
                      scale: mark.isEmpty ? 0 : 1,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      child: Text(
                        mark,
                        style: TextStyle(
                          fontSize: cell * 0.62,
                          fontWeight: FontWeight.bold,
                          color: markColor,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}