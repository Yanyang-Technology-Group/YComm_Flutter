import '../../core/design/adaptive.dart';

import 'package:flutter/material.dart';

import '../../core/network/community_api.dart';
import '../../core/widgets/design.dart';

class ResourceTile extends StatelessWidget {
  const ResourceTile(this.resource, {super.key, required this.onTap});
  final Json resource;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    if (isApple(context)) {
      final scheme = Theme.of(context).colorScheme;
      return AppTap(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 52,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: AppIcon(
                      Icons.insert_drive_file_outlined,
                      size: 28,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarkdownText(
                          str(resource['title']),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (str(resource['summary']).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          MarkdownText(
                            str(resource['summary']),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (str(resource['versionLabel']).isNotEmpty)
                              Text(
                                str(resource['versionLabel']),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            Text(
                              '${resource['downloadCount'] ?? 0} 次下载',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              dateLabel(
                                resource['publishedAt'] ??
                                    resource['createdAt'],
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: AppIcon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 76),
              child: AppDivider(),
            ),
          ],
        ),
      );
    }
    return AppSurface(
      color: Colors.transparent,
      child: AppTap(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppIcon(
                    Icons.inventory_2_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MarkdownText(
                      str(resource['title']),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const AppIcon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
              if (str(resource['summary']).isNotEmpty) ...[
                const SizedBox(height: 10),
                MarkdownText(
                  str(resource['summary']),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (str(resource['versionLabel']).isNotEmpty)
                    Text(
                      str(resource['versionLabel']),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  Text(
                    '${resource['downloadCount'] ?? 0} 次下载',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    dateLabel(resource['publishedAt'] ?? resource['createdAt']),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const AppDivider(),
            ],
          ),
        ),
      ),
    );
  }
}
