# 👥 Admin Management System — Dokumentasi Lengkap

Fitur untuk owner/manager mengelola admin dengan kontrol akses berbasis role dan permission.

---

## 🏗️ Arsitektur Role & Permission

### Role Hierarchy

```
Owner (Level 1)
  ├─ Full access ke semua fitur
  ├─ Bisa manage admin lain
  ├─ Lihat laporan finansial & dashboard owner
  └─ Setting system-wide
      
Admin (Level 2)
  ├─ Manage order (create, update status, delete)
  ├─ Input pelanggan baru
  ├─ Lihat notifikasi
  └─ TIDAK bisa:
      ├─ Manage admin lain
      ├─ Lihat laporan finansial
      └─ Change system settings
```

---

## 🔑 Implementasi di Database

### Users Collection

```firestore
users/{userId}
  ├── email: string
  ├── nama: string
  ├── role: "owner" | "admin"
  ├── outlet_id: string (outlet yang diassign)
  ├── status: "aktif" | "suspended" | "inactive"
  ├── createdAt: timestamp
  ├── createdBy: string (user ID yang create)
  ├── lastLogin: timestamp
  ├── permissions: {
  │   canCreateOrder: boolean
  │   canUpdateOrder: boolean
  │   canDeleteOrder: boolean
  │   canViewDashboard: boolean
  │   canViewFinancial: boolean (owner only)
  │   canManageAdmin: boolean (owner only)
  │   canViewSettings: boolean (owner only)
  └── }
  └── notes: string (catatan dari owner)
```

### Config Collection (Owner Code)

```firestore
config/owner_code
  ├── code: string ("MDN2024OWNER")
  ├── createdAt: timestamp
  ├── lastUsed: timestamp
  ├── usedCount: integer (berapa kali pernah dipakai)
  └── notes: string (optional)
```

---

## 🎯 User Flows

### Flow 1: User Baru Daftar (dengan owner code)

```
User Input Email & Password
    ↓
Ada opsi "Registrasi sebagai Owner"?
    ├─ Ya → Minta input Owner Code
    │         ↓
    │     Validasi code dengan `config/owner_code`
    │         ├─ ✅ Cocok → Buat user dengan role: "owner"
    │         └─ ❌ Salah → Error, retry
    │
    └─ Tidak → Buat user dengan role: "admin"
                 (assign ke outlet default)
```

### Flow 2: Owner Manage Admin

```
Owner → Settings → Admin Management
    ↓
Lihat list admin
    ├─ Tambah Admin Baru
    │   ├─ Input email, nama, outlet
    │   ├─ Generate temporary password / send invite link
    │   └─ Set permissions per admin
    │
    ├─ Edit Admin
    │   ├─ Change outlet assignment
    │   ├─ Enable/disable permissions
    │   └─ Add catatan (notes)
    │
    └─ Suspend/Delete Admin
        ├─ Suspend → Akun tidak bisa login
        └─ Delete → Hapus akun + data-nya (atau archive)
```

### Flow 3: Admin Manage Order (dengan permission check)

```
Admin → Halaman Order
    ├─ List order (sesuai outlet-nya)
    ├─ Klik order → Detail + tombol action
    └─ Action tersedia (tergantung permission):
        ├─ Update status ✅ (jika canUpdateOrder = true)
        ├─ Delete order ✅ (jika canDeleteOrder = true)
        └─ Lihat finansial ❌ (jika canViewFinancial = false)
```

---

