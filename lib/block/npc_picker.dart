import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/story_api.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

Future<void> showNpcPicker(BuildContext context) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  if (!context.mounted) return;

  String selected = prefs.getString('selected_npc') ?? '';

  final Future<List<Map<String, dynamic>>> future = StoryApi.getNpcOptions();

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.paper,
    isScrollControlled: true,
    builder: (sheet) => StatefulBuilder(
      builder: (context, setSheet) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '${snapshot.error}'.replaceFirst('Exception: ', ''),
                      style: AppTextStyles.bodySmallBold,
                    ),
                  );
                }

                final List<Map<String, dynamic>> options = snapshot.data ?? [];

                Future<void> choose(String value) async {
                  await prefs.setString('selected_npc', value);
                  setSheet(() => selected = value);
                  if (sheet.mounted) Navigator.of(sheet).pop();
                }

                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    ListTile(
                      title: Text(
                        '依劇情角色',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      trailing: selected.isEmpty
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () => choose(''),
                    ),
                    for (final Map<String, dynamic> npc in options)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.background,
                          backgroundImage:
                              (npc['avatar_url']?.toString() ?? '').isEmpty
                              ? null
                              : NetworkImage(npc['avatar_url'].toString()),
                        ),
                        title: Text(
                          npc['label']?.toString() ?? '',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          npc['description']?.toString() ?? '',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        trailing: selected == npc['value']?.toString()
                            ? const Icon(Icons.check, color: AppColors.primary)
                            : null,
                        onTap: () => choose(npc['value']?.toString() ?? ''),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    ),
  );
}
