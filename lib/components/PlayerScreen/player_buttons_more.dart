import 'package:audio_service/audio_service.dart';
import 'package:finamp/components/AlbumScreen/song_menu.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/screens/add_to_playlist_screen.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/player_screen_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';

import '../AlbumScreen/song_list_tile.dart';

enum PlayerButtonsMoreItems { shuffle, repeat, addToPlaylist }

class PlayerButtonsMore extends ConsumerWidget {
  final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
  BaseItemDto? item;

  PlayerButtonsMore({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconTheme(
      data: IconThemeData(
        color: ref.watch(playerScreenThemeProvider) ??
            (Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white),
      ),
      child: IconButton(
        icon: const Icon(
          TablerIcons.menu_2,
        ),
        onPressed: () async {
          if (item == null) return;
          final canGoToAlbum = item!.albumId != item!.parentId &&
              isAlbumDownloadedIfOffline(item!.parentId);
          await showModalSongMenu(context, item!, false, canGoToAlbum,
              (){}, item!.parentId);
        },
      ),
      // child: PopupMenuButton(
      //   onSelected: (value) {},
      //   shape: const RoundedRectangleBorder(
      //     borderRadius: BorderRadius.all(
      //       Radius.circular(15),
      //     ),
      //   ),
      //   icon: const Icon(
      //     TablerIcons.menu_2,
      //   ),
      //   itemBuilder: (BuildContext context) =>
      //       <PopupMenuEntry<PlayerButtonsMoreItems>>[
      //     PopupMenuItem<PlayerButtonsMoreItems>(
      //         value: PlayerButtonsMoreItems.addToPlaylist,
      //         child: StreamBuilder(
      //             stream: audioHandler.mediaItem,
      //             builder: (context, snapshot) {
      //               if (snapshot.hasData) {
      //                 return ListTile(
      //                     leading: const Icon(TablerIcons.playlist_add),
      //                     onTap: () => Navigator.of(context)
      //                         .pushReplacementNamed(
      //                             AddToPlaylistScreen.routeName,
      //                             arguments: BaseItemDto.fromJson(
      //                                     snapshot.data!.extras!["itemJson"])
      //                                 .id),
      //                     title: Text(AppLocalizations.of(context)!
      //                         .addToPlaylistTooltip));
      //               } else {
      //                 return ListTile(
      //                     leading: const Icon(TablerIcons.playlist_add),
      //                     onTap: () {},
      //                     title: Text(AppLocalizations.of(context)!
      //                         .addToPlaylistTooltip));
      //               }
      //             }))
      //   ],
      // ),
    );
  }
}
