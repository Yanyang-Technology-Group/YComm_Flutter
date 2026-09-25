import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as m;

import 'apple_chrome.dart';

/// Explicit semantic equivalents, with no Material font fallback in Apple UI.
IconData appleIconData(IconData icon) {
  if (icon.fontFamily != 'MaterialIcons') return icon;
  final mapped = _appleIcons[icon];
  assert(mapped != null, 'Missing Apple icon mapping: $icon');
  return mapped ?? CupertinoIcons.question_circle;
}

final _appleIcons = <IconData, IconData>{
  m.Icons.add: CupertinoIcons.plus,
  m.Icons.admin_panel_settings_outlined: CupertinoIcons.person_badge_plus,
  m.Icons.android_outlined: CupertinoIcons.device_phone_portrait,
  m.Icons.api_outlined: CupertinoIcons.chevron_left_slash_chevron_right,
  m.Icons.apple: CupertinoIcons.device_laptop,
  m.Icons.archive_outlined: CupertinoIcons.archivebox,
  m.Icons.arrow_downward: CupertinoIcons.arrow_down,
  m.Icons.arrow_forward: CupertinoIcons.arrow_right,
  m.Icons.arrow_forward_rounded: CupertinoIcons.arrow_right,
  m.Icons.arrow_upward: CupertinoIcons.arrow_up,
  m.Icons.arrow_upward_rounded: CupertinoIcons.arrow_up,
  m.Icons.article_outlined: CupertinoIcons.doc_text,
  m.Icons.block_rounded: CupertinoIcons.nosign,
  m.Icons.brightness_auto_outlined: CupertinoIcons.circle_lefthalf_fill,
  m.Icons.calendar_month: CupertinoIcons.calendar,
  m.Icons.cancel_outlined: CupertinoIcons.xmark_circle,
  m.Icons.chat_bubble_outline_rounded: CupertinoIcons.chat_bubble,
  m.Icons.check_circle_outline: CupertinoIcons.check_mark_circled,
  m.Icons.check_rounded: CupertinoIcons.check_mark,
  m.Icons.chevron_right_rounded: CupertinoIcons.chevron_right,
  m.Icons.close_rounded: CupertinoIcons.xmark,
  m.Icons.cloud_off_outlined: CupertinoIcons.cloud,
  m.Icons.cloud_off_rounded: CupertinoIcons.cloud,
  m.Icons.code_rounded: CupertinoIcons.chevron_left_slash_chevron_right,
  m.Icons.confirmation_number_outlined: CupertinoIcons.ticket,
  m.Icons.copy: CupertinoIcons.doc_on_doc,
  m.Icons.copy_rounded: CupertinoIcons.doc_on_doc,
  m.Icons.crop_square_rounded: CupertinoIcons.square,
  m.Icons.dark_mode_outlined: CupertinoIcons.moon,
  m.Icons.dashboard_customize_outlined: CupertinoIcons.square_grid_2x2,
  m.Icons.dashboard_outlined: CupertinoIcons.square_grid_2x2,
  m.Icons.delete_outline: CupertinoIcons.trash,
  m.Icons.description_outlined: CupertinoIcons.doc_text,
  m.Icons.desktop_windows_outlined: CupertinoIcons.desktopcomputer,
  m.Icons.devices_outlined: CupertinoIcons.device_laptop,
  m.Icons.done_all_rounded: CupertinoIcons.checkmark_alt_circle,
  m.Icons.download_rounded: CupertinoIcons.arrow_down_to_line,
  m.Icons.edit_outlined: CupertinoIcons.pencil,
  m.Icons.error_outline: CupertinoIcons.exclamationmark_circle,
  m.Icons.fact_check_outlined: CupertinoIcons.checkmark_shield,
  m.Icons.favorite_border_rounded: CupertinoIcons.heart,
  m.Icons.favorite_rounded: CupertinoIcons.heart_fill,
  m.Icons.folder_open_rounded: CupertinoIcons.folder,
  m.Icons.forum_outlined: CupertinoIcons.chat_bubble_2,
  m.Icons.forum_rounded: CupertinoIcons.chat_bubble_2_fill,
  m.Icons.history_rounded: CupertinoIcons.clock,
  m.Icons.inbox_outlined: CupertinoIcons.tray,
  m.Icons.info_outline_rounded: CupertinoIcons.info_circle,
  m.Icons.insert_drive_file_outlined: CupertinoIcons.doc,
  m.Icons.inventory_2_outlined: CupertinoIcons.cube_box,
  m.Icons.ios_share_rounded: CupertinoIcons.share,
  m.Icons.light_mode_outlined: CupertinoIcons.sun_max,
  m.Icons.lock_open_rounded: CupertinoIcons.lock_open,
  m.Icons.lock_outline: CupertinoIcons.lock,
  m.Icons.lock_outline_rounded: CupertinoIcons.lock,
  m.Icons.login_rounded: CupertinoIcons.person_crop_circle_badge_checkmark,
  m.Icons.mail_outline_rounded: CupertinoIcons.mail,
  m.Icons.mark_chat_unread_outlined: CupertinoIcons.chat_bubble_text,
  m.Icons.mark_email_read_outlined: CupertinoIcons.envelope_open,
  m.Icons.mic_off_outlined: CupertinoIcons.mic_slash,
  m.Icons.mic_rounded: CupertinoIcons.mic,
  m.Icons.monitor_heart_outlined: CupertinoIcons.waveform_path_ecg,
  m.Icons.north_east_rounded: CupertinoIcons.arrow_up_right,
  m.Icons.notifications_active_outlined: CupertinoIcons.bell,
  m.Icons.notifications_none_rounded: CupertinoIcons.bell,
  m.Icons.notifications_rounded: CupertinoIcons.bell_fill,
  m.Icons.open_in_new: CupertinoIcons.arrow_up_right_square,
  m.Icons.open_in_new_rounded: CupertinoIcons.arrow_up_right_square,
  m.Icons.palette_outlined: CupertinoIcons.paintbrush,
  m.Icons.password_rounded: CupertinoIcons.lock_shield,
  m.Icons.people_outline: CupertinoIcons.person_2,
  m.Icons.people_outline_rounded: CupertinoIcons.person_2,
  m.Icons.person_add_alt_rounded: CupertinoIcons.person_badge_plus,
  m.Icons.person_outline: CupertinoIcons.person,
  m.Icons.person_outline_rounded: CupertinoIcons.person,
  m.Icons.person_remove_outlined: CupertinoIcons.person_badge_minus,
  m.Icons.person_rounded: CupertinoIcons.person_fill,
  m.Icons.play_arrow_rounded: CupertinoIcons.play_fill,
  m.Icons.public_rounded: CupertinoIcons.globe,
  m.Icons.refresh: CupertinoIcons.arrow_clockwise,
  m.Icons.refresh_rounded: CupertinoIcons.arrow_clockwise,
  m.Icons.remove_circle_outline: CupertinoIcons.minus_circle,
  m.Icons.remove_circle_outline_rounded: CupertinoIcons.minus_circle,
  m.Icons.remove_rounded: CupertinoIcons.minus,
  m.Icons.reply_all_rounded: CupertinoIcons.arrowshape_turn_up_left_2,
  m.Icons.reply_rounded: CupertinoIcons.arrowshape_turn_up_left,
  m.Icons.restore: CupertinoIcons.arrow_counterclockwise,
  m.Icons.search: CupertinoIcons.search,
  m.Icons.search_off_rounded: CupertinoIcons.search,
  m.Icons.search_rounded: CupertinoIcons.search,
  m.Icons.security_outlined: CupertinoIcons.shield,
  m.Icons.settings_outlined: CupertinoIcons.gear,
  m.Icons.shield_outlined: CupertinoIcons.shield,
  m.Icons.source_rounded: CupertinoIcons.folder,
  m.Icons.system_update_alt_rounded: CupertinoIcons.arrow_down_square,
  m.Icons.task_alt_rounded: CupertinoIcons.check_mark_circled,
  m.Icons.travel_explore_rounded: CupertinoIcons.globe,
  m.Icons.tune_rounded: CupertinoIcons.slider_horizontal_3,
  m.Icons.verified_user_outlined: CupertinoIcons.checkmark_shield,
  m.Icons.visibility_off_outlined: CupertinoIcons.eye_slash,
  m.Icons.visibility_outlined: CupertinoIcons.eye,
  m.Icons.vpn_key_outlined: CupertinoIcons.lock,
  m.Icons.widgets_outlined: CupertinoIcons.square_grid_2x2,
  m.Icons.widgets_rounded: CupertinoIcons.square_grid_2x2_fill,
  m.Icons.workspace_premium_outlined: CupertinoIcons.rosette,
};

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });
  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => Icon(
    icon != null && appleTokensOf(context) != null
        ? appleIconData(icon!)
        : icon,
    size: size,
    color: color,
    semanticLabel: semanticLabel,
  );
}
