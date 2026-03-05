import 'dart:async';

import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/app_settings.dart';
import '../services/note_service.dart';
import '../services/sync_service.dart';
import '../widgets/custom_appBar.dart';
import '../widgets/custom_bottom_navbar.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final SyncService _syncService = SyncService();
  final AppSettings _appSettings = AppSettings();
  int _activeBackupJobs = 0;

  bool get _isAppBarLoading => _activeBackupJobs > 0;

  void _setBackupLoading(bool isStarting) {
    if (!mounted) return;
    setState(() {
      if (isStarting) {
        _activeBackupJobs += 1;
      } else {
        _activeBackupJobs = (_activeBackupJobs - 1).clamp(0, 1 << 30);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _appSettings.get('notes'),
        isLoading: _isAppBarLoading,
        isOnline: _syncService.isOnline,
        lastSyncTime: _syncService.lastSyncTime,
        onSyncPressed: () async {
          final wasOnline = _syncService.isOnline;
          await _syncService.checkConnectivity();
          if (!mounted) return;

          final isNowOnline = _syncService.isOnline;
          String message;
          Color bgColor;

          if (isNowOnline) {
            message = _appSettings.get('notesSyncedSuccessfully');
            bgColor = Colors.green;
          } else if (wasOnline && !isNowOnline) {
            message = _appSettings.get('connectionLostWorkingOffline');
            bgColor = Colors.orange;
          } else {
            message = _appSettings.get('workingOfflineUsingLocalData');
            bgColor = Colors.orange;
          }

          // Rebuild to update AppBar sync icon
          setState(() {});

          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: bgColor,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        onSignOut: () async {
          // Sign out is handled separately
        },
      ),
      bottomNavigationBar: CustomBottomNavbar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pop();
          } else if (index == 2) {
            Navigator.of(context).pop();
          }
        },
      ),
      body: NotesScreenBody(onBackupStateChanged: _setBackupLoading),
    );
  }
}

class NotesScreenBody extends StatefulWidget {
  const NotesScreenBody({super.key, required this.onBackupStateChanged});

  final ValueChanged<bool> onBackupStateChanged;

  @override
  State<NotesScreenBody> createState() => _NotesScreenBodyState();
}

class _NotesScreenBodyState extends State<NotesScreenBody> {
  final NoteService _noteService = NoteService();
  final SyncService _syncService = SyncService();
  final AppSettings _appSettings = AppSettings();
  List<Note> notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
    // Check connectivity status immediately
    unawaited(_syncService.checkConnectivity());
  }

  Future<void> _loadNotes() async {
    // Always show local data immediately when Notes tab opens
    final localNotes = await _noteService.loadFromLocal();
    if (mounted) {
      setState(() {
        notes = localNotes;
      });
    }
  }

  Future<void> _saveNotes() async {
    await _noteService.saveToLocal(notes);

    final notesSnapshot = notes
        .map((note) => Note.fromJson(note.toJson()))
        .toList();
    widget.onBackupStateChanged(true);
    unawaited(_saveNotesToFirebaseWithRetry(notesSnapshot));
  }

  Future<void> _saveNotesToFirebaseWithRetry(List<Note> notesSnapshot) async {
    try {
      var isSaved = await _noteService.saveToFirebase(notesSnapshot);

      if (!isSaved) {
        await _syncService.checkConnectivity();
        if (_syncService.isOnline) {
          await Future.delayed(const Duration(milliseconds: 500));
          isSaved = await _noteService.saveToFirebase(notesSnapshot);
        }
      }

      if (mounted) {
        setState(() {});
      }
    } finally {
      widget.onBackupStateChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        notes.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.note_outlined,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _appSettings.get('noNotes'),
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _appSettings.get('tapToCreateNote'),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
            : ReorderableListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: notes.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final movedNote = notes.removeAt(oldIndex);
                    notes.insert(newIndex, movedNote);
                  });
                  unawaited(_saveNotes());
                },
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return Card(
                    key: ValueKey(note.id),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ListTile(
                      title: Text(
                        note.title.isEmpty
                            ? _appSettings.get('untitled')
                            : note.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        note.content.isEmpty
                            ? _appSettings.get('noContent')
                            : note.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(_appSettings.get('deleteNote')),
                              content: Text(
                                _appSettings.get('deleteNoteConfirm'),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: Text(_appSettings.get('cancel')),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: Text(
                                    _appSettings.get('delete'),
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            setState(() {
                              notes.removeAt(index);
                            });
                            await _saveNotes();
                            if (!mounted) return;

                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_appSettings.get('noteDeleted')),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                      onTap: () async {
                        final editedNote = await Navigator.of(context)
                            .push<Note>(
                              MaterialPageRoute(
                                builder: (_) => NoteEditorScreen(note: note),
                              ),
                            );

                        if (editedNote != null) {
                          setState(() {
                            notes[index] = editedNote;
                          });
                          await _saveNotes();
                        }
                      },
                    ),
                  );
                },
              ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            elevation: 2,
            backgroundColor: const Color.fromARGB(255, 148, 203, 255),
            onPressed: () async {
              final newNote = await Navigator.of(context).push<Note>(
                MaterialPageRoute(
                  builder: (_) => NoteEditorScreen(
                    note: Note(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: '',
                      content: '',
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  ),
                ),
              );

              if (newNote != null) {
                setState(() {
                  notes.insert(0, newNote);
                });
                await _saveNotes();
              }
            },
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class NoteEditorScreen extends StatefulWidget {
  final Note note;

  const NoteEditorScreen({super.key, required this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final AppSettings _appSettings = AppSettings();
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveNote() {
    if (_titleController.text.isEmpty && _contentController.text.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final updatedNote = widget.note.copyWith(
      title: _titleController.text,
      content: _contentController.text,
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop(updatedNote);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appSettings.get('editNote')),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _saveNote),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: _appSettings.get('title'),
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: TextField(
                controller: _contentController,
                decoration: InputDecoration(
                  hintText: _appSettings.get('startTyping'),
                  border: InputBorder.none,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
