// ABOUTME: Library routes (drafts / clips / clips-only / sounds tabs)
// ABOUTME: Split from app_router.dart (#4508)

import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/screens/library_screen.dart';

List<RouteBase> libraryRoutes() {
  return [
    GoRoute(
      path: LibraryScreen.draftsPath,
      name: LibraryScreen.draftsRouteName,
      builder: (_, _) => const LibraryScreen(),
    ),
    GoRoute(
      path: LibraryScreen.clipsPath,
      name: LibraryScreen.clipsRouteName,
      builder: (_, _) => const LibraryScreen(initialTabIndex: 1),
    ),
    GoRoute(
      path: LibraryScreen.clipsOnlyPath,
      name: LibraryScreen.clipsOnlyRouteName,
      // `type` scopes the clips to the recorder's mode (stop-motion vs normal);
      // absent → both types (the standalone default).
      builder: (_, state) => LibraryScreen(
        tabsMode: LibraryTabsMode.clipsOnly,
        clipTypeFilter: LibraryClipTypeFilter.fromQuery(
          state.uri.queryParameters['type'],
        ),
      ),
    ),
    GoRoute(
      path: LibraryScreen.soundsPath,
      name: LibraryScreen.soundsRouteName,
      builder: (_, _) => const LibraryScreen(initialTabIndex: 2),
    ),
  ];
}
