// Containts logic for home page, tabs page header and footers, and logic to call their body functions

// Dependencies
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:ui';
import 'contacts/class_contacts.dart';
// ignore: unused_import
import 'dart:io';
// ignore: unused_import
import 'projects/class_projects.dart';
import 'events/class_events.dart';
import 'tasks/class_tasks.dart';
import 'projects/project.dart';
import 'shared/mongodb.dart';
import 'login/login.dart';
import 'shared/user_session.dart';
import 'notifications/call_notifs/call_notifications.dart';
import 'home/class_user_profile.dart';
import 'shared/app_title.dart';

// Global navigator key for navigation from anywhere in the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

String appVersion = "";

// Function to navigate to home page from anywhere in the app
void navigateToHome() {
  final context = navigatorKey.currentContext;
  if (context != null) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

standardTile(double borderRadius, {bool isSelected = false}) {
  // Code to create the common tile with the background blur
  // defiend here to avoid repeating code elsewhere
  return BoxDecoration(
    color:
        isSelected
            ? Color.fromARGB(100, 255, 255, 255)
            : Color.fromARGB(
              22,
              255,
              255,
              255,
            ), // Sweet spot between 18 and 25 for perfect purple glow balance
    borderRadius: BorderRadius.circular(borderRadius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha(51),
        blurRadius: 40,
        spreadRadius: 2,
        offset: Offset(0, 12),
      ),
      BoxShadow(
        color: Colors.black.withAlpha(25),
        blurRadius: 80,
        spreadRadius: 8,
        offset: Offset(0, 24),
      ),
    ],
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print("!!!!! APPLICATION STARTING !!!!!");

  // Load environment variables
  print("Loading environment variables...");
  await dotenv.load(fileName: "assets/.env");

  // Connect to MongoDB
  print("Connecting to MongoDB...");
  bool connected = await MongoDatabase.connect();
  print("MongoDB connection status: $connected");

  // Initialize user session
  print("Initializing user session...");
  bool sessionInitialized = await userSession.initialize();
  print("User session initialized: $sessionInitialized");
  print("User logged in: ${userSession.isLoggedIn}");
  if (userSession.isLoggedIn) {
    print("Current user: ${userSession.currentUser}");
  }

  // Initialize call notification service for incoming call detection
  final callService = CallNotificationService();
  await callService.init();
  callService.listenForCalls();

  final info = await PackageInfo.fromPlatform();
  appVersion = "v${info.version}+${info.buildNumber}";

  // Run the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final String? initialContactPhone;
  const MyApp({super.key, this.initialContactPhone});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      // Set global date format configuration
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      locale: const Locale('en', 'GB'), // Use day/month format by default
      title: 'ontop.',
      // Theme stores details like the font and colours used
      theme: ThemeData(
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          primary: Colors.black,
          onPrimary: Colors.white,
          secondary: Color.fromARGB(255, 101, 28, 132),
          tertiary: Color.fromARGB(255, 200, 162, 200),
          onSecondary: Color.fromARGB(255, 88, 81, 111),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Color.fromARGB(255, 200, 162, 200), // Lilac cursor color
        ),
      ),
      // Show HomePage if user is logged in, otherwise show LoginPage
      home: _buildHomePage(),
    );
  }

  Widget _buildHomePage() {
    final isLoggedIn = userSession.isLoggedIn;
    final userData = userSession.currentUser;

    print('🏗️ MyApp: Building home page...');
    print('🔐 MyApp: User logged in: $isLoggedIn');
    print('👤 MyApp: User data: ${userData?.toString() ?? "null"}');

    if (isLoggedIn) {
      print('✅ MyApp: Showing HomePage');
      return HomePage(userData: userData);
    } else {
      print('❌ MyApp: Showing LoginPage');
      return LoginPage();
    }
  }
}

class HomePage extends StatefulWidget {
  HomePage({super.key, this.userData});
  final Map<String, dynamic>? userData;
  final String username = 'usernameDefault';
  final List<String> tabs = ['Tasks', 'Contacts', 'Projects', 'Events'];

