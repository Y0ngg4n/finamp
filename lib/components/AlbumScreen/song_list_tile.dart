import 'package:audio_service/audio_service.dart';
import 'package:finamp/to_contrast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../models/jellyfin_models.dart';
import '../../services/audio_service_helper.dart';
import '../../services/current_album_image_provider.dart';
import '../../services/jellyfin_api_helper.dart';
import '../../services/finamp_settings_helper.dart';
import '../../services/downloads_helper.dart';
import '../../services/player_screen_theme_provider.dart';
import '../../services/process_artist.dart';
import '../../services/music_player_background_task.dart';
import '../../screens/album_screen.dart';
import '../../screens/add_to_playlist_screen.dart';
import '../PlayerScreen/album_chip.dart';
import '../PlayerScreen/artist_chip.dart';
import '../favourite_button.dart';
import '../album_image.dart';
import '../print_duration.dart';
import '../error_snackbar.dart';
import 'downloaded_indicator.dart';

enum SongListTileMenuItems {
  addToQueue,
  replaceQueueWithItem,
  addToPlaylist,
  removeFromPlaylist,
  instantMix,
  goToAlbum,
  addFavourite,
  removeFavourite,
}

class SongListTile extends StatefulWidget {
  const SongListTile({
    Key? key,
    required this.item,

    /// Children that are related to this list tile, such as the other songs in
    /// the album. This is used to give the audio service all the songs for the
    /// item. If null, only this song will be given to the audio service.
    this.children,

    /// Index of the song in whatever parent this widget is in. Used to start
    /// the audio service at a certain index, such as when selecting the middle
    /// song in an album.
    this.index,
    this.parentId,
    this.isSong = false,
    this.showArtists = true,
    this.onDelete,

    /// Whether this widget is being displayed in a playlist. If true, will show
    /// the remove from playlist button.
    this.isInPlaylist = false,
  }) : super(key: key);

  final BaseItemDto item;
  final List<BaseItemDto>? children;
  final int? index;
  final bool isSong;
  final String? parentId;
  final bool showArtists;
  final VoidCallback? onDelete;
  final bool isInPlaylist;

  @override
  State<SongListTile> createState() => _SongListTileState();
}

