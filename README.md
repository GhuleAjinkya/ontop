# 📱 ONTOP - Personal Workspace Management App

A Flutter-based productivity app that combines contact management, project collaboration, task tracking, and smart call notifications into one seamless workspace.

---

## 🧩 Problem Statement

Modern professionals juggle multiple contacts, projects, and tasks across different platforms, leading to:
- **Scattered Information**: Contacts, projects, and tasks stored in separate apps
- **Poor Collaboration**: Difficulty linking team members to specific projects
- **Missed Connections**: Unknown callers during important business hours
- **Inefficient Workflow**: Switching between multiple productivity apps

**ONTOP solves this by providing a unified workspace where contacts, projects, and tasks work together seamlessly.**

---

## ✨ Key Features

- **📞 Smart Contact Management**
  - Store detailed contact profiles with call identification and project context.
  - Import contacts from your device's contact list.
  - Link contacts to organizations, projects, and events for seamless collaboration.

- **🚀 Project Collaboration**
  - Create and manage team projects with task assignments and linked notes.
  - Track project progress with deadlines and milestones.
  - Share project updates and notifications with team members.

- **✅ Task Organization**
  - Organize tasks into custom sections with priority levels and deadline tracking.
  - Set reminders and recurring tasks for better productivity.

- **📅 Event Planning**
  - Schedule and manage events linked to contacts and projects.
  - Sync events with system calendars for unified scheduling.

- **🔔 Call Notifications**
  - Instant caller identification with relevant project details.
  - Display contextual information during calls to reduce missed connections.

- **🔐 Secure Data**
  - User authentication with personal data isolation.
  - Encrypt sensitive information for enhanced security.

- **⚡ Local-First Performance**
  - Fast, responsive interactions even before syncing to the cloud.
  - Offline mode for uninterrupted access to data.

- **📤 Cloud Sync**
  - Automatic background sync with MongoDB Atlas.
  - Ensure data consistency across devices.

---

## 🛠️ Tech Stack

### Frontend
- **Flutter 3.7.2+** - Cross-platform mobile framework
- **Dart** - Programming language

### Backend
- **Node.js + Express.js** - REST API server
- **MongoDB Atlas** - Cloud NoSQL database
- **MongoDB Dart Driver** - Direct database connection

### Key Packages
- `flutter_local_notifications` - Push notifications
- `phone_state` - Call state monitoring
- `flutter_contacts` - System contact integration
- `shared_preferences` - Local storage
- `crypto` - Password hashing

---

## 🏗️ Architecture

```
User Interface (Flutter)
        ↓
Optimistic Updates Layer
        ↓
Service Adapters
        ↓
MongoDB Atlas / Node.js API
```

**Key Design Patterns:**
- **Optimistic Updates** - Instant UI feedback with background sync
- **Adapter Pattern** - Seamless switching between MongoDB and API
- **User-Specific Collections** - Data isolation for security

---

## 📂 App Structure

```
lib/
├── main.dart                 # App entry point
├── login.dart                # Authentication
├── mongodb.dart              # Database operations
├── models/                   # Data models
│   ├── user_model.dart       # User data model
│   ├── project_model.dart    # Project data model
│   └── task_model.dart       # Task data model
├── screens/                  # UI screens
│   ├── home_screen.dart      # Main dashboard
│   ├── contact_screen.dart   # Contact management
│   ├── project_screen.dart   # Project collaboration
│   └── event_screen.dart     # Event planning
├── services/                 # Business logic and API integrations
│   ├── contacts_adapter.dart # Contact-related logic
│   ├── node_js_api.dart      # Node.js API integration
│   └── task_service.dart     # Task-related logic
├── widgets/                  # Reusable UI components
│   ├── custom_button.dart    # Custom button widget
│   ├── notification_card.dart # Notification UI component
│   └── project_card.dart     # Project card UI component
└── utils/                    # Helper functions and utilities
    ├── constants.dart        # App-wide constants
    ├── session_manager.dart  # User session management
    └── validators.dart       # Input validation utilities
```

---

## 👥 Team

- **Alesha Mulla** - muggloaf[github.com/muggloaf]

- **Ajinkya Ghule** - GhuleAjinkya[github.com/GhuleAjinkya]

---

*Built with ❤️ using Flutter & MongoDB*
