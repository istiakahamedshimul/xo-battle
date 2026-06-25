import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/providers.dart';
import 'lobby_screen.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  final String uid;
  const FriendsScreen({super.key, required this.uid});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;

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
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(10)
        .get();
    setState(() {
      _searchResults = snap.docs
          .where((d) => d.id != widget.uid)
          .map((d) => {'uid': d.id, ...d.data()})
          .toList();
      _searching = false;
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
            Tab(text: 'Friends'),
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
          // ── Friends tab ────────────────────────────────
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search players by name...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                    suffixIcon: _searching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                  ),
                  onChanged: _search,
                ),
              ),
              if (_searchResults.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (_, i) {
                      final u = _searchResults[i];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(u['name'] ?? 'Player'),
                        trailing: ElevatedButton(
                          onPressed: () => _sendRequest(u['uid']),
                          child: const Text('Add'),
                        ),
                      );
                    },
                  ),
                )
              else
                Expanded(
                  child: friendsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (friends) => friends.isEmpty
                        ? const Center(child: Text('No friends yet.\nSearch for players above.', textAlign: TextAlign.center))
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
                        onAccepted: (roomId) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => LobbyScreen(roomId: roomId)));
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendRequest(String toUid) async {
    await ref.read(roomServiceProvider).sendFriendRequest(widget.uid, toUid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request sent!')));
      setState(() {
        _searchResults = [];
        _searchCtrl.clear();
      });
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Challenge sent! Waiting for lobby...')));
    }
  }
}

class _RequestTile extends ConsumerWidget {
  final String requestId;
  final String fromUid;
  final String myUid;
  final void Function(String roomId) onAccepted;

  const _RequestTile({required this.requestId, required this.fromUid, required this.myUid, required this.onAccepted});

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
