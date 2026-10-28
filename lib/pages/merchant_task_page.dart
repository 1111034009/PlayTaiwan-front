import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../core/app_notice.dart';
import '../core/app_colors.dart';
import '../core/app_session.dart';
import '../core/app_text_styles.dart';

const Color _pageColor = AppColors.background;
const Color _cardColor = AppColors.merchantPaper;
const Color _paperColor = AppColors.paper;
const Color _textColor = AppColors.textPrimary;
const Color _primaryColor = AppColors.primaryDark;
const Color _accentColor = AppColors.primaryAccent;
const Color _borderColor = Colors.black;

class MerchantTaskPage extends StatefulWidget {
  const MerchantTaskPage({super.key});

  @override
  State<MerchantTaskPage> createState() => _MerchantTaskPageState();
}

class _MerchantTaskPageState extends State<MerchantTaskPage> {
  final String _apiBaseUrl =
      (dotenv.env['API_BASE_URL'] ?? 'https://backend.angelalala.com')
          .trim()
          .replaceFirst(RegExp(r'/$'), '');

  List<_MerchantQuestion> _questions = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;
  String? _errorMessage;

  bool get _isBusy => _isSaving || _isDeleting;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _pageColor,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _pageColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _loadQuestions();
  }

  String _getToken() {
    final token = AppSession.token;

    if (token == null || token.isEmpty) {
      throw Exception('登入狀態已失效，請重新登入');
    }

    return token;
  }

  Map<String, String> _headers({bool jsonContent = false}) {
    return {
      'accept': '*/*',
      'Authorization': 'Bearer ${_getToken()}',
      if (jsonContent) 'Content-Type': 'application/json',
    };
  }

  Uri _questionsUri() => Uri.parse('$_apiBaseUrl/api/merchant/questions');

  Uri _questionUri(int questionId) =>
      Uri.parse('$_apiBaseUrl/api/merchant/questions/$questionId');

  Uri get _uploadUri => Uri.parse('$_apiBaseUrl/api/Upload');

  dynamic _decodeResponse(http.Response response) {
    if (response.body.trim().isEmpty) return null;

    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw Exception('伺服器回傳的資料格式錯誤');
    }
  }

  dynamic _tryDecode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  void _checkResponse(http.Response response, {bool allowEmptyBody = false}) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = _tryDecode(response);
      final message = decoded is Map ? decoded['message']?.toString() : null;

      throw Exception(
        message?.isNotEmpty == true
            ? message
            : '操作失敗（HTTP ${response.statusCode}）',
      );
    }

    if (response.body.trim().isEmpty && allowEmptyBody) return;

    final decoded = _decodeResponse(response);

    if (decoded is Map && decoded['isSuccess'] == false) {
      throw Exception(decoded['message']?.toString() ?? '操作失敗，請稍後再試');
    }
  }

  List<dynamic> _extractQuestionList(dynamic decoded) {
    if (decoded is List) return decoded;

    if (decoded is! Map) {
      throw Exception('題目資料格式錯誤');
    }

    if (decoded['isSuccess'] == false) {
      throw Exception(decoded['message']?.toString() ?? '查詢題目失敗');
    }

    final result =
        decoded['Result'] ??
        decoded['result'] ??
        decoded['data'] ??
        decoded['Data'];

    if (result is List) return result;
    if (result == null) return [];

    throw Exception('題目清單格式錯誤');
  }

  List<_QuestionOption> _parseOptions(dynamic rawOptions) {
    if (rawOptions is! List) return [];

    return rawOptions.whereType<Map>().map((item) {
      final correctValue = item['is_correct'] ?? item['Is_Correct'];

      return _QuestionOption(
        optionContext:
            item['option_context']?.toString() ??
            item['Option_Context']?.toString() ??
            '',
        optionUrl:
            item['option_url']?.toString() ??
            item['Option_Url']?.toString() ??
            '',
        isCorrect:
            correctValue == true ||
            correctValue == 1 ||
            correctValue?.toString() == '1' ||
            correctValue?.toString().toLowerCase() == 'true',
        optionKey:
            item['option_key']?.toString() ??
            item['Option_Key']?.toString() ??
            '',
      );
    }).toList();
  }

  Future<void> _loadQuestions() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .get(_questionsUri(), headers: _headers())
          .timeout(const Duration(seconds: 20));

      _checkResponse(response);

      final rawQuestions = _extractQuestionList(_decodeResponse(response));

      final loadedQuestions =
          rawQuestions
              .whereType<Map>()
              .map((item) {
                final rawId =
                    item['question_id'] ??
                    item['Question_ID'] ??
                    item['questionId'] ??
                    item['id'];

                return _MerchantQuestion(
                  id: int.tryParse(rawId?.toString() ?? '') ?? 0,
                  description:
                      item['question_describe']?.toString() ??
                      item['Question_Describe']?.toString() ??
                      item['questionDescribe']?.toString() ??
                      '',
                  options: _parseOptions(
                    item['options'] ??
                        item['Options'] ??
                        item['question_options'] ??
                        item['Question_Options'],
                  ),
                );
              })
              .where((question) => question.id > 0)
              .toList()
            ..sort((a, b) => b.id.compareTo(a.id));

      if (!mounted) return;

      setState(() {
        _questions = loadedQuestions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _errorText(e);
      });
    }
  }

  String _errorText(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    AppNotice.show(message);
  }

  Future<void> _openQuestionForm({_MerchantQuestion? question}) async {
    if (_isBusy) return;

    final result = await showDialog<_QuestionFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QuestionFormDialog(
        question: question,
        uploadUri: _uploadUri,
        getToken: _getToken,
      ),
    );

    if (!mounted || result == null) return;

    await _saveQuestion(result, question: question);
  }

  Future<void> _saveQuestion(
    _QuestionFormResult form, {
    _MerchantQuestion? question,
  }) async {
    if (_isBusy) return;

    setState(() => _isSaving = true);

    try {
      final body = {
        'question_describe': form.description.trim(),
        'options': form.options
            .asMap()
            .entries
            .map(
              (entry) => {
                'option_context': entry.value.optionContext.trim(),
                'option_url': entry.value.optionUrl.trim(),
                'is_correct': entry.value.isCorrect,
                'option_key': String.fromCharCode(97 + entry.key),
              },
            )
            .toList(),
      };

      final response = question == null
          ? await http
                .post(
                  _questionsUri(),
                  headers: _headers(jsonContent: true),
                  body: jsonEncode(body),
                )
                .timeout(const Duration(seconds: 20))
          : await http
                .put(
                  _questionUri(question.id),
                  headers: _headers(jsonContent: true),
                  body: jsonEncode(body),
                )
                .timeout(const Duration(seconds: 20));

      _checkResponse(response);

      if (!mounted) return;

      _showMessage(question == null ? '題目新增成功' : '題目修改成功');
      await _loadQuestions();
    } catch (e) {
      if (!mounted) return;
      _showMessage(_errorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteQuestion(_MerchantQuestion question) async {
    if (_isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: _borderColor, width: 1.2),
          ),
          title: Text(
            '刪除題目',
            style: AppTextStyles.sectionTitle.copyWith(color: _textColor),
          ),
          content: Text(
            '確定要刪除這道題目嗎？刪除後無法復原。',
            style: AppTextStyles.body.copyWith(color: _textColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                '取消',
                style: AppTextStyles.bodySmallBold.copyWith(color: _textColor),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                '刪除',
                style: AppTextStyles.bodySmallBold.copyWith(
                  color: AppColors.dangerDark,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      final response = await http
          .delete(_questionUri(question.id), headers: _headers())
          .timeout(const Duration(seconds: 20));

      _checkResponse(response, allowEmptyBody: true);

      if (!mounted) return;

      _showMessage('題目已刪除');
      await _loadQuestions();
    } catch (e) {
      if (!mounted) return;
      _showMessage(_errorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      appBar: AppBar(
        backgroundColor: _pageColor,
        foregroundColor: _textColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '題庫管理',
          style: AppTextStyles.title.copyWith(color: _textColor),
        ),
        actions: [
          IconButton(
            tooltip: '重新載入',
            onPressed: _isBusy || _isLoading ? null : _loadQuestions,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                  child: _buildHeaderCard(),
                ),
                Expanded(child: _buildQuestionList()),
              ],
            ),
            if (_isBusy)
              Positioned.fill(
                child: AbsorbPointer(
                  child: Container(
                    color: Colors.black.withOpacity(0.12),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _borderColor, width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 23,
                              height: 23,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: _primaryColor,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              _isSaving ? '正在儲存題目…' : '正在刪除題目…',
                              style: AppTextStyles.bodySmallBold.copyWith(
                                color: _textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isBusy ? null : () => _openQuestionForm(),
        backgroundColor: _accentColor,
        foregroundColor: _cardColor,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          '新增題目',
          style: AppTextStyles.button.copyWith(color: _cardColor),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor, width: 1.2),
        boxShadow: const [
          BoxShadow(color: _textColor, offset: Offset(2, 3), blurRadius: 0),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: _borderColor),
            ),
            child: const Icon(
              Icons.quiz_outlined,
              color: _primaryColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '目前您的題目數： ${_questions.length}',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: _textColor.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: _primaryColor,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: _primaryColor,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: _textColor),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _loadQuestions,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  '重新載入',
                  style: AppTextStyles.bodySmallBold.copyWith(
                    color: _textColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textColor,
                  side: const BorderSide(color: _borderColor),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: _cardColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: _borderColor, width: 1.2),
                ),
                child: const Icon(
                  Icons.quiz_outlined,
                  size: 40,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '目前沒有題目',
                style: AppTextStyles.title.copyWith(color: _textColor),
              ),
              const SizedBox(height: 8),
              Text(
                '點選下方「新增題目」，建立店家知識問答。',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(color: _textColor),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQuestions,
      color: _primaryColor,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
        itemCount: _questions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 13),
        itemBuilder: (context, index) {
          final question = _questions[index];

          return _QuestionCard(
            question: question,
            index: index + 1,
            onEdit: () => _openQuestionForm(question: question),
            onDelete: () => _deleteQuestion(question),
          );
        },
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final _MerchantQuestion question;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuestionCard({
    required this.question,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _borderColor, width: 1.2),
        boxShadow: const [
          BoxShadow(color: _textColor, offset: Offset(2, 3), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 35,
                height: 35,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: _borderColor),
                ),
                child: Text(
                  '$index',
                  style: AppTextStyles.bodySmallBold.copyWith(
                    color: _primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    question.description.isEmpty
                        ? '未填寫題目內容'
                        : question.description,
                    style: AppTextStyles.bodyBold.copyWith(color: _textColor),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '題目操作',
                icon: const Icon(Icons.more_vert_rounded, color: _textColor),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_outlined,
                          size: 19,
                          color: _textColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '編輯題目',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: _textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                          color: AppColors.dangerDark,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '刪除題目',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.dangerDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: _borderColor.withOpacity(0.18)),
          const SizedBox(height: 10),
          _QuestionMeta(
            icon: Icons.list_alt_rounded,
            label: '選項 ${question.options.length} 個',
          ),
          if (question.options.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (int i = 0; i < question.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      question.options[i].isCorrect
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 17,
                      color: question.options[i].isCorrect
                          ? _primaryColor
                          : _textColor.withOpacity(0.55),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${String.fromCharCode(65 + i)}. ${question.options[i].optionContext}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: _textColor,
                            ),
                          ),
                          if (question.options[i].optionUrl
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                question.options[i].optionUrl,
                                width: 150,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      width: 150,
                                      height: 70,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _paperColor,
                                        border: Border.all(
                                          color: _borderColor.withOpacity(0.25),
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: _textColor.withOpacity(0.55),
                                      ),
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _QuestionMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _QuestionMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: _primaryColor),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTextStyles.captionBold.copyWith(color: _textColor),
        ),
      ],
    );
  }
}

class _QuestionFormDialog extends StatefulWidget {
  final _MerchantQuestion? question;
  final Uri uploadUri;
  final String Function() getToken;

  const _QuestionFormDialog({
    this.question,
    required this.uploadUri,
    required this.getToken,
  });

  @override
  State<_QuestionFormDialog> createState() => _QuestionFormDialogState();
}

class _QuestionFormDialogState extends State<_QuestionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _descriptionController;
  late List<_OptionFormData> _options;

  String? _validationMessage;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();

    _descriptionController = TextEditingController(
      text: widget.question?.description ?? '',
    );

    if (widget.question != null && widget.question!.options.isNotEmpty) {
      _options = widget.question!.options
          .map(
            (option) => _OptionFormData(
              optionContext: option.optionContext,
              optionUrl: option.optionUrl,
              optionKey: option.optionKey,
              isCorrect: option.isCorrect,
            ),
          )
          .toList();
    } else {
      _options = [_OptionFormData(), _OptionFormData()];
    }

    for (int i = 0; i < _options.length; i++) {
      _options[i].keyController.text = String.fromCharCode(97 + i);
    }

    if (!_options.any((option) => option.isCorrect)) {
      _options.first.isCorrect = true;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    for (final option in _options) {
      option.dispose();
    }
    super.dispose();
  }

  Future<void> _uploadOptionImage(int index) async {
    if (_isUploadingImage) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (!mounted || image == null) return;

      setState(() {
        _isUploadingImage = true;
        _validationMessage = null;
      });

      final request = http.MultipartRequest('POST', widget.uploadUri);
      request.headers.addAll({
        'accept': 'text/plain',
        'Authorization': 'Bearer ${widget.getToken()}',
      });
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          image.path,
          filename: image.name,
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        dynamic decoded;
        try {
          decoded = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {
          decoded = null;
        }

        final message = decoded is Map ? decoded['message']?.toString() : null;

        throw Exception(
          message?.isNotEmpty == true
              ? message
              : '圖片上傳失敗（HTTP ${response.statusCode}）',
        );
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        throw Exception('圖片上傳回傳格式錯誤');
      }

      if (decoded is! Map || decoded['isSuccess'] != true) {
        throw Exception(
          decoded is Map
              ? decoded['message']?.toString() ?? '圖片上傳失敗'
              : '圖片上傳失敗',
        );
      }

      final imageUrl = decoded['Result']?.toString().trim() ?? '';

      if (imageUrl.isEmpty) {
        throw Exception('圖片上傳成功，但沒有取得圖片網址');
      }

      if (!mounted) return;

      setState(() {
        _options[index].urlController.text = imageUrl;
      });

      AppNotice.show('圖片上傳成功');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _validationMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _addOption() {
    if (_options.length >= 8) {
      setState(() => _validationMessage = '最多只能新增 8 個選項');
      return;
    }

    setState(() {
      _options.add(
        _OptionFormData(optionKey: String.fromCharCode(97 + _options.length)),
      );
      _validationMessage = null;
    });
  }

  void _removeOption(int index) {
    if (_options.length <= 2) {
      setState(() => _validationMessage = '至少需要 2 個選項');
      return;
    }

    setState(() {
      final removed = _options.removeAt(index);
      removed.dispose();

      for (int i = 0; i < _options.length; i++) {
        _options[i].keyController.text = String.fromCharCode(97 + i);
      }

      if (!_options.any((option) => option.isCorrect)) {
        _options.first.isCorrect = true;
      }

      _validationMessage = null;
    });
  }

  void _setCorrectOption(int index, bool value) {
    setState(() {
      if (value) {
        for (int i = 0; i < _options.length; i++) {
          _options[i].isCorrect = i == index;
        }
      } else {
        _options[index].isCorrect = false;

        if (!_options.any((option) => option.isCorrect)) {
          _options[index].isCorrect = true;
        }
      }

      _validationMessage = null;
    });
  }

  void _submit() {
    FocusScope.of(context).unfocus();

    if (_isUploadingImage) {
      setState(() => _validationMessage = '請等待圖片上傳完成');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_options.length < 2) {
      setState(() => _validationMessage = '請至少新增 2 個選項');
      return;
    }

    if (!_options.any((option) => option.isCorrect)) {
      setState(() => _validationMessage = '請設定至少一個正確答案');
      return;
    }

    final options = _options
        .asMap()
        .entries
        .map(
          (entry) => _QuestionOption(
            optionContext: entry.value.contextController.text.trim(),
            optionUrl: entry.value.urlController.text.trim(),
            isCorrect: entry.value.isCorrect,
            optionKey: String.fromCharCode(97 + entry.key),
          ),
        )
        .toList();

    Navigator.of(context).pop(
      _QuestionFormResult(
        description: _descriptionController.text.trim(),
        options: options,
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: AppTextStyles.bodySmall.copyWith(color: _textColor),
      hintStyle: AppTextStyles.caption.copyWith(
        color: _textColor.withOpacity(0.55),
      ),
      filled: true,
      fillColor: _paperColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(color: _borderColor.withOpacity(0.65)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(5)),
        borderSide: BorderSide(color: _primaryColor, width: 1.6),
      ),
      errorStyle: AppTextStyles.caption.copyWith(color: AppColors.dangerDark),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.question != null;

    return Dialog(
      backgroundColor: _cardColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: const BorderSide(color: _borderColor, width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEditing ? '編輯題目' : '新增題目',
                        style: AppTextStyles.title.copyWith(color: _textColor),
                      ),
                    ),
                    IconButton(
                      tooltip: '關閉',
                      onPressed: _isUploadingImage
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: _textColor),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: _borderColor.withOpacity(0.2)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  children: [
                    Text(
                      '題目內容',
                      style: AppTextStyles.bodyBold.copyWith(color: _textColor),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      minLines: 2,
                      maxLength: 500,
                      style: AppTextStyles.body.copyWith(color: _textColor),
                      decoration: _inputDecoration(
                        label: '題目描述',
                        hint: '輸入店家知識問答的題目',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '請輸入題目內容';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '題目選項',
                            style: AppTextStyles.bodyBold.copyWith(
                              color: _textColor,
                            ),
                          ),
                        ),
                        Text(
                          '${_options.length}/8',
                          style: AppTextStyles.captionBold.copyWith(
                            color: _primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '請至少設定 2 個選項，並選擇一個正確答案。',
                      style: AppTextStyles.caption.copyWith(color: _textColor),
                    ),
                    const SizedBox(height: 12),
                    for (int i = 0; i < _options.length; i++)
                      _buildOptionForm(i),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _isUploadingImage ? null : _addOption,
                        icon: const Icon(Icons.add_rounded, size: 19),
                        label: Text(
                          '新增選項',
                          style: AppTextStyles.bodySmallBold.copyWith(
                            color: _textColor,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textColor,
                          side: const BorderSide(color: _borderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                    if (_validationMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _validationMessage!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.dangerDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(height: 1, color: _borderColor.withOpacity(0.2)),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isUploadingImage
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: _borderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: Text(
                          '取消',
                          style: AppTextStyles.button.copyWith(
                            color: _textColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isUploadingImage ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: _cardColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                            side: const BorderSide(color: _borderColor),
                          ),
                        ),
                        child: Text(
                          isEditing ? '儲存' : '新增',
                          style: AppTextStyles.button.copyWith(
                            color: _cardColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionForm(int index) {
    final option = _options[index];
    final imageUrl = option.urlController.text.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _paperColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: option.isCorrect ? _primaryColor : _borderColor,
          width: option.isCorrect ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '選項 ${String.fromCharCode(65 + index)}',
                  style: AppTextStyles.bodySmallBold.copyWith(
                    color: _textColor,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isUploadingImage
                    ? null
                    : () => _uploadOptionImage(index),
                icon: const Icon(Icons.image_outlined, size: 17),
                label: Text(
                  imageUrl.isEmpty ? '上傳' : '更換',
                  style: AppTextStyles.captionBold.copyWith(color: _textColor),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: const BorderSide(color: _borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              IconButton(
                tooltip: '移除此選項',
                visualDensity: VisualDensity.compact,
                onPressed: _isUploadingImage
                    ? null
                    : () => _removeOption(index),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.dangerDark,
                  size: 21,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Checkbox(
                value: option.isCorrect,
                activeColor: _primaryColor,
                onChanged: _isUploadingImage
                    ? null
                    : (value) => _setCorrectOption(index, value ?? false),
              ),
              GestureDetector(
                onTap: _isUploadingImage
                    ? null
                    : () => _setCorrectOption(index, true),
                child: Text(
                  '正確答案',
                  style: AppTextStyles.captionBold.copyWith(
                    color: option.isCorrect ? _primaryColor : _textColor,
                  ),
                ),
              ),
            ],
          ),
          TextFormField(
            controller: option.contextController,
            maxLines: 2,
            minLines: 1,
            maxLength: 300,
            style: AppTextStyles.bodySmall.copyWith(color: _textColor),
            decoration: _inputDecoration(label: '選項內容', hint: '輸入選項文字'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '請輸入選項內容';
              }
              return null;
            },
          ),
          if (imageUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 150,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 80,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _cardColor,
                    border: Border.all(color: _borderColor.withOpacity(0.25)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '圖片載入失敗',
                    style: AppTextStyles.caption.copyWith(color: _textColor),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MerchantQuestion {
  final int id;
  final String description;
  final List<_QuestionOption> options;

  const _MerchantQuestion({
    required this.id,
    required this.description,
    required this.options,
  });
}

class _QuestionOption {
  final String optionContext;
  final String optionUrl;
  final bool isCorrect;
  final String optionKey;

  const _QuestionOption({
    required this.optionContext,
    required this.optionUrl,
    required this.isCorrect,
    required this.optionKey,
  });
}

class _QuestionFormResult {
  final String description;
  final List<_QuestionOption> options;

  const _QuestionFormResult({required this.description, required this.options});
}

class _OptionFormData {
  final TextEditingController contextController;
  final TextEditingController urlController;
  final TextEditingController keyController;
  bool isCorrect;

  _OptionFormData({
    String optionContext = '',
    String optionUrl = '',
    String optionKey = '',
    this.isCorrect = false,
  }) : contextController = TextEditingController(text: optionContext),
       urlController = TextEditingController(text: optionUrl),
       keyController = TextEditingController(text: optionKey);

  void dispose() {
    contextController.dispose();
    urlController.dispose();
    keyController.dispose();
  }
}
