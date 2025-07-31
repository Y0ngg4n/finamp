import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:finamp/components/PlayerScreen/queue_source_helper.dart';
import 'package:finamp/models/finamp_models.dart';

class ShuffleFromHereMenuEntry extends ConsumerWidget
    implements HideableMenuEntry {
  final BaseItemDto baseItem;
  BaseItemDto? parentItem;

  ShuffleFromHereMenuEntry({
    super.key,
    required this.baseItem,
    this.parentItem,
  });

  final _queueService = GetIt.instance<QueueService>();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Visibility(
      visible: !ref.watch(finampSettingsProvider.isOffline),
      child: MenuEntry(
        icon: TablerIcons.arrows_shuffle,
        title: AppLocalizations.of(context)!.shuffleFromHere,
        onTap: () async {
          Navigator.pop(context); // close menu
          _queueService.startPlayback(items: items, source: source);

          _queueService.startPlayback(
            items: items,
            source: QueueItemSource(
              type: QueueItemSourceType.artist,
              name: QueueItemSourceName(
                type: QueueItemSourceNameType.preTranslated,
                pretranslatedName:
                    parentItem.name ??
                    AppLocalizations.of(context)!.placeholderSource,
              ),
              id: parentItem.id,
              item: parentItem,
            ),
            order: FinampPlaybackOrder.shuffled,
          );
        },
      ),
    );
  }

  @override
  bool get isVisible => !FinampSettingsHelper.finampSettings.isOffline;
}
