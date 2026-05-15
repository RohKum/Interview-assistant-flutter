import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/services.dart';

import '../models/chat_message.dart';
import '../widgets/chat_bubble.dart';

class AssistantHome extends StatefulWidget {
  const AssistantHome({super.key});

  @override
  State<AssistantHome> createState() => _AssistantHomeState();
}

class _AssistantHomeState extends State<AssistantHome> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _professionController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();
  
  String _apiKey = '';
  String _profession = '';
  String _experience = '';
  
  List<ChatMessage> _messages = [];
  ChatSession? _chatSession;
  bool _isLoading = false;
  bool _isSettingsOpen = false;

  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadSettings();
    _initSpeech();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  Future<void> _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (val) {
        if (val == 'done' || val == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (val) => print('onError: $val'),
    );
    setState(() {
      _speechEnabled = available;
    });
  }

  void _clear() {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    }
    setState(() {
      _questionController.clear();
      _messages.clear();
      _chatSession = null;
    });
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _questionController.text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      await _speech.stop();
      // Wait a tiny bit to ensure the final recognized word is updated
      await Future.delayed(const Duration(milliseconds: 500));
      _generateAnswer();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('gemini_api_key') ?? '';
      _profession = prefs.getString('user_profession') ?? '';
      _experience = prefs.getString('user_experience') ?? '';
      
      _apiKeyController.text = _apiKey;
      _professionController.text = _profession;
      _experienceController.text = _experience;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _apiKeyController.text.trim();
    final prof = _professionController.text.trim();
    final exp = _experienceController.text.trim();
    
    await prefs.setString('gemini_api_key', key);
    await prefs.setString('user_profession', prof);
    await prefs.setString('user_experience', exp);
    
    setState(() {
      _apiKey = key;
      _profession = prof;
      _experience = exp;
      // Reset chat session if settings change to apply new system instructions
      _chatSession = null; 
    });
    
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully!')),
      );
    }
  }

  void _showSettingsDialog() {
    _isSettingsOpen = true;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Configure your AI Assistant.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Gemini API Key',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _professionController,
                  decoration: const InputDecoration(
                    labelText: 'Your Profession (e.g., Flutter Developer)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _experienceController,
                  decoration: const InputDecoration(
                    labelText: 'Experience Level (e.g., 5 years)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Save'),
            ),
          ],
        );
      },
    ).then((_) {
      if (mounted) {
        _isSettingsOpen = false;
      }
    });
  }

  Future<void> _generateAnswer() async {
    if (_apiKey.isEmpty) {
      _showSettingsDialog();
      return;
    }

    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    setState(() {
      _isLoading = true;
      _messages.add(ChatMessage(text: question, isUser: true));
      _questionController.clear();
      if (_isListening) {
        _isListening = false;
        _speech.stop();
      }
    });

    try {
      if (_chatSession == null) {
        String persona = "You are a highly skilled AI Interview Assistant. ";
        if (_profession.isNotEmpty) {
          persona += "The user's profession is $_profession. ";
        }
        if (_experience.isNotEmpty) {
          persona += "They have $_experience of experience. ";
        }
        persona += "The user is currently in a live interview and the interviewer has just asked them a question. "
            "Provide a concise, professional, and excellent answer that the user can read or adapt quickly. "
            "Use bullet points if it helps readability. Do not include unnecessary pleasantries. "
            "Focus on delivering a strong, structured response tailored to their profession and experience level.";

        final model = GenerativeModel(
          model: 'gemini-3-flash-preview',
          apiKey: _apiKey,
          systemInstruction: Content.system(persona),
          generationConfig: GenerationConfig(
            temperature: 0.2, // Low temperature for more factual, precise answers
          ),
        );
        _chatSession = model.startChat();
      }

      final response = await _chatSession!.sendMessage(Content.text(question));

      setState(() {
        _messages.add(ChatMessage(
          text: response.text ?? 'No response generated.', 
          isUser: false
        ));
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: 'Error: $e', isUser: false));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white30, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Scaffold(
          appBar: AppBar(
            title: const Text(
              'Interview Assistant',
              style: TextStyle(fontSize: 14),
            ),
            backgroundColor: Colors.black.withOpacity(0.5),
            elevation: 0,
            shape: const Border(
              bottom: BorderSide(color: Colors.white24, width: 1),
            ),
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.settings),
                onPressed: _showSettingsDialog,
                tooltip: 'Settings',
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              children: [
                // Question Input
                TextField(
                  controller: _questionController,
                  focusNode: _textFieldFocusNode,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText:
                        'Type, paste, or speak the interviewer\'s question...',
                    hintStyle: const TextStyle(fontSize: 12),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 10),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Primary Action Button (Listen -> Stop & Answer -> Loading)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : (_speechEnabled ? _listen : null),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _isListening
                                    ? LucideIcons.micOff
                                    : LucideIcons.mic,
                                size: 20,
                              ),
                        label: Text(
                          _isLoading
                              ? 'Generating Answer...'
                              : (_isListening
                                    ? 'Stop Listening & Answer'
                                    : 'Start Listening'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isListening
                              ? Colors.redAccent
                              : Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Clear Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _clear,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(LucideIcons.trash, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Answer Display
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: _messages.isEmpty
                        ? const Center(
                            child: Text(
                              'Waiting for a question...',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              return ChatBubble(message: _messages[index]);
                            },
                          ),
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (_isSettingsOpen) {
      return false;
    }

    if (event is KeyDownEvent) {
      if (_textFieldFocusNode.hasFocus) {
        if (event.logicalKey == LogicalKeyboardKey.enter || 
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          // If shift is not pressed, submit the question
          if (!HardwareKeyboard.instance.isShiftPressed) {
            if (!_isLoading && _questionController.text.trim().isNotEmpty) {
              _generateAnswer();
            }
            return true; // Handle the key event so it doesn't add a newline
          }
        }
        return false; // Let the text field handle other keys (like Shift+Enter)
      }

      if (event.logicalKey == LogicalKeyboardKey.space) {
        if (!_isLoading && _speechEnabled) {
          _listen();
        }
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.backspace ||
          event.logicalKey == LogicalKeyboardKey.delete) {
        if (!_isLoading) {
          _clear();
        }
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _textFieldFocusNode.dispose();
    _questionController.dispose();
    _apiKeyController.dispose();
    _professionController.dispose();
    _experienceController.dispose();
    super.dispose();
  }
}
