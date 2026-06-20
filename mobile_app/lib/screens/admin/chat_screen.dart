// ============================================================
//  chat_screen.dart  –  Flutter Chat UI for Anti-Theft Bot
//  Place this file in:  lib/screens/chat_screen.dart
//  Dependencies (pubspec.yaml):
//    http: ^1.2.0
//    intl: ^0.19.0
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
//import 'package:permission_handler/permission_handler.dart';
// import 'package:device_info_plus/device_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
// ── DATA MODEL ───────────────────────────────────────────────
enum MessageSender { user, bot }

class ChatMessage {
  final String text;
  final MessageSender sender;
  final DateTime time;
  final bool isLoading;
  final String? type; // 'text' or 'report_request'
  final String? reportType; // 'alerts' or 'tags'
  final List<String>? formats; // ['csv', 'pdf']

  const ChatMessage({
    required this.text,
    required this.sender,
    required this.time,
    this.isLoading = false,
    this.type,
    this.reportType,
    this.formats,
  });
}

// ── MAIN SCREEN ──────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  // ↓↓ Change this to your server URL ↓↓
  static const String _apiUrl = 'http://10.102.0.68/Reader/chatbot.php';

  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  
  // Report generation state
  DateTime? _reportDateFrom;
  DateTime? _reportDateTo;

  // App design colors
  static const Color _navyBlue = Color(0xFF0A3C6F);
  static const Color _teal = Color(0xFF168D8C);
  static const Color _lightBg = Color(0xFFF6F6F6);

  // Suggested quick questions
  final List<String> _suggestions = [
    "🏷️ Combien de tags?",
    "📊 Tags par type?",
    "🚨 Alertes aujourd'hui?",
    "📈 Alertes cette semaine?",
    "📥 Rapport des Alertes",
    "📋 Rapport des Tags",
    "⚠️ Dernier vol?",
    "🔍 Alertes non lues?",
  ];

  @override
  void initState() {
    super.initState();
    // Welcome message
    _messages.add(ChatMessage(
      text: "Bonjour! 👋 Je suis votre Assistant IA.\nPosez-moi des questions sur vos statistiques, alertes ou tags.",
      sender: MessageSender.bot,
      time: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── SEND MESSAGE ─────────────────────────────────────────
  Future<void> _sendMessage(String text) async {
    final question = text.trim();
    if (question.isEmpty || _isSending) return;

    _controller.clear();
    setState(() {
      _isSending = true;
      _messages.add(ChatMessage(
        text: question,
        sender: MessageSender.user,
        time: DateTime.now(),
      ));
      // Loading bubble
      _messages.add(ChatMessage(
        text: '',
        sender: MessageSender.bot,
        time: DateTime.now(),
        isLoading: true,
      ));
    });
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'question': question}),
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body);
      final answer = data['answer'] ?? 'No response received.';
      final type = data['type'] ?? 'text';
      
      debugPrint('💬 Chatbot response received:');
      debugPrint('   - Type: $type');
      debugPrint('   - Answer: $answer');
      debugPrint('   - Report Type: ${data['report_type']}');
      debugPrint('   - Formats: ${data['formats']}');
      debugPrint('   - Full JSON: ${jsonEncode(data)}');

      setState(() {
        _messages.removeLast(); // remove loading bubble
        final newMsg = ChatMessage(
          text: answer,
          sender: MessageSender.bot,
          time: DateTime.now(),
          type: type,
          reportType: data['report_type'] as String?,
          formats: data['formats'] != null ? List<String>.from(data['formats'] as List) : null,
        );
        debugPrint('📌 Creating message: type=${newMsg.type}, reportType=${newMsg.reportType}');
        _messages.add(newMsg);
        
        // Initialize report dates if report request
        if (type == 'report_request') {
          _reportDateTo = DateTime.now();
          _reportDateFrom = DateTime.now().subtract(const Duration(days: 7));
          debugPrint('✅ Report dates initialized: from=$_reportDateFrom to=$_reportDateTo');
        }
      });
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(
          text: "⚠️ Connection error. Make sure the server is running.\n\nError: $e",
          sender: MessageSender.bot,
          time: DateTime.now(),
        ));
      });
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildSuggestions(),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── APP BAR ───────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _navyBlue,
      elevation: 4,
      shadowColor: _navyBlue.withValues(alpha: 0.3),
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5DCAD).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.chat_bubble_outlined, color: Color(0xFFF5DCAD), size: 22),
        ),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💬 Assistant IA',
            style: TextStyle(
              color: Color(0xFFF5DCAD),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          Text(
            'Posez vos questions sur le système',
            style: TextStyle(color: Color(0xFFF5DCAD), fontSize: 10),
          )
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Color(0xFFF5DCAD)),
          tooltip: 'Effacer le chat',
          onPressed: () {
            setState(() {
              _messages.clear();
              _messages.add(ChatMessage(
                text: "Chat effacé. Comment puis-je vous aider?",
                sender: MessageSender.bot,
                time: DateTime.now(),
              ));
            });
          },
        ),
      ],
    );
  }

  // ── MESSAGE LIST ─────────────────────────────────────────
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.sender == MessageSender.user;
    
    // Handle report request bubble
    debugPrint('🔍 _buildMessageBubble: type="${msg.type}", sender=${msg.sender}');
    if (msg.type == 'report_request') {
      debugPrint('✅ Rendering REPORT BUBBLE');
      return _buildReportBubble(msg);
    }
    
    debugPrint('📝 Rendering TEXT BUBBLE');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _buildAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? _navyBlue : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    border: Border.all(
                      color: isUser ? _navyBlue : _teal.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: msg.isLoading
                      ? const _TypingIndicator()
                      : Text(
                          msg.text,
                          style: TextStyle(
                            color: isUser ? Colors.white : _navyBlue,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm').format(msg.time),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: _teal.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _teal.withValues(alpha: 0.3)),
      ),
      child: const Icon(Icons.smart_toy_outlined, color: Color(0xFF168D8C), size: 18),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: _navyBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 18),
    );
  }

  // ── REPORT BUBBLE ────────────────────────────────────────
  Widget _buildReportBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                    border: Border.all(
                      color: _teal.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      color: _navyBlue,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Date pickers
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _lightBg,
                    border: Border(
                      left: BorderSide(
                        color: _teal.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      right: BorderSide(
                        color: _teal.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDatePickerField('De:', _reportDateFrom, (date) {
                        setState(() => _reportDateFrom = date);
                      }),
                      const SizedBox(height: 8),
                      _buildDatePickerField('À:', _reportDateTo, (date) {
                        setState(() => _reportDateTo = date);
                      }),
                    ],
                  ),
                ),
                // Download buttons
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(
                      color: _teal.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (msg.formats?.contains('csv') ?? false)
                        _buildDownloadButton('CSV', 'csv', msg.reportType ?? 'alerts'),
                      if (msg.formats?.contains('pdf') ?? false)
                        _buildDownloadButton('PDF', 'pdf', msg.reportType ?? 'alerts'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerField(String label, DateTime? date, Function(DateTime) onDateChanged) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: ThemeData.light().copyWith(
                primaryColor: _navyBlue,
                colorScheme: ColorScheme.light(primary: _teal),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onDateChanged(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _teal.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: _teal, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$label ${date != null ? DateFormat('dd/MM/yyyy').format(date) : 'Select'}',
                style: TextStyle(color: _navyBlue, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton(String label, String format, String reportType) {
    return GestureDetector(
      onTap: () => _downloadReport(format, reportType),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: format == 'csv' ? _teal : _navyBlue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.download, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _downloadReport(String format, String reportType) async {
    if (_reportDateFrom == null || _reportDateTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez les deux dates')),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('⏳ Génération du rapport...')),
    );

    try {
      final dateFrom = DateFormat('yyyy-MM-dd').format(_reportDateFrom!);
      final dateTo   = DateFormat('yyyy-MM-dd').format(_reportDateTo!);
      final url      = 'http://10.102.0.68/Reader/generate_report.php'
                      '?format=$format&date_from=$dateFrom&date_to=$dateTo&type=$reportType';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Erreur serveur: ${response.statusCode}')),
          );
        }
        return;
      }

      // ✅ Save to TEMP folder — zero permissions needed
      final tempDir   = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
      final fileName  = '$reportType-rapport-$timestamp.$format';
      final filePath  = '${tempDir.path}/$fileName';

      await File(filePath).writeAsBytes(response.bodyBytes);

      // ✅ Open Android share sheet — user picks where to save
      //final mimeType = format == 'pdf' ? 'application/pdf' : 'text/csv';
      final mimeType = format == 'pdf' ? 'text/html' : 'text/csv';
      await Share.shareXFiles(
        [XFile(filePath, mimeType: mimeType, name: fileName)],
        subject: fileName,
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e')),
        );
      }
    }
  }


  Widget _buildSuggestions() {
    return Container(
      color: Colors.white,
      child: SizedBox(
        height: 48,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          itemCount: _suggestions.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _sendMessage(_suggestions[index]),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _lightBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _teal.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _suggestions[index],
                    style: const TextStyle(
                      color: Color(0xFF168D8C),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  // ── INPUT BAR ─────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _lightBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _controller,
                style: TextStyle(color: _navyBlue, fontSize: 14),
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                decoration: InputDecoration(
                  hintText: 'Tapez votre question...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isSending ? null : () => _sendMessage(_controller.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isSending ? Colors.grey.shade300 : _teal,
                borderRadius: BorderRadius.circular(14),
                boxShadow: _isSending
                    ? []
                    : [
                        BoxShadow(
                          color: _teal.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
              ),
              child: _isSending
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _navyBlue,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── TYPING INDICATOR (animated dots) ─────────────────────────
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) ctrl.repeat(reverse: true);
      });
      return ctrl;
    });
    _animations = _controllers
        .map((c) => Tween<double>(begin: 0, end: 1).animate(c))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _animations[i],
            builder: (_, _) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 7,
              height: 7 + (_animations[i].value * 5),
              decoration: BoxDecoration(
                color: Color.lerp(
                  Colors.grey.shade400,
                  const Color(0xFF168D8C),
                  _animations[i].value,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }
}
