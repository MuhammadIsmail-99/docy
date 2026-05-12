import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class AppChatbotFab extends StatelessWidget {
  const AppChatbotFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showChatbot(context),
      backgroundColor: const Color(0xFF1B3C40),
      child: const Icon(Icons.smart_toy, color: Colors.white),
    );
  }

  void _showChatbot(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AppChatbotSheet(),
    );
  }
}

class _AppChatbotSheet extends StatefulWidget {
  const _AppChatbotSheet();

  @override
  State<_AppChatbotSheet> createState() => _AppChatbotSheetState();
}

class _AppChatbotSheetState extends State<_AppChatbotSheet> {
  final _api = ApiService();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<Map<String, String>> _messages = [];
  final List<Map<String, String>> _history = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'assistant',
      'content': 'Hi! I\'m Smart Doctor Connect AI. I can help you find the right doctor or answer general health questions. What can I help you with?',
    });
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    _textCtrl.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final result = await _api.appChatbot(message: text, history: _history);
      final response = result['response'] as String? ?? '';

      _history.add({'role': 'user', 'content': text});
      _history.add({'role': 'assistant', 'content': response});

      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': response});
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1B3C40),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Smart Doctor AI', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('General health assistant', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                itemCount: _messages.length + (_isSending ? 1 : 0),
                itemBuilder: (context, i) {
                  if (_isSending && i == _messages.length) {
                    return _buildTyping();
                  }
                  final msg = _messages[i];
                  final isUser = msg['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isUser ? const Color(0xFF1B3C40) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        msg['content'] ?? '',
                        style: GoogleFonts.inter(
                          color: isUser ? Colors.white : Colors.black87,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textCtrl,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Ask me anything...',
                          hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FB),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _send,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(color: Color(0xFF1B3C40), shape: BoxShape.circle),
                        child: const Icon(Icons.send, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTyping() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 40,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[400]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}
