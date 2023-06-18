import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';

import '../../models/jellyfin_models.dart';
import '../../screens/album_screen.dart';
import '../../services/finamp_settings_helper.dart';
import '../../services/jellyfin_api_helper.dart';

final _borderRadius = BorderRadius.circular(4);

class AlbumChip extends StatelessWidget {
  const AlbumChip({
    Key? key,
    this.item,
  }) : super(key: key);

  final BaseItemDto? item;

  @override
  Widget build(BuildContext context) {
    if (item == null) return const _EmptyAlbumChip();

    return Container(
        constraints: const BoxConstraints(minWidth: 10, maxWidth: 200),
        child: _AlbumChipContent(item: item!));
  }
}

class _EmptyAlbumChip extends StatelessWidget {
  const _EmptyAlbumChip({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 20,
      child: Material(
        borderRadius: _borderRadius,
      ),
    );
  }
}

class _AlbumChipContent extends StatelessWidget {
  const _AlbumChipContent({
    Key? key,
    required this.item,
  }) : super(key: key);

  final BaseItemDto item;

  @override
  Widget build(BuildContext context) {
    final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

    return Material(
      borderRadius: _borderRadius,
      child: InkWell(
        borderRadius: _borderRadius,
        onTap: FinampSettingsHelper.finampSettings.isOffline
            ? null
            // getItemById doesn't work in offline mode so we disable it.
            : () => jellyfinApiHelper.getItemById(item.albumId!).then((album) =>
                Navigator.of(context)
                    .popAndPushNamed(AlbumScreen.routeName, arguments: album)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: Text(
            item.album ?? AppLocalizations.of(context)!.noAlbum,
            overflow: TextOverflow.fade,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}
