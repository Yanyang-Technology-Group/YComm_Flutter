import '../../core/design/adaptive.dart';

import 'package:flutter/material.dart';

import '../../core/network/community_api.dart';
import '../../core/widgets/design.dart';

class ResourceTile extends StatelessWidget {
  const ResourceTile(this.resource, {super.key, required this.onTap});
  final Json resource;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AppSurface(
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
