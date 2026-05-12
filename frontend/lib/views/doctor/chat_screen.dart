import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';

class DoctorChatScreen extends StatefulWidget {
  final String conversationId;
  final String patientName;

  const DoctorChatScreen({
    super.key,
    required this.conversationId,
    required this.patientName,
  });

  @override
  State<DoctorChatScreen> createState() => _DoctorChatScreenState();
}

class _DoctorChatScreenState extends State<DoctorChatScreen> {
  final _chat = ChatService();
  final _supabase = Supabase.instance.client;
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  StreamSubscription? _sub;
  List<Map<String, dynamic>> _messages = [];
  bool _aiActive = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadConvState();
    _sub = _chat.messagesStream(widget.conversationId).listen((msgs) {
      if (mounted) {
        setState(() => _messages = msgs);
        _scrollToBottom();
      }
    });
  }

  Future<void> _loadConvState() async {
    final conv = await _chat.getConversation(widget.conversationId);
    if (mounted && conv != null) {
      setState(() => _aiActive = conv['ai_active'] as bool? ?? true);
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

  Future<void> _takeOver() async {
    await _chat.setAiActive(widget.conversationId, false);
    setState(() => _aiActive = false);
  }

  Future<void> _handBackToAI() async {
    await _chat.setAiActive(widget.conversationId, true);
    setState(() => _aiActive = true);
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _isSending) return;
    _textCtrl.clear();
    setState(() => _isSending = true);
    try {
      await _chat.insertMessage(widget.conversationId, text, 'doctor');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.patientName, style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
            Text(
              _aiActive ? 'AI is handling intake' : 'You are responding',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _aiActive ? Colors.orange[700] : Colors.green[700],
              ),
            ),
          ],
        ),
        actions: [
          if (_aiActive)
            TextButton.icon(
              onPressed: _takeOver,
              icon: const Icon(Icons.person, size: 16),
              label: const Text('Take Over'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF1B3C40)),
            )
          else
            TextButton.icon(
              onPressed: _handBackToAI,
              icon: const Icon(Icons.smart_toy, size: 16),
              label: const Text('Hand to AI'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange[700]),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_aiActive)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.green[50],
              child: Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Text('You are now responding as the doctor.',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.green[800])),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) => _buildBubble(_messages[i]),
            ),
          ),
          if (!_aiActive) _buildInput(),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    final role = msg['sender_role'] as String;
    final isDoctor = role == 'doctor';
    final isAI = role == 'ai';
    final label = isDoctor ? 'You' : (isAI ? 'AI Assistant' : widget.patientName);

    return Align(
      alignment: isDoctor ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDoctor ? const Color(0xFF1B3C40) : (isAI ? Colors.blue[50] : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: isAI ? Border.all(color: Colors.blue[100]!) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDoctor ? Colors.white70 : Colors.grey[500],
                )),
            const SizedBox(height: 4),
            Text(msg['content'] as String,
                style: GoogleFonts.inter(
                  color: isDoctor ? Colors.white : Colors.black87,
                  fontSize: 14,
                  height: 1.4,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return SafeArea(
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
                  hintText: 'Reply to patient...',
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
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}