class _SongListTileState extends State<SongListTile>
    with SingleTickerProviderStateMixin {
  final _audioServiceHelper = GetIt.instance<AudioServiceHelper>();
  final _audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  bool songMenuFullSize = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    /// Sets the item's favourite on the Jellyfin server.
    Future<void> setFavourite() async {
      try {
        // We switch the widget state before actually doing the request to
        // make the app feel faster (without, there is a delay from the
        // user adding the favourite and the icon showing)
        setState(() {
          widget.item.userData!.isFavorite = !widget.item.userData!.isFavorite;
        });

        // Since we flipped the favourite state already, we can use the flipped
        // state to decide which API call to make
        final newUserData = widget.item.userData!.isFavorite
            ? await _jellyfinApiHelper.addFavourite(widget.item.id)
            : await _jellyfinApiHelper.removeFavourite(widget.item.id);

        if (!mounted) return;

        setState(() {
          widget.item.userData = newUserData;
        });
      } catch (e) {
        setState(() {
          widget.item.userData!.isFavorite = !widget.item.userData!.isFavorite;
        });
        errorSnackbar(e, context);
      }
    }

    final listTile = ListTile(
      leading: AlbumImage(item: widget.item),
      title: StreamBuilder<MediaItem?>(
        stream: _audioHandler.mediaItem,
        builder: (context, snapshot) {
          return RichText(
            text: TextSpan(
              children: [
                // third condition checks if the item is viewed from its album (instead of e.g. a playlist)
                // same horrible check as in canGoToAlbum in GestureDetector below
                if (widget.item.indexNumber != null &&
                    !widget.isSong &&
                    widget.item.albumId == widget.parentId)
                  TextSpan(
                      text: "${widget.item.indexNumber}. ",
                      style: TextStyle(color: Theme.of(context).disabledColor)),
                TextSpan(
                  text: widget.item.name ??
                      AppLocalizations.of(context)!.unknownName,
                  style: TextStyle(
                    color: snapshot.data?.extras?["itemJson"]["Id"] ==
                                widget.item.id &&
                            snapshot.data?.extras?["itemJson"]["AlbumId"] ==
                                widget.parentId
                        ? Theme.of(context).colorScheme.secondary
                        : null,
                  ),
                ),
              ],
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        },
      ),
      subtitle: RichText(
        text: TextSpan(
          children: [
            WidgetSpan(
              child: Transform.translate(
                offset: const Offset(-3, 0),
                child: DownloadedIndicator(
                  item: widget.item,
                  size: Theme.of(context).textTheme.bodyMedium!.fontSize! + 3,
                ),
              ),
              alignment: PlaceholderAlignment.top,
            ),
            TextSpan(
              text: printDuration(Duration(
                  microseconds: (widget.item.runTimeTicks == null
                      ? 0
                      : widget.item.runTimeTicks! ~/ 10))),
              style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withOpacity(0.7)),
            ),
            if (widget.showArtists)
              TextSpan(
                text:
                    " · ${processArtist(widget.item.artists?.join(", ") ?? widget.item.albumArtist, context)}",
                style: TextStyle(color: Theme.of(context).disabledColor),
              )
          ],
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: FavoriteButton(
        item: widget.item,
        onlyIfFav: true,
      ),
      onTap: () {
        _audioServiceHelper.replaceQueueWithItem(
          itemList: widget.children ?? [widget.item],
          initialIndex: widget.index ?? 0,
        );
      },
    );

    return GestureDetector(
      onLongPressStart: (details) async {
        Feedback.forLongPress(context);

        // This horrible check does 2 things:
        //  - Checks if the item's album is not the same as the parent item
        //    that created the widget. The ids will be different if the
        //    SongListTile is in a playlist, but they will be the same if viewed
        //    in the item's album. We don't want to show this menu item if we're
        //    already in the item's album.
        //
        //  - Checks if the album is downloaded if in offline mode. If we're in
        //    offline mode, we need the album to actually be downloaded to show
        //    its metadata. This function also checks if widget.item.parentId is
        //    null.
        final canGoToAlbum = widget.item.albumId != widget.parentId &&
            _isAlbumDownloadedIfOffline(widget.item.parentId);

        // Some options are disabled in offline mode
        final isOffline = FinampSettingsHelper.finampSettings.isOffline;
        await showModalBottomSheet(
            context: context,
            isDismissible: true,
            enableDrag: true,
            isScrollControlled: true,
            clipBehavior: Clip.hardEdge,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            useSafeArea: true,
            builder: (BuildContext context) {
              return StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                // return GestureDetector(
                // onVerticalDragEnd: (details) {
                //   if (details.velocity.pixelsPerSecond.dy < 0) {
                //     if (!songMenuFullSize) {
                //       setState(() {
                //         songMenuFullSize = true;
                //       });
                //     }
                //   } else if (details.velocity.pixelsPerSecond.dy > 0) {
                //     if (songMenuFullSize) {
                //       setState(() {
                //         songMenuFullSize = false;
                //       });
                //     } else {
                //       Navigator.pop(context);
                //     }
                //   }
                // },
                // );
                return Stack(children: [
                  Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Icon(Icons.expand_circle_down,
                          size: 40, color: Colors.white.withOpacity(0.2))),
                  DraggableScrollableSheet(
                    snap: true,
                    snapSizes: const [0.5, 1.0],
                    expand: false,
                    builder: (context, scrollController) {
                      return CustomScrollView(
                        controller: scrollController,
                        physics: const ClampingScrollPhysics(),
                        slivers: [
                          SliverPersistentHeader(
                            delegate: SongMenuSliverAppBar(item: widget.item),
                            pinned: true,
                          ),
                          SliverList(
                            delegate: SliverChildListDelegate([
                              ListTile(
                                leading: const Icon(Icons.queue_music),
                                title: Text(
                                    AppLocalizations.of(context)!.addToQueue),
                                onTap: () async {
                                  await _audioServiceHelper
                                      .addQueueItem(widget.item);

                                  if (!mounted) return;

                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(AppLocalizations.of(context)!
                                        .addedToQueue),
                                  ));
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.play_circle),
                                title: Text(
                                    AppLocalizations.of(context)!.replaceQueue),
                                onTap: () async {
                                  await _audioServiceHelper
                                      .replaceQueueWithItem(
                                          itemList: [widget.item]);

                                  if (!mounted) return;

                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(AppLocalizations.of(context)!
                                        .queueReplaced),
                                  ));
                                  Navigator.pop(context);
                                },
                              ),
                              widget.isInPlaylist
                                  ? Visibility(
                                      visible: !isOffline,
                                      child: ListTile(
                                        leading:
                                            const Icon(Icons.playlist_remove),
                                        title: Text(
                                            AppLocalizations.of(context)!
                                                .removeFromPlaylistTitle),
                                        enabled: !isOffline &&
                                            widget.parentId != null,
                                        onTap: () async {
                                          try {
                                            await _jellyfinApiHelper
                                                .removeItemsFromPlaylist(
                                                    playlistId:
                                                        widget.parentId!,
                                                    entryIds: [
                                                  widget.item.playlistItemId!
                                                ]);

                                            if (!mounted) return;

                                            await _jellyfinApiHelper.getItems(
                                              parentItem:
                                                  await _jellyfinApiHelper
                                                      .getItemById(widget
                                                          .item.parentId!),
                                              sortBy:
                                                  "ParentIndexNumber,IndexNumber,SortName",
                                              includeItemTypes: "Audio",
                                              isGenres: false,
                                            );

                                            if (!mounted) return;

                                            if (widget.onDelete != null)
                                              widget.onDelete!();

                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                              content: Text(
                                                  AppLocalizations.of(context)!
                                                      .removedFromPlaylist),
                                            ));
                                            Navigator.pop(context);
                                          } catch (e) {
                                            errorSnackbar(e, context);
                                          }
                                        },
                                      ),
                                    )
                                  : Visibility(
                                      visible: !isOffline,
                                      child: ListTile(
                                        leading: const Icon(Icons.playlist_add),
                                        title: Text(
                                            AppLocalizations.of(context)!
                                                .addToPlaylistTitle),
                                        enabled: !isOffline,
                                        onTap: () {
                                          Navigator.of(context).pushNamed(
                                              AddToPlaylistScreen.routeName,
                                              arguments: widget.item.id);
                                        },
                                      ),
                                    ),
                              Visibility(
                                visible: !isOffline,
                                child: ListTile(
                                  leading: const Icon(Icons.explore),
                                  title: Text(
                                      AppLocalizations.of(context)!.instantMix),
                                  enabled: !isOffline,
                                  onTap: () async {
                                    await _audioServiceHelper
                                        .startInstantMixForItem(widget.item);

                                    if (!mounted) return;

                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(
                                          AppLocalizations.of(context)!
                                              .startingInstantMix),
                                    ));
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                              Visibility(
                                visible: canGoToAlbum,
                                child: ListTile(
                                  leading: const Icon(Icons.album),
                                  title: Text(
                                      AppLocalizations.of(context)!.goToAlbum),
                                  enabled: canGoToAlbum,
                                  onTap: () async {
                                    late BaseItemDto album;
                                    if (FinampSettingsHelper
                                        .finampSettings.isOffline) {
                                      // If offline, load the album's BaseItemDto from DownloadHelper.
                                      final downloadsHelper =
                                          GetIt.instance<DownloadsHelper>();

                                      // downloadedParent won't be null here since the menu item already
                                      // checks if the DownloadedParent exists.
                                      album = downloadsHelper
                                          .getDownloadedParent(
                                              widget.item.parentId!)!
                                          .item;
                                    } else {
                                      // If online, get the album's BaseItemDto from the server.
                                      try {
                                        album = await _jellyfinApiHelper
                                            .getItemById(widget.item.parentId!);
                                      } catch (e) {
                                        errorSnackbar(e, context);
                                        return;
                                      }
                                    }
                                    if (mounted) {
                                      Navigator.of(context).pushNamed(
                                          AlbumScreen.routeName,
                                          arguments: album);
                                    }
                                  },
                                ),
                              ),
                              widget.item.userData!.isFavorite
                                  ? ListTile(
                                      leading:
                                          const Icon(Icons.favorite_border),
                                      title: Text(AppLocalizations.of(context)!
                                          .removeFavourite),
                                      onTap: () async {
                                        await setFavourite();
                                        if (mounted) Navigator.pop(context);
                                      },
                                    )
                                  : ListTile(
                                      leading: const Icon(Icons.favorite),
                                      title: Text(AppLocalizations.of(context)!
                                          .addFavourite),
                                      onTap: () async {
                                        await setFavourite();
                                        if (mounted) Navigator.pop(context);
                                      },
                                    ),
                            ]),
                          )
                        ],
                      );
                    },
                  ),
                ]);
              });
            });
      },
      child: widget.isSong
          ? listTile
          : Dismissible(
              key: Key(widget.index.toString()),
              direction: FinampSettingsHelper.finampSettings.disableGesture
                  ? DismissDirection.none
                  : DismissDirection.horizontal,
              background: Container(
                color: Theme.of(context).colorScheme.secondary,
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: const [
                      AspectRatio(
                        aspectRatio: 1,
                        child: FittedBox(
                          fit: BoxFit.fitHeight,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Icon(Icons.queue_music),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              confirmDismiss: (direction) async {
                await _audioServiceHelper.addQueueItem(widget.item);

                if (!mounted) return false;

                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(AppLocalizations.of(context)!.addedToQueue),
                ));

                return false;
              },
              child: listTile,
            ),
    );
  }
}

