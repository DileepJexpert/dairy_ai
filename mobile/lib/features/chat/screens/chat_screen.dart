import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/shared/widgets/farmer_auth_action.dart';
import 'package:dairy_ai/features/chat/models/chat_models.dart';
import 'package:dairy_ai/features/chat/providers/chat_provider.dart';
import 'package:dairy_ai/features/chat/widgets/chat_bubble.dart';
import 'package:dairy_ai/features/chat/widgets/typing_indicator.dart';

/// Flagship Kisan Sahayata Kendra & Pashu Mitra AI Screen.
/// Provides 24/7 AI chat assistance, government subsidy catalog, and emergency helplines.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.initialTab = 0, this.initialQuery});

  final int initialTab;
  final String? initialQuery;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  static const List<Map<String, String>> _quickTopics = [
    {
      'label': '🏛️ KCC लोन योजना',
      'query': 'पशुपालन किसान क्रेडिट कार्ड (KCC) लोन कैसे मिलता है और ब्याज दर क्या है?',
    },
    {
      'label': '🧬 गोकुल मिशन (सेक्स्ड सीमेन)',
      'query': 'राष्ट्रीय गोकुल मिशन के तहत ₹100 में बछिया पैदा करने वाला सीमेन कैसे लें?',
    },
    {
      'label': '🛡️ पशु बीमा (70% सब्सिडी)',
      'query': 'पशुधन बीमा योजना में 70% सब्सिडी और क्लेम की प्रक्रिया क्या है?',
    },
    {
      'label': '🚨 थनैला प्राथमिक उपचार',
      'query': 'गाय के थन में सूजन और थनैला (Mastitis) का तुरंत देसी व प्राथमिक उपचार क्या है?',
    },
    {
      'label': '💨 अफारा देसी नुस्खा',
      'query': 'पशु का पेट फूलने और गैस (अफारा / Bloat) पर तुरंत क्या पिलाएं?',
    },
    {
      'label': '🌾 दूध बढ़ाने का आहार',
      'query': 'गाय-भैंस का दूध बढ़ाने के लिए संतुलित आहार व दाना का सही अनुपात क्या है?',
    },
    {
      'label': '🥛 फैट व SNF कैसे बढ़ाएं',
      'query': 'दूध में फैट और SNF बढ़ाने के वैज्ञानिक देसी तरीके क्या हैं?',
    },
    {
      'label': '🐮 सही समय पर AI (AM-PM)',
      'query': 'पशु की हीट पहचान और कृत्रिम गर्भाधान (AI) कराने का AM-PM नियम क्या है?',
    },
    {
      'label': '📞 24/7 हेल्पलाइन',
      'query': 'पशु एम्बुलेंस 1962 और किसान हेल्पलाइन नंबर की जानकारी दें।',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );

    Future.microtask(() {
      ref.read(chatProvider.notifier).loadConversationHistory();
      if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
        _handleDirectQuery(widget.initialQuery!);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    ref.read(chatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _handleDirectQuery(String query) {
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
    }
    ref.read(chatProvider.notifier).sendMessage(query);
    _scrollToBottom();
  }

  Future<void> _makePhoneCall(String phoneUrl) async {
    final uri = Uri.parse(phoneUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot launch call: $phoneUrl')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    // Auto-scroll on new messages
    ref.listen<ChatState>(chatProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      appBar: AppBar(
        backgroundColor: const Color(0xff047857),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'किसान सहायता केंद्र',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            Text(
              'Pashu Mitra AI & Govt Schemes',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          // Language selector
          _LanguageSelector(
            selectedCode: chatState.selectedLanguage,
            onChanged: (code) {
              ref.read(chatProvider.notifier).setLanguage(code);
            },
          ),
          // Clear / New chat
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'नया वार्तालाप (New Conversation)',
            onPressed: () {
              ref.read(chatProvider.notifier).clearConversation();
            },
          ),
          // Universal Login / Profile action
          const FarmerAuthAction(nextRoute: '/more/chat'),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.smart_toy_outlined, size: 20), text: 'पशु मित्र AI'),
            Tab(icon: Icon(Icons.account_balance_outlined, size: 20), text: 'सरकारी योजनाएं'),
            Tab(icon: Icon(Icons.headset_mic_outlined, size: 20), text: 'हेल्पलाइन'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Pashu Mitra AI Chat
              _buildChatTab(context, chatState),
              // Tab 2: Government Schemes Directory
              _buildSchemesTab(context),
              // Tab 3: Emergency Helplines & Support
              _buildHelplineTab(context),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Pashu Mitra AI Chat View
  // ---------------------------------------------------------------------------

  Widget _buildChatTab(BuildContext context, ChatState chatState) {
    final messages = chatState.messages;
    final isSending = chatState.isSending;

    return Column(
      children: [
        // Error banner
        if (chatState.error != null)
          MaterialBanner(
            content: Text(chatState.error!),
            backgroundColor: Colors.red.shade50,
            actions: [
              TextButton(
                onPressed: () => ref.read(chatProvider.notifier).clearError(),
                child: const Text('DISMISS'),
              ),
            ],
          ),

        // Quick Topic Bar
        Container(
          height: 48,
          color: Colors.white,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _quickTopics.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final topic = _quickTopics[index];
              return ActionChip(
                label: Text(
                  topic['label']!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff065f46),
                  ),
                ),
                backgroundColor: const Color(0xffecfdf5),
                side: const BorderSide(color: Color(0xffa7f3d0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                onPressed: () => _handleDirectQuery(topic['query']!),
              );
            },
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xffe2e8f0)),

        // Message List or Empty State
        Expanded(
          child: chatState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      itemCount: messages.length + (isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length && isSending) {
                          return const TypingIndicator();
                        }
                        return ChatBubble(message: messages[index]);
                      },
                    ),
        ),

        // Chat Input Bar
        _buildChatInputBar(context, isSending: isSending),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xffecfdf5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xffa7f3d0), width: 2),
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              size: 56,
              color: Color(0xff047857),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'राम-राम! मैं आपका पशु मित्र AI सहायक हूँ।',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xff0f172a),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'पशुपालन, दुग्ध उत्पादन, सरकारी सब्सिडी (KCC लोन, गोकुल मिशन, पशु बीमा) व बीमारी के प्राथमिक उपचार पर 24/7 तुरंत सलाह पाएं।',
            style: TextStyle(fontSize: 13, color: Color(0xff475569), height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'लोकप्रिय सवाल (Tap to Ask):',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xff047857),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickTopics.map((topic) {
              return OutlinedButton.icon(
                icon: const Icon(Icons.help_outline, size: 14, color: Color(0xff047857)),
                label: Text(
                  topic['label']!,
                  style: const TextStyle(fontSize: 12, color: Color(0xff0f172a)),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xffcbd5e1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () => _handleDirectQuery(topic['query']!),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInputBar(BuildContext context, {required bool isSending}) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xffe2e8f0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Quick Video Vet Shortcut
          IconButton(
            icon: const Icon(Icons.video_call, color: Color(0xff047857)),
            tooltip: 'पशु चिकित्सक से वीडियो परामर्श',
            onPressed: () => context.push('/vet/booking'),
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'पशु स्वास्थ्य, चारा या योजना का सवाल पूछें...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xff94a3b8)),
                filled: true,
                fillColor: const Color(0xfff1f5f9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xff047857),
                    ),
                  )
                : const Icon(Icons.send, color: Color(0xff047857)),
            tooltip: 'भेजें (Send)',
            onPressed: isSending ? null : _handleSend,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Government Schemes Directory
  // ---------------------------------------------------------------------------

  Widget _buildSchemesTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Schemes Header Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff065f46), Color(0xff047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'भारत सरकार डेयरी व पशुपालन योजनाएं',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'पशुपालकों के लिए 4% सस्ता ऋण, सेक्स्ड सीमेन व 70% बीमा सब्सिडी की पूरी जानकारी।',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Scheme 1: KCC Pashupalan
        _buildSchemeCard(
          context,
          title: 'KCC Pashupalan (किसान क्रेडिट कार्ड - पशुपालन)',
          badge: '4% Subsidized Loan',
          badgeColor: Colors.blue.shade700,
          maxAmount: '₹2,00,000 (Collateral-Free)',
          interest: '4% Effective p.a. (3% Timely Repayment Rebate)',
          overview:
              'पशुपालकों को चारा, दाना व दैनिक खर्चों हेतु ₹2 लाख तक का बिना किसी बंधक (Security-free) ऋण केवल 4% वार्षिक ब्याज पर मिलता है।',
          eligibility: [
            'दुधारू गाय या भैंस रखने वाले किसान',
            'महिला स्वयं सहायता समूह व दुग्ध समिति सदस्य',
            'भूमिहीन व बटाईदार पशुपालक भी पात्र',
          ],
          documents: [
            'आधार कार्ड व 2 पासपोर्ट फोटो',
            'बैंक पासबुक',
            'दुग्ध सहकारी समिति का आपूर्ति प्रमाण पत्र',
          ],
          onAskAi: () => _handleDirectQuery(
            'KCC पशुपालन लोन के लिए आवेदन कैसे करें और कौन-कौन से दस्तावेज चाहिए?',
          ),
        ),

        // Scheme 2: Rashtriya Gokul Mission
        _buildSchemeCard(
          context,
          title: 'Rashtriya Gokul Mission (राष्ट्रीय गोकुल मिशन)',
          badge: '90%+ Female Calf Guarantee',
          badgeColor: Colors.purple.shade700,
          maxAmount: '₹100/Sexed Semen Straw & ₹5,000 IVF Grant',
          interest: 'N/A (Direct Govt Subsidy)',
          overview:
              'देशी नस्लों (गीर, साहीवाल, थारपारकर, मुर्रा) के नस्ल सुधार हेतु मात्र ₹100 में बछिया पैदा करने वाला सॉर्टेड सीमेन और ₹5,000 तक आईवीएफ अनुदान।',
          eligibility: [
            'सभी देशी गाय व भैंस पालक किसान',
            'प्रजनन योग्य स्वस्थ मादा पशु',
          ],
          documents: [
            'पशु का 12-अंकीय ईयर टैग (INAPH)',
            'पशु स्वास्थ्य प्रमाण पत्र',
          ],
          onAskAi: () => _handleDirectQuery(
            'राष्ट्रीय गोकुल मिशन के तहत ₹100 में सेक्स्ड सीमेन कैसे प्राप्त करें?',
          ),
        ),

        // Scheme 3: Pashu Bima Yojana
        _buildSchemeCard(
          context,
          title: 'Pashu Bima Yojana (पशुधन बीमा योजना)',
          badge: 'Up to 70% Premium Subsidy',
          badgeColor: Colors.teal.shade700,
          maxAmount: 'Market Valuation Coverage (Up to ₹80,000)',
          interest: 'N/A (Insurance Scheme)',
          overview:
              'दूधारू गाय-भैंस की बीमारी, प्रसव जटिलता या आकस्मिक मृत्यु होने पर आर्थिक सुरक्षा। प्रीमियम पर सरकार 70% (SC/ST/BPL) तथा 50% (सामान्य) सब्सिडी देती है।',
          eligibility: [
            'देशी, संकर गाय व दुधारू भैंसें',
            'प्रति परिवार अधिकतम 5 पशुओं का बीमा',
          ],
          documents: [
            'पशु का 12 अंकों का कान का टैग',
            'सरकारी पशु डॉक्टर द्वारा स्वास्थ्य व मूल्य प्रमाण पत्र',
            'बीपीएल / जाति प्रमाण पत्र (सब्सिडी हेतु)',
          ],
          onAskAi: () => _handleDirectQuery(
            'पशुधन बीमा योजना के लिए फॉर्म कैसे भरें और क्लेम की क्या शर्तें हैं?',
          ),
        ),

        // Scheme 4: National Livestock Mission
        _buildSchemeCard(
          context,
          title: 'National Livestock Mission (राष्ट्रीय पशुधन मिशन - NLM)',
          badge: '50% Capital Grant',
          badgeColor: const Color(0xffb45309),
          maxAmount: 'Up to ₹50,00,000 Capital Subsidy',
          interest: 'Bank-Linked Project Loan',
          overview:
              'साइलेज बैंक, टीएमआर पैलेट प्लांट व पशु नस्ल संवर्धन इकाई लगाने हेतु सरकार द्वारा 50% तक पूंजीगत अनुदान उपलब्ध कराया जाता है।',
          eligibility: [
            'व्यक्तिगत किसान, एफपीओ (FPO) व दुग्ध उद्यमी',
            'परियोजना हेतु पर्याप्त भूमि व जल स्रोत',
          ],
          documents: [
            'विस्तृत परियोजना रिपोर्ट (DPR)',
            'जमीन के स्वामित्व/लीज दस्तावेज',
            'बैंक ऋण स्वीकृति पत्र',
          ],
          onAskAi: () => _handleDirectQuery(
            'राष्ट्रीय पशुधन मिशन (NLM) में 50% सब्सिडी पर चारा व साइलेज यूनिट कैसे लगाएं?',
          ),
        ),
      ],
    );
  }

  Widget _buildSchemeCard(
    BuildContext context, {
    required String title,
    required String badge,
    required Color badgeColor,
    required String maxAmount,
    required String interest,
    required String overview,
    required List<String> eligibility,
    required List<String> documents,
    required VoidCallback onAskAi,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xffe2e8f0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xff0f172a),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              overview,
              style: const TextStyle(fontSize: 13, color: Color(0xff334155), height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xfff8fafc),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffe2e8f0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.currency_rupee, size: 16, color: Color(0xff047857)),
                      const SizedBox(width: 6),
                      const Text(
                        'अधिकतम लाभ: ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Text(
                          maxAmount,
                          style: const TextStyle(fontSize: 12, color: Color(0xff047857), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.percent, size: 16, color: Colors.blue),
                      const SizedBox(width: 6),
                      const Text(
                        'ब्याज / अनुदान: ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Text(
                          interest,
                          style: const TextStyle(fontSize: 12, color: Color(0xff1e293b)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'पात्रता व जरूरी दस्तावेज देखें',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xff047857)),
              ),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'पात्रता (Eligibility):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 4),
                ...eligibility.map((e) => Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(child: Text(e, style: const TextStyle(fontSize: 12))),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'जरूरी दस्तावेज (Documents):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 4),
                ...documents.map((d) => Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(child: Text(d, style: const TextStyle(fontSize: 12))),
                        ],
                      ),
                    )),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xff047857)),
                label: const Text('💬 AI से इस योजना के बारे में पूछें'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xff047857)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onAskAi,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Emergency Helplines & Support
  // ---------------------------------------------------------------------------

  Widget _buildHelplineTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Helpline Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.emergency, color: Colors.red.shade700, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '24/7 आपातकालीन किसान व पशु हेल्पलाइन',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'पशु गंभीर बीमार होने या तुरंत सलाह हेतु 1-टैप पर सीधे कॉल करें।',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Helpline 1: 1962 Mobile Veterinary Ambulance
        _buildHelplineCard(
          context,
          title: '1962 - मोबाइल पशु चिकित्सा एम्बुलेंस',
          subtitle: 'National Mobile Veterinary Unit (MVU)',
          description:
              'पशु के गंभीर रूप से बीमार होने, एक्सीडेंट या आकस्मिक स्थिति में टोल-फ्री कॉल करें। सरकारी पशु चिकित्सा वैन सीधे आपके दरवाजे पर पहुंचेगी।',
          badge: 'Toll-Free 24/7',
          badgeColor: Colors.red.shade700,
          phoneNumber: '1962',
          icon: Icons.emergency_outlined,
        ),

        // Helpline 2: Kisan Call Centre 1800-180-1551
        _buildHelplineCard(
          context,
          title: '1800-180-1551 - किसान कॉल सेंटर',
          subtitle: 'Ministry of Agriculture, Government of India',
          description:
              'कृषि विशेषज्ञों व पशुपालन वैज्ञानिकों से अपनी स्थानीय भाषा में चारा प्रबंधन, सब्सिडी, बीज, कीट व मौसम पर निःशुल्क सलाह लें।',
          badge: 'Govt Toll-Free',
          badgeColor: Colors.orange.shade800,
          phoneNumber: '18001801551',
          icon: Icons.support_agent_outlined,
        ),

        // Helpline 3: NDDB Dairy Helpline 1800-233-1962
        _buildHelplineCard(
          context,
          title: '1800-233-1962 - NDDB राष्ट्रीय डेयरी हेल्पलाइन',
          subtitle: 'National Dairy Development Board',
          description:
              'वैज्ञानिक दुग्ध उत्पादन, संतुलित पशुआहार, साइलेज निर्माण व नस्ल संवर्धन तकनीक पर राष्ट्रीय डेयरी बोर्ड की आधिकारिक सहायता।',
          badge: 'NDDB Helpline',
          badgeColor: Colors.blue.shade700,
          phoneNumber: '18002331962',
          icon: Icons.local_drink_outlined,
        ),

        // Helpline 4: Milterra Tele-Vet Video Clinic
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xffa7f3d0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xffecfdf5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.video_call, color: Color(0xff047857), size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'मिल्टेरा टेली-वेट वीडियो क्लिनिक',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            'Verified Bovine Veterinary Specialists',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'NDRI व IVRI प्रमाणित पशु चिकित्सकों से 1-क्लिक वीडियो परामर्श, डिजिटल ई-पर्चा (Rx) और त्वरित व्हाट्सएप चैट सहायता।',
                  style: TextStyle(fontSize: 13, color: Color(0xff334155), height: 1.4),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.video_call, color: Colors.white),
                    label: const Text('📹 वीडियो डॉक्टर से परामर्श लें (Book Tele-Vet)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff047857),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => context.push('/vet/booking'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHelplineCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String description,
    required String badge,
    required Color badgeColor,
    required String phoneNumber,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xffe2e8f0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: badgeColor, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(fontSize: 13, color: Color(0xff334155), height: 1.4),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.phone_in_talk, size: 18),
                label: Text('📞 कॉल करें: $phoneNumber'),
                style: FilledButton.styleFrom(
                  backgroundColor: badgeColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: () => _makePhoneCall('tel:$phoneNumber'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Language Selector Dropdown
// ---------------------------------------------------------------------------
class _LanguageSelector extends StatelessWidget {
  final String selectedCode;
  final ValueChanged<String> onChanged;

  const _LanguageSelector({
    required this.selectedCode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = ChatLanguage.supported.firstWhere(
      (l) => l.code == selectedCode,
      orElse: () => ChatLanguage.supported.first,
    );

    return PopupMenuButton<String>(
      tooltip: 'भाषा बदलें (Change Language)',
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language, size: 18, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            current.code.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
      onSelected: onChanged,
      itemBuilder: (context) => ChatLanguage.supported
          .map((lang) => PopupMenuItem<String>(
                value: lang.code,
                child: Row(
                  children: [
                    if (lang.code == selectedCode)
                      const Icon(Icons.check, size: 16, color: DairyTheme.primaryGreen)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Text(lang.nativeName),
                    const SizedBox(width: 8),
                    Text(
                      '(${lang.name})',
                      style: const TextStyle(
                        color: DairyTheme.subtleGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
