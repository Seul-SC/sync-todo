import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';

Future<void> showAboutAppSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const AboutAppBody(),
  );
}

class AboutAppBody extends StatelessWidget {
  const AboutAppBody({super.key});

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开：$uri')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snap) {
            final version = snap.data == null
                ? ''
                : '${snap.data!.version}（${snap.data!.buildNumber}）';
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('关于同步待办', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: const Text('作者'),
                  subtitle: const Text(AppInfo.author),
                ),
                if (version.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.tag_outlined),
                    title: const Text('版本'),
                    subtitle: Text(version),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.code_outlined),
                  title: const Text('GitHub 仓库'),
                  subtitle: const Text(AppInfo.githubUrl),
                  onTap: () => _open(context, Uri.parse(AppInfo.githubUrl)),
                ),
                const SizedBox(height: 8),
                Text('遇到问题或想提建议', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('发邮件提问'),
                  subtitle: const Text(AppInfo.feedbackEmail),
                  onTap: () => _open(
                    context,
                    Uri(
                      scheme: 'mailto',
                      path: AppInfo.feedbackEmail,
                      query: 'subject=${Uri.encodeComponent('同步待办问题反馈')}',
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.forum_outlined),
                  title: const Text('在 GitHub 上留言'),
                  subtitle: const Text('打开 Issues，直接提交问题'),
                  onTap: () =>
                      _open(context, Uri.parse(AppInfo.githubIssuesUrl)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