  String getGreetingTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Morning';
    }
    if (hour < 17) {
      return 'Afternoon';
    }
    return 'Evening';
  }

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  String greetingTime = 'notInitialized';

  // Animation controllers for magical blob animations! ✨
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late AnimationController _secondBlobController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    greetingTime =
        widget
            .getGreetingTime(); // Initialize the magical animations! 🌟 (Made even more frequent for liveliness!)
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 800), // Even faster! 1.2s → 0.8s
      vsync: this,
    );

    _floatController = AnimationController(
      duration: Duration(milliseconds: 1200), // Faster! 1.8s → 1.2s
      vsync: this,
    );

    _secondBlobController = AnimationController(
      duration: Duration(milliseconds: 700), // Faster! 1s → 0.7s
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start the magical animations! ✨
    _pulseController.repeat(reverse: true);
    _floatController.repeat(reverse: true);
    _secondBlobController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    _secondBlobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        toolbarHeight: MediaQuery.of(context).size.height * 0.33,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        flexibleSpace: Stack(
          children: [
            Container(
              decoration: BoxDecoration(color: Colors.black),
            ), // Animated background blob - Top left, brought down a bit! 💜
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Positioned(
                  top: 60, // Brought down from 25
                  left: -35,
                  child: Transform.scale(
                    scale:
                        1.0 +
                        ((_pulseAnimation.value - 1.0) * 0.15), // Very subtle
                    child: Container(
                      width: 130,
                      height: 175,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 55, sigmaY: 40),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 35,
              right: 20,
              child: IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => UserProfile(userData: widget.userData),
                    ),
                  );
                },
                icon: Icon(
                  Icons.person_2_outlined,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 35,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        titleSpacing: 10,
        title: SizedBox(
          child: Column(
            spacing: 20,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Appbar with name and greeting              SizedBox(height: 5),
              AppTitle(
                isMain: true, // This is the main screen
              ),
              Column(
                children: [
                  Text("Good $greetingTime,", style: TextStyle(fontSize: 20)),
                  Text(
                    widget.userData != null
                        ? widget.userData!['name']
                        : widget.username,
                    style: const TextStyle(fontSize: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // Big animated blob - Mid right, the star of the show! ✨
          AnimatedBuilder(
            animation: Listenable.merge([_pulseController, _floatController]),
            builder: (context, child) {
              return Positioned(
                right: -80, // Positioned further out for dramatic effect
                top: MediaQuery.of(context).size.height * 0.45, // Mid area
                child: Transform.scale(
                  scale:
                      1.0 +
                      ((_pulseAnimation.value - 1.0) *
                          0.25), // Slightly more dramatic
                  child: Container(
                    width: 200, // BIG blob!
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),
              );
            },
          ),
          // Soft center blob - Gentle and light! 💫
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Positioned(
                left:
                    MediaQuery.of(context).size.width * 0.5 -
                    60, // Perfectly centered
                top:
                    MediaQuery.of(context).size.height *
                    0.55, // Center vertically
                child: Transform.scale(
                  scale:
                      1.0 +
                      ((_pulseAnimation.value - 1.0) *
                          0.08), // Very gentle pulse
                  child: Container(
                    width: 120, // Nice medium size
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.secondary.withValues(
                        alpha: 0.25,
                      ), // Very light and soft!
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 80,
                        sigmaY: 80,
                      ), // Soft dreamy blur
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),
              );
            },
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // for loop creates a new tile automatically, so we only need to add a string the tabs
                for (int index = 0; index < widget.tabs.length; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    child: Container(
                      decoration: standardTile(50),
                      margin: const EdgeInsets.symmetric(horizontal: 25),
                      child: ListTile(
                        title: Center(
                          child: Text(
                            // Title of the tab
                            widget.tabs[index],
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            // Redirect to tab
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => Tabs(
                                    currentIndex: index,
                                    tabs: widget.tabs,
                                    userData: widget.userData,
                                  ),
                            ),
                          );
                        },
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
}

class Tabs extends StatefulWidget {
  const Tabs({
    super.key,
    required this.currentIndex,
    required this.tabs,
    this.userData,
    this.initialContact,
    this.initialProject,
  });
  final int currentIndex;
  final List<String> tabs;
  final Map<String, dynamic>? userData;
  final Contact? initialContact;
  final Project? initialProject;

  @override
  State<Tabs> createState() => _TabsState();
}

class _TabsState extends State<Tabs> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    index = widget.currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    List<String> drawerTabs = [
      'Home',
      ...widget.tabs,
    ]; // initialize the list with drawer tiles
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        // most of the following is to avoid the body showing up behing the appbar and affecting the background colours
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        toolbarHeight: MediaQuery.of(context).size.height * 0.15,
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        actions: [Container()],
        title: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.onPrimary,
                width: 2.0,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTitle(
                isMain: false, // Not the main screen, enable navigation
              ),
              Builder(
                // sidebar requires context, hence the builder widget
                // instead of directly creating an iconButton
                builder:
                    (context) => IconButton(
                      icon: const Icon(Icons.menu, size: 35),
                      onPressed: () => Scaffold.of(context).openEndDrawer(),
                    ),
              ),
            ],
          ),
        ),
      ),
      body: TabsContentCaller(
        tab: index,
        initialContact: widget.initialContact,
        initialProject: widget.initialProject,
      ), // Calls tabsContentCaller with index of tab required
      // cleaner that writing the code here
      endDrawer: Drawer(
        // Sidebar code
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                width: 1.5,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.end, // FOr right aligned icons
            children: [
              // Close sidebar button (moved lower)
              IconButton(
                padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                icon: Icon(Icons.arrow_forward, color: Colors.white, size: 30),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.only(
                    top:
                        MediaQuery.of(context).size.height *
                        0.10, // Back to original vertical offset
                  ),
                  itemCount: drawerTabs.length,
                  separatorBuilder: // Add in the gap and the horizontal line between tiles
                      (context, index) => Container(
                        height: 3,
                        margin: EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          border: Border(
                            bottom: BorderSide(
                              width: 1.5,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                        ),
                      ),
                  itemBuilder:
                      (context, drawerIndex) => ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 30,
                        ),
                        title: Text(
                          // Contains the text of the list tile and text style
                          drawerTabs[drawerIndex],
                          style: TextStyle(
                            color:
                                drawerIndex - 1 ==
                                        index // make the text white if this tile is currently opened
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.tertiary,
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        onTap: () {
                          if (drawerIndex == 0) {
                            // home is at index 0, special case for it
                            Navigator.pushAndRemoveUntil(
                              // redirect to home, kill the history of the previous tabs visited
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        HomePage(userData: widget.userData),
                              ),
                              (route) =>
                                  false, // just means no tab other than home should be in stack
                            );
                          } else {
                            Navigator.pop(context); // Remove Sidebar
                            Navigator.push(
                              context, // Open clicked-on tab
                              MaterialPageRoute(
                                builder:
                                    (context) => Tabs(
                                      currentIndex: drawerIndex - 1,
                                      tabs: widget.tabs,
                                      userData: widget.userData,
                                    ),
                              ),
                            );
                          }
                        },
                      ),
                ),
              ),
              // Profile and Settings Button (back at bottom, just a little above lower boundary)
              Container(
                margin: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      appVersion,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.person_outline, color: Colors.white, size: 30),
                      onPressed: () {
                        Navigator.pop(context); // Close drawer first
                        Navigator.push(context,
                          MaterialPageRoute(
                            builder: (context) => UserProfile(userData: widget.userData),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// This class just returns the body of the specific tab called
class TabsContentCaller extends StatelessWidget {
  const TabsContentCaller({
    super.key,
    required this.tab,
    this.initialContact,
    this.initialProject,
  });
  final int tab;
  final Contact? initialContact;
  final Project? initialProject;
  // tabs list for index reference
  /*'Tasks',
    'Contacts',
    'Projects',
    'Events'*/
  @override
  Widget build(BuildContext context) {
    switch (tab) {
      case 1:
        return Contacts(contactToOpen: initialContact);

      case 2:
        return Projects(initialProject: initialProject);

      case 3:
        return Events();

      case 0:
        return Tasks();

      default:
        return Text("$tab Body not added or wrong index passed");
    }
  }
}
