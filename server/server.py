#!/usr/bin/env python3
"""CampusOS Dedicated Backend Server — ERP, Leave Management, and Auth API.

Provides real persistence using SQLite (ACID compliant), HMAC-SHA256 bearer token authentication,
server-side role and ownership enforcement, and atomic state-transition guards.
Zero external pip dependencies required — uses Python 3 standard library.

Usage:
    python3 server/server.py [port]   # Defaults to port 8000
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import re
import secrets
import sqlite3
import sys
import time
from datetime import datetime, timezone
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

DB_PATH = os.environ.get("CAMPUSOS_DB_PATH", str(Path(__file__).parent / "campusos.db"))
# Token signing key. Set CAMPUSOS_SECRET_KEY in production; otherwise a random per-process key is
# used (safe, but every restart invalidates all sessions).
_CONFIGURED_SECRET = os.environ.get("CAMPUSOS_SECRET_KEY", "")
JWT_SECRET = (_CONFIGURED_SECRET or secrets.token_hex(32)).encode()
IS_PRODUCTION = os.environ.get("CAMPUSOS_ENV", "").lower() == "production"


def check_startup_config() -> None:
    """Production refuses to start without a stable, sufficiently long signing key."""
    if IS_PRODUCTION and len(_CONFIGURED_SECRET) < 32:
        sys.exit("FATAL: CAMPUSOS_ENV=production requires CAMPUSOS_SECRET_KEY (min 32 chars).")
    if not _CONFIGURED_SECRET:
        print("WARNING: CAMPUSOS_SECRET_KEY unset; using a random key, sessions end on restart.", file=sys.stderr)
TOKEN_TTL_SEC = 8 * 3600  # 8 hours
# Comma-separated browser origins allowed via CORS. Unset = no CORS headers (native app needs none).
CORS_ORIGINS = [o.strip() for o in os.environ.get("CAMPUSOS_CORS_ORIGINS", "").split(",") if o.strip()]
MAX_BODY_BYTES = 64 * 1024
LOGIN_MAX_FAILURES = 5
LOGIN_LOCK_SEC = 300
_login_failures: Dict[str, List[float]] = {}  # ponytail: in-memory, per-process; use a shared store if multi-instance


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    dk = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 200_000)
    return f"pbkdf2${_b64(salt)}${_b64(dk)}"


def verify_password(password: str, stored: str) -> bool:
    try:
        scheme, salt, dk = stored.split("$")
        if scheme != "pbkdf2":
            return False
        calc = hashlib.pbkdf2_hmac("sha256", password.encode(), _unb64(salt), 200_000)
        return hmac.compare_digest(calc, _unb64(dk))
    except Exception:
        return False


# -----------------------------------------------------------------------------
# Security & Token Utilities
# -----------------------------------------------------------------------------

def _b64(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def _unb64(s: str) -> bytes:
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def issue_token(sub: str, name: str, role: str) -> Dict[str, Any]:
    exp = int(time.time()) + TOKEN_TTL_SEC
    payload = json.dumps({"sub": sub, "name": name, "role": role.lower(), "exp": exp}, separators=(",", ":"))
    body = _b64(payload.encode())
    sig = _b64(hmac.new(JWT_SECRET, body.encode(), hashlib.sha256).digest())
    token = f"{body}.{sig}"
    return {"token": token, "expires_at": exp, "id": sub, "name": name, "role": role.lower()}


def verify_token(token_str: str) -> Optional[Dict[str, Any]]:
    if not token_str:
        return None
    try:
        parts = token_str.strip().split(".")
        if len(parts) != 2:
            return None
        body, sig = parts
        expected_sig = _b64(hmac.new(JWT_SECRET, body.encode(), hashlib.sha256).digest())
        if not hmac.compare_digest(sig, expected_sig):
            return None
        payload = json.loads(_unb64(body).decode("utf-8"))
        if payload.get("exp", 0) < time.time():
            return None
        return payload
    except Exception:
        return None


# -----------------------------------------------------------------------------
# Database Setup & Migrations
# -----------------------------------------------------------------------------

def get_db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH, timeout=10.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")
    conn.execute("PRAGMA journal_mode = WAL;")
    return conn


def init_db() -> None:
    Path(DB_PATH).parent.mkdir(parents=True, exist_ok=True)
    conn = get_db()
    with conn:
        conn.executescript("""
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            role TEXT NOT NULL,
            password_hash TEXT NOT NULL,
            department TEXT,
            created_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS warden_assignments (
            warden_id TEXT PRIMARY KEY,
            warden_name TEXT NOT NULL,
            email TEXT,
            phone TEXT,
            assigned_hostels TEXT NOT NULL,     -- JSON array
            assigned_departments TEXT NOT NULL, -- JSON array
            assigned_student_ids TEXT NOT NULL  -- JSON array
        );

        CREATE TABLE IF NOT EXISTS leaves (
            id TEXT PRIMARY KEY,
            applicant_id TEXT NOT NULL,
            applicant_name TEXT NOT NULL,
            applicant_role TEXT NOT NULL,       -- 'student' or 'employee'
            department TEXT NOT NULL,
            hostel TEXT,
            assigned_warden_id TEXT,
            leave_type TEXT NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL,
            reason TEXT NOT NULL,
            destination_address TEXT,
            emergency_contact TEXT,
            status TEXT NOT NULL CHECK(status IN ('pending', 'approved', 'rejected', 'cancelled')),
            applied_at TEXT NOT NULL,
            decision_remarks TEXT,
            decided_by TEXT,
            decided_by_id TEXT,
            decided_at TEXT,
            FOREIGN KEY (applicant_id) REFERENCES users(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS leave_audit (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            leave_id TEXT NOT NULL,
            actor_id TEXT NOT NULL,
            actor_name TEXT NOT NULL,
            actor_role TEXT NOT NULL,
            action TEXT NOT NULL,
            remarks TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            FOREIGN KEY (leave_id) REFERENCES leaves(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS employees (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            department TEXT NOT NULL,
            designation TEXT NOT NULL,
            email TEXT NOT NULL,
            phone TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'Active',
            leave_balance TEXT NOT NULL         -- JSON dict
        );

        -- Who approves each employee's leave. Explicit on purpose: being a warden grants no employee-leave rights.
        CREATE TABLE IF NOT EXISTS employee_approvers (
            employee_id TEXT PRIMARY KEY,
            approver_id TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_leaves_applicant ON leaves(applicant_id);
        CREATE INDEX IF NOT EXISTS idx_leaves_warden ON leaves(assigned_warden_id);
        CREATE INDEX IF NOT EXISTS idx_leaves_status ON leaves(status);
        CREATE INDEX IF NOT EXISTS idx_audit_leave ON leave_audit(leave_id);
        """)

        # Seed default users if empty
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) AS c FROM users")
        if cur.fetchone()["c"] == 0:
            # Demo accounts are only created when passwords are supplied via the environment.
            demo_pw = os.environ.get("CAMPUSOS_DEMO_PASSWORD", "")
            admin_pw = os.environ.get("CAMPUSOS_ADMIN_PASSWORD", "")
            if not demo_pw or not admin_pw:
                print("WARNING: CAMPUSOS_DEMO_PASSWORD / CAMPUSOS_ADMIN_PASSWORD not set; no demo accounts seeded.", file=sys.stderr)
            else:
                now_iso = datetime.now(timezone.utc).isoformat()
                demo_hash, admin_hash = hash_password(demo_pw), hash_password(admin_pw)
                users = [
                    ("22CS1042", "Aarav Sharma", "student", demo_hash, "Computer Science & Engineering", now_iso),
                    ("22EE2001", "Vikram Singh", "student", demo_hash, "Electrical Engineering", now_iso),
                    ("FAC-CS-08", "Dr. Priya Sen", "teacher", demo_hash, "Computer Science & Engineering", now_iso),
                    ("FAC-CS-12", "Prof. Amit Sharma", "teacher", demo_hash, "Computer Science & Engineering", now_iso),
                    ("WARDEN-YAMUNA", "Prof. Rajesh Khanna", "teacher", demo_hash, "Electrical Engineering", now_iso),
                    ("ADMIN01", "Campus SuperAdmin", "admin", admin_hash, "Central Administration", now_iso),
                ]
                cur.executemany("INSERT INTO users VALUES (?, ?, ?, ?, ?, ?)", users)

        # Seed warden assignments if empty
        cur.execute("SELECT COUNT(*) AS c FROM warden_assignments")
        if cur.fetchone()["c"] == 0:
            assignments = [
                ("FAC-CS-08", "Dr. Priya Sen", "priya.sen@campusos.edu", "+91 98765 43210",
                 json.dumps(["Hostel Ganga", "Ganga Block B"]),
                 json.dumps(["Computer Science & Engineering", "CSE"]),
                 json.dumps(["22CS1042", "22CS1043", "22CS1044"])),
                ("WARDEN-YAMUNA", "Prof. Rajesh Khanna", "rajesh.khanna@campusos.edu", "+91 98765 11223",
                 json.dumps(["Hostel Yamuna", "Yamuna Block A"]),
                 json.dumps(["Electrical Engineering", "EE"]),
                 json.dumps(["22EE2001", "22EE2002"])),
                ("ADMIN01", "Campus SuperAdmin", "admin@campusos.edu", "+91 99999 00000",
                 json.dumps(["*"]), json.dumps(["*"]), json.dumps(["*"])),
            ]
            cur.executemany("INSERT INTO warden_assignments VALUES (?, ?, ?, ?, ?, ?, ?)", assignments)

        # Seed approver assignments if empty (mirrors the 'reporting manager' column of the employee directory)
        cur.execute("SELECT COUNT(*) AS c FROM employee_approvers")
        if cur.fetchone()["c"] == 0:
            cur.executemany("INSERT INTO employee_approvers VALUES (?, ?)", [
                ("FAC-CS-12", "FAC-CS-08"),
                ("WARDEN-YAMUNA", "ADMIN01"),
                ("FAC-CS-08", "ADMIN01"),
            ])

        # Seed employees if empty
        cur.execute("SELECT COUNT(*) AS c FROM employees")
        if cur.fetchone()["c"] == 0:
            emps = [
                ("FAC-CS-08", "Dr. Priya Sen", "Computer Science & Engineering", "Associate Professor & Chief Warden",
                 "priya.sen@campusos.edu", "+91 98765 43210", "Active", json.dumps({"Casual": 10, "Sick": 8, "Earned": 14, "Duty": 5})),
                ("FAC-CS-12", "Prof. Amit Sharma", "Computer Science & Engineering", "Assistant Professor",
                 "amit.sharma@campusos.edu", "+91 98123 45678", "Active", json.dumps({"Casual": 8, "Sick": 10, "Earned": 12, "Duty": 3})),
                ("STAFF-ADM-03", "Sunita Rao", "Academic Section & Registrar", "Senior Administrative Officer",
                 "sunita.rao@campusos.edu", "+91 94321 09876", "Active", json.dumps({"Casual": 12, "Sick": 6, "Earned": 20, "Duty": 0})),
            ]
            cur.executemany("INSERT INTO employees VALUES (?, ?, ?, ?, ?, ?, ?, ?)", emps)

        # Seed initial leave if empty
        has_seed_user = conn.execute("SELECT 1 FROM users WHERE id = '22CS1042'").fetchone()
        if cur.execute("SELECT COUNT(*) AS c FROM leaves").fetchone()["c"] == 0 and has_seed_user:
            now_iso = datetime.now(timezone.utc).isoformat()
            cur.execute("""
            INSERT INTO leaves VALUES (
                'LEAVE-2026-001', '22CS1042', 'Aarav Sharma', 'student',
                'Computer Science & Engineering', 'Hostel Ganga (Block B)', 'FAC-CS-08',
                'Hostel Outing', '2026-10-18T00:00:00.000Z', '2026-10-20T00:00:00.000Z',
                'Attending Smart India Hackathon zonal round at IIT Delhi',
                'IIT Delhi, Hauz Khas, New Delhi', '+91 98765 12345',
                'pending', ?, NULL, NULL, NULL, NULL
            )
            """, (now_iso,))
            cur.execute("""
            INSERT INTO leave_audit (leave_id, actor_id, actor_name, actor_role, action, remarks, timestamp)
            VALUES ('LEAVE-2026-001', '22CS1042', 'Aarav Sharma', 'student', 'SUBMITTED', 'Leave request submitted via student portal', ?)
            """, (now_iso,))
    conn.close()


def is_student_assigned_to_warden(conn: sqlite3.Connection, warden_id: str, student_id: str) -> bool:
    """Trusted check: uses only server-side records (warden_assignments + users.department).

    Client-supplied hostel/department values are never consulted. There is no trusted
    student->hostel table yet, so hostel-based assignment is intentionally NOT supported.
    """
    row = conn.execute("SELECT * FROM warden_assignments WHERE warden_id = ?", (warden_id,)).fetchone()
    if not row:
        return False
    students = json.loads(row["assigned_student_ids"])
    if "*" in students or student_id in students:
        return True
    user = conn.execute("SELECT department FROM users WHERE id = ? AND role = 'student'", (student_id,)).fetchone()
    if not user or not user["department"]:
        return False
    dept = user["department"].lower().strip()
    return any(d.strip() == "*" or d.lower().strip() == dept for d in json.loads(row["assigned_departments"]))


def approver_for_employee(conn: sqlite3.Connection, employee_id: str) -> Optional[str]:
    row = conn.execute("SELECT approver_id FROM employee_approvers WHERE employee_id = ?", (employee_id,)).fetchone()
    return row["approver_id"] if row else None


def can_decide_employee_leave(conn: sqlite3.Connection, caller: Dict[str, Any], applicant_id: str) -> bool:
    """Admin, or the explicitly assigned approver. Never the applicant, never a student."""
    if caller["role"] == "student" or caller["sub"] == applicant_id:
        return False
    if caller["role"] == "admin":
        return True
    return caller["role"] in ("teacher", "faculty", "warden") and approver_for_employee(conn, applicant_id) == caller["sub"]


# -----------------------------------------------------------------------------
# HTTP Request Handler
# -----------------------------------------------------------------------------

class CampusApiHandler(BaseHTTPRequestHandler):
    server_version = "CampusOS-Backend/1.0"

    def _send_cors(self):
        origin = self.headers.get("Origin", "")
        if origin and origin in CORS_ORIGINS:
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, Accept")

    def do_OPTIONS(self):
        self.send_response(204)
        self._send_cors()
        self.end_headers()

    def _json_response(self, data: Any, status: int = 200):
        body = json.dumps(data, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self._send_cors()
        self.end_headers()
        self.wfile.write(body)

    def _error(self, status: int, message: str, code: str = "error"):
        self._json_response({"error": {"code": code, "message": message}, "detail": message}, status=status)

    def _read_json(self) -> Optional[Dict[str, Any]]:
        try:
            length = int(self.headers.get("Content-Length", 0))
            if length <= 0:
                return {}
            if length > MAX_BODY_BYTES:
                return None
            data = json.loads(self.rfile.read(length).decode("utf-8"))
            return data if isinstance(data, dict) else None
        except Exception:
            return None

    def _authenticate(self) -> Optional[Dict[str, Any]]:
        auth_header = self.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return None
        token = auth_header[7:].strip()
        return verify_token(token)

    # -------------------------------------------------------------------------
    # Route Dispatchers
    # -------------------------------------------------------------------------

    def do_GET(self):
        path = self.path.split("?")[0].rstrip("/")
        self._include_decided = "status=all" in self.path.partition("?")[2]

        if path == "/api/health":
            return self._json_response({
                "status": "ok",
                "service": "CampusOS REST API & Leave Server",
                "version": "1.0.0",
                "timestamp": datetime.now(timezone.utc).isoformat(),
            })

        user = self._authenticate()
        if not user:
            return self._error(401, "Missing or invalid Authorization Bearer token.", code="unauthorized")

        # GET /api/erp/leaves
        if path == "/api/erp/leaves":
            return self._handle_get_all_leaves(user)

        # GET /api/erp/leaves/student/<id>
        if path.startswith("/api/erp/leaves/student/"):
            student_id = path.split("/")[-1]
            return self._handle_get_student_leaves(user, student_id)

        # GET /api/erp/leaves/warden/<id>
        if path.startswith("/api/erp/leaves/warden/"):
            warden_id = path.split("/")[-1]
            return self._handle_get_warden_inbox(user, warden_id)

        # GET /api/erp/leaves/employee/<id>   (own history, or admin)
        if path.startswith("/api/erp/leaves/employee/"):
            return self._handle_get_employee_leaves(user, path.split("/")[-1])

        # GET /api/erp/leaves/approver/<id>   (assigned approver's employee-leave inbox)
        if path.startswith("/api/erp/leaves/approver/"):
            return self._handle_get_approver_inbox(user, path.split("/")[-1])

        # GET /api/erp/employees
        if path == "/api/erp/employees":
            return self._handle_get_employees(user)

        # GET /api/erp/leaves/<id>
        if path.startswith("/api/erp/leaves/"):
            leave_id = path.split("/")[-1]
            return self._handle_get_single_leave(user, leave_id)

        return self._error(404, f"Endpoint {path} not found.", code="not_found")

    def do_POST(self):
        path = self.path.split("?")[0].rstrip("/")

        # POST /api/auth/login (public)
        if path == "/api/auth/login":
            return self._handle_login()

        user = self._authenticate()
        if not user:
            return self._error(401, "Missing or invalid Authorization Bearer token.", code="unauthorized")

        # POST /api/erp/leaves
        if path == "/api/erp/leaves":
            return self._handle_create_leave(user)

        # POST /api/erp/admin/employee-approvers   {"employeeId": "...", "approverId": "..."}  (admin only)
        if path == "/api/erp/admin/employee-approvers":
            return self._handle_set_employee_approver(user)

        # POST /api/erp/leaves/<id>/decision
        if re.match(r"^/api/erp/leaves/[^/]+/decision$", path):
            leave_id = path.split("/")[4]
            return self._handle_leave_decision(user, leave_id)

        # POST /api/erp/leaves/<id>/cancel
        if re.match(r"^/api/erp/leaves/[^/]+/cancel$", path):
            leave_id = path.split("/")[4]
            return self._handle_leave_cancel(user, leave_id)

        return self._error(404, f"Endpoint {path} not found.", code="not_found")

    # -------------------------------------------------------------------------
    # Route Implementations
    # -------------------------------------------------------------------------

    def _handle_login(self):
        body = self._read_json()
        if not body or "id" not in body or "password" not in body:
            return self._error(400, "Fields 'id' and 'password' are required.", code="bad_request")

        uid = str(body["id"]).strip()
        pwd = str(body["password"])

        now = time.time()
        recent = [t for t in _login_failures.get(uid, []) if now - t < LOGIN_LOCK_SEC]
        if len(recent) >= LOGIN_MAX_FAILURES:
            return self._error(429, "Too many failed attempts. Try again in a few minutes.", code="rate_limited")

        conn = get_db()
        cur = conn.cursor()
        cur.execute("SELECT * FROM users WHERE id = ?", (uid,))
        user = cur.fetchone()
        conn.close()

        if not user or not verify_password(pwd, user["password_hash"]):
            _login_failures[uid] = recent + [now]
            return self._error(401, "Invalid Roll Number / Employee ID or password.", code="invalid_credentials")
        _login_failures.pop(uid, None)

        token_data = issue_token(sub=user["id"], name=user["name"], role=user["role"])
        return self._json_response(token_data)

    def _handle_create_leave(self, caller: Dict[str, Any]):
        body = self._read_json()
        if not body:
            return self._error(400, "Empty or invalid JSON body.", code="bad_request")

        reason = str(body.get("reason", "")).strip()
        leave_type = str(body.get("leaveType", "")).strip()
        start_date_str = str(body.get("startDate", "")).strip()
        end_date_str = str(body.get("endDate", "")).strip()

        if not reason or len(reason) < 10:
            return self._error(400, "Reason must be substantive (minimum 10 characters).", code="validation_error")
        if not leave_type:
            return self._error(400, "Leave category is required.", code="validation_error")

        try:
            start_date = datetime.fromisoformat(start_date_str.replace("Z", "+00:00"))
            end_date = datetime.fromisoformat(end_date_str.replace("Z", "+00:00"))
            if end_date < start_date:
                return self._error(400, "Leave end date cannot precede start date.", code="validation_error")
        except Exception:
            return self._error(400, "Invalid start or end date format.", code="validation_error")

        conn = get_db()
        cur = conn.cursor()

        # Enforce server-derived applicant ID (Prevent client spoofing)
        applicant_id = caller["sub"]
        cur.execute("SELECT name, department, role FROM users WHERE id = ?", (applicant_id,))
        user_row = cur.fetchone()
        applicant_name = user_row["name"] if user_row else caller.get("name", "Student")
        applicant_role = "student" if (user_row["role"] if user_row else caller.get("role")) == "student" else "employee"
        dept = (user_row["department"] if user_row else None) or "General"  # server record, not client input
        hostel = (str(body.get("hostel") or "")[:80] or None) if applicant_role == "student" else None  # display only; never used for routing

        # Resolve assigned warden
        assigned_warden_id = None  # unassigned students are visible to admins only
        # For employee leave the column holds the explicitly assigned approver instead of a warden.
        if applicant_role == "employee":
            assigned_warden_id = approver_for_employee(conn, applicant_id)
        cur.execute("SELECT * FROM warden_assignments")
        for row in (cur.fetchall() if applicant_role == "student" else []):
            if "*" in json.loads(row["assigned_student_ids"]):
                continue  # superadmin sees everything; never the routed warden
            if is_student_assigned_to_warden(conn, row["warden_id"], applicant_id):
                assigned_warden_id = row["warden_id"]
                break

        now_iso = datetime.now(timezone.utc).isoformat()
        leave_id = f"LEAVE-{datetime.now().year}-{secrets.token_hex(4).upper()}"

        cur.execute(
            "SELECT 1 FROM leaves WHERE applicant_id = ? AND status = 'pending' AND leave_type = ? AND start_date = ? AND end_date = ?",
            (applicant_id, leave_type, start_date.isoformat(), end_date.isoformat()),
        )
        if cur.fetchone():
            conn.close()
            return self._error(409, "An identical pending leave request already exists.", code="conflict")

        try:
            with conn:
                conn.execute("""
                INSERT INTO leaves (
                    id, applicant_id, applicant_name, applicant_role, department, hostel,
                    assigned_warden_id, leave_type, start_date, end_date, reason,
                    destination_address, emergency_contact, status, applied_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?)
                """, (
                    leave_id, applicant_id, applicant_name, applicant_role, dept, hostel,
                    assigned_warden_id, leave_type, start_date.isoformat(), end_date.isoformat(),
                    reason, body.get("destinationAddress"), body.get("emergencyContact"), now_iso
                ))
                conn.execute("""
                INSERT INTO leave_audit (leave_id, actor_id, actor_name, actor_role, action, remarks, timestamp)
                VALUES (?, ?, ?, ?, 'SUBMITTED', 'Official leave application submitted and persisted on server', ?)
                """, (leave_id, applicant_id, applicant_name, applicant_role, now_iso))
        except sqlite3.IntegrityError as e:
            conn.close()
            return self._error(409, "Leave could not be saved (conflict).", code="conflict")

        leave_dict = self._fetch_full_leave(conn, leave_id)
        conn.close()
        return self._json_response(leave_dict, status=201)

    def _handle_get_all_leaves(self, caller: Dict[str, Any]):
        conn = get_db()
        cur = conn.cursor()
        role = caller["role"]
        sub = caller["sub"]

        if role == "student":
            cur.execute("SELECT id FROM leaves WHERE applicant_id = ? ORDER BY applied_at DESC", (sub,))
        elif role in ("teacher", "faculty", "warden"):
            # Return leaves where warden is assigned
            cur.execute("SELECT id FROM leaves WHERE applicant_role = 'student' ORDER BY applied_at DESC")
        else: # admin
            cur.execute("SELECT id FROM leaves ORDER BY applied_at DESC")

        rows = cur.fetchall()
        result = []
        for r in rows:
            l = self._fetch_full_leave(conn, r["id"])
            if l:
                if role in ("teacher", "faculty", "warden"):
                    if is_student_assigned_to_warden(conn, sub, l["applicantId"]):
                        result.append(l)
                else:
                    result.append(l)
        conn.close()
        return self._json_response({"items": result, "count": len(result)})

    def _handle_get_student_leaves(self, caller: Dict[str, Any], student_id: str):
        # Scoping rule: Caller must be the student themselves or an admin
        if caller["role"] != "admin" and caller["sub"] != student_id:
            return self._error(403, "Access denied: You cannot view another student's leave records.", code="forbidden")

        conn = get_db()
        cur = conn.cursor()
        cur.execute("SELECT id FROM leaves WHERE applicant_id = ? ORDER BY applied_at DESC", (student_id,))
        rows = cur.fetchall()
        leaves = [self._fetch_full_leave(conn, r["id"]) for r in rows]
        conn.close()
        return self._json_response({"items": leaves, "count": len(leaves)})

    def _handle_get_warden_inbox(self, caller: Dict[str, Any], warden_id: str):
        # Scoping rule: Caller must have approver privileges
        if caller["role"] not in ("admin", "teacher", "faculty", "warden"):
            return self._error(403, "Access denied: Approver privileges required.", code="forbidden")

        # Caller can only query their own inbox unless admin
        if caller["role"] != "admin" and caller["sub"] != warden_id:
            return self._error(403, "Access denied: You can only query your own assigned inbox.", code="forbidden")

        conn = get_db()
        cur = conn.cursor()
        status_filter = "" if getattr(self, "_include_decided", False) else "AND status = 'pending'"
        cur.execute(f"SELECT id FROM leaves WHERE applicant_role = 'student' {status_filter} ORDER BY applied_at DESC")
        rows = cur.fetchall()
        assigned_leaves = []
        for r in rows:
            l = self._fetch_full_leave(conn, r["id"])
            if l:
                if caller["role"] == "admin" or is_student_assigned_to_warden(conn, warden_id, l["applicantId"]):
                    assigned_leaves.append(l)
        conn.close()
        return self._json_response({"items": assigned_leaves, "count": len(assigned_leaves)})

    def _handle_leave_decision(self, caller: Dict[str, Any], leave_id: str):
        if caller["role"] not in ("admin", "teacher", "faculty", "warden"):
            return self._error(403, "Access denied: Approver role required.", code="forbidden")

        body = self._read_json() or {}
        new_status = str(body.get("status", "")).lower().strip()
        remarks = str(body.get("remarks", "")).strip() or ("Approved by Warden" if new_status == "approved" else "Rejected by Warden")

        if new_status not in ("approved", "rejected"):
            return self._error(400, "Decision status must be 'approved' or 'rejected'.", code="bad_request")

        conn = get_db()
        cur = conn.cursor()
        cur.execute("SELECT * FROM leaves WHERE id = ?", (leave_id,))
        row = cur.fetchone()
        if not row:
            conn.close()
            return self._error(404, f"Leave application {leave_id} not found.", code="not_found")

        # Atomic State Transition Guard
        if row["status"] != "pending":
            conn.close()
            return self._error(409, f"Application #{leave_id} has already been decided ({row['status']}) by {row['decided_by'] or 'approver'}.", code="conflict")

        # Authorization differs by kind: employee leave needs the explicitly assigned approver (or admin, never the applicant);
        # student leave needs the assigned warden (or admin).
        if row["applicant_role"] == "employee":
            if not can_decide_employee_leave(conn, caller, row["applicant_id"]):
                conn.close()
                return self._error(403, "Access denied: you are not the assigned approver for this employee.", code="forbidden")
        elif caller["role"] != "admin":
            if not is_student_assigned_to_warden(conn, caller["sub"], row["applicant_id"]):
                conn.close()
                return self._error(403, "Access denied: You are not assigned to this student.", code="forbidden")

        now_iso = datetime.now(timezone.utc).isoformat()
        with conn:
            conn.execute("""
            UPDATE leaves
            SET status = ?, decision_remarks = ?, decided_by = ?, decided_by_id = ?, decided_at = ?
            WHERE id = ? AND status = 'pending'
            """, (new_status, remarks, caller.get("name", "Warden"), caller["sub"], now_iso, leave_id))

            conn.execute("""
            INSERT INTO leave_audit (leave_id, actor_id, actor_name, actor_role, action, remarks, timestamp)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (leave_id, caller["sub"], caller.get("name", "Warden"), caller["role"], new_status.upper(), remarks, now_iso))

        updated_leave = self._fetch_full_leave(conn, leave_id)
        conn.close()
        return self._json_response(updated_leave)

    def _handle_leave_cancel(self, caller: Dict[str, Any], leave_id: str):
        conn = get_db()
        cur = conn.cursor()
        cur.execute("SELECT * FROM leaves WHERE id = ?", (leave_id,))
        row = cur.fetchone()
        if not row:
            conn.close()
            return self._error(404, f"Leave application {leave_id} not found.", code="not_found")

        # Authorization: Applicant only
        if row["applicant_id"] != caller["sub"] and caller["role"] != "admin":
            conn.close()
            return self._error(403, "Access denied: You cannot cancel another student's leave.", code="forbidden")

        # Atomic Status Guard: Pending only
        if row["status"] != "pending":
            conn.close()
            return self._error(409, f"Cannot cancel: Current status is already {row['status']}.", code="conflict")

        now_iso = datetime.now(timezone.utc).isoformat()
        with conn:
            conn.execute("UPDATE leaves SET status = 'cancelled' WHERE id = ? AND status = 'pending'", (leave_id,))
            conn.execute("""
            INSERT INTO leave_audit (leave_id, actor_id, actor_name, actor_role, action, remarks, timestamp)
            VALUES (?, ?, ?, ?, 'CANCELLED', 'Cancelled by student', ?)
            """, (leave_id, caller["sub"], caller.get("name", "Student"), caller["role"], now_iso))

        cancelled_leave = self._fetch_full_leave(conn, leave_id)
        conn.close()
        return self._json_response(cancelled_leave)

    def _handle_get_employee_leaves(self, caller: Dict[str, Any], employee_id: str):
        # Own history only (admin may view anyone's). Students never reach employee data.
        if caller["role"] == "student" or (caller["role"] != "admin" and caller["sub"] != employee_id):
            return self._error(403, "Access denied: you can only view your own employee leave records.", code="forbidden")
        conn = get_db()
        rows = conn.execute("SELECT id FROM leaves WHERE applicant_id = ? AND applicant_role = 'employee' ORDER BY applied_at DESC", (employee_id,)).fetchall()
        leaves = [self._fetch_full_leave(conn, r["id"]) for r in rows]
        conn.close()
        return self._json_response({"items": leaves, "count": len(leaves)})

    def _handle_get_approver_inbox(self, caller: Dict[str, Any], approver_id: str):
        if caller["role"] not in ("admin", "teacher", "faculty", "warden"):
            return self._error(403, "Access denied: approver privileges required.", code="forbidden")
        if caller["role"] != "admin" and caller["sub"] != approver_id:
            return self._error(403, "Access denied: you can only open your own approval inbox.", code="forbidden")
        conn = get_db()
        status_filter = "" if getattr(self, "_include_decided", False) else "AND status = 'pending'"
        rows = conn.execute(f"SELECT id, applicant_id FROM leaves WHERE applicant_role = 'employee' {status_filter} ORDER BY applied_at DESC").fetchall()
        items = []
        for r in rows:
            if r["applicant_id"] == approver_id:
                continue  # your own requests are never in your own approval queue
            if caller["role"] == "admin" or approver_for_employee(conn, r["applicant_id"]) == approver_id:
                items.append(self._fetch_full_leave(conn, r["id"]))
        conn.close()
        return self._json_response({"items": items, "count": len(items)})

    def _handle_set_employee_approver(self, caller: Dict[str, Any]):
        if caller["role"] != "admin":
            return self._error(403, "Access denied: administrators only.", code="forbidden")
        body = self._read_json() or {}
        employee_id, approver_id = str(body.get("employeeId", "")).strip(), str(body.get("approverId", "")).strip()
        if not employee_id or not approver_id or employee_id == approver_id:
            return self._error(400, "employeeId and approverId are required and must differ.", code="validation_error")
        conn = get_db()
        known = {r["id"]: r["role"] for r in conn.execute("SELECT id, role FROM users").fetchall()}
        if employee_id not in known or known[employee_id] == "student" or known.get(approver_id) not in ("teacher", "admin"):
            conn.close()
            return self._error(400, "employeeId must be a staff account and approverId a teacher or admin account.", code="validation_error")
        with conn:
            conn.execute("INSERT INTO employee_approvers (employee_id, approver_id) VALUES (?, ?) "
                         "ON CONFLICT(employee_id) DO UPDATE SET approver_id = excluded.approver_id", (employee_id, approver_id))
            conn.execute("UPDATE leaves SET assigned_warden_id = ? WHERE applicant_id = ? AND applicant_role = 'employee' AND status = 'pending'",
                         (approver_id, employee_id))
        conn.close()
        return self._json_response({"employeeId": employee_id, "approverId": approver_id})

    def _handle_get_employees(self, caller: Dict[str, Any]):
        if caller["role"] == "student":
            return self._error(403, "Access denied: staff only.", code="forbidden")
        conn = get_db()
        cur = conn.cursor()
        cur.execute("SELECT * FROM employees")
        rows = cur.fetchall()
        emps = []
        for r in rows:
            emps.append({
                "id": r["id"],
                "name": r["name"],
                "department": r["department"],
                "designation": r["designation"],
                "email": r["email"],
                "phone": r["phone"],
                "status": r["status"],
                "leaveBalance": json.loads(r["leave_balance"]),
            })
        conn.close()
        return self._json_response({"items": emps, "count": len(emps)})

    def _handle_get_single_leave(self, caller: Dict[str, Any], leave_id: str):
        conn = get_db()
        leave = self._fetch_full_leave(conn, leave_id)
        conn.close()
        if not leave:
            return self._error(404, f"Leave #{leave_id} not found.", code="not_found")

        # Authorization check
        if caller["role"] != "admin" and leave["applicantId"] != caller["sub"]:
            conn = get_db()
            if leave["applicantRole"] == "employee":
                allowed = caller["role"] in ("teacher", "faculty", "warden") and approver_for_employee(conn, leave["applicantId"]) == caller["sub"]
                conn.close()
                return self._json_response(leave) if allowed else self._error(403, "Access denied to private leave record.", code="forbidden")
            assigned = (
                caller["role"] in ("teacher", "faculty", "warden")
                and is_student_assigned_to_warden(conn, caller["sub"], leave["applicantId"])
            )
            conn.close()
            if not assigned:
                return self._error(403, "Access denied to private leave record.", code="forbidden")

        return self._json_response(leave)

    def _fetch_full_leave(self, conn: sqlite3.Connection, leave_id: str) -> Optional[Dict[str, Any]]:
        cur = conn.cursor()
        cur.execute("SELECT * FROM leaves WHERE id = ?", (leave_id,))
        row = cur.fetchone()
        if not row:
            return None

        cur.execute("SELECT * FROM leave_audit WHERE leave_id = ? ORDER BY id ASC", (leave_id,))
        audit_rows = cur.fetchall()
        audit_trail = [{
            "actorId": a["actor_id"],
            "actorName": a["actor_name"],
            "actorRole": a["actor_role"],
            "action": a["action"],
            "remarks": a["remarks"],
            "timestamp": a["timestamp"],
        } for a in audit_rows]

        return {
            "id": row["id"],
            "applicantId": row["applicant_id"],
            "applicantName": row["applicant_name"],
            "applicantRole": row["applicant_role"],
            "department": row["department"],
            "hostel": row["hostel"],
            "assignedWardenId": row["assigned_warden_id"],
            "leaveType": row["leave_type"],
            "startDate": row["start_date"],
            "endDate": row["end_date"],
            "reason": row["reason"],
            "destinationAddress": row["destination_address"],
            "emergencyContact": row["emergency_contact"],
            "status": row["status"],
            "appliedAt": row["applied_at"],
            "decisionRemarks": row["decision_remarks"],
            "decidedBy": row["decided_by"],
            "decidedById": row["decided_by_id"],
            "decidedAt": row["decided_at"],
            "auditTrail": audit_trail,
        }


# -----------------------------------------------------------------------------
# Server Entry Point
# -----------------------------------------------------------------------------

def run_server(port: int = 8000, host: str = "0.0.0.0") -> None:
    check_startup_config()
    init_db()
    server_address = (host, port)
    httpd = ThreadingHTTPServer(server_address, CampusApiHandler)
    print(f"CampusOS Backend REST API running at http://{host}:{port} (Database: {DB_PATH})")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down CampusOS Backend Server...")
        httpd.server_close()


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else int(os.environ.get("PORT", 8000))
    run_server(port=port)
