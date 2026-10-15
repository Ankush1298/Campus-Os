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
        status, body = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": "password123"})
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
        login_st, login_body = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": "password123"})
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
        _, login_body = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": "password123"})
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
        _, login_body = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": "password123"})
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
        _, login_body = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": "password123"})
        token = login_body["token"]

        # Attempts to pass applicantId: 22EE2001 in body
        payload = {
            "applicantId": "22EE2001",
            "leaveType": "Hostel Outing",
            "startDate": "2026-10-20T00:00:00Z",
            "endDate": "2026-10-22T00:00:00Z",
            "reason": "Spoof test application with another student ID",
        }
        status, body = self._request("POST", "/api/erp/leaves", payload, token=token)
        self.assertEqual(status, 201)
        # Server MUST have overridden applicantId with token identity!
        self.assertEqual(body["applicantId"], "22CS1042")

    # 4. Student History & Data Scoping
    def test_08_student_can_only_view_own_leaves(self):
        _, s1 = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": "password123"})
        _, s2 = self._request("POST", "/api/auth/login", {"id": "22EE2001", "password": "password123"})

        # Student 1 gets own leaves
        status, body = self._request("GET", "/api/erp/leaves/student/22CS1042", token=s1["token"])
        self.assertEqual(status, 200)
        self.assertGreater(body["count"], 0)

        # Student 1 tries to access Student 2 leaves -> Forbidden (403)
        status, body = self._request("GET", "/api/erp/leaves/student/22EE2001", token=s1["token"])
        self.assertEqual(status, 403)

    # 5. Warden Authorization & Assigned Scoping
    def test_09_non_warden_cannot_access_warden_inbox(self):
        _, student = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": "password123"})
        status, body = self._request("GET", "/api/erp/leaves/warden/FAC-CS-08", token=student["token"])
        self.assertEqual(status, 403)

    def test_10_warden_sees_only_assigned_students(self):
        # Dr. Priya Sen (Hostel Ganga & CSE)
        _, priya = self._request("POST", "/api/auth/login", {"id": "FAC-CS-08", "password": "password123"})
        status, priya_inbox = self._request("GET", "/api/erp/leaves/warden/FAC-CS-08", token=priya["token"])
        self.assertEqual(status, 200)
        for item in priya_inbox["items"]:
            self.assertEqual(item["hostel"], "Hostel Ganga (Block B)")

        # Prof. Rajesh Khanna (Hostel Yamuna & EE)
        _, yamuna = self._request("POST", "/api/auth/login", {"id": "WARDEN-YAMUNA", "password": "password123"})
        status, yamuna_inbox = self._request("GET", "/api/erp/leaves/warden/WARDEN-YAMUNA", token=yamuna["token"])
        self.assertEqual(status, 200)
        # Should not contain 22CS1042 (Ganga student)
        self.assertFalse(any(i["applicantId"] == "22CS1042" for i in yamuna_inbox["items"]))

    # 6. Warden Approval & Rejection Decisions
    def test_11_warden_approves_assigned_leave(self):
        _, priya = self._request("POST", "/api/auth/login", {"id": "FAC-CS-08", "password": "password123"})

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
        _, priya = self._request("POST", "/api/auth/login", {"id": "FAC-CS-08", "password": "password123"})

        # LEAVE-2026-001 is now approved from previous test. Attempting second decision must return 409 Conflict!
        status, body = self._request("POST", "/api/erp/leaves/LEAVE-2026-001/decision", {
            "status": "rejected",
            "remarks": "Second attempt",
        }, token=priya["token"])

        self.assertEqual(status, 409)
        self.assertIn("already been decided", body["error"]["message"])

    def test_13_unassigned_warden_cannot_decide(self):
        # Create a new pending leave for Ganga student
        _, student = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": "password123"})
        _, new_leave = self._request("POST", "/api/erp/leaves", {
            "leaveType": "Hostel Outing",
            "startDate": "2026-10-25T00:00:00Z",
            "endDate": "2026-10-27T00:00:00Z",
            "reason": "Attending inter-college symposium event",
        }, token=student["token"])

        # Yamuna warden tries to approve Ganga student's leave -> 403 Forbidden
        _, yamuna = self._request("POST", "/api/auth/login", {"id": "WARDEN-YAMUNA", "password": "password123"})
        status, body = self._request("POST", f"/api/erp/leaves/{new_leave['id']}/decision", {
            "status": "approved",
        }, token=yamuna["token"])

        self.assertEqual(status, 403)

    # 7. Student Cancellation
    def test_14_student_can_cancel_pending_leave(self):
        _, student = self._request("POST", "/api/auth/login", {"id": "22CS1042", "password": "password123"})
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


if __name__ == "__main__":
    unittest.main()