## 💾 Firestore Rules untuk Admin Management

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users dapat read/write profile mereka sendiri
    match /users/{userId} {
      allow read: if request.auth.uid == userId;
      allow write: if request.auth.uid == userId;
    }
    
    // Owner bisa manage admin lain
    match /users/{document=**} {
      allow read: if getUserRole(request.auth.uid) == 'owner';
      allow write: if getUserRole(request.auth.uid) == 'owner';
    }
    
    // Order - Admin/Owner bisa read & write sesuai permission
    match /order/{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null 
                   && (getUserRole(request.auth.uid) == 'owner'
                       || hasPermission(request.auth.uid, 'canCreateOrder'));
    }
    
    // Config hanya owner yang boleh read
    match /config/{document=**} {
      allow read: if getUserRole(request.auth.uid) == 'owner';
      allow write: if false; // Jangan update dari app
    }
  }
  
  // Helper functions
  function getUserRole(userId) {
    return get(/databases/$(database)/documents/users/$(userId)).data.role;
  }
  
  function hasPermission(userId, permission) {
    return get(/databases/$(database)/documents/users/$(userId)).data.permissions[permission] == true;
  }
}
```

---

## 🔐 Security Best Practices

### 1. Owner Code Management

```
✅ DO:
- Store owner_code di Firestore (bukan di app/code)
- Update code setiap 6-12 bulan
- Log setiap penggunaan owner_code
- Limit berapa banyak owner bisa dibuat dari 1 code

❌ DON'T:
- Hardcode owner_code di Flutter app
- Commit owner_code ke GitHub
- Reuse owner_code selamanya
- Share owner_code di public channel
```

### 2. Admin Permission Validation

```
Backend (Firestore Rules):
- Setiap write ke order, check permission user
- Setiap delete order, verify canDeleteOrder = true
- Financial data, hanya expose ke role: "owner"

Frontend (Flutter):
- Hide tombol yang user tidak punya permission
- Disable input yang tidak boleh diubah
- Show warning kalau user coba bypass
```

### 3. Audit & Logging

```
Rekam setiap aktivitas admin:
- Admin A create order X → log {userId, action, orderId, timestamp}
- Admin B delete order Y → log {userId, action, orderId, timestamp}
- Owner Z suspend admin A → log {userId, action, targetUserId, timestamp}

Data log disimpan di Firestore collection: activity_logs
Retensi: 1 tahun (buat audit trail)
```

---

## 📱 UI Implementation

### Screen: Admin Management (Owner Only)

```
┌─────────────────────────────────┐
│ Admin Management                 │
├─────────────────────────────────┤
│ [+ Tambah Admin Baru]            │
├─────────────────────────────────┤
│ Admin Aktif (5):                 │
│ ├─ Eka (eka@email.com)           │
│ │  Outlet: Jakarta Pusat         │
│ │  Status: Aktif                 │
│ │  [Edit] [Suspend] [Hapus]      │
│ └─                               │
│ ├─ Budi (budi@email.com)         │
│ │  Outlet: Jakarta Selatan       │
│ │  Status: Aktif                 │
│ │  [Edit] [Suspend] [Hapus]      │
│ └─                               │
│ ...                              │
├─────────────────────────────────┤
│ Admin Suspended (1):             │
│ ├─ Citra (citra@email.com)       │
│ │  Status: Suspended             │
│ │  [Reactivate] [Hapus]          │
│ └─                               │
└─────────────────────────────────┘
```

### Dialog: Edit Admin Permissions

```
┌─────────────────────────────────┐
│ Edit Admin: Eka                  │
├─────────────────────────────────┤
│ Email: eka@email.com (read-only)│
│ Nama: [Eka Wijaya______]        │
│ Outlet: [Dropdown: Jakarta Pusat]│
│ Status: [Dropdown: Aktif]        │
├─────────────────────────────────┤
│ Permissions:                     │
│ ☑ Create Order                   │
│ ☑ Update Order Status            │
│ ☐ Delete Order                   │
│ ☑ View Dashboard                 │
│ ☐ View Financial Report          │
│ ☐ Manage Admin                   │
├─────────────────────────────────┤
│ Notes (optional):                │
│ [Admin baru, perlu training]    │
├─────────────────────────────────┤
│       [Simpan]  [Batal]          │
└─────────────────────────────────┘
```

---

## 🚀 Implementasi Step-by-Step

### Step 1: Buat Users Schema & UI

```dart
// File: lib/models/user.dart
class AppUser {
  final String uid;
  final String email;
  final String nama;
  final String role; // "owner" atau "admin"
  final String? outletId;
  final String status; // "aktif", "suspended", "inactive"
  final Map<String, bool> permissions;
  final DateTime createdAt;
  final String? createdBy;
  final DateTime? lastLogin;
  
