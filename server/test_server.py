#!/usr/bin/env python3
"""Comprehensive backend verification suite for CampusOS REST API & Leave Server.
Runs against the real SQLite database and in-process HTTP test client.
"""
from __future__ import annotations

import json
import os
import sqlite3
import tempfile
import threading
import time
import unittest
from http.server import HTTPServer
from urllib import request, error

# Set isolated test database path before importing server
TEST_DIR = tempfile.mkdtemp(prefix="campusos_test_")
TEST_DB_PATH = os.path.join(TEST_DIR, "test_campusos.db")
os.environ["CAMPUSOS_DB_PATH"] = TEST_DB_PATH
# Throwaway credentials generated per test run; nothing is hardcoded.
import secrets as _secrets
DEMO_PW = _secrets.token_urlsafe(12)
ADMIN_PW = _secrets.token_urlsafe(12)
os.environ["CAMPUSOS_DEMO_PASSWORD"] = DEMO_PW
os.environ["CAMPUSOS_ADMIN_PASSWORD"] = ADMIN_PW

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import server as srv


class CampusBackendTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        srv.init_db()
        cls.port = 8889
        cls.server = HTTPServer(("127.0.0.1", cls.port), srv.CampusApiHandler)
        cls.server_thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.server_thread.start()
        cls.base_url = f"http://127.0.0.1:{cls.port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def _request(self, method: str, path: str, data: dict = None, token: str = None) -> tuple[int, dict]:
        url = f"{self.base_url}{path}"
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"

        req_data = json.dumps(data).encode("utf-8") if data is not None else None
        req = request.Request(url, data=req_data, headers=headers, method=method)

        try:
            with request.urlopen(req) as resp:
                body = json.loads(resp.read().decode("utf-8"))
                return resp.status, body
        except error.HTTPError as e:
            try:
                body = json.loads(e.read().decode("utf-8"))
            except Exception:
                body = {"detail": e.reason}
            return e.code, body

    # 1. Health Probe
    def test_01_health_probe(self):
        status, body = self._request("GET", "/api/health")
        self.assertEqual(status, 200)
        self.assertEqual(body.get("status"), "ok")

    # 2. Authentication & Login
    def test_02_login_success(self):
        status, body = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": DEMO_PW})
        self.assertEqual(status, 200)
        self.assertIn("token", body)
        self.assertEqual(body["role"], "student")
        self.assertEqual(body["id"], "22CS1042")

    def test_03_login_bad_credentials(self):
        status, body = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": "wrongpassword"})
        self.assertEqual(status, 401)
        self.assertIn("Invalid", body["error"]["message"])

    # 3. Student Leave Submission & Persistence
    def test_04_student_submit_leave_persists(self):
        login_st, login_body = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": DEMO_PW})
        token = login_body["token"]

        payload = {
            "leaveType": "Hostel Outing",
            "startDate": "2026-10-20T00:00:00Z",
            "endDate": "2026-10-22T00:00:00Z",
            "reason": "Attending university tech festival and competitive coding",
            "destinationAddress": "DTU Delhi Campus",
            "emergencyContact": "+91 98765 00000",
        }
        status, body = self._request("POST", "/api/erp/leaves", payload, token=token)
        self.assertEqual(status, 201)
        self.assertTrue(body["id"].startswith("LEAVE-"))
        self.assertEqual(body["applicantId"], "22CS1042")
        self.assertEqual(body["status"], "pending")
        self.assertEqual(body["assignedWardenId"], "FAC-CS-08")
        self.assertEqual(len(body["auditTrail"]), 1)
        self.assertEqual(body["auditTrail"][0]["action"], "SUBMITTED")

    def test_05_student_submit_invalid_dates_rejected(self):
        _, login_body = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": DEMO_PW})
        token = login_body["token"]

        payload = {
            "leaveType": "Hostel Outing",
            "startDate": "2026-10-22T00:00:00Z",
            "endDate": "2026-10-20T00:00:00Z", # End before start
            "reason": "Attending university tech festival and coding",
        }
        status, body = self._request("POST", "/api/erp/leaves", payload, token=token)
        self.assertEqual(status, 400)
        self.assertIn("cannot precede", body["error"]["message"])

    def test_06_student_submit_short_reason_rejected(self):
        _, login_body = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": DEMO_PW})
        token = login_body["token"]

        payload = {
            "leaveType": "Hostel Outing",
            "startDate": "2026-10-20T00:00:00Z",
            "endDate": "2026-10-22T00:00:00Z",
            "reason": "Short",
        }
        status, body = self._request("POST", "/api/erp/leaves", payload, token=token)
        self.assertEqual(status, 400)
        self.assertIn("minimum 10 characters", body["error"]["message"])

    def test_07_student_cannot_spoof_another_student_id(self):
        # Aarav logs in with token
        _, login_body = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": DEMO_PW})
        token = login_body["token"]

        # Attempts to pass applicantId: 22EE2001 in body
        payload = {
            "applicantId": "22EE2001",
            "leaveType": "Hostel Outing",
            "startDate": "2026-10-24T00:00:00Z",
            "endDate": "2026-10-25T00:00:00Z",
            "reason": "Spoof test application with another student ID",
        }
        status, body = self._request("POST", "/api/erp/leaves", payload, token=token)
        self.assertEqual(status, 201)
        # Server MUST have overridden applicantId with token identity!
        self.assertEqual(body["applicantId"], "22CS1042")

    # 4. Student History & Data Scoping
    def test_08_student_can_only_view_own_leaves(self):
        _, s1 = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": DEMO_PW})
        _, s2 = self._request("POST", "/api/auth/login", {"id": "22EE2001", "password": DEMO_PW})

        # Student 1 gets own leaves
        status, body = self._request("GET", "/api/erp/leaves/student/22CS1042", token=s1["token"])
        self.assertEqual(status, 200)
        self.assertGreater(body["count"], 0)

        # Student 1 tries to access Student 2 leaves -> Forbidden (403)
        status, body = self._request("GET", "/api/erp/leaves/student/22EE2001", token=s1["token"])
        self.assertEqual(status, 403)

    # 5. Warden Authorization & Assigned Scoping
    def test_09_non_warden_cannot_access_warden_inbox(self):
        _, student = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": DEMO_PW})
        status, body = self._request("GET", "/api/erp/leaves/warden/FAC-CS-08", token=student["token"])
        self.assertEqual(status, 403)

    def test_10_warden_sees_only_assigned_students(self):
        # Dr. Priya Sen (Hostel Ganga & CSE)
        _, priya = self._request("POST", "/api/auth/login", {"id": "FAC-CS-08", "password": DEMO_PW})
        status, priya_inbox = self._request("GET", "/api/erp/leaves/warden/FAC-CS-08", token=priya["token"])
        self.assertEqual(status, 200)
        for item in priya_inbox["items"]:
            self.assertEqual(item["department"], "Computer Science & Engineering")

        # Prof. Rajesh Khanna (Hostel Yamuna & EE)
        _, yamuna = self._request("POST", "/api/auth/login", {"id": "WARDEN-YAMUNA", "password": DEMO_PW})
        status, yamuna_inbox = self._request("GET", "/api/erp/leaves/warden/WARDEN-YAMUNA", token=yamuna["token"])
        self.assertEqual(status, 200)
        # Should not contain 22CS1042 (Ganga student)
        self.assertFalse(any(i["applicantId"] == "22CS1042" for i in yamuna_inbox["items"]))

    # 6. Warden Approval & Rejection Decisions
    def test_11_warden_approves_assigned_leave(self):
        _, priya = self._request("POST", "/api/auth/login", {"id": "FAC-CS-08", "password": DEMO_PW})

        status, body = self._request("POST", "/api/erp/leaves/LEAVE-2026-001/decision", {
            "status": "approved",
            "remarks": "Verified with parents over telephone",
        }, token=priya["token"])

        self.assertEqual(status, 200)
        self.assertEqual(body["status"], "approved")
        self.assertEqual(body["decidedBy"], "Dr. Priya Sen")
        self.assertEqual(body["decisionRemarks"], "Verified with parents over telephone")
        self.assertEqual(body["auditTrail"][-1]["action"], "APPROVED")

    def test_12_double_decision_conflict_rejected(self):
        _, priya = self._request("POST", "/api/auth/login", {"id": "FAC-CS-08", "password": DEMO_PW})

        # LEAVE-2026-001 is now approved from previous test. Attempting second decision must return 409 Conflict!
        status, body = self._request("POST", "/api/erp/leaves/LEAVE-2026-001/decision", {
            "status": "rejected",
            "remarks": "Second attempt",
        }, token=priya["token"])

        self.assertEqual(status, 409)
        self.assertIn("already been decided", body["error"]["message"])

    def test_13_unassigned_warden_cannot_decide(self):
        # Create a new pending leave for Ganga student
        _, student = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": DEMO_PW})
        _, new_leave = self._request("POST", "/api/erp/leaves", {
            "leaveType": "Hostel Outing",
            "startDate": "2026-10-25T00:00:00Z",
            "endDate": "2026-10-27T00:00:00Z",
            "reason": "Attending inter-college symposium event",
        }, token=student["token"])

        # Yamuna warden tries to approve Ganga student's leave -> 403 Forbidden
        _, yamuna = self._request("POST", "/api/auth/login", {"id": "WARDEN-YAMUNA", "password": DEMO_PW})
        status, body = self._request("POST", f"/api/erp/leaves/{new_leave['id']}/decision", {
            "status": "approved",
        }, token=yamuna["token"])

        self.assertEqual(status, 403)

    # 7. Student Cancellation
    def test_14_student_can_cancel_pending_leave(self):
        _, student = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": DEMO_PW})
        _, new_leave = self._request("POST", "/api/erp/leaves", {
            "leaveType": "Hostel Outing",
            "startDate": "2026-10-28T00:00:00Z",
            "endDate": "2026-10-30T00:00:00Z",
            "reason": "Personal errands that will be cancelled",
        }, token=student["token"])

        status, body = self._request("POST", f"/api/erp/leaves/{new_leave['id']}/cancel", {}, token=student["token"])
        self.assertEqual(status, 200)
        self.assertEqual(body["status"], "cancelled")
        self.assertEqual(body["auditTrail"][-1]["action"], "CANCELLED")

    # 8. Security regressions
    def test_15_passwords_are_hashed_at_rest(self):
        conn = sqlite3.connect(TEST_DB_PATH)
        stored = conn.execute("SELECT password_hash FROM users WHERE id='22CS1042'").fetchone()[0]
        conn.close()
        self.assertNotIn(DEMO_PW, stored)
        self.assertTrue(stored.startswith("pbkdf2$"))

    def test_16_students_cannot_list_employees(self):
        _, student = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": DEMO_PW})
        status, _ = self._request("GET", "/api/erp/employees", token=student["token"])
        self.assertEqual(status, 403)

    def test_17_unassigned_warden_cannot_read_single_leave(self):
        _, student = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": DEMO_PW})
        _, leave = self._request("POST", "/api/erp/leaves", {
            "leaveType": "Home Visit", "startDate": "2026-11-02T00:00:00Z", "endDate": "2026-11-03T00:00:00Z",
            "reason": "Family function at home town",
        }, token=student["token"])
        _, other = self._request("POST", "/api/auth/login", {"id": "WARDEN-YAMUNA", "password": DEMO_PW})
        status, _ = self._request("GET", f"/api/erp/leaves/{leave['id']}", token=other["token"])
        self.assertEqual(status, 403)

    def test_18_duplicate_pending_request_rejected(self):
        _, student = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": DEMO_PW})
        payload = {"leaveType": "Medical", "startDate": "2026-11-10T00:00:00Z", "endDate": "2026-11-11T00:00:00Z",
                   "reason": "Doctor appointment and rest"}
        self.assertEqual(self._request("POST", "/api/erp/leaves", payload, token=student["token"])[0], 201)
        self.assertEqual(self._request("POST", "/api/erp/leaves", payload, token=student["token"])[0], 409)

    def test_19_student_cannot_choose_leave_id(self):
        _, student = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": DEMO_PW})
        _, leave = self._request("POST", "/api/erp/leaves", {
            "id": "LEAVE-2026-001", "leaveType": "Outing", "startDate": "2026-11-20T00:00:00Z",
            "endDate": "2026-11-21T00:00:00Z", "reason": "Trying to overwrite an existing id",
        }, token=student["token"])
        self.assertNotEqual(leave["id"], "LEAVE-2026-001")

    def test_20_login_lockout_after_repeated_failures(self):
        for _ in range(5):
            self._request("POST", "/api/auth/login", {"id": "22EE2001", "password": "bad"})
        status, _ = self._request("POST", "/api/auth/login", {"id": "22EE2001", "password": DEMO_PW})
        self.assertEqual(status, 429)
        srv._login_failures.clear()

    # 9. Warden routing / authorization (trusted server-side assignment only)
    def _login(self, uid, pw=None):
        return self._request("POST", "/api/auth/login", {"id": uid, "password": pw or DEMO_PW})[1]["token"]

    def test_21_student_cannot_route_request_via_hostel_or_department(self):
        tok = self._login("22CS1042")
        status, leave = self._request("POST", "/api/erp/leaves", {
            "leaveType": "Outing", "startDate": "2026-12-01T00:00:00Z", "endDate": "2026-12-02T00:00:00Z",
            "reason": "Trying to reroute to the Yamuna warden",
            "hostel": "Hostel Yamuna", "department": "Electrical Engineering",
        }, token=tok)
        self.assertEqual(status, 201)
        self.assertEqual(leave["assignedWardenId"], "FAC-CS-08")  # from users.department, not the body
        self.assertEqual(leave["department"], "Computer Science & Engineering")
        yamuna = self._login("WARDEN-YAMUNA")
        _, inbox = self._request("GET", "/api/erp/leaves/warden/WARDEN-YAMUNA?status=all", token=yamuna)
        self.assertNotIn(leave["id"], [i["id"] for i in inbox["items"]])
        status, _ = self._request("POST", f"/api/erp/leaves/{leave['id']}/decision", {"status": "approved"}, token=yamuna)
        self.assertEqual(status, 403)

    def test_22_warden_cannot_read_other_wardens_inbox(self):
        yamuna = self._login("WARDEN-YAMUNA")
        status, _ = self._request("GET", "/api/erp/leaves/warden/FAC-CS-08", token=yamuna)
        self.assertEqual(status, 403)

    def test_23_teacher_without_assignment_sees_nothing(self):
        tok = self._login("FAC-CS-12")  # teacher with no warden_assignments row
        status, inbox = self._request("GET", "/api/erp/leaves/warden/FAC-CS-12?status=all", token=tok)
        self.assertEqual(status, 200)
        self.assertEqual(inbox["items"], [])
        _, all_leaves = self._request("GET", "/api/erp/leaves", token=tok)
        self.assertEqual(all_leaves["items"], [])

    def test_24_student_cannot_decide_or_read_others(self):
        tok = self._login("22EE2001")
        status, _ = self._request("POST", "/api/erp/leaves/LEAVE-2026-001/decision", {"status": "approved"}, token=tok)
        self.assertEqual(status, 403)
        status, _ = self._request("GET", "/api/erp/leaves/LEAVE-2026-001", token=tok)
        self.assertEqual(status, 403)
        status, _ = self._request("GET", "/api/erp/leaves/student/22CS1042", token=tok)
        self.assertEqual(status, 403)

    def test_25_tampered_and_missing_tokens_rejected(self):
        tok = self._login("22CS1042")
        body, sig = tok.split(".")
        self.assertEqual(self._request("GET", "/api/erp/leaves", token=body + "." + sig[::-1])[0], 401)
        self.assertEqual(self._request("GET", "/api/erp/leaves")[0], 401)

    def test_26_no_cors_header_unless_origin_configured(self):
        req = request.Request(self.base_url + "/api/health", headers={"Origin": "https://evil.example"})
        with request.urlopen(req) as resp:
            self.assertIsNone(resp.headers.get("Access-Control-Allow-Origin"))
        srv.CORS_ORIGINS.append("https://app.example")
        try:
            req = request.Request(self.base_url + "/api/health", headers={"Origin": "https://app.example"})
            with request.urlopen(req) as resp:
                self.assertEqual(resp.headers.get("Access-Control-Allow-Origin"), "https://app.example")
            req = request.Request(self.base_url + "/api/health", headers={"Origin": "https://evil.example"})
            with request.urlopen(req) as resp:
                self.assertIsNone(resp.headers.get("Access-Control-Allow-Origin"))
        finally:
            srv.CORS_ORIGINS.remove("https://app.example")

    # 10. Employee / teacher leave: explicit approver, role isolation, audit trail
    def _apply_employee(self, tok, start="2027-01-10", end="2027-01-11", reason="Attending an academic conference"):
        return self._request("POST", "/api/erp/leaves", {
            "leaveType": "Duty Leave", "startDate": f"{start}T00:00:00Z", "endDate": f"{end}T00:00:00Z", "reason": reason}, token=tok)

    def test_27_student_cannot_touch_any_employee_leave_route(self):
        stu = self._login("22CS1042")
        emp = self._login("FAC-CS-12")
        _, leave = self._apply_employee(emp, "2027-02-01", "2027-02-02")
        for method, path, body in [
            ("GET", "/api/erp/leaves/employee/FAC-CS-12", None),
            ("GET", "/api/erp/leaves/approver/FAC-CS-08", None),
            ("GET", f"/api/erp/leaves/{leave['id']}", None),
            ("POST", f"/api/erp/leaves/{leave['id']}/decision", {"status": "approved"}),
            ("POST", "/api/erp/admin/employee-approvers", {"employeeId": "22CS1042", "approverId": "FAC-CS-08"}),
            ("GET", "/api/erp/employees", None),
        ]:
            status, _ = self._request(method, path, body, token=stu)
            self.assertEqual(status, 403, (method, path))
        # a student's own submission is a STUDENT leave: it never appears in employee queues
        _, mine = self._request("POST", "/api/erp/leaves", {"leaveType": "Outing", "startDate": "2027-02-05T00:00:00Z",
                                "endDate": "2027-02-06T00:00:00Z", "reason": "Visiting family for a function"}, token=stu)
        self.assertEqual(mine["applicantRole"], "student")
        _, inbox = self._request("GET", "/api/erp/leaves/approver/FAC-CS-08?status=all", token=self._login("FAC-CS-08"))
        self.assertNotIn(mine["id"], [i["id"] for i in inbox["items"]])

    def test_28_employee_leave_full_workflow_with_audit_and_persistence(self):
        emp, approver, admin = self._login("FAC-CS-12"), self._login("FAC-CS-08"), self._login("ADMIN01", ADMIN_PW)
        status, leave = self._apply_employee(emp)
        self.assertEqual(status, 201)
        self.assertEqual([leave["applicantRole"], leave["assignedWardenId"], leave["status"], leave["hostel"]], ["employee", "FAC-CS-08", "pending", None])
        # applicant sees it; the assigned approver sees it in the inbox
        _, mine = self._request("GET", "/api/erp/leaves/employee/FAC-CS-12", token=emp)
        self.assertIn(leave["id"], [i["id"] for i in mine["items"]])
        _, inbox = self._request("GET", "/api/erp/leaves/approver/FAC-CS-08", token=approver)
        self.assertIn(leave["id"], [i["id"] for i in inbox["items"]])
        # nobody else may read it: another teacher (not the approver), or decide on it
        other = self._login("WARDEN-YAMUNA")
        self.assertEqual(self._request("GET", "/api/erp/leaves/employee/FAC-CS-12", token=other)[0], 403)
        self.assertEqual(self._request("GET", "/api/erp/leaves/approver/FAC-CS-08", token=other)[0], 403)
        self.assertEqual(self._request("GET", f"/api/erp/leaves/{leave['id']}", token=other)[0], 403)
        _, other_inbox = self._request("GET", "/api/erp/leaves/approver/WARDEN-YAMUNA?status=all", token=other)
        self.assertNotIn(leave["id"], [i["id"] for i in other_inbox["items"]])
        self.assertEqual(self._request("POST", f"/api/erp/leaves/{leave['id']}/decision", {"status": "approved"}, token=other)[0], 403)
        # the applicant can never approve their own request
        self.assertEqual(self._request("POST", f"/api/erp/leaves/{leave['id']}/decision", {"status": "approved"}, token=emp)[0], 403)
        # a duplicate submission is rejected
        self.assertEqual(self._apply_employee(emp)[0], 409)
        # the assigned approver decides, with remarks; a repeat decision conflicts
        status, done = self._request("POST", f"/api/erp/leaves/{leave['id']}/decision", {"status": "approved", "remarks": "Approved, arrange cover."}, token=approver)
        self.assertEqual(status, 200)
        self.assertEqual([done["status"], done["decidedById"], done["decisionRemarks"]], ["approved", "FAC-CS-08", "Approved, arrange cover."])
        self.assertIsNotNone(done["decidedAt"])
        self.assertEqual([a["action"] for a in done["auditTrail"]], ["SUBMITTED", "APPROVED"])
        self.assertEqual(self._request("POST", f"/api/erp/leaves/{leave['id']}/decision", {"status": "rejected"}, token=approver)[0], 409)
        # the employee sees the persisted decision; admin can see it too
        _, mine = self._request("GET", "/api/erp/leaves/employee/FAC-CS-12", token=emp)
        got = next(i for i in mine["items"] if i["id"] == leave["id"])
        self.assertEqual([got["status"], got["decisionRemarks"]], ["approved", "Approved, arrange cover."])
        self.assertEqual(self._request("GET", f"/api/erp/leaves/{leave['id']}", token=admin)[0], 200)
        # the row really is in SQLite (not just in memory)
        conn = sqlite3.connect(TEST_DB_PATH)
        self.assertEqual(conn.execute("SELECT status FROM leaves WHERE id=?", (leave["id"],)).fetchone()[0], "approved")
        conn.close()

    def test_29_employee_leave_rejection_and_reassignment(self):
        emp, admin = self._login("FAC-CS-12"), self._login("ADMIN01", ADMIN_PW)
        _, leave = self._apply_employee(emp, "2027-03-01", "2027-03-02")
        # only an admin may reassign, and only to a real teacher/admin account
        self.assertEqual(self._request("POST", "/api/erp/admin/employee-approvers", {"employeeId": "FAC-CS-12", "approverId": "WARDEN-YAMUNA"}, token=emp)[0], 403)
        self.assertEqual(self._request("POST", "/api/erp/admin/employee-approvers", {"employeeId": "FAC-CS-12", "approverId": "22CS1042"}, token=admin)[0], 400)
        self.assertEqual(self._request("POST", "/api/erp/admin/employee-approvers", {"employeeId": "FAC-CS-12", "approverId": "FAC-CS-12"}, token=admin)[0], 400)
        self.assertEqual(self._request("POST", "/api/erp/admin/employee-approvers", {"employeeId": "FAC-CS-12", "approverId": "WARDEN-YAMUNA"}, token=admin)[0], 200)
        old, new = self._login("FAC-CS-08"), self._login("WARDEN-YAMUNA")
        _, old_inbox = self._request("GET", "/api/erp/leaves/approver/FAC-CS-08", token=old)
        self.assertNotIn(leave["id"], [i["id"] for i in old_inbox["items"]])
        self.assertEqual(self._request("POST", f"/api/erp/leaves/{leave['id']}/decision", {"status": "approved"}, token=old)[0], 403)
        status, done = self._request("POST", f"/api/erp/leaves/{leave['id']}/decision", {"status": "rejected", "remarks": "Exam duty that week."}, token=new)
        self.assertEqual([status, done["status"], done["decidedById"]], [200, "rejected", "WARDEN-YAMUNA"])
        # restore the original assignment for other tests
        self._request("POST", "/api/erp/admin/employee-approvers", {"employeeId": "FAC-CS-12", "approverId": "FAC-CS-08"}, token=admin)

    # 11. PractiVerse practical generation endpoint
    def test_30_generate_requires_auth_and_valid_text(self):
        self.assertEqual(self._request("POST", "/api/practiverse/generate", {"text": "Photosynthesis"})[0], 401)
        tok = self._login("22CS1042")
        self.assertEqual(self._request("POST", "/api/practiverse/generate", {"text": ""}, token=tok)[0], 400)
        self.assertEqual(self._request("POST", "/api/practiverse/generate", {"nope": 1}, token=tok)[0], 400)

    def test_31_generate_reports_unconfigured_server_honestly(self):
        import practical_gen
        old = {k: os.environ.pop(k, None) for k in ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "GROQ_API_KEY", "CAMPUSOS_LLM_PROVIDER")}
        try:
            status, body = self._request("POST", "/api/practiverse/generate", {"text": "Photosynthesis in C3 plants"}, token=self._login("22CS1042"))
        finally:
            for k, v in old.items():
                if v is not None:
                    os.environ[k] = v
        self.assertEqual(status, 503)
        self.assertEqual(body["error"]["code"], "llm_not_configured")

    def test_32_generate_caches_and_rate_limits_per_user(self):
        import practical_gen
        calls = []
        spec = {"title": "T", "generated_by": "ai"}
        real = practical_gen.generate
        practical_gen.generate = lambda text, client=None: (calls.append(text) or dict(spec))
        old_limit = srv.GEN_PER_HOUR
        srv._gen_cache.clear(); srv._gen_calls.clear()
        try:
            tok = self._login("22EE2001")
            s1, b1 = self._request("POST", "/api/practiverse/generate", {"text": "Supply and demand"}, token=tok)
            s2, b2 = self._request("POST", "/api/practiverse/generate", {"text": "  supply AND demand "}, token=tok)
            self.assertEqual((s1, b1["cached"], s2, b2["cached"], len(calls)), (200, False, 200, True, 1))
            srv.GEN_PER_HOUR = 2
            self.assertEqual(self._request("POST", "/api/practiverse/generate", {"text": "Topic two"}, token=tok)[0], 200)
            status, body = self._request("POST", "/api/practiverse/generate", {"text": "Topic three"}, token=tok)
            self.assertEqual((status, body["error"]["code"]), (429, "rate_limited"))
            # another user is not affected
            self.assertEqual(self._request("POST", "/api/practiverse/generate", {"text": "Topic four"}, token=self._login("FAC-CS-12"))[0], 200)
        finally:
            practical_gen.generate = real
            srv.GEN_PER_HOUR = old_limit
            srv._gen_cache.clear(); srv._gen_calls.clear()


if __name__ == "__main__":
    unittest.main()
