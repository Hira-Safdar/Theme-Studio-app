import 'package:flutter/material.dart';
import '../services/native_bridge_service.dart';

/// Ye screen sirf fallback ke tor par khulti hai -- jab Notes widget tap
/// hota hai aur device par koi real notes app (Samsung Notes/Google Keep/
/// wagera) resolve nahi hota (WidgetClickActions.kt ka last-resort).
/// Normal case mein user ka apna Notes app seedha khulta hai, ye screen
/// kabhi nahi dikhti.
class NotesEditorScreen extends StatefulWidget {
  const NotesEditorScreen({super.key});

  @override
  State<NotesEditorScreen> createState() => _NotesEditorScreenState();
}

class _NotesEditorScreenState extends State<NotesEditorScreen> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingNote();
  }

  Future<void> _loadExistingNote() async {
    final text = await NativeBridgeService.instance.getNoteText();
    if (!mounted) return;
    setState(() {
      _controller.text = text ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await NativeBridgeService.instance.saveNoteText(_controller.text);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).maybePop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\'t save note — tap to retry')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit note'),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _saving ? null : _save,
            tooltip: 'Save',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Type your note...',
                  border: InputBorder.none,
                ),
              ),
            ),
    );
  }
}