  // ... constructor, fromFirestore, toFirestore, etc
}
```

### Step 2: Buat Owner Management Screen

```dart
// File: lib/screens/settings/admin_management.dart
class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});
  
  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  // Query users dengan role: "admin" dari Firestore
  // Build list dengan action buttons (Edit, Suspend, Delete)
  
  Future<void> _editAdmin(AppUser admin) async {
    // Open dialog dengan form untuk edit
  }
  
  Future<void> _suspendAdmin(String userId) async {
    // Update user status ke "suspended"
  }
  
  Future<void> _deleteAdmin(String userId) async {
    // Confirm & delete user
  }
}
```

### Step 3: Permission Checking Middleware

```dart
// File: lib/services/permission_service.dart
class PermissionService {
  static Future<bool> canCreateOrder(String userId) async {
    final user = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    return user.data()?['permissions']['canCreateOrder'] ?? false;
  }
  
  static Future<bool> canDeleteOrder(String userId) async {
    // ... similar check
  }
  
  static Future<bool> canManageAdmin(String userId) async {
    final user = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    return user.data()?['role'] == 'owner';
  }
}
```

### Step 4: UI Permission Gating

```dart
// File: lib/screens/order_detail.dart
Widget _buildActionButtons(OrderItem order, String currentUserId) {
  return FutureBuilder<bool>(
    future: PermissionService.canDeleteOrder(currentUserId),
    builder: (context, snapshot) {
      if (snapshot.data == true) {
        return ElevatedButton(
          onPressed: _deleteOrder,
          child: const Text('Hapus Order'),
        );
      } else {
        return const SizedBox.shrink(); // Hide button
      }
    },
  );
}
```

---

## 🔄 Data Migration (Jika Upgrade dari Version Lama)

Kalau sebelumnya tidak ada role system, perlu migrate existing users:

```javascript
// Run sekali di Firestore Cloud Functions
exports.migrateUsersRole = functions.https.onCall(async (data, context) => {
  if (context.auth?.token.admin !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Admin only');
  }
  
  const batch = admin.firestore().batch();
  const usersRef = admin.firestore().collection('users');
  
  const snapshot = await usersRef.get();
  snapshot.forEach((doc) => {
    // Assign role berdasarkan criteria (email, createdAt, etc)
    batch.update(doc.ref, {
      role: 'admin',
      permissions: {
        canCreateOrder: true,
        canUpdateOrder: true,
        canDeleteOrder: false,
        canViewDashboard: true,
        canViewFinancial: false,
        canManageAdmin: false,
        canViewSettings: false,
      },
      status: 'aktif',
    });
  });
  
  await batch.commit();
  return { success: true, count: snapshot.size };
});
```

---

## 📊 Monitoring & Analytics

Owner bisa lihat:

```
Dashboard Admin:
├─ Total admin aktif: 5
├─ Total admin suspended: 1
├─ Activity log (last 7 days):
│  ├─ Eka: 42 orders processed
│  ├─ Budi: 38 orders processed
│  └─ Citra: suspended 2 days ago
└─ Last admin created: 10 days ago
```

---

## 🆘 Troubleshooting

### Problem: Admin tidak bisa akses fitur tertentu

**Cek:**
```
1. Firestore Rules — pastikan allow read/write untuk user
2. User permission field — cek di console apakah permission true/false
3. App cache — flutter clean & rebuild
```

### Problem: Owner code tidak bisa divalidasi

**Cek:**
```
1. Document path benar: config/owner_code (case-sensitive)
2. Field name benar: "code" (bukan "ownerCode" atau lain)
3. Firestore Rules — pastikan owner bisa read config collection
```

### Problem: Admin tiba-tiba suspended

**Debug:**
```
1. Cek Firestore users/{userId}/status
2. Cek activity_logs untuk siapa yang suspend
3. Owner bisa reactivate dari Admin Management screen
```

---

## 📖 Related Files

- `lib/models/user.dart` — User model dengan role & permission
- `lib/services/permission_service.dart` — Permission checking
- `lib/screens/settings/admin_management.dart` — Admin management UI
- `lib/screens/settings/user_settings.dart` — User edit profile

---

Untuk pertanyaan lebih lanjut atau improvement, buat issue di GitHub repo!