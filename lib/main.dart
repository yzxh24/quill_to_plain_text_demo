import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  final quill.QuillController quillController = quill.QuillController.basic();

  @override
  void initState() {
    super.initState();

    quillController.document = quill.Document.fromJson(
      jsonDecode(r'[{"insert":"content\n"},{"insert":{"custom":"{\"notes\":\"[{\\\"insert\\\":\\\"Notes\\\\n\\\"}]\"}"}},{"insert":"\n"}]')
    );
  }

  @override
  void dispose() {
    quillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(onPressed: () {
              _addEditNote(context);
            },
            icon: const Icon(Icons.add),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: () async {
          var text = quillController.document.toPlainText([NotesEmbedBuilder(addEditNote: _addEditNote) ]);
          await Clipboard.setData(ClipboardData(text: text));
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..removeCurrentSnackBar()
              ..showSnackBar(const SnackBar(
                content: Text('Copy it'),
                duration: Duration(seconds: 1),
              ));
          }
        },
        child: const Icon(Icons.copy)
      ),
      body: Column(
        children: [
          quill.QuillToolbar.simple(controller: quillController),
          Expanded(child: quill.QuillEditor.basic(
            controller: quillController,
            focusNode: FocusNode(),
            configurations: quill.QuillEditorConfigurations(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              embedBuilders: [NotesEmbedBuilder(addEditNote: _addEditNote)],
            )
          ))
        ],
      )
    );
  }

  Future<void> _addEditNote(BuildContext context,
      {quill.Document? document}) async {
    final isEditing = document != null;
    final quillEditorController = quill.QuillController(
      document: document ?? quill.Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.only(left: 16, right: 16, top: 8),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${isEditing ? 'Edit' : 'Add'} note'),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            )
          ],
        ),
        content: quill.QuillEditor.basic(
          controller: quillEditorController,
          configurations: const quill.QuillEditorConfigurations(),
        ),
      ),
    );

    if (quillEditorController.document.isEmpty()) return;

    final block = quill.BlockEmbed.custom(
      NotesBlockEmbed.fromDocument(quillEditorController.document),
    );
    final controller = quillController;
    final index = controller.selection.baseOffset;
    final length = controller.selection.extentOffset - index;

    if (isEditing) {
      final offset =
          quill.getEmbedNode(controller, controller.selection.start).offset;
      controller.replaceText(
          offset, 1, block, TextSelection.collapsed(offset: offset));
    } else {
      controller.replaceText(index, length, block, null);
    }
  }
}

class NotesBlockEmbed extends quill.CustomBlockEmbed {
  const NotesBlockEmbed(String value) : super(noteType, value);

  static const String noteType = 'notes';

  static NotesBlockEmbed fromDocument(quill.Document document) =>
      NotesBlockEmbed(jsonEncode(document.toDelta().toJson()));

  quill.Document get document => quill.Document.fromJson(jsonDecode(data));
}

class NotesEmbedBuilder extends quill.EmbedBuilder {
  NotesEmbedBuilder({required this.addEditNote});

  Future<void> Function(BuildContext context, {quill.Document? document})
  addEditNote;

  @override
  String get key => 'notes';

  @override
  String toPlainText(quill.Embed node) {
    return node.toPlainText();
  }

  @override
  Widget build(
      BuildContext context,
      quill.QuillController controller,
      quill.Embed node,
      bool readOnly,
      bool inline,
      TextStyle textStyle,
      ) {
    final notes = NotesBlockEmbed(node.value.data).document;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          // border: Border.all(color: Colors.grey),
          color: isDark ? Colors.grey[900] : Colors.grey[200],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                notes.toPlainText().trimRight(),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.6)),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => addEditNote(context, document: notes),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.edit, size: 16.0, color: Colors.grey),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        final notesText = notes.toPlainText().trimRight();
                        Clipboard.setData(ClipboardData(text: notesText));
                        ScaffoldMessenger.of(context)
                          ..removeCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text('Copy it'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.copy, size: 16.0, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
