// lib/flavors/customer/screens/group_order_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/models/menu_models.dart';

class GroupOrderScreen extends StatefulWidget {
  final String establishmentId;
  const GroupOrderScreen({super.key, required this.establishmentId});

  @override
  State<GroupOrderScreen> createState() => _GroupOrderScreenState();
}

class _GroupOrderScreenState extends State<GroupOrderScreen> {
  final SupabaseService _svc = SupabaseService();
  String? _sessionId;
  final Map<String, CartItem> _localCart = {};
  bool _creating = false;
  bool _loading = false;
  List<MenuItem> _menuItems = [];
  final TextEditingController _joinSessionController = TextEditingController();
  final Map<String, String> _participants = {}; // user_id -> user_name

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
    _loadCurrentUser();
  }

  Future<void> _loadMenuItems() async {
    try {
      final response = await _svc.client
          .from('menu_items')
          .select('*, menu_categories(name)')
          .eq('establishment_id', widget.establishmentId)
          .eq('is_available', true);

      setState(() {
        _menuItems = response
            .map(
              (item) => MenuItem(
                id: item['id'] as String,
                name: item['name'] as String,
                description: item['description'] as String?,
                price: (item['price'] as num).toDouble(),
                imageUrl: item['image_url'] as String?,
                categoryId: item['category_id'] as String,
              ),
            )
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading menu items: $e');
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = _svc.client.auth.currentUser;
    if (user != null) {
      setState(() {
        _participants[user.id] = user.email?.split('@').first ?? 'You';
      });
    }
  }

  Future<void> _createSession() async {
    setState(() => _creating = true);
    try {
      // Create group session in database
      final response = await _svc.client
          .from('group_sessions')
          .insert({
            'establishment_id': widget.establishmentId,
            'created_by': _svc.client.auth.currentUser?.id,
            'status': 'active',
          })
          .select()
          .single();

      setState(() => _sessionId = response['id'] as String);

      // Add creator as participant
      await _svc.client.from('group_session_participants').insert({
        'session_id': _sessionId,
        'user_id': _svc.client.auth.currentUser?.id,
        'joined_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group session created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _joinSession(String sessionId) async {
    if (sessionId.isEmpty) return;

    setState(() => _loading = true);
    try {
      // Verify session exists and is active
      await _svc.client
          .from('group_sessions')
          .select()
          .eq('id', sessionId)
          .eq('status', 'active')
          .single();

      // Add user as participant
      await _svc.client.from('group_session_participants').insert({
        'session_id': sessionId,
        'user_id': _svc.client.auth.currentUser?.id,
        'joined_at': DateTime.now().toIso8601String(),
      });

      setState(() => _sessionId = sessionId);

      // Load existing participants
      await _loadParticipants(sessionId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Joined session successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _joinSessionController.clear();
      }
    }
  }

  Future<void> _loadParticipants(String sessionId) async {
    try {
      final response = await _svc.client
          .from('group_session_participants')
          .select('user_id, users(email)')
          .eq('session_id', sessionId);

      if (mounted) {
        setState(() {
          _participants.clear();
          for (final participant in response) {
            final userId = participant['user_id'] as String;
            final userData = participant['users'] as Map<String, dynamic>;
            final email = userData['email'] as String;
            _participants[userId] = email.split('@').first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading participants: $e');
    }
  }

  void _addItem(MenuItem menuItem) {
    setState(() {
      if (_localCart.containsKey(menuItem.id)) {
        _localCart[menuItem.id] = CartItem(
          menuItem: menuItem,
          quantity: _localCart[menuItem.id]!.quantity + 1,
        );
      } else {
        _localCart[menuItem.id] = CartItem(menuItem: menuItem, quantity: 1);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${menuItem.name} added to group order'),
        backgroundColor: const Color(0xFF53B175),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _removeItem(String itemId) {
    setState(() {
      if (_localCart.containsKey(itemId)) {
        if (_localCart[itemId]!.quantity > 1) {
          _localCart[itemId] = CartItem(
            menuItem: _localCart[itemId]!.menuItem,
            quantity: _localCart[itemId]!.quantity - 1,
          );
        } else {
          _localCart.remove(itemId);
        }
      }
    });
  }

  Future<void> _leaveSession() async {
    if (_sessionId != null) {
      try {
        await _svc.client
            .from('group_session_participants')
            .delete()
            .eq('session_id', _sessionId!)
            .eq('user_id', _svc.client.auth.currentUser!.id);
      } catch (e) {
        debugPrint('Error leaving session: $e');
      }
    }

    if (mounted) {
      setState(() {
        _sessionId = null;
        _localCart.clear();
        _participants.clear();
      });
    }

    _loadCurrentUser(); // Reload current user
  }

  Future<void> _submitGroupOrder() async {
    if (_localCart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // Create the main order
      final orderResponse = await _svc.client
          .from('orders')
          .insert({
            'establishment_id': widget.establishmentId,
            'table_id': 'group-order',
            'customer_id': _svc.client.auth.currentUser?.id,
            'status': 'pending',
            'total_amount': _calculateTotal(),
            'special_instructions': 'Group order from session $_sessionId',
            'group_session_id': _sessionId,
          })
          .select()
          .single();

      final orderId = orderResponse['id'] as String;

      // Create order items
      final orderItems = _localCart.entries.map((entry) {
        final cartItem = entry.value;
        return {
          'order_id': orderId,
          'menu_item_id': cartItem.menuItem.id,
          'quantity': cartItem.quantity,
          'unit_price': cartItem.menuItem.price,
          'line_total': cartItem.quantity * cartItem.menuItem.price,
        };
      }).toList();

      await _svc.client.from('order_items').insert(orderItems);

      // Clear local cart
      if (mounted) {
        setState(() => _localCart.clear());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group order #${orderId.substring(0, 8)} submitted!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  double _calculateTotal() {
    return _localCart.values.fold(
      0,
      (total, item) => total + (item.menuItem.price * item.quantity),
    );
  }

  int get _totalItemCount {
    return _localCart.values.fold(0, (count, item) => count + item.quantity);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Order'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_sessionId == null)
              _buildSessionCreationUI()
            else
              _buildSessionUI(),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCreationUI() {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group, size: 80, color: Color(0xFF53B175)),
          const SizedBox(height: 20),
          const Text(
            'Group Order',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a group order or join an existing one',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              icon: _creating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.group_add),
              label: Text(_creating ? 'Creating...' : 'Start Group Order'),
              onPressed: _creating ? null : _createSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF53B175),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('OR'),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _joinSessionController,
            decoration: const InputDecoration(
              labelText: 'Enter Session ID',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.group),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _loading
                  ? null
                  : () => _joinSession(_joinSessionController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join Session'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionUI() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Session Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Session: ${_sessionId!.substring(0, 8)}...',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.exit_to_app, size: 16),
                        label: const Text('Leave'),
                        onPressed: _loading ? null : _leaveSession,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Participants:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _participants.entries.map((entry) {
                      return Chip(
                        label: Text(entry.value),
                        backgroundColor: const Color(
                          0xFF53B175,
                        ).withValues(alpha: 0.1),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Menu Items and Cart
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Menu Items
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Menu Items',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _menuItems.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                                itemCount: _menuItems.length,
                                itemBuilder: (context, index) {
                                  final item = _menuItems[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: item.imageUrl != null
                                          ? CircleAvatar(
                                              backgroundImage: NetworkImage(
                                                item.imageUrl!,
                                              ),
                                            )
                                          : const CircleAvatar(
                                              child: Icon(Icons.fastfood),
                                            ),
                                      title: Text(item.name),
                                      subtitle: Text(
                                        'MWK ${item.price.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF53B175),
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.add,
                                          color: Color(0xFF53B175),
                                        ),
                                        onPressed: () => _addItem(item),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Cart Summary
                Expanded(
                  flex: 1,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Order',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _localCart.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No items added yet',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                : ListView(
                                    children: _localCart.entries.map((entry) {
                                      final cartItem = entry.value;
                                      return ListTile(
                                        dense: true,
                                        leading: CircleAvatar(
                                          radius: 12,
                                          backgroundColor: const Color(
                                            0xFF53B175,
                                          ),
                                          child: Text(
                                            '${cartItem.quantity}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          cartItem.menuItem.name,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        subtitle: Text(
                                          'MWK ${(cartItem.menuItem.price * cartItem.quantity).toStringAsFixed(0)}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.remove,
                                            size: 16,
                                          ),
                                          onPressed: () =>
                                              _removeItem(cartItem.menuItem.id),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Items:'),
                              Text('$_totalItemCount'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Amount:'),
                              Text(
                                'MWK ${_calculateTotal().toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF53B175),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loading || _localCart.isEmpty
                                  ? null
                                  : _submitGroupOrder,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF53B175),
                                foregroundColor: Colors.white,
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Submit Group Order'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _joinSessionController.dispose();
    super.dispose();
  }
}