/// If offline, check if an album is downloaded. Always returns true if online.
/// Returns false if albumId is null.
bool _isAlbumDownloadedIfOffline(String? albumId) {
  if (albumId == null) {
    return false;
  } else if (FinampSettingsHelper.finampSettings.isOffline) {
    final downloadsHelper = GetIt.instance<DownloadsHelper>();
    return downloadsHelper.isAlbumDownloaded(albumId);
  } else {
    return true;
  }
}

class SongMenuSliverAppBar extends SliverPersistentHeaderDelegate {
  BaseItemDto item;

  SongMenuSliverAppBar({required this.item});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return _SongInfo(item: item);
  }

  @override
  double get maxExtent => 150;

  @override
  double get minExtent => 100;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;

}

class _SongInfo extends ConsumerWidget {
  BaseItemDto item;

  _SongInfo({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.pink,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            child: AlbumImage(
              borderRadius: BorderRadius.zero,
              item: item,

              // We need a post frame callback because otherwise this
              // widget rebuilds on the same frame
            ),
          ),
          Expanded(
            child: Container(
              color: ref.watch(playerScreenThemeProvider) ??
            (Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 0, 0),
                  child: Column(
                    children: [
                      if (item.name != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                            child: Text(
                              item.name!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                height: 24 / 20,
                              ),
                              overflow: TextOverflow.fade,
                              softWrap: true,
                              maxLines: 2,
                            ),
                          ),
                        ),
                      if (item.album != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: ArtistChip(
                              item: item,
                              key: item.albumArtist == null
                                  ? null
                                  // We have to add -artist and -album to the keys because otherwise
                                  // self-titled albums (e.g. Aerosmith by Aerosmith) will break due
                                  // to duplicate keys.
                                  // Its probably more efficient to put a single character instead
                                  // of a whole 6-7 characters, but I think we can spare the CPU
                                  // cycles.
                                  : ValueKey("${item.albumArtist}-artist"),
                            ),
                          ),
                        ),
                      if (item.artists != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: AlbumChip(
                              item: item,
                              key: item.album == null
                                  ? null
                                  : ValueKey("${item.album}-album"),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
