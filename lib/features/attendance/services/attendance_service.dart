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

    try {
      if (session.isStudent) {
        return await ApiClient.get('/api/me/student/overview');
      } else if (session.isTeacher) {
        return await ApiClient.get('/api/me/teacher/overview');
      } else {
        return await ApiClient.get('/api/dashboard');
      }
    } catch (e) {
      // Graceful fallback to mock demo data if live server unreachable
      return _mockOverview(session);
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
        'my_attendance': {
          'classes_conducted': 36,
          'average_attendance': 89.2,
        },
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
