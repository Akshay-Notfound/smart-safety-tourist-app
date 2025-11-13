import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vibration/vibration.dart';
import 'tourist_detail_screen.dart';
import 'qr_scanner_screen.dart';
import 'aadhar_detail_screen.dart';

class AuthorityDashboardScreen extends StatefulWidget {
  const AuthorityDashboardScreen({super.key});

  @override
  State<AuthorityDashboardScreen> createState() =>
      _AuthorityDashboardScreenState();
}

class _AuthorityDashboardScreenState extends State<AuthorityDashboardScreen>
    with TickerProviderStateMixin {
  StreamSubscription? _panicSubscription;
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _listenForPanicAlerts();
  }

  void _listenForPanicAlerts() {
    _panicSubscription = FirebaseFirestore.instance
        .collection('live_locations')
        .where('status', isEqualTo: 'panic')
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        bool? hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator == true) {
          Vibration.vibrate(duration: 1000, amplitude: 128);
        }
      }
    });
  }

  @override
  void dispose() {
    _panicSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Authority Dashboard'),
        backgroundColor: Colors.deepPurple.shade400,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'List View'),
            Tab(icon: Icon(Icons.map), text: 'Map View'),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade400,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.admin_panel_settings,
                      size: 30,
                      color: Colors.deepPurple,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Authority Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Tourist List'),
              onTap: () {
                Navigator.pop(context);
                _tabController.animateTo(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Map View'),
              onTap: () {
                Navigator.pop(context);
                _tabController.animateTo(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Scan Tourist ID'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const QRScannerScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.notifications_active),
              title: const Text('Panic Alerts'),
              onTap: () {
                Navigator.pop(context);
                // This would show panic alerts if we had a separate screen for them
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Monitoring panic alerts in real-time'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          TouristListView(),
          LiveMapView(),
        ],
      ),
      floatingActionButton: _buildConditionalFAB(),
    );
  }

  Widget _buildConditionalFAB() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        // Show FAB only on List View (index 0)
        return _tabController.index == 0
            ? FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const QRScannerScreen()),
                  );
                },
                label: const Text('Scan ID'),
                icon: const Icon(Icons.qr_code_scanner),
                backgroundColor: Colors.deepPurple,
              )
            : const SizedBox.shrink(); // Hide FAB on Map View
      },
    );
  }
}

class TouristListView extends StatelessWidget {
  const TouristListView({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'tourist')
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!userSnapshot.hasData || userSnapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No tourists registered yet.'));
        }

        final tourists = userSnapshot.data!.docs;

