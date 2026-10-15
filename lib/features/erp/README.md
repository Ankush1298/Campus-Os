# CampusOS — ERP & Official Leave Management Module

**Owner:** Person 2  
**Feature Branch:** `feature/erp-leave`  
**Status:** Feature Complete, Verified & Integrated  
**Version:** 1.0.0-ready  

---

## 📌 Executive Summary
The ERP & Leave Management module provides complete, persistent, and authorized student and employee leave management, warden inboxes scoped strictly by hostel and department assignments, role-based access control, concurrency conflict guards, and full audit trails.

---

## 🔌 Integration Contract for Person 1

### 1. Module Entry Point
```dart
import 'package:campus_os/features/erp/erp_module.dart';

// Invoked to open the ERP & Leave module from the Dashboard or Navigator
ErpModule.getEntryPoint(context);
```

### 2. Registration in `DashboardScreen`
Person 1's `lib/features/dashboard/screens/dashboard_screen.dart` is already wired to open this entry point on tapping the **ERP & Leave Management** module card:
```dart
ModuleCard(
  title: 'ERP & Leave Management',
  subtitle: 'Official Leave Management, Warden Inboxes & Staff ERP',
  icon: Icons.assignment_outlined,
  iconColor: const Color(0xFFD97706),
  iconBgColor: const Color(0xFFFFFBEB),
  badgeText: 'INTEGRATED',
  badgeColor: AppColors.success,
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ErpModule.getEntryPoint(context)),
    );
  },
)
```

### 3. Authenticated Context & Roles
- **Active Session:** The module automatically inspects `AuthService.instance.currentSession.value`.
- **Role Permissions:**
  - `student`: Can submit leave requests, view own application history, and cancel own pending requests. Cannot access warden inboxes or approve leaves.
  - `teacher` / `faculty` / `warden`: Authorized to access the Warden Review Inbox. Scoped strictly to students belonging to assigned hostels/departments (e.g. `FAC-CS-08` / Dr. Priya Sen manages Hostel Ganga and CS students).
  - `admin`: SuperAdmin privileges across all hostels and departments.

### 4. Dependencies
No new dependencies are required! The module utilizes existing packages:
- `flutter` (Material 3)
- `flutter_secure_storage: ^11.2.0` (for session and offline persistence)
- `http: ^1.6.0` (for backend API sync)

---

## 📡 REST API & Persistence Contract

If a live backend server is running (`ApiClient.baseUrl`, default: `http://10.0.2.2:8000`), the module syncs with the following endpoints:

| Method | Endpoint | Description | Scoped Roles |
|---|---|---|---|
| `POST` | `/api/erp/leaves` | Create student or employee leave application | `student`, `employee` |
| `GET` | `/api/erp/leaves/student/:id` | List leave applications for student | `student`, `admin` |
| `GET` | `/api/erp/leaves/warden/:wardenId` | List pending leaves for assigned students | `warden`, `faculty`, `admin` |
| `POST` | `/api/erp/leaves/:id/decision` | Approve or reject a leave application | `warden`, `admin` |
| `POST` | `/api/erp/leaves/:id/cancel` | Cancel student's own pending leave | `student` |

### Request Payload: Leave Submission
```json
{
  "id": "LEAVE-2026-1042001",
  "applicantId": "22CS1042",
  "applicantName": "Aarav Sharma",
  "applicantRole": "student",
  "department": "Computer Science & Engineering",
  "hostel": "Hostel Ganga (Block B)",
  "assignedWardenId": "FAC-CS-08",
  "leaveType": "Hostel Outing",
  "startDate": "2026-10-18T00:00:00.000Z",
  "endDate": "2026-10-20T00:00:00.000Z",
  "reason": "Attending Google Developer Group hackathon",
  "destinationAddress": "Cyber City, Gurgaon",
  "emergencyContact": "+91 98765 00000",
  "status": "pending",
  "appliedAt": "2026-10-16T00:15:00.000Z"
}
```

### Request Payload: Warden Decision
```json
{
  "status": "approved", // or "rejected"
  "remarks": "Parental consent verified via SMS",
  "decidedBy": "Dr. Priya Sen",
  "decidedById": "FAC-CS-08",
  "decidedAt": "2026-10-16T00:20:00.000Z"
}
```

---

## 🛡️ Security & Integrity Invariants Verified
1. **Student Identity Spoofing Protection:** The server/service binds leave applications strictly to the authenticated `UserSession.id`.
2. **Warden Scope Restriction:** A warden can only review and decide on applications for students assigned to their hostel or department. Attempts by unassigned wardens are rejected with `ErpAuthException`.
3. **Double-Decision Concurrency Guard:** Once an application is approved, rejected, or cancelled, subsequent decision attempts are rejected with `ErpConflictException`.
4. **Data Isolation:** Students cannot view, edit, or cancel other students' records.
5. **Full Audit Trail:** Every lifecycle transition (`SUBMITTED`, `APPROVED`, `REJECTED`, `CANCELLED`) appends an immutable audit entry with actor ID, actor role, timestamp, and remarks.

---

## 🧪 Verification Commands & Results
```bash
# Analyze all files
flutter analyze
# Result: No issues found!

# Run all tests (including smoke test and 20 ERP unit & widget tests)
flutter test
# Result: 20/20 passed!
```
