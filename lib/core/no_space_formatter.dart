import 'package:flutter/services.dart';

import 'app_notice.dart';

class NoSpaceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!RegExp(r'\s').hasMatch(newValue.text)) return newValue;

    AppNotice.show('請勿輸入空格');

    final String cleaned = newValue.text.replaceAll(RegExp(r'\s'), '');
    final int offset =
        (newValue.selection.baseOffset -
                (newValue.text.length - cleaned.length))
            .clamp(0, cleaned.length);

    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
