import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/providers.dart';
import 'lobby_screen.dart';
import 'profile_screen.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  final String uid;
  const FriendsScreen({super.key, required this.uid});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  bool _showingSearch = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _showingSearch = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _showingSearch = true;
    });
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('name')
        .startAt([q])
        .endAt(['$q\uf8ff'])
        .limit(20)
        .get();
    if (mounted) {
      setState(() {
        _searchResults = snap.docs
            .where((d) => d.id != widget.uid)
            .map((d) => {'uid': d.id, ...d.data()})
            .toList();
        _searching = false;
      });
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _searchResults = [];
      _showingSearch = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(incomingRequestsProvider(widget.uid));
    final friendsAsync = ref.watch(friendsProvider(widget.uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            const Tab(text: 'Friends'),
            requestsAsync.maybeWhen(
              data: (l) => Tab(text: l.isEmpty ? 'Requests' : 'Requests (${l.length})'),
              orElse: () => const Tab(text: 'Requests'),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Friends / Search tab ───────────────────────
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search all players by name...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                    suffixIcon: _showingSearch
                        ? _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                            : IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch)
                        : null,
                  ),
                  onChanged: _search,
                ),
              ),
              Expanded(
                child: _showingSearch
                    ? _searchResults.isEmpty && !_searching
                        ? const Center(child: Text('No players found'))
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (_, i) => _SearchResultTile(
                              result: _searchResults[i],
                              myUid: widget.uid,
                            ),
                          )
                    : friendsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Error: $e')),
                        data: (friends) => friends.isEmpty
                            ? const Center(
                                child: Text(
                                  'No friends yet.\nSearch for players above.',
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.builder(
                                itemCount: friends.length,
                                itemBuilder: (_, i) => _FriendTile(
                                  friendUid: friends[i]['uid'],
                                  myUid: widget.uid,
                                ),
                              ),
                      ),
              ),
            ],
          ),

          // ── Requests tab ───────────────────────────────
          requestsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (requests) => requests.isEmpty
                ? const Center(child: Text('No pending requests'))
                : ListView.builder(
                    itemCount: requests.length,
                    itemBuilder: (_, i) {
                      final req = requests[i];
                      return _RequestTile(
                        requestId: req.id,
                        fromUid: req.fromUid,
                        myUid: widget.uid,
                        onAccepted: (roomId) => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => LobbyScreen(roomId: roomId)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// A search result tile — shows the right action based on relationship state.
class _SearchResultTile extends ConsumerWidget {
  final Map<String, dynamic> result;
  final String myUid;

  const _SearchResultTile({required this.result, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetUid = result['uid'] as String;
    final isFriendAsync = ref.watch(isFriendProvider((viewer: myUid, target: targetUid)));
    final hasPendingAsync = ref.watch(hasPendingRequestProvider((viewer: myUid, target: targetUid)));

    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(uid: targetUid, viewerUid: myUid)),
      ),
      leading: CircleAvatar(
        backgroundColor: Colors.deepPurple.shade100,
        child: Text(
          (result['name'] as String? ?? '?').isNotEmpty
              ? (result['name'] as String)[0].toUpperCase()
              : '?',
        ),
      ),
      title: Text(result['name'] ?? 'Player'),
      subtitle: Text('${result['points'] ?? 0} pts · ${result['wins'] ?? 0}W'),
      trailing: isFriendAsync.when(
        loading: () => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, __) => const SizedBox(),
        data: (isFriend) {
          if (isFriend) {
            return ElevatedButton.icon(
              onPressed: () => _challenge(context, ref, targetUid),
              icon: const Icon(Icons.sports_esports, size: 14),
              label: const Text('Challenge'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
              ),
            );
          }
          return hasPendingAsync.when(
            loading: () => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, __) => const SizedBox(),
            data: (hasPending) => hasPending
                ? Chip(
                    label: const Text('Sent', style: TextStyle(fontSize: 12)),
                    backgroundColor: Colors.grey.shade200,
                  )
                : ElevatedButton.icon(
                    onPressed: () => _sendRequest(context, ref, targetUid),
                    icon: const Icon(Icons.person_add, size: 14),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Future<void> _sendRequest(BuildContext context, WidgetRef ref, String targetUid) async {
    await ref.read(roomServiceProvider).sendFriendRequest(myUid, targetUid);
    ref.invalidate(hasPendingRequestProvider((viewer: myUid, target: targetUid)));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request sent!')));
    }
  }

  Future<void> _challenge(BuildContext context, WidgetRef ref, String targetUid) async {
    await ref.read(roomServiceProvider).challengeFriend(myUid, targetUid);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Challenge sent!')));
    }
  }
}

class _FriendTile extends ConsumerWidget {
  final String friendUid;
  final String myUid;
  const _FriendTile({required this.friendUid, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider(friendUid));
    return userAsync.when(
      loading: () => const ListTile(title: Text('Loading...')),
      error: (_, __) => const SizedBox(),
      data: (user) => ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfileScreen(uid: friendUid, viewerUid: myUid)),
        ),
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple.shade100,
          child: Text(user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?'),
        ),
        title: Text(user?.name ?? 'Player'),
        subtitle: Text('${user?.points ?? 0} pts · ${user?.wins ?? 0}W'),
        trailing: ElevatedButton.icon(
          onPressed: () => _challenge(context, ref),
          icon: const Icon(Icons.sports_esports, size: 16),
          label: const Text('Challenge'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ),
    );
  }

  Future<void> _challenge(BuildContext context, WidgetRef ref) async {
    await ref.read(roomServiceProvider).challengeFriend(myUid, friendUid);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Challenge sent!')));
    }
  }
}

class _RequestTile extends ConsumerWidget {
  final String requestId;
  final String fromUid;
  final String myUid;
  final void Function(String roomId) onAccepted;

  const _RequestTile({
    required this.requestId,
    required this.fromUid,
    required this.myUid,
    required this.onAccepted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider(fromUid));
    return userAsync.when(
      loading: () => const ListTile(title: Text('Loading...')),
      error: (_, __) => const SizedBox(),
      data: (user) => ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.shade100,
          child: Text(user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?'),
        ),
        title: Text(user?.name ?? 'Player'),
        subtitle: const Text('Wants to be your friend'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => _decline(ref),
              child: const Text('Decline', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () => _accept(context, ref),
              child: const Text('Accept'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final room = await ref.read(roomServiceProvider).acceptFriendRequest(requestId, myUid, fromUid);
    onAccepted(room.roomId);
  }

  Future<void> _decline(WidgetRef ref) async {
    await FirebaseFirestore.instance
        .collection('friendRequests')
        .doc(requestId)
        .update({'status': 'declined'});
  }
}
