class AcademicRecord {
  final String title;
  final String category;
  final String issueDate;
  final String referenceNumber;
  final String status;

  const AcademicRecord({
    required this.title,
    required this.category,
    required this.issueDate,
    required this.referenceNumber,
    required this.status,
  });

  factory AcademicRecord.fromJson(Map<String, dynamic> json) {
    return AcademicRecord(
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      issueDate: json['issueDate'] as String? ?? '',
      referenceNumber: json['referenceNumber'] as String? ?? '',
      status: json['status'] as String? ?? 'Verified',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'category': category,
      'issueDate': issueDate,
      'referenceNumber': referenceNumber,
      'status': status,
    };
  }
}

class StudentAcademicProfile {
  final String rollNo;
  final String name;
  final String program;
  final String department;
  final String semester;
  final String batch;
  final String cgpa;
  final String hostel;
  final String roomNo;
  final String assignedWardenName;
  final String assignedWardenId;
  final List<Map<String, String>> timetable;
  final List<AcademicRecord> officialRecords;

  const StudentAcademicProfile({
    required this.rollNo,
    required this.name,
    required this.program,
    required this.department,
    required this.semester,
    required this.batch,
    required this.cgpa,
    required this.hostel,
    required this.roomNo,
    required this.assignedWardenName,
    required this.assignedWardenId,
    this.timetable = const [],
    this.officialRecords = const [],
  });

  factory StudentAcademicProfile.defaultProfile({required String rollNo, required String name}) {
    return StudentAcademicProfile(
      rollNo: rollNo,
      name: name,
      program: 'B.Tech Computer Science & Engineering',
      department: 'Computer Science & Engineering',
      semester: '6th Semester',
      batch: '2022 - 2026',
      cgpa: '8.74',
      hostel: 'Hostel Ganga (Block B)',
      roomNo: 'B-204',
      assignedWardenName: 'Dr. Priya Sen',
      assignedWardenId: 'FAC-CS-08',
      timetable: const [
        {
          'day': 'Monday',
          'slot': '09:00 - 10:00 AM',
          'course': 'CS301: Data Structures & Algorithms',
          'room': 'LH-101',
          'faculty': 'Dr. Priya Sen'
        },
        {
          'day': 'Monday',
          'slot': '11:15 - 12:15 PM',
          'course': 'CS302: Computer Networks',
          'room': 'LH-102',
          'faculty': 'Prof. A. Verma'
        },
        {
          'day': 'Monday',
          'slot': '02:00 - 04:00 PM',
          'course': 'CS303: Operating Systems Lab',
          'room': 'Lab-2',
          'faculty': 'Er. R. Kumar'
        },
        {
          'day': 'Tuesday',
          'slot': '10:00 - 11:00 AM',
          'course': 'CS304: Database Management Systems',
          'room': 'LH-103',
          'faculty': 'Dr. S. Nair'
        },
        {
          'day': 'Wednesday',
          'slot': '03:00 - 05:00 PM',
          'course': 'CS305: Cloud Computing & Virtualization',
          'room': 'Lab-4',
          'faculty': 'Prof. M. Patel'
        },
      ],
      officialRecords: const [
        AcademicRecord(
          title: 'Semester 5 Grade Card & Transcript',
          category: 'Gradesheet',
          issueDate: 'Jan 15, 2026',
          referenceNumber: 'TR-2026-CS-1042',
          status: 'Official & Verified',
        ),
        AcademicRecord(
          title: 'Bonafide Student Certificate',
          category: 'Certification',
          issueDate: 'Feb 10, 2026',
          referenceNumber: 'BNF-2026-8812',
          status: 'Issued',
        ),
        AcademicRecord(
          title: 'Hostel Resident ID & Gate Pass Approval',
          category: 'Hostel ERP',
          issueDate: 'Aug 01, 2025',
          referenceNumber: 'HST-GANGA-204',
          status: 'Active',
        ),
      ],
    );
  }
}
