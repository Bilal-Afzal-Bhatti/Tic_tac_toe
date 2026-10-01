import 'package:flutter/material.dart';
import 'home.dart';

class UserNamePage extends StatefulWidget {
  const UserNamePage({super.key});

  @override
  State<UserNamePage> createState() => _UserNamePageState();
}

class _UserNamePageState extends State<UserNamePage> {
  final TextEditingController _nameController = TextEditingController();

  bool _nameDone = false; // false = name step, true = mode step
  String _userName = '';
  String _sign = 'X';
  bool _tournamentSelected = false;
  int _rounds = 3;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _continue() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _userName = name;
      _nameDone = true;
    });
  }

  void _openHome(String mode) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePage(
          userName: _userName,
          mode: mode,
          rounds: mode == 'Tournament' ? _rounds : 1,
          playerSign: _sign,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _nameDone ? _modeStep() : _nameStep(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- STEP 1: NAME ----------
  Widget _nameStep() {
    return Column(
      key: const ValueKey('name'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('X',
                style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF22D3EE))),
            SizedBox(width: 16),
            Text('O',
                style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF472B6))),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Welcome',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 8),
        const Text('Enter your name to start',
            style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 32),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          maxLength: 15,
          onSubmitted: (_) => _continue(),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Your name',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.person, color: Colors.white54),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _bigButton('Continue', const Color(0xFF22D3EE), _continue),
      ],
    );
  }

  // ---------- STEP 2: SIGN + MODE ----------
  Widget _modeStep() {
    return Column(
      key: const ValueKey('mode'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Hi, $_userName 👋',
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 8),
        const Text('Choose game mode',
            style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 24),

        _signPicker(),
        const SizedBox(height: 28),

        _bigButton('Simple Match', const Color(0xFF22D3EE),
            () => _openHome('Simple Match')),
        const SizedBox(height: 16),

        _bigButton(
          'Tournament',
          const Color(0xFFF472B6),
          () => setState(() => _tournamentSelected = true),
          selected: _tournamentSelected,
        ),

        if (_tournamentSelected) ...[
          const SizedBox(height: 24),
          const Text('Select rounds',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [3, 5, 7].map((r) {
              final active = _rounds == r;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ChoiceChip(
                  label: Text('Best of $r'),
                  selected: active,
                  selectedColor: const Color(0xFFF472B6),
                  backgroundColor: const Color(0xFF1E293B),
                  labelStyle: TextStyle(
                    color: active ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(() => _rounds = r),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _bigButton('Start', const Color(0xFF4ADE80),
              () => _openHome('Tournament')),
        ],
      ],
    );
  }

  Widget _signPicker() {
    return Column(
      children: [
        const Text('Choose your sign',
            style: TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['X', 'O'].map((s) {
            final active = _sign == s;
            final color =
                s == 'X' ? const Color(0xFF22D3EE) : const Color(0xFFF472B6);
            return GestureDetector(
              onTap: () => setState(() => _sign = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: active
                      ? color.withValues(alpha: 0.2)
                      : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? color : Colors.white10,
                    width: active ? 3 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    s,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: active ? color : Colors.white38,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        const Text('X plays first',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }

  Widget _bigButton(String text, Color color, VoidCallback onTap,
      {bool selected = false}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          elevation: selected ? 8 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: selected ? Colors.white : Colors.transparent,
                width: 2),
          ),
        ),
        child: Text(text,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}