        return StreamBuilder<QuerySnapshot>(
          stream:
          FirebaseFirestore.instance.collection('live_locations').snapshots(),
          builder: (context, locationSnapshot) {
            Map<String, DocumentSnapshot> liveLocations = {};
            if (locationSnapshot.hasData) {
              for (var doc in locationSnapshot.data!.docs) {
                liveLocations[doc.id] = doc;
              }
            }

            return ListView.builder(
              itemCount: tourists.length,
              itemBuilder: (context, index) {
                final touristDoc = tourists[index];
                final touristData = touristDoc.data() as Map<String, dynamic>;
                final locationData =
                liveLocations[touristDoc.id]?.data() as Map<String, dynamic>?;

                Icon statusIcon;
                String statusText = "Not Tracking";

                if (locationData != null) {
                  final status = locationData['status'];
                  final timestamp =
                  (locationData['timestamp'] as Timestamp?)?.toDate();

                  if (status == 'panic') {
                    statusIcon =
                    const Icon(Icons.circle, color: Colors.red, size: 16);
                    statusText = "PANIC ALERT!";
                  } else if (timestamp != null &&
                      DateTime.now().difference(timestamp).inMinutes > 15) {
                    statusIcon = const Icon(Icons.circle,
                        color: Colors.yellow, size: 16);
                    statusText = "Inactive / Location Off";
                  } else {
                    statusIcon =
                    const Icon(Icons.circle, color: Colors.green, size: 16);
                    statusText = "Live Tracking On";
                  }
                } else {
                  statusIcon =
                      Icon(Icons.circle, color: Colors.grey.shade400, size: 16);
                }

                return Card(
                  margin:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(touristData['fullName']?[0] ?? 'T'),
                    ),
                    title: Text(touristData['fullName'] ?? 'No Name'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            statusIcon,
                            const SizedBox(width: 8),
                            Text(statusText),
                          ],
                        ),
                        if (touristData['phoneNumber'] != null && 
                            touristData['phoneNumber'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Phone: ${touristData['phoneNumber']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        if (touristData['aadharNumber'] != null && 
                            touristData['aadharNumber'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Aadhaar: ${touristData['aadharNumber']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TouristDetailScreen(
                                touristData: touristData,
                                locationData: locationData,
                              ),
                        ),
                      );
                    },
                    onLongPress: () {
                      // Show bottom sheet with options
                      showModalBottomSheet(
                        context: context,
                        builder: (BuildContext context) {
                          return SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.visibility),
                                  title: const Text('View Details'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            TouristDetailScreen(
                                              touristData: touristData,
                                              locationData: locationData,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.edit),
                                  title: const Text('Edit Tourist Info'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    // Show a dialog or screen for editing tourist info
                                    _showEditTouristDialog(context, touristDoc, touristData);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.badge_outlined),
                                  title: const Text('View Aadhaar Details'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AadharDetailScreen(
                                              userId: touristDoc.id,
                                              isAuthorityView: true,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showEditTouristDialog(BuildContext context, DocumentSnapshot touristDoc, Map<String, dynamic> touristData) {
    // Show a simple dialog with tourist information
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Tourist Information'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name: ${touristData['fullName'] ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('Email: ${touristData['email'] ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('Phone: ${touristData['phoneNumber'] ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('Emergency Contact: ${touristData['emergencyContact'] ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('Aadhaar: ${touristData['aadharNumber'] ?? 'N/A'}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class LiveMapView extends StatelessWidget {
  const LiveMapView({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('live_locations').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text('No tourists are currently sharing their location.'),
              ],
            ),
          );
        }

        Set<Marker> markers = <Marker>{};
        List<Map<String, dynamic>> locationList = [];
        
        for (var doc in snapshot.data!.docs) {
          final locationData = doc.data() as Map<String, dynamic>;
          // Add debug print to see what data we're getting
          print('Location data for ${doc.id}: $locationData');
          locationList.add({
            'id': doc.id,
            'data': locationData,
          });
          
          if (locationData['latitude'] != null && locationData['longitude'] != null) {
            final lat = locationData['latitude'];
            final lon = locationData['longitude'];
            final status = locationData['status'];

            BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarker;
            if (status == 'panic') {
              markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
            } else {
              final timestamp = (locationData['timestamp'] as Timestamp?)?.toDate();
              if (timestamp != null && DateTime.now().difference(timestamp).inMinutes > 15) {
                markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
              } else {
                markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
              }
            }

            markers.add(
              Marker(
                markerId: MarkerId(doc.id),
                position: LatLng(lat, lon),
                icon: markerIcon,
                infoWindow: InfoWindow(
                  title: locationData['touristName'] ?? 'Tourist',
                  snippet: 'Status: $status',
                ),
              ),
            );
          }
        }

        // If no valid markers were created, show the "no locations" message
        if (markers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text('No tourists are currently sharing their location.'),
              ],
            ),
          );
        }

        LatLng initialCameraPosition = markers.isNotEmpty
            ? markers.first.position
            : const LatLng(20.5937, 78.9629); // Center of India

        return _buildMapWithFallback(
          initialCameraPosition: initialCameraPosition,
          markers: markers,
          locationList: locationList,
        );
      },
    );
  }

  Widget _buildMapWithFallback({
    required LatLng initialCameraPosition,
    required Set<Marker> markers,
    required List<Map<String, dynamic>> locationList,
  }) {
    return FutureBuilder<bool>(
      future: _checkGoogleMapsAvailability(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasData && snapshot.data == true) {
          // Google Maps is available, show the map
          try {
            return GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialCameraPosition,
                zoom: 12,
              ),
              markers: markers,
              // Add map type and other options for better visibility
              mapType: MapType.normal,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            );
          } catch (e) {
            // If Google Maps fails, show fallback
            return _buildMapFallback(locationList);
          }
        } else {
          // Google Maps not available, show fallback
          return _buildMapFallback(locationList);
        }
      },
    );
  }

  Future<bool> _checkGoogleMapsAvailability() async {
    try {
      // This is a simple check - in a real app you might want to do a more thorough check
      return true;
    } catch (e) {
      return false;
    }
  }

  Widget _buildMapFallback(List<Map<String, dynamic>> locationList) {
    // Show a list of locations instead of the map
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: locationList.length,
      itemBuilder: (context, index) {
        final location = locationList[index]['data'] as Map<String, dynamic>;
        final lat = location['latitude'];
        final lon = location['longitude'];
        final name = location['touristName'] ?? 'Tourist';
        final status = location['status'] ?? 'unknown';
        
        Color statusColor = Colors.grey;
        if (status == 'panic') {
          statusColor = Colors.red;
        } else if (status == 'tracking') {
          final timestamp = (location['timestamp'] as Timestamp?)?.toDate();
          if (timestamp != null && DateTime.now().difference(timestamp).inMinutes > 15) {
            statusColor = Colors.orange;
          } else {
            statusColor = Colors.green;
          }
        }
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(Icons.location_on, color: statusColor),
            title: Text(name),
            subtitle: Text('Lat: ${lat.toStringAsFixed(6)}, Lon: ${lon.toStringAsFixed(6)}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}