import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/chat_service.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/red_flag_card.dart';
import 'booking_flow_screen.dart';

class ChatBottomSheet extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const ChatBottomSheet({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  static Future<void> show(BuildContext context, String doctorId, String doctorName) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatBottomSheet(doctorId: doctorId, doctorName: doctorName),
    );
  }

  @override
  State<ChatBottomSheet> createState() => _ChatBottomSheetState();
}

class _ChatBottomSheetState extends State<ChatBottomSheet> {
  final _chat = ChatService();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String? _conversationId;
  StreamSubscription? _sub;
  List<Map<String, dynamic>> _messages = [];

  bool _isLoading = true;
  bool _isSending = false;
  bool _isRedFlag = false;
  bool _intakeComplete = false;

  @override
  void initState() {
    super.initState();
    _initConversation();
  }

  Future<void> _initConversation() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final convId = await _chat.getOrCreateConversation(user.id, widget.doctorId);
    setState(() => _conversationId = convId);

    // Check existing conversation state
    final conv = await _chat.getConversation(convId);
    if (conv != null) {
      setState(() {
        _intakeComplete = conv['intake_complete'] as bool? ?? false;
      });
    }

    _sub = _chat.messagesStream(convId).listen((msgs) {
      if (mounted) {
        setState(() {
          _messages = msgs;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    });

    // Send opening greeting if conversation is new
    if (_messages.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && _messages.isEmpty) {
        await _chat.insertMessage(
          convId,
          'Hi! I\'m the Smart Booking Assistant for Dr. ${widget.doctorName}. What brings you in today?',
          'ai',
        );
      }
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

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _isSending || _conversationId == null) return;

    _textCtrl.clear();
    setState(() => _isSending = true);

    try {
      final result = await _chat.sendAndRespond(
        conversationId: _conversationId!,
        message: text,
        doctorId: widget.doctorId,
      );

      if (mounted) {
        setState(() {
          _isRedFlag = result['is_red_flag'] as bool? ?? false;
          _intakeComplete = result['intake_complete'] as bool? ?? false;
        });

        // Trigger SOAP note generation when intake completes
        if (_intakeComplete) {
          final conv = await _chat.getConversation(_conversationId!);
          final triageData = conv?['triage_data'] as Map<String, dynamic>?;
          if (triageData != null) {
            _chat.generateSoap(
              conversationId: _conversationId!,
              doctorId: widget.doctorId,
              triageData: triageData,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(),
              Expanded(child: _buildBody()),
              if (!_isRedFlag && !_intakeComplete) _buildInput(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1B3C40).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy, color: Color(0xFF1B3C40), size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI Booking Assistant', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('for Dr. ${widget.doctorName}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        ..._messages.map((msg) => _buildBubble(msg)),
        if (_isSending) _buildTypingIndicator(),
        if (_isRedFlag) ...[const SizedBox(height: 8), const RedFlagCard()],
        if (_intakeComplete) ...[const SizedBox(height: 8), _buildBookingCta()],
      ],
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    final role = msg['sender_role'] as String;
    final isPatient = role == 'patient';
    return Align(
      alignment: isPatient ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isPatient ? const Color(0xFF1B3C40) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isPatient ? 16 : 4),
            bottomRight: Radius.circular(isPatient ? 4 : 16),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isPatient)
              Text(
                role == 'ai' ? 'AI Assistant' : 'Dr. ${widget.doctorName}',
                style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w600),
              ),
            Text(
              msg['content'] as String,
              style: GoogleFonts.inter(
                color: isPatient ? Colors.white : Colors.black87,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('AI is typing', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(width: 8),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCta() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 36),
          const SizedBox(height: 8),
          Text(
            'Info received! Ready to book.',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green[800]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingFlowScreen(
                      doctorId: widget.doctorId,
                      doctorName: widget.doctorName,
                      conversationId: _conversationId,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B3C40),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Book Appointment'),
            ),
          ),
        ],
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
                  hintText: 'Describe your symptoms...',
                  hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
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
                decoration: const BoxDecoration(
                  color: Color(0xFF1B3C40),
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
