import '../../../core/network/api_client.dart';
import '../../auth/models/user_session.dart';

class AttendanceService {
  static final AttendanceService instance = AttendanceService._internal();
  AttendanceService._internal();

  Future<bool> checkHealth() async {
    try {
      final res = await ApiClient.get('/api/health');
      return res['status'] == 'ok' || res['health'] == 'ok' || res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchOverview(UserSession session) async {
    if (session.isDemo) {
      return _mockOverview(session);
    }

    // Live authenticated sessions query real backend endpoints directly
    if (session.isStudent) {
      return await ApiClient.get('/api/me/student/overview');
    } else if (session.isTeacher) {
      return await ApiClient.get('/api/me/teacher/overview');
    } else {
      return await ApiClient.get('/api/dashboard');
    }
  }

  Future<List<Map<String, dynamic>>> fetchStudentHistory(
    UserSession session, {
    int limit = 60,
  }) async {
    if (session.isDemo) {
      return [
        {
          'session_id': 'SES-101',
          'course_code': 'CS301',
          'course_name': 'Data Structures & Algorithms',
          'date': '2026-10-14',
          'slot': '09:00 - 10:00',
          'room_number': 'Lab 302',
          'status': 'present',
          'minutes_present': 54,
          'override_by': null,
        },
        {
          'session_id': 'SES-098',
          'course_code': 'CS304',
          'course_name': 'Computer Networks',
          'date': '2026-10-13',
          'slot': '11:15 - 12:15',
          'room_number': 'LH 101',
          'status': 'present',
          'minutes_present': 58,
          'override_by': null,
        },
        {
          'session_id': 'SES-095',
          'course_code': 'CS302',
          'course_name': 'Operating Systems',
          'date': '2026-10-12',
          'slot': '14:00 - 16:00',
          'room_number': 'Lab 104',
          'status': 'absent',
          'minutes_present': 0,
          'override_by': null,
        },
      ];
    }

    final res = await ApiClient.get('/api/me/student/history?limit=$limit');
    final items = res['items'] ?? res['data'] ?? [];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> fetchTeacherSession(
    String sessionId,
    UserSession session,
  ) async {
    if (session.isDemo) {
      return {
        'session': {
          'id': sessionId,
          'course_code': 'CS301',
          'course_name': 'Data Structures & Algorithms',
          'room_number': 'LH 204',
          'section': 'CS-B',
          'status': 'completed',
        },
        'students': [
          {
            'roll_no': '21CS001',
            'name': 'Aditi Sharma',
            'status': 'present',
            'minutes': 55,
          },
          {
            'roll_no': '21CS002',
            'name': 'Ankush Sharma',
            'status': 'present',
            'minutes': 52,
          },
          {
            'roll_no': '21CS003',
            'name': 'Bharat Verma',
            'status': 'absent',
            'minutes': 5,
          },
          {
            'roll_no': '21CS004',
            'name': 'Chirag Sen',
            'status': 'present',
            'minutes': 48,
          },
        ],
      };
    }

    return await ApiClient.get('/api/me/teacher/sessions/$sessionId');
  }

  Future<Map<String, dynamic>> submitTeacherOverride({
    required String sessionId,
    required String rollNo,
    required String newStatus,
    required String password,
    required String reason,
  }) async {
    return await ApiClient.post('/api/me/teacher/override', {
      'session_id': sessionId,
      'roll_no': rollNo,
      'new_status': newStatus,
      'password': password,
      'reason': reason,
    });
  }

  Future<List<Map<String, dynamic>>> fetchCameras() async {
    final res = await ApiClient.get('/api/cameras');
    final items = res['items'] ?? res['data'] ?? [];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchTimetable({String? day}) async {
    final path = day != null && day.isNotEmpty
        ? '/api/timetable?day=$day'
        : '/api/timetable';
    final res = await ApiClient.get(path);
    final items = res['items'] ?? res['data'] ?? [];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> setSlotSection({
    required int slotId,
    required String sectionId,
  }) async {
    return await ApiClient.put('/api/timetable/$slotId/section', {
      'section_id': sectionId,
    });
  }

  // --- Two-Phase QR Attendance Methods ---

  Future<Map<String, dynamic>> startQrAttendance({
    required int timetableId,
    String? date,
    bool isDemo = false,
  }) async {
    if (isDemo) {
      return {
        'qr_session_id': 'demo_qr_start_session',
        'session_id': 'demo_session',
        'timetable_id': timetableId,
        'date': date ?? '2026-10-16',
        'phase': 'start',
        'qr_token': 'qrs_start_demo_${DateTime.now().millisecondsSinceEpoch}',
        'remaining_seconds': 300,
        'message': 'Demo Start session initiated (Simulation)',
      };
    }
    return await ApiClient.post('/api/attendance/qr/start', {
      'timetable_id': timetableId,
      if (date != null && date.isNotEmpty) 'date': date,
    });
  }

  Future<Map<String, dynamic>> endQrAttendance({
    required int timetableId,
    String? date,
    bool isDemo = false,
  }) async {
    if (isDemo) {
      return {
        'qr_session_id': 'demo_qr_end_session',
        'session_id': 'demo_session',
        'timetable_id': timetableId,
        'date': date ?? '2026-10-16',
        'phase': 'end',
        'qr_token': 'qrs_end_demo_${DateTime.now().millisecondsSinceEpoch}',
        'remaining_seconds': 300,
        'message': 'Demo End session initiated (Simulation)',
      };
    }
    return await ApiClient.post('/api/attendance/qr/end', {
      'timetable_id': timetableId,
      if (date != null && date.isNotEmpty) 'date': date,
    });
  }

  Future<Map<String, dynamic>> scanQrAttendance({
    required String qrToken,
    bool isDemo = false,
  }) async {
    if (isDemo) {
      final isStart = qrToken.contains('start');
      return {
        'scanned': true,
        'phase': isStart ? 'start' : 'end',
        'status': isStart ? 'recorded' : 'present',
        'message': isStart
            ? 'Demo Start scan recorded. Scan again at class end.'
            : 'Demo Two-phase QR attendance verified! (Simulation)',
      };
    }
    return await ApiClient.post('/api/attendance/qr/scan', {
      'qr_token': qrToken.trim(),
    });
  }

  Future<Map<String, dynamic>> fetchStudentTimetable({
    bool isDemo = false,
  }) async {
    if (isDemo) {
      return {
        'roll_no': 'DEMO_STUDENT',
        'sections': ['CS-A'],
        'items': [
          {
            'id': 1,
            'day_of_week': 'monday',
            'start_time': '09:00',
            'end_time': '09:50',
            'subject': 'Data Structures & Algorithms',
            'teacher_id': 'T_PROF_SHARMA',
            'room_id': 'CR-101',
            'section_id': 'CS-A',
            'start_scanned': false,
            'end_scanned': false,
            'attendance_status': 'unrecorded',
          },
          {
            'id': 2,
            'day_of_week': 'monday',
            'start_time': '10:00',
            'end_time': '10:50',
            'subject': 'Computer Networks',
            'teacher_id': 'T_PROF_VERMA',
            'room_id': 'CR-102',
            'section_id': 'CS-A',
            'start_scanned': true,
            'end_scanned': false,
            'attendance_status': 'pending',
          },
        ],
      };
    }
    return await ApiClient.get('/api/me/student/timetable');
  }

  Future<Map<String, dynamic>> fetchTeacherTimetable({
    bool isDemo = false,
  }) async {
    if (isDemo) {
      return {
        'teacher_id': 'DEMO_TEACHER',
        'items': [
          {
            'id': 101,
            'day_of_week': 'monday',
            'start_time': '10:00',
            'end_time': '10:50',
            'subject': 'Advanced Database Systems',
            'teacher_id': 'DEMO_TEACHER',
            'room_id': 'LH 204',
            'section_id': 'CS-B',
            'active_phase': 'start',
            'can_start': false,
            'can_end': true,
            'start_scans_count': 24,
            'end_scans_count': 0,
            'remaining_seconds': 180,
          },
          {
            'id': 102,
            'day_of_week': 'monday',
            'start_time': '14:00',
            'end_time': '15:00',
            'subject': 'Cloud Computing Seminar',
            'teacher_id': 'DEMO_TEACHER',
            'room_id': 'Audi 1',
            'section_id': 'CS-All',
            'active_phase': null,
            'can_start': true,
            'can_end': false,
            'start_scans_count': 0,
            'end_scans_count': 0,
            'remaining_seconds': 0,
          },
        ],
      };
    }
    return await ApiClient.get('/api/me/teacher/timetable');
  }

  Future<Map<String, dynamic>> updateTimetableDraft({
    required String draftId,
    required List<Map<String, dynamic>> rows,
    bool isDemo = false,
  }) async {
    if (isDemo) {
      return {
        'ok': true,
        'draft_id': draftId,
        'rows_count': rows.length,
        'errors_count': 0,
        'warnings_count': 0,
        'issues': [],
      };
    }
    return await ApiClient.put('/api/timetable/drafts/$draftId', {
      'rows': rows,
    });
  }

  Future<Map<String, dynamic>> publishTimetableDraft({
    required String draftId,
    bool confirm = true,
    bool isDemo = false,
  }) async {
    if (isDemo) {
      return {'ok': true, 'published_slots': 3, 'draft_id': draftId};
    }
    return await ApiClient.post('/api/timetable/publish', {
      'draft_id': draftId,
      'confirm': confirm,
    });
  }

  /// Uploads a timetable (PDF, image, Excel, CSV, Word) to the server's OCR/parser; returns the new draft.
  Future<Map<String, dynamic>> uploadTimetable({
    required List<int> bytes,
    required String filename,
    bool isDemo = false,
  }) async {
    if (isDemo) {
      return {'draft_id': 'demo_draft'};
    }
    return await ApiClient.postFile(
      '/api/timetable/preview',
      field: 'file',
      bytes: bytes,
      filename: filename,
    );
  }

  Future<Map<String, dynamic>> getTimetableDraft(
    String draftId, {
    bool isDemo = false,
  }) async {
    if (isDemo || draftId.contains('demo')) {
      return {
        'draft_id': draftId,
        'rows': [
          {
            'day': 'Monday',
            'start': '09:00',
            'end': '09:50',
            'subject': 'Data Structures & Algorithms',
            'teacher': 'T_SHARMA',
            'room': 'CR-101',
            'section': 'CS-A',
          },
          {
            'day': 'Monday',
            'start': '10:00',
            'end': '10:50',
            'subject': 'Computer Networks',
            'teacher': 'T_VERMA',
            'room': 'CR-102',
            'section': 'CS-A',
          },
          {
            'day': 'Monday',
            'start': '11:00',
            'end': '11:50',
            'subject': 'Operating Systems',
            'teacher': 'T_SEN',
            'room': 'CR-103',
            'section': 'CS-A',
          },
        ],
        'issues': [],
        'errors': 0,
        'warnings': 0,
      };
    }
    return await ApiClient.get('/api/timetable/drafts/$draftId');
  }

  Future<Map<String, dynamic>> fetchRegistrationInfo() async {
    try {
      return await ApiClient.get('/api/registration-info');
    } catch (_) {
      return {
        'enabled': true,
        'host': 'https://attendance-register-production.up.railway.app',
        'student_url':
            'https://attendance-register-production.up.railway.app/student',
        'teacher_url':
            'https://attendance-register-production.up.railway.app/teacher',
      };
    }
  }

  Map<String, dynamic> _mockOverview(UserSession session) {
    if (session.isStudent) {
      return {
        'profile': {
          'id': session.id,
          'name': session.name,
          'sections': ['CS-A', 'CS-LAB-2'],
          'face_registered': true,
        },
        'summary': {
          'total_classes': 48,
          'attended': 42,
          'percentage': 87.5,
          'status': 'Good Standing',
        },
        'today': [
          {
            'slot': '09:00 - 10:00 AM',
            'course': 'Data Structures & Algorithms',
            'room': 'Lab 302',
            'status': 'Present',
          },
          {
            'slot': '11:15 - 12:15 PM',
            'course': 'Computer Networks',
            'room': 'LH 101',
            'status': 'Present',
          },
          {
            'slot': '02:00 - 04:00 PM',
            'course': 'Operating Systems Lab',
            'room': 'Lab 104',
            'status': 'Scheduled',
          },
        ],
      };
    } else {
      return {
        'profile': {
          'id': session.id,
          'name': session.name,
          'face_registered': true,
        },
        'my_attendance': {'classes_conducted': 36, 'average_attendance': 89.2},
        'today': [
          {
            'slot': '10:00 - 11:00 AM',
            'course': 'Advanced Database Systems',
            'room': 'LH 204',
            'section': 'CS-B',
          },
          {
            'slot': '02:00 - 03:00 PM',
            'course': 'Cloud Computing Seminar',
            'room': 'Audi 1',
            'section': 'CS-All',
          },
        ],
      };
    }
  }
}
