import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_toast.dart';

class ManageQuestionsScreen extends StatefulWidget {
  final Map<String, dynamic> quiz;

  const ManageQuestionsScreen({
    super.key,
    required this.quiz,
  });

  @override
  State<ManageQuestionsScreen> createState() => _ManageQuestionsScreenState();
}

class _ManageQuestionsScreenState extends State<ManageQuestionsScreen> {
  late Map<String, dynamic> _quizData;
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // CSV Sample Template Content matching Backend sample-csv
  final String _sampleCsvTemplate =
      'Question,Type,Difficulty,Option1,Option2,Option3,Option4,Correct_Option\n'
      'What is the capital of France?,single,easy,Paris,London,Berlin,Madrid,Paris\n'
      'Select prime numbers from options,multiple,medium,2,4,5,9,2|5\n'
      'Which gas do plants absorb during photosynthesis?,single,easy,Carbon Dioxide,Oxygen,Nitrogen,Hydrogen,Carbon Dioxide';

  @override
  void initState() {
    super.initState();
    _quizData = Map<String, dynamic>.from(widget.quiz);
    _loadQuizQuestions();
  }

  Future<void> _loadQuizQuestions() async {
    setState(() => _isLoading = true);
    final quizId = _quizData['id'];
    if (quizId != null) {
      final details = await ApiService.getQuizDetails(int.parse(quizId.toString()));
      if (details != null && mounted) {
        _quizData = Map<String, dynamic>.from(details);
        if (details['questions'] is List) {
          _questions = List<Map<String, dynamic>>.from(details['questions']);
        }
      }
    } else if (_quizData['questions'] is List) {
      _questions = List<Map<String, dynamic>>.from(_quizData['questions']);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // Filtered questions based on search prompt
  List<Map<String, dynamic>> get _filteredQuestions {
    if (_searchQuery.trim().isEmpty) return _questions;
    final q = _searchQuery.trim().toLowerCase();
    return _questions.where((item) {
      final text = (item['question'] ?? '').toString().toLowerCase();
      return text.contains(q);
    }).toList();
  }

  int get _singleChoiceCount =>
      _questions.where((q) => (q['type'] ?? 'single').toString().toLowerCase() == 'single').length;

  int get _multipleChoiceCount =>
      _questions.where((q) => (q['type'] ?? 'single').toString().toLowerCase() == 'multiple').length;

  // Open Add / Edit Question Modal Sheet
  void _openQuestionEditorModal({Map<String, dynamic>? existingQuestion}) {
    final bool isEdit = existingQuestion != null;
    final questionId = isEdit ? existingQuestion['id'] : null;

    final questionTextController =
        TextEditingController(text: isEdit ? (existingQuestion['question'] ?? '') : '');

    // Question Type: 'single' (Radio) or 'multiple' (Checkbox)
    String questionType =
        isEdit ? (existingQuestion['type'] ?? 'single').toString().toLowerCase() : 'single';

    String difficulty =
        isEdit ? (existingQuestion['difficulty'] ?? 'easy').toString().toLowerCase() : 'easy';

    // Parse options
    List<String> optionTexts = [];
    if (isEdit && existingQuestion['options'] != null) {
      if (existingQuestion['options'] is List) {
        optionTexts = (existingQuestion['options'] as List).map((e) => e.toString()).toList();
      }
    }

    if (optionTexts.length < 2) {
      optionTexts = ['', '', '', '']; // 4 default options
    }

    final optionControllers = optionTexts.map((txt) => TextEditingController(text: txt)).toList();

    // Parse correct answers
    List<int> selectedCorrectIndices = [];
    if (isEdit && existingQuestion['correct_option'] != null) {
      final rawCorrect = existingQuestion['correct_option'];
      if (rawCorrect is List) {
        for (var item in rawCorrect) {
          final idx = optionTexts.indexOf(item.toString());
          if (idx != -1) selectedCorrectIndices.add(idx);
        }
      } else if (rawCorrect is num) {
        selectedCorrectIndices.add(rawCorrect.toInt());
      } else {
        final idx = optionTexts.indexOf(rawCorrect.toString());
        if (idx != -1) {
          selectedCorrectIndices.add(idx);
        } else {
          // If correct option is numeric 1-based index string
          final numVal = int.tryParse(rawCorrect.toString());
          if (numVal != null && numVal >= 1 && numVal <= optionTexts.length) {
            selectedCorrectIndices.add(numVal - 1);
          }
        }
      }
    }

    if (selectedCorrectIndices.isEmpty) {
      selectedCorrectIndices.add(0);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.88,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    // Handle Bar & Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppTheme.border)),
                      ),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isEdit ? Icons.edit_note_rounded : Icons.add_task_rounded,
                                      color: AppTheme.primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isEdit ? 'Edit Question' : 'Create New Question',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.mainText,
                                        ),
                                      ),
                                      Text(
                                        _quizData['title'] ?? 'Quiz',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                                onPressed: () => Navigator.pop(sheetContext),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Scrollable Question Editor Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Question Type Choice Selector (Single Choice vs Multiple Choice)
                            const Text(
                              'Question Answer Type',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.mainText),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        questionType = 'single';
                                        if (selectedCorrectIndices.length > 1) {
                                          selectedCorrectIndices = [selectedCorrectIndices.first];
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: questionType == 'single'
                                            ? AppTheme.primary.withValues(alpha: 0.1)
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: questionType == 'single' ? AppTheme.primary : AppTheme.border,
                                          width: questionType == 'single' ? 1.8 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.radio_button_checked_rounded,
                                            size: 18,
                                            color: questionType == 'single' ? AppTheme.primary : AppTheme.textMuted,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Single Choice',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: questionType == 'single' ? AppTheme.primary : AppTheme.mainText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        questionType = 'multiple';
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: questionType == 'multiple'
                                            ? Colors.purple.withValues(alpha: 0.1)
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: questionType == 'multiple' ? Colors.purple : AppTheme.border,
                                          width: questionType == 'multiple' ? 1.8 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.check_box_rounded,
                                            size: 18,
                                            color: questionType == 'multiple' ? Colors.purple : AppTheme.textMuted,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Multiple Choice',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: questionType == 'multiple' ? Colors.purple : AppTheme.mainText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            // Difficulty Level Selector
                            const Text(
                              'Difficulty Level',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.mainText),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: ['easy', 'medium', 'hard'].map((lvl) {
                                final isSel = difficulty == lvl;
                                final color = lvl == 'easy'
                                    ? AppTheme.success
                                    : (lvl == 'medium' ? Colors.orange : AppTheme.error);
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child: GestureDetector(
                                      onTap: () => setModalState(() => difficulty = lvl),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSel ? color.withValues(alpha: 0.12) : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSel ? color : AppTheme.border,
                                            width: isSel ? 1.5 : 1.0,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            lvl.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: isSel ? color : AppTheme.textMuted,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 18),

                            // Question Prompt Field
                            const Text(
                              'Question Prompt',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.mainText),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: questionTextController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'Enter question text or prompt here...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Options List Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    questionType == 'single'
                                        ? 'Answer Choices (Select 1 correct option):'
                                        : 'Answer Choices (Select ALL correct options):',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.mainText),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (optionControllers.length < 6)
                                  TextButton.icon(
                                    onPressed: () {
                                      setModalState(() {
                                        optionControllers.add(TextEditingController());
                                      });
                                    },
                                    icon: const Icon(Icons.add_rounded, size: 16),
                                    label: const Text('Add Choice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Dynamic Option Fields List
                            ...List.generate(optionControllers.length, (index) {
                              final isCorrect = selectedCorrectIndices.contains(index);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isCorrect
                                        ? AppTheme.success.withValues(alpha: 0.06)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isCorrect ? AppTheme.success : AppTheme.border,
                                      width: isCorrect ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      if (questionType == 'single')
                                        Radio<int>(
                                          value: index,
                                          groupValue: selectedCorrectIndices.isNotEmpty
                                              ? selectedCorrectIndices.first
                                              : 0,
                                          activeColor: AppTheme.success,
                                          onChanged: (val) {
                                            if (val != null) {
                                              setModalState(() {
                                                selectedCorrectIndices = [val];
                                              });
                                            }
                                          },
                                        )
                                      else
                                        Checkbox(
                                          value: isCorrect,
                                          activeColor: AppTheme.success,
                                          onChanged: (val) {
                                            setModalState(() {
                                              if (val == true) {
                                                if (!selectedCorrectIndices.contains(index)) {
                                                  selectedCorrectIndices.add(index);
                                                }
                                              } else {
                                                if (selectedCorrectIndices.length > 1) {
                                                  selectedCorrectIndices.remove(index);
                                                } else {
                                                  CustomToast.show(
                                                    context,
                                                    message: 'At least 1 correct option must be selected',
                                                    type: ToastType.warning,
                                                  );
                                                }
                                              }
                                            });
                                          },
                                        ),
                                      Expanded(
                                        child: TextField(
                                          controller: optionControllers[index],
                                          decoration: InputDecoration(
                                            labelText: 'Option ${index + 1}',
                                            contentPadding:
                                                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            border: InputBorder.none,
                                          ),
                                        ),
                                      ),
                                      if (optionControllers.length > 2)
                                        IconButton(
                                          icon: Icon(Icons.delete_outline_rounded,
                                              size: 18, color: Colors.grey.shade500),
                                          onPressed: () {
                                            setModalState(() {
                                              optionControllers.removeAt(index);
                                              selectedCorrectIndices.remove(index);
                                              selectedCorrectIndices = selectedCorrectIndices
                                                  .map((i) => i > index ? i - 1 : i)
                                                  .toList();
                                              if (selectedCorrectIndices.isEmpty) {
                                                selectedCorrectIndices.add(0);
                                              }
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),

                    // Save / Update Footer Button
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppTheme.border)),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final qText = questionTextController.text.trim();
                            final opts = optionControllers.map((c) => c.text.trim()).toList();

                            if (qText.isEmpty) {
                              CustomToast.show(context, message: 'Please enter question prompt', type: ToastType.error);
                              return;
                            }
                            if (opts.any((o) => o.isEmpty)) {
                              CustomToast.show(context, message: 'Please fill in all options', type: ToastType.error);
                              return;
                            }
                            if (selectedCorrectIndices.isEmpty) {
                              CustomToast.show(context, message: 'Please select at least 1 correct option', type: ToastType.error);
                              return;
                            }

                            dynamic correctOptionPayload;
                            if (questionType == 'single') {
                              correctOptionPayload = opts[selectedCorrectIndices.first];
                            } else {
                              correctOptionPayload =
                                  selectedCorrectIndices.map((i) => opts[i]).toList();
                            }

                            Map<String, dynamic> res;
                            if (isEdit && questionId != null) {
                              res = await ApiService.updateQuestion(
                                questionId: int.parse(questionId.toString()),
                                question: qText,
                                type: questionType,
                                difficulty: difficulty,
                                options: opts,
                                correctOption: correctOptionPayload,
                              );
                            } else {
                              res = await ApiService.addQuestionToQuiz(
                                quizId: int.parse(_quizData['id'].toString()),
                                question: qText,
                                type: questionType,
                                difficulty: difficulty,
                                options: opts,
                                correctOption: correctOptionPayload,
                              );
                            }

                            if (mounted) {
                              if (res['success'] == true) {
                                if (modalCtx.mounted) Navigator.pop(modalCtx);
                                CustomToast.show(
                                  context,
                                  message: isEdit ? 'Question updated successfully!' : 'Question added successfully!',
                                  type: ToastType.success,
                                );
                                _loadQuizQuestions();
                              } else {
                                CustomToast.show(
                                  context,
                                  message: res['message'] ?? 'Failed to save question',
                                  type: ToastType.error,
                                );
                              }
                            }
                          },
                          icon: Icon(isEdit ? Icons.save_rounded : Icons.check_circle_rounded, size: 20),
                          label: Text(
                            isEdit ? 'Update Question' : 'Save Question',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Handle CSV Import
  Future<void> _handleCsvImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final quizId = int.parse(_quizData['id'].toString());

        if (mounted) {
          CustomToast.show(context, message: 'Uploading and parsing CSV...', type: ToastType.info);
        }

        final res = await ApiService.importQuestionsCsv(
          quizId: quizId,
          filePath: file.path,
          bytes: file.bytes,
          filename: file.name,
        );

        if (mounted) {
          if (res['success'] == true) {
            CustomToast.show(context, message: res['message'] ?? 'CSV Questions Imported Successfully!', type: ToastType.success);
            _loadQuizQuestions();
          } else {
            CustomToast.show(context, message: res['message'] ?? 'Failed to import CSV', type: ToastType.error);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, message: 'File picking error: $e', type: ToastType.error);
      }
    }
  }

  // Show Sample CSV Template Modal
  void _showCsvTemplateModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.file_present_rounded, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CSV Questions Template',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.mainText),
                      ),
                      Text(
                        'Matches Admin Panel & Backend format',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    _sampleCsvTemplate,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.greenAccent,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Columns Explanation:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.mainText),
              ),
              const SizedBox(height: 6),
              const Text(
                '• Question: Question prompt text\n'
                '• Type: "single" or "multiple"\n'
                '• Difficulty: "easy", "medium", or "hard"\n'
                '• Option1..Option4: Choice options\n'
                '• Correct_Option: Option text or 1-based index (for multiple choice, separate with | pipe, e.g. 2|4)',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _sampleCsvTemplate));
                        Navigator.pop(sheetCtx);
                        CustomToast.show(context, message: 'CSV Template Copied to Clipboard!', type: ToastType.success);
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy Template', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _handleCsvImport();
                      },
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: const Text('Upload CSV File', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Delete question handler
  Future<void> _handleDeleteQuestion(Map<String, dynamic> question) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Question'),
        content: Text('Are you sure you want to delete this question?\n\n"${question['question']}"'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true && question['id'] != null) {
      final qId = int.parse(question['id'].toString());
      final ok = await ApiService.deleteQuestion(qId);
      if (ok && mounted) {
        CustomToast.show(context, message: 'Question deleted', type: ToastType.info);
        _loadQuizQuestions();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String quizTitle = _quizData['title'] ?? 'Quiz Questions';
    final String subject = _quizData['subject'] ?? 'General';
    final int duration = _quizData['duration_minutes'] ?? 15;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.mainText),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quizTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.mainText),
            ),
            Text(
              '$subject  •  $duration mins',
              style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.mainText),
            onPressed: _loadQuizQuestions,
            tooltip: 'Reload Questions',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                // Top Header Controls & Action Tools Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Question Count Metrics Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              label: 'Total Questions',
                              value: '${_questions.length}',
                              icon: Icons.format_list_bulleted_rounded,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricTile(
                              label: 'Single Choice',
                              value: '$_singleChoiceCount',
                              icon: Icons.radio_button_checked_rounded,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricTile(
                              label: 'Multiple Choice',
                              value: '$_multipleChoiceCount',
                              icon: Icons.check_box_rounded,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Action Buttons Row (Add Question, Import CSV, CSV Template)
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () => _openQuestionEditorModal(),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add Question', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: OutlinedButton.icon(
                              onPressed: _handleCsvImport,
                              icon: const Icon(Icons.upload_file_rounded, size: 18),
                              label: const Text('Import CSV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                side: const BorderSide(color: AppTheme.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _showCsvTemplateModal,
                            icon: const Icon(Icons.description_outlined, color: AppTheme.primary),
                            tooltip: 'Sample CSV Template',
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Search Bar Field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search questions...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                  ),
                ),

                // Question Cards List View
                Expanded(
                  child: _filteredQuestions.isEmpty
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            margin: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.help_outline_rounded, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty ? 'No Matching Questions Found' : 'No Questions Added Yet',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.mainText),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Try searching with different keywords.'
                                      : 'Click "Add Question" or "Import CSV" above to populate this quiz.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _filteredQuestions.length,
                          itemBuilder: (ctx, index) {
                            final question = _filteredQuestions[index];
                            return _buildQuestionCard(question, index + 1);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, int number) {
    final String type = (question['type'] ?? 'single').toString().toLowerCase();
    final bool isMultiple = type == 'multiple';
    final String difficulty = (question['difficulty'] ?? 'easy').toString().toUpperCase();

    List<dynamic> options = [];
    if (question['options'] is List) {
      options = question['options'] as List;
    }

    final rawCorrect = question['correct_option'];
    List<String> correctAnswersList = [];
    if (rawCorrect is List) {
      correctAnswersList = rawCorrect.map((e) => e.toString()).toList();
    } else if (rawCorrect != null) {
      correctAnswersList = [rawCorrect.toString()];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: Question Number, Type Badge, Difficulty Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Q#$number',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isMultiple ? Colors.purple.withValues(alpha: 0.12) : AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isMultiple ? Icons.check_box_rounded : Icons.radio_button_checked_rounded,
                      size: 13,
                      color: isMultiple ? Colors.purple : AppTheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isMultiple ? 'MULTIPLE CHOICE' : 'SINGLE CHOICE',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isMultiple ? Colors.purple : AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: difficulty == 'EASY'
                      ? AppTheme.success.withValues(alpha: 0.12)
                      : (difficulty == 'MEDIUM' ? Colors.orange.withValues(alpha: 0.12) : AppTheme.error.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  difficulty,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: difficulty == 'EASY'
                        ? AppTheme.success
                        : (difficulty == 'MEDIUM' ? Colors.orange : AppTheme.error),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Question Prompt
          Text(
            question['question'] ?? 'Question Prompt',
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.mainText,
              height: 1.35,
            ),
          ),

          const SizedBox(height: 12),

          // Options List
          ...List.generate(options.length, (optIdx) {
            final optStr = options[optIdx].toString();
            final isCorrect = correctAnswersList.contains(optStr) ||
                correctAnswersList.contains('${optIdx + 1}') ||
                (correctAnswersList.length == 1 && correctAnswersList.first == '$optIdx');

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCorrect ? AppTheme.success.withValues(alpha: 0.08) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCorrect ? AppTheme.success : Colors.grey.shade200,
                  width: isCorrect ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCorrect
                        ? Icons.check_circle_rounded
                        : (isMultiple ? Icons.check_box_outline_blank_rounded : Icons.radio_button_unchecked_rounded),
                    size: 16,
                    color: isCorrect ? AppTheme.success : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      optStr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                        color: isCorrect ? AppTheme.mainText : Colors.grey.shade800,
                      ),
                    ),
                  ),
                  if (isCorrect)
                    const Text(
                      'Correct',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.success),
                    ),
                ],
              ),
            );
          }),

          const Divider(height: 20),

          // Action Buttons: Edit & Delete
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openQuestionEditorModal(existingQuestion: question),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                tooltip: 'Delete Question',
                onPressed: () => _handleDeleteQuestion(question),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
