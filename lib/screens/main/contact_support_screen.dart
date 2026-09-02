import 'package:flutter/material.dart';
import '../../services/support_service.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate() || _sending) return;
    setState(() => _sending = true);

    try {
      await SupportService.instance.submitMessage(
        subject: _subject.text,
        message: _message.text,
      );
      if (!mounted) return;
      _subject.clear();
      _message.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your message was sent successfully.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to send message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Support')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.support_agent_rounded, size: 46, color: theme.colorScheme.primary),
                        const SizedBox(height: 12),
                        Text('Contact Support', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('Send us a message and the support team will receive it.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 22),
                        TextFormField(
                          controller: _subject,
                          maxLength: 150,
                          decoration: const InputDecoration(labelText: 'Subject', prefixIcon: Icon(Icons.subject_rounded)),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Enter a subject' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _message,
                          minLines: 7,
                          maxLines: 12,
                          maxLength: 5000,
                          decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true, prefixIcon: Icon(Icons.message_outlined)),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Enter your message' : null,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _sending ? null : _send,
                          icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
                          label: Text(_sending ? 'Sending...' : 'Send Message'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
