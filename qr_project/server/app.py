"""Goi mon tai ban bang QR - ban day du: nhieu chi nhanh, VietQR, danh gia mon,
API cho app Android (Kivy).   Chay:  python app.py
"""
import io
import json
import time
import urllib.request
import secrets
from functools import wraps
import os
import uuid
import re
import socket
import sqlite3
import unicodedata
from werkzeug.middleware.proxy_fix import ProxyFix
from werkzeug.security import check_password_hash, generate_password_hash
from flask import (Flask, abort, flash, g, jsonify, redirect, render_template,
                   request, send_file, session, url_for)
import qrcode

DATA_DIR = os.environ.get("DATA_DIR", os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(DATA_DIR, "restaurant.db")
PORT = int(os.environ.get("PORT", 5000))
# Dia chi cong khai (internet) cua server, vd https://quan-abc.onrender.com
# De trong = tu nhan theo dia chi dang truy cap trang /qr.
PUBLIC_URL = os.environ.get("PUBLIC_URL", "").strip().rstrip("/")
STATUS = {"new": "Mới", "cooking": "Đang chế biến", "served": "Đã phục vụ",
          "cancelled": "Đã hủy"}
BANKS = {"970436": "Vietcombank", "970415": "VietinBank", "970418": "BIDV",
         "970405": "Agribank", "970407": "Techcombank", "970422": "MB Bank",
         "970416": "ACB", "970432": "VPBank", "970403": "Sacombank",
         "970423": "TPBank"}
DEFAULT_MENU = [
    ("Mâm cơm", "Mâm cơm 2 người (3 món + canh)", 149000, "🍱"),
    ("Mâm cơm", "Mâm cơm 4 người (5 món + canh)", 289000, "🍱"),
    ("Món mặn", "Thịt kho trứng (2–3 người)", 85000, "🥘"),
    ("Món mặn", "Cá kho tộ (2–3 người)", 95000, "🐟"),
    ("Món mặn", "Sườn rim mặn ngọt", 90000, "🍖"),
    ("Món mặn", "Gà chiên nước mắm", 110000, "🍗"),
    ("Món mặn", "Đậu hũ sốt cà", 55000, "🍅"),
    ("Món mặn", "Trứng chiên thịt băm", 45000, "🍳"),
    ("Canh", "Canh chua cá lóc", 90000, "🍲"),
    ("Canh", "Canh bí đỏ nấu tôm", 60000, "🥣"),
    ("Canh", "Canh rau ngót thịt băm", 50000, "🥬"),
    ("Rau", "Rau muống xào tỏi", 40000, "🥬"),
    ("Rau", "Rau luộc chấm kho quẹt", 35000, "🥕"),
    ("Cơm & ăn kèm", "Cơm trắng", 8000, "🍚"),
    ("Cơm & ăn kèm", "Dưa leo, cà pháo muối", 15000, "🥒"),
    ("Đồ uống", "Trà đá", 5000, "🧊"),
    ("Đồ uống", "Nước sâm", 15000, "🍵"),
    ("Đồ uống", "Nước chanh muối", 20000, "🍋"),
]

app = Flask(__name__)
def _secret():
    """Khoa ky phien dang nhap: lay tu bien SECRET_KEY, neu khong thi tu sinh
    ngau nhien va luu vao file (khong de khoa mac dinh de ai cung biet)."""
    if os.environ.get("SECRET_KEY"):
        return os.environ["SECRET_KEY"]
    path = os.path.join(DATA_DIR, ".secret_key")
    if not os.path.exists(path):
        with open(path, "w") as fh:
            fh.write(secrets.token_hex(32))
    return open(path).read().strip()


app.secret_key = _secret()
app.config["SESSION_COOKIE_SAMESITE"] = "Lax"
app.config["PERMANENT_SESSION_LIFETIME"] = 60 * 60 * 24 * 7
# Chay sau proxy/tunnel (Cloudflare, ngrok, Render...) van nhan dung https + ten mien
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1)
app.config["MAX_CONTENT_LENGTH"] = 6 * 1024 * 1024      # anh toi da 6MB
UPLOAD_DIR = os.environ.get("UPLOAD_DIR", os.path.join(app.static_folder, "uploads"))
ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
os.makedirs(UPLOAD_DIR, exist_ok=True)


@app.errorhandler(413)
def too_big(_):
    return "Ảnh quá lớn (tối đa 6MB). Hãy quay lại và chọn ảnh nhỏ hơn.", 413


# ================= Database =================
def get_db():
    if "db" not in g:
        g.db = sqlite3.connect(DB)
        g.db.row_factory = sqlite3.Row
    return g.db


@app.teardown_appcontext
def close_db(_):
    db = g.pop("db", None)
    if db:
        db.close()


def init_db():
    db = sqlite3.connect(DB)
    db.executescript("""
    CREATE TABLE IF NOT EXISTS branches(
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, address TEXT,
        tables INTEGER DEFAULT 10, bank_bin TEXT, bank_account TEXT,
        bank_holder TEXT);
    CREATE TABLE IF NOT EXISTS menu(
        id INTEGER PRIMARY KEY AUTOINCREMENT, branch_id INTEGER,
        category TEXT, name TEXT, price INTEGER, emoji TEXT,
        available INTEGER DEFAULT 1, image TEXT);
    CREATE TABLE IF NOT EXISTS orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT, branch_id INTEGER,
        table_no INTEGER, note TEXT, total INTEGER, status TEXT DEFAULT 'new',
        paid INTEGER DEFAULT 0,
        created TEXT DEFAULT (datetime('now','localtime')));
    CREATE TABLE IF NOT EXISTS order_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT, order_id INTEGER,
        name TEXT, price INTEGER, qty INTEGER);
    CREATE TABLE IF NOT EXISTS calls(
        id INTEGER PRIMARY KEY AUTOINCREMENT, branch_id INTEGER,
        table_no INTEGER, kind TEXT DEFAULT 'staff', done INTEGER DEFAULT 0,
        created TEXT DEFAULT (datetime('now','localtime')));
    CREATE TABLE IF NOT EXISTS users(
        id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT UNIQUE,
        password TEXT, role TEXT, branch_id INTEGER, name TEXT);
    CREATE TABLE IF NOT EXISTS ratings(
        id INTEGER PRIMARY KEY AUTOINCREMENT, branch_id INTEGER,
        order_id INTEGER, item_name TEXT, stars INTEGER, comment TEXT,
        created TEXT DEFAULT (datetime('now','localtime')));
    """)
    try:                                   # nang cap DB cu
        db.execute("ALTER TABLE menu ADD COLUMN image TEXT")
    except sqlite3.OperationalError:
        pass
    if db.execute("SELECT COUNT(*) FROM branches").fetchone()[0] == 0:
        for name, addr in (("Chi nhánh Quận 1", "12 Nguyễn Huệ, Q1, TP.HCM"),
                           ("Chi nhánh Thủ Đức", "45 Võ Văn Ngân, Thủ Đức")):
            cur = db.execute(
                "INSERT INTO branches(name,address,bank_bin,bank_account,"
                "bank_holder) VALUES(?,?,?,?,?)",
                (name, addr, "970436", "0123456789", "NGUYEN VAN A"))
            db.executemany(
                "INSERT INTO menu(branch_id,category,name,price,emoji) "
                "VALUES(?,?,?,?,?)", [(cur.lastrowid, *m) for m in DEFAULT_MENU])
    if db.execute("SELECT COUNT(*) FROM users").fetchone()[0] == 0:
        for u, pw, role, nm in (("admin", "admin123", "admin", "Quản trị"),
                                ("nhanvien", "nv123", "staff", "Nhân viên"),
                                ("bep", "bep123", "kitchen", "Bếp")):
            db.execute("INSERT INTO users(username,password,role,branch_id,"
                       "name) VALUES(?,?,?,?,?)",
                       (u, generate_password_hash(pw), role,
                        None if role == "admin" else 1, nm))
        print(">>> Tai khoan mac dinh: admin/admin123, nhanvien/nv123, "
              "bep/bep123  -> HAY DOI MAT KHAU trong Admin > Tai khoan")
    db.commit()
    db.close()


def lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


_tunnel = {"t": 0.0, "url": None}


def tunnel_url():
    """Neu cloudflared dang chay tren may nay, hoi no xem link Internet hien tai
    (cloudflared mo cong thong ke 127.0.0.1:20241 → /quicktunnel)."""
    now = time.time()
    if now - _tunnel["t"] < 10:
        return _tunnel["url"]
    _tunnel["t"], _tunnel["url"] = now, None
    for port in range(20241, 20246):
        try:
            with urllib.request.urlopen(
                    f"http://127.0.0.1:{port}/quicktunnel", timeout=0.5) as r:
                host = json.load(r).get("hostname")
            if host:
                _tunnel["url"] = "https://" + host
                break
        except Exception:
            continue
    return _tunnel["url"]


def base_url():
    """Dia chi goc dung de ma hoa vao QR: PUBLIC_URL > dia chi dang truy cap
    (neu la ten mien/IP cong khai) > link cloudflared dang chay > IP mang LAN."""
    if PUBLIC_URL:
        return PUBLIC_URL
    host = request.host.split(":")[0]
    if host not in ("localhost", "127.0.0.1", "0.0.0.0", "10.0.2.2"):
        return request.host_url.rstrip("/")
    return tunnel_url() or f"http://{lan_ip()}:{PORT}"


def is_public_url(u):
    h = re.sub(r"^https?://", "", u).split(":")[0].split("/")[0]
    return not (h == "localhost" or re.match(
        r"^(127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)", h))


DRINK_WORDS = ("uống", "nước", "bia", "rượu", "giải khát", "sinh tố",
               "cà phê", "cafe", "trà")


def is_drink_cat(cat):
    """Nhom do uong: ten nhom chua 1 trong cac tu khoa o tren."""
    c = (cat or "").lower()
    return any(w in c for w in DRINK_WORDS)


@app.template_filter("vnd")
def vnd(v):
    return f"{int(v or 0):,}".replace(",", ".") + "đ"


def img_url(d):
    d["image"] = f"/static/uploads/{d['image']}" if d.get("image") else None
    return d


def save_image(file):
    """Luu anh upload, tra ve ten file (hoac None neu khong co/sai dinh dang)."""
    if not file or not file.filename:
        return None
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in ALLOWED_EXT:
        return None
    name = uuid.uuid4().hex + ext
    file.save(os.path.join(UPLOAD_DIR, name))
    return name


def drop_image(name):
    """Xoa file anh neu khong con mon nao dung (chi nhanh khac co the dung chung)."""
    if not name:
        return
    n = get_db().execute("SELECT COUNT(*) FROM menu WHERE image=?",
                         (name,)).fetchone()[0]
    if n == 0:
        try:
            os.remove(os.path.join(UPLOAD_DIR, name))
        except OSError:
            pass


def get_branch(bid):
    b = get_db().execute("SELECT * FROM branches WHERE id=?", (bid,)).fetchone()
    if not b:
        abort(404)
    return b


ROLES = {"admin": "Quản trị", "staff": "Nhân viên", "kitchen": "Bếp"}


def current_user():
    if "user" not in g:
        g.user = None
        uid = session.get("uid")
        if uid:
            g.user = get_db().execute("SELECT * FROM users WHERE id=?",
                                      (uid,)).fetchone()
    return g.user


def need(*roles):
    """Chi cho phep cac vai tro nay (admin luon duoc phep)."""
    def deco(f):
        @wraps(f)
        def wrapper(*a, **k):
            u = current_user()
            if not u:
                if request.path.startswith("/api/"):
                    return jsonify(error="Cần đăng nhập"), 401
                nxt = request.full_path.rstrip("?") if request.method == "GET" else ""
                return redirect(url_for("login", next=nxt))
            if u["role"] != "admin" and u["role"] not in roles:
                if request.path.startswith("/api/"):
                    return jsonify(error="Không có quyền"), 403
                return render_template("forbidden.html"), 403
            return f(*a, **k)
        return wrapper
    return deco


def cur_branch():
    u = current_user()
    if u and u["role"] != "admin" and u["branch_id"]:
        return int(u["branch_id"])        # nhan vien/bep chi thay chi nhanh cua minh
    return int(session.get("branch", 1))


@app.context_processor
def inject_nav():
    rows = get_db().execute("SELECT id,name FROM branches").fetchall()
    return dict(all_branches=rows, cur_bid=cur_branch(), user=current_user(),
                ROLES=ROLES)


# ================= Dang nhap =================
@app.route("/login", methods=["GET", "POST"])
def login():
    err = None
    nxt = request.values.get("next", "")
    if request.method == "POST":
        u = get_db().execute("SELECT * FROM users WHERE username=?",
                             (request.form.get("username", "").strip().lower(),)
                             ).fetchone()
        if u and check_password_hash(u["password"], request.form.get("password", "")):
            session.clear()
            session["uid"] = u["id"]
            session.permanent = True
            if u["role"] == "admin" and u["branch_id"]:
                session["branch"] = u["branch_id"]
            if nxt.startswith("/") and not nxt.startswith("//"):
                return redirect(nxt)
            return redirect(url_for(HOME_OF[u["role"]]))
        err = "Sai tên đăng nhập hoặc mật khẩu"
    return render_template("login.html", err=err, next=nxt)


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


HOME_OF = {"admin": "admin", "staff": "staff", "kitchen": "kitchen"}


def orders_with_items(rows):
    db = get_db()
    return [(o, db.execute("SELECT * FROM order_items WHERE order_id=?",
                           (o["id"],)).fetchall()) for o in rows]


# ================= VietQR (EMVCo) =================
def _tlv(tag, val):
    return f"{tag}{len(val):02d}{val}"


def _crc16(s):
    crc = 0xFFFF
    for b in s.encode():
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if crc & 0x8000 else crc << 1
            crc &= 0xFFFF
    return f"{crc:04X}"


def _ascii(s):
    s = unicodedata.normalize("NFD", s).replace("đ", "d").replace("Đ", "D")
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return re.sub(r"[^A-Za-z0-9 ]", "", s)[:25]


def vietqr_payload(bank_bin, account, amount, info):
    """Chuoi VietQR tinh theo chuan NAPAS (quet duoc bang moi app ngan hang)."""
    acc = _tlv("00", bank_bin) + _tlv("01", account)
    merchant = (_tlv("00", "A000000727") + _tlv("01", acc)
                + _tlv("02", "QRIBFTTA"))
    p = (_tlv("00", "01") + _tlv("01", "12") + _tlv("38", merchant)
         + _tlv("53", "704") + _tlv("54", str(int(amount)))
         + _tlv("58", "VN") + _tlv("62", _tlv("08", _ascii(info))) + "6304")
    return p + _crc16(p)


def unpaid_total(bid, table_no):
    return get_db().execute(
        "SELECT COALESCE(SUM(total),0) FROM orders WHERE branch_id=? AND "
        "table_no=? AND paid=0 AND status!='cancelled'",
        (bid, table_no)).fetchone()[0]


def pay_payload(br, table_no):
    total = unpaid_total(br["id"], table_no)
    return total, vietqr_payload(br["bank_bin"], br["bank_account"], total,
                                 f"Ban {table_no} CN{br['id']}")


def png_response(text):
    buf = io.BytesIO()
    qrcode.make(text).save(buf, format="PNG")
    buf.seek(0)
    return send_file(buf, mimetype="image/png")


@app.route("/admin/branch/<int:bid>")
@need()
def switch_branch(bid):
    get_branch(bid)
    session["branch"] = bid
    return redirect(request.referrer or url_for("admin"))


# ================= Khach hang =================
@app.route("/")
def home():
    rows = get_db().execute("SELECT * FROM branches").fetchall()
    return render_template("home.html", rows=rows)


@app.route("/b/<int:bid>/")
def branch_page(bid):
    return render_template("branch.html", br=get_branch(bid))


@app.route("/b/<int:bid>/table/<int:t>")
def menu(bid, t):
    br = get_branch(bid)
    rows = get_db().execute(
        "SELECT m.*, (SELECT AVG(stars) FROM ratings r WHERE r.branch_id="
        "m.branch_id AND r.item_name=m.name) avg, (SELECT COUNT(*) FROM "
        "ratings r WHERE r.branch_id=m.branch_id AND r.item_name=m.name) cnt "
        "FROM menu m WHERE branch_id=? ORDER BY id", (bid,)).fetchall()
    cats = {}
    for r in rows:
        cats.setdefault(r["category"], []).append(dict(r))
    prices = {r["id"]: r["price"] for r in rows if r["available"]}
    kinds = {r["id"]: ("drink" if is_drink_cat(r["category"]) else "food")
             for r in rows}
    drink_cats = [c for c in cats if is_drink_cat(c)]
    return render_template("menu.html", br=br, t=t, cats=cats, prices=prices,
                           kinds=kinds, drink_cats=drink_cats)


@app.route("/b/<int:bid>/table/<int:t>/orders")
def table_orders(bid, t):
    br = get_branch(bid)
    rows = get_db().execute(
        "SELECT * FROM orders WHERE branch_id=? AND table_no=? AND paid=0 "
        "ORDER BY id DESC", (bid, t)).fetchall()
    total = sum(o["total"] for o in rows if o["status"] != "cancelled")
    return render_template("table_orders.html", br=br, t=t, total=total,
                           data=orders_with_items(rows), status=STATUS)


@app.route("/b/<int:bid>/table/<int:t>/pay")
def pay_page(bid, t):
    br = get_branch(bid)
    total, _ = pay_payload(br, t)
    return render_template("pay.html", br=br, t=t, total=total,
                           bank=BANKS.get(br["bank_bin"], br["bank_bin"]))


@app.route("/b/<int:bid>/table/<int:t>/pay.png")
def pay_png(bid, t):
    return png_response(pay_payload(get_branch(bid), t)[1])


@app.route("/order/<int:oid>")
def order_status(oid):
    db = get_db()
    o = db.execute("SELECT * FROM orders WHERE id=?", (oid,)).fetchone()
    if not o:
        abort(404)
    items = db.execute("SELECT * FROM order_items WHERE order_id=?",
                       (oid,)).fetchall()
    rated = db.execute("SELECT 1 FROM ratings WHERE order_id=?",
                       (oid,)).fetchone() is not None
    return render_template("order.html", o=o, items=items, status=STATUS,
                           rated=rated)


# ================= API (web + app Android) =================
@app.route("/api/branches")
def api_branches():
    rows = get_db().execute("SELECT id,name,address,tables FROM branches")
    return jsonify([dict(r) for r in rows])


@app.route("/api/b/<int:bid>/menu")
def api_menu(bid):
    br = get_branch(bid)
    rows = get_db().execute(
        "SELECT m.id,m.category,m.name,m.price,m.emoji,m.image,m.available, (SELECT "
        "AVG(stars) FROM ratings r WHERE r.branch_id=m.branch_id AND "
        "r.item_name=m.name) avg FROM menu m WHERE branch_id=? ORDER BY id",
        (bid,)).fetchall()
    return jsonify(branch=br["name"], tables=br["tables"],
                   items=[img_url(dict(r)) for r in rows])


@app.route("/api/b/<int:bid>/table/<int:t>/pay")
def api_pay(bid, t):
    br = get_branch(bid)
    total, payload = pay_payload(br, t)
    return jsonify(total=total, payload=payload, holder=br["bank_holder"],
                   bank=BANKS.get(br["bank_bin"], br["bank_bin"]),
                   account=br["bank_account"])


@app.route("/api/order", methods=["POST"])
def create_order():
    data = request.get_json(force=True)
    bid = int(data.get("branch", 1))
    db = get_db()
    total, lines = 0, []
    for it in data.get("items", []):
        qty = min(int(it.get("qty", 0)), 50)
        row = db.execute("SELECT * FROM menu WHERE id=? AND branch_id=? AND "
                         "available=1", (it.get("id"), bid)).fetchone()
        if row and qty > 0:
            total += row["price"] * qty
            lines.append((row["name"], row["price"], qty))
    if not lines:
        return jsonify(error="Giỏ hàng trống hoặc món đã hết"), 400
    cur = db.execute("INSERT INTO orders(branch_id,table_no,note,total) "
                     "VALUES(?,?,?,?)", (bid, int(data["table"]),
                                         data.get("note", "")[:200], total))
    oid = cur.lastrowid
    db.executemany("INSERT INTO order_items(order_id,name,price,qty) "
                   "VALUES(?,?,?,?)", [(oid, *l) for l in lines])
    db.commit()
    return jsonify(order_id=oid)


@app.route("/api/order/<int:oid>")
def order_api(oid):
    db = get_db()
    o = db.execute("SELECT * FROM orders WHERE id=?", (oid,)).fetchone()
    if not o:
        return jsonify(error="not found"), 404
    items = db.execute("SELECT name,price,qty FROM order_items WHERE "
                       "order_id=?", (oid,)).fetchall()
    rated = db.execute("SELECT 1 FROM ratings WHERE order_id=?",
                       (oid,)).fetchone() is not None
    return jsonify(status=o["status"], status_text=STATUS[o["status"]],
                   total=o["total"], table=o["table_no"], branch=o["branch_id"],
                   rated=rated, items=[dict(i) for i in items])


@app.route("/api/order/<int:oid>/cancel", methods=["POST"])
@need()                                  # chi quan tri (admin) moi huy duoc
def cancel_order(oid):
    db = get_db()
    cur = db.execute("UPDATE orders SET status='cancelled' WHERE id=? AND "
                     "status!='cancelled' AND paid=0", (oid,))
    db.commit()
    if cur.rowcount:
        return jsonify(ok=True)
    return jsonify(error="Không hủy được đơn này"), 400


@app.route("/api/call", methods=["POST"])
def call_staff():
    d = request.get_json(force=True)
    bid, table = int(d.get("branch", 1)), int(d["table"])
    kind = "pay" if d.get("kind") == "pay" else "staff"
    db = get_db()
    if not db.execute("SELECT 1 FROM calls WHERE branch_id=? AND table_no=? "
                      "AND kind=? AND done=0", (bid, table, kind)).fetchone():
        db.execute("INSERT INTO calls(branch_id,table_no,kind) VALUES(?,?,?)",
                   (bid, table, kind))
        db.commit()
    return jsonify(ok=True)


@app.route("/api/rating", methods=["POST"])
def api_rating():
    d = request.get_json(force=True)
    db = get_db()
    o = db.execute("SELECT * FROM orders WHERE id=?",
                   (d.get("order_id"),)).fetchone()
    if not o or o["status"] != "served":
        return jsonify(error="Chỉ đánh giá được khi món đã phục vụ"), 400
    names = {r["name"] for r in db.execute(
        "SELECT name FROM order_items WHERE order_id=?", (o["id"],))}
    db.execute("DELETE FROM ratings WHERE order_id=?", (o["id"],))
    n = 0
    for r in d.get("ratings", []):
        stars = max(1, min(5, int(r.get("stars", 0))))
        if r.get("name") in names:
            db.execute("INSERT INTO ratings(branch_id,order_id,item_name,"
                       "stars,comment) VALUES(?,?,?,?,?)",
                       (o["branch_id"], o["id"], r["name"], stars,
                        d.get("comment", "")[:300] if n == 0 else ""))
            n += 1
    db.commit()
    return jsonify(ok=True, saved=n)


# ================= Bep =================
@app.route("/kitchen")
@need("kitchen")
def kitchen():
    db, bid = get_db(), cur_branch()
    rows = db.execute("SELECT * FROM orders WHERE branch_id=? AND status IN "
                      "('new','cooking') ORDER BY id", (bid,)).fetchall()
    calls = db.execute("SELECT * FROM calls WHERE branch_id=? AND done=0 "
                       "ORDER BY id", (bid,)).fetchall()
    return render_template("kitchen.html", data=orders_with_items(rows),
                           calls=calls, status=STATUS)


@app.route("/api/kitchen/state")
@need("kitchen", "staff")
def kitchen_state():
    db, bid = get_db(), cur_branch()
    o = db.execute("SELECT COALESCE(MAX(id),0) FROM orders WHERE branch_id=?",
                   (bid,)).fetchone()[0]
    c = db.execute("SELECT COALESCE(MAX(id),0) FROM calls WHERE branch_id=?",
                   (bid,)).fetchone()[0]
    ch = db.execute("SELECT COUNT(*)||'-'||COALESCE(SUM(LENGTH(status)),0) "
                    "FROM orders WHERE branch_id=? AND paid=0",
                    (bid,)).fetchone()[0]
    return jsonify(orders=o, calls=c, changed=ch)


@app.route("/kitchen/<int:oid>/<new_status>", methods=["POST"])
@need("kitchen")
def set_status(oid, new_status):
    allowed = {"cooking", "served"}          # bep: nhan lam / da len mon
    if current_user()["role"] == "admin":
        allowed.add("cancelled")             # chi admin moi duoc huy don
    if new_status not in allowed:
        abort(403)
    db = get_db()
    db.execute("UPDATE orders SET status=? WHERE id=? AND branch_id=? AND "
               "status!='cancelled'", (new_status, oid, cur_branch()))
    db.commit()
    return redirect(request.referrer or url_for("kitchen"))


@app.route("/kitchen/call/<int:cid>/done", methods=["POST"])
@need("kitchen", "staff")
def call_done(cid):
    db = get_db()
    db.execute("UPDATE calls SET done=1 WHERE id=? AND branch_id=?",
               (cid, cur_branch()))
    db.commit()
    return redirect(request.referrer or url_for("kitchen"))


# ================= Nhan vien =================
@app.route("/staff")
@need("staff")
def staff():
    """Nhan vien: xem don khach da goi (moi/dang lam/da len mon), cac cuoc goi."""
    db, bid = get_db(), cur_branch()
    rows = db.execute("SELECT * FROM orders WHERE branch_id=? AND paid=0 AND "
                      "status!='cancelled' ORDER BY table_no, id",
                      (bid,)).fetchall()
    tables = {}
    for o, items in orders_with_items(rows):
        t = tables.setdefault(o["table_no"], {"orders": [], "total": 0})
        t["orders"].append((o, items))
        t["total"] += o["total"]
    calls = db.execute("SELECT * FROM calls WHERE branch_id=? AND done=0 "
                       "ORDER BY id", (bid,)).fetchall()
    return render_template("staff.html", tables=sorted(tables.items()),
                           calls=calls, status=STATUS)


@app.route("/staff/order")
@need("staff")
def staff_order():
    """Nhan vien chon ban de goi mon ho khach."""
    br = get_branch(cur_branch())
    return render_template("staff_order.html", br=br)


# ================= Quan ly =================
def day_stats(db, bid):
    today = "date(created)=date('now','localtime')"
    rev = db.execute(f"SELECT COALESCE(SUM(total),0) FROM orders WHERE "
                     f"branch_id=? AND paid=1 AND status!='cancelled' AND "
                     f"{today}", (bid,)).fetchone()[0]
    n = db.execute(f"SELECT COUNT(*) FROM orders WHERE branch_id=? AND "
                   f"status!='cancelled' AND {today}", (bid,)).fetchone()[0]
    return rev, n


@app.route("/admin")
@need()
def admin():
    db, bid = get_db(), cur_branch()
    revenue, n_orders = day_stats(db, bid)
    unpaid = db.execute("SELECT COALESCE(SUM(total),0) FROM orders WHERE "
                        "branch_id=? AND paid=0 AND status!='cancelled'",
                        (bid,)).fetchone()[0]
    top = db.execute(
        "SELECT oi.name, SUM(oi.qty) q FROM order_items oi JOIN orders o ON "
        "o.id=oi.order_id WHERE o.branch_id=? AND o.status!='cancelled' "
        "GROUP BY oi.name ORDER BY q DESC LIMIT 5", (bid,)).fetchall()
    days = db.execute(
        "SELECT date(created) d, SUM(total) t FROM orders WHERE branch_id=? "
        "AND paid=1 AND status!='cancelled' GROUP BY d ORDER BY d DESC "
        "LIMIT 7", (bid,)).fetchall()
    days = list(reversed(days))
    mx = max([d["t"] for d in days], default=1)
    chain = []
    for b in db.execute("SELECT id,name FROM branches").fetchall():
        r, n = day_stats(db, b["id"])
        chain.append((b["name"], r, n))
    return render_template("admin.html", revenue=revenue, n_orders=n_orders,
                           unpaid=unpaid, top=top, days=days, mx=mx,
                           chain=chain)


@app.route("/admin/menu")
@need()
def admin_menu():
    db = get_db()
    items = db.execute("SELECT * FROM menu WHERE branch_id=? ORDER BY "
                       "category,id", (cur_branch(),)).fetchall()
    cats = [r[0] for r in db.execute(
        "SELECT DISTINCT category FROM menu WHERE branch_id=?", (cur_branch(),))]
    return render_template("admin_menu.html", items=items, cats=cats)


@app.route("/admin/menu/save", methods=["POST"])
@need()
def menu_save():
    f, db = request.form, get_db()
    vals = (f["category"].strip() or "Món khác", f["name"].strip(),
            int(f["price"] or 0), f.get("emoji", "").strip() or "🍽️")
    new_img = save_image(request.files.get("image"))
    if f.get("id"):
        row = db.execute("SELECT image FROM menu WHERE id=? AND branch_id=?",
                         (f["id"], cur_branch())).fetchone()
        if row:
            old = row["image"]
            image = new_img or (None if f.get("remove_image") else old)
            db.execute("UPDATE menu SET category=?,name=?,price=?,emoji=?,"
                       "image=? WHERE id=? AND branch_id=?",
                       (*vals, image, f["id"], cur_branch()))
            db.commit()
            if image != old:
                drop_image(old)
    else:
        db.execute("INSERT INTO menu(category,name,price,emoji,image,"
                   "branch_id) VALUES(?,?,?,?,?,?)",
                   (*vals, new_img, cur_branch()))
        db.commit()
        flash(f"✅ Đã thêm «{vals[1]}» ({vnd(vals[2])}) vào nhóm «{vals[0]}» "
              f"· {get_branch(cur_branch())['name']}. Món nằm trong danh sách "
              f"bên dưới, xếp theo tên nhóm.")
    return redirect(url_for("admin_menu"))


@app.route("/admin/menu/<int:mid>/toggle", methods=["POST"])
@need()
def menu_toggle(mid):
    db = get_db()
    db.execute("UPDATE menu SET available=1-available WHERE id=? AND "
               "branch_id=?", (mid, cur_branch()))
    db.commit()
    return redirect(url_for("admin_menu"))


@app.route("/admin/menu/<int:mid>/delete", methods=["POST"])
@need()
def menu_delete(mid):
    db = get_db()
    row = db.execute("SELECT image FROM menu WHERE id=? AND branch_id=?",
                     (mid, cur_branch())).fetchone()
    db.execute("DELETE FROM menu WHERE id=? AND branch_id=?",
               (mid, cur_branch()))
    db.commit()
    if row:
        drop_image(row["image"])
    return redirect(url_for("admin_menu"))


@app.route("/admin/menu/clear", methods=["POST"])
@need()
def menu_clear():
    """Xoa toan bo mon cua chi nhanh dang chon (de tu nhap thuc don rieng)."""
    db = get_db()
    imgs = [r[0] for r in db.execute(
        "SELECT image FROM menu WHERE branch_id=? AND image IS NOT NULL",
        (cur_branch(),))]
    db.execute("DELETE FROM menu WHERE branch_id=?", (cur_branch(),))
    db.commit()
    for im in imgs:
        drop_image(im)
    return redirect(url_for("admin_menu"))


@app.route("/admin/tables")
@need("staff")
def admin_tables():
    rows = get_db().execute(
        "SELECT table_no, COUNT(*) n, SUM(total) t FROM orders WHERE "
        "branch_id=? AND paid=0 AND status!='cancelled' GROUP BY table_no "
        "ORDER BY table_no", (cur_branch(),)).fetchall()
    return render_template("admin_tables.html", rows=rows)


@app.route("/bill/<int:table_no>")
@need("staff")
def bill(table_no):
    rows = get_db().execute(
        "SELECT * FROM orders WHERE branch_id=? AND table_no=? AND paid=0 "
        "AND status!='cancelled' ORDER BY id",
        (cur_branch(), table_no)).fetchall()
    merged = {}
    for o, items in orders_with_items(rows):
        for i in items:
            k = (i["name"], i["price"])
            merged[k] = merged.get(k, 0) + i["qty"]
    return render_template("bill.html", table_no=table_no,
                           br=get_branch(cur_branch()),
                           lines=[(n, p, q) for (n, p), q in merged.items()],
                           total=sum(o["total"] for o in rows))


@app.route("/admin/pay/<int:table_no>", methods=["POST"])
@need("staff")
def pay(table_no):
    db = get_db()
    db.execute("UPDATE orders SET paid=1 WHERE branch_id=? AND table_no=? AND "
               "paid=0 AND status!='cancelled'", (cur_branch(), table_no))
    db.execute("UPDATE calls SET done=1 WHERE branch_id=? AND table_no=? AND "
               "kind='pay'", (cur_branch(), table_no))
    db.commit()
    return redirect(url_for("admin_tables"))


@app.route("/admin/ratings")
@need()
def admin_ratings():
    db, bid = get_db(), cur_branch()
    avg = db.execute("SELECT item_name, AVG(stars) a, COUNT(*) c FROM ratings "
                     "WHERE branch_id=? GROUP BY item_name ORDER BY a DESC",
                     (bid,)).fetchall()
    cm = db.execute("SELECT * FROM ratings WHERE branch_id=? AND comment!='' "
                    "ORDER BY id DESC LIMIT 20", (bid,)).fetchall()
    return render_template("admin_ratings.html", avg=avg, cm=cm)


@app.route("/admin/branches", methods=["GET", "POST"])
@need()
def admin_branches():
    db = get_db()
    if request.method == "POST":
        f = request.form
        vals = (f["name"], f["address"], int(f["tables"] or 10),
                f["bank_bin"], f["bank_account"].strip(),
                f["bank_holder"].strip().upper())
        if f.get("id"):
            db.execute("UPDATE branches SET name=?,address=?,tables=?,"
                       "bank_bin=?,bank_account=?,bank_holder=? WHERE id=?",
                       (*vals, f["id"]))
        else:   # chi nhanh moi: sao chep thuc don cua chi nhanh dang chon
            cur = db.execute("INSERT INTO branches(name,address,tables,"
                             "bank_bin,bank_account,bank_holder) "
                             "VALUES(?,?,?,?,?,?)", vals)
            db.execute("INSERT INTO menu(branch_id,category,name,price,emoji,image)"
                       " SELECT ?,category,name,price,emoji,image FROM menu WHERE "
                       "branch_id=?", (cur.lastrowid, cur_branch()))
        db.commit()
        return redirect(url_for("admin_branches"))
    rows = db.execute("SELECT * FROM branches").fetchall()
    return render_template("admin_branches.html", rows=rows, banks=BANKS)


# ================= Tai khoan (admin) =================
@app.route("/admin/users", methods=["GET", "POST"])
@need()
def admin_users():
    db = get_db()
    if request.method == "POST":
        f = request.form
        uname = f.get("username", "").strip().lower()
        pw, role = f.get("password", ""), f.get("role")
        if f.get("id"):                                   # sua
            u = db.execute("SELECT * FROM users WHERE id=?", (f["id"],)).fetchone()
            if u:
                if u["role"] == "admin" and role != "admin" and db.execute(
                        "SELECT COUNT(*) FROM users WHERE role='admin'").fetchone()[0] < 2:
                    flash("Phải còn ít nhất 1 tài khoản quản trị.")
                else:
                    db.execute("UPDATE users SET role=?,branch_id=?,name=? WHERE id=?",
                               (role, f.get("branch_id") or None, f.get("name", ""), u["id"]))
                    if pw:
                        db.execute("UPDATE users SET password=? WHERE id=?",
                                   (generate_password_hash(pw), u["id"]))
                    flash("Đã lưu.")
        elif not uname or len(pw) < 4 or role not in ROLES:
            flash("Cần tên đăng nhập, mật khẩu ≥ 4 ký tự và vai trò.")
        elif db.execute("SELECT 1 FROM users WHERE username=?", (uname,)).fetchone():
            flash("Tên đăng nhập đã tồn tại.")
        else:
            db.execute("INSERT INTO users(username,password,role,branch_id,name) "
                       "VALUES(?,?,?,?,?)", (uname, generate_password_hash(pw), role,
                                             f.get("branch_id") or None, f.get("name", "")))
            flash("Đã thêm tài khoản.")
        db.commit()
        return redirect(url_for("admin_users"))
    rows = db.execute("SELECT * FROM users ORDER BY id").fetchall()
    return render_template("admin_users.html", rows=rows)


@app.route("/admin/users/<int:uid>/delete", methods=["POST"])
@need()
def user_delete(uid):
    db = get_db()
    u = db.execute("SELECT * FROM users WHERE id=?", (uid,)).fetchone()
    if u and u["id"] == current_user()["id"]:
        flash("Không thể xóa chính mình.")
    elif u:
        db.execute("DELETE FROM users WHERE id=?", (uid,))
        db.commit()
    return redirect(url_for("admin_users"))


# ================= Ma QR ban =================
@app.route("/qr/<int:bid>/<int:t>.png")
@need()
def qr_png(bid, t):
    return png_response(f"{base_url()}/b/{bid}/table/{t}")


@app.route("/qr")
@need()
def qr_page():
    br = get_branch(cur_branch())
    base = base_url()
    return render_template("qr.html", br=br, base=base,
                           public=is_public_url(base),
                           tables=range(1, br["tables"] + 1))


init_db()      # chay ca khi khoi dong bang gunicorn

if __name__ == "__main__":
    print(f"\n>>> Quan ly: http://localhost:{PORT}/admin")
    print(f">>> Dien thoai/app (cung WiFi): http://{lan_ip()}:{PORT}")
    if PUBLIC_URL:
        print(f">>> QR dung dia chi INTERNET: {PUBLIC_URL}\n")
    else:
        print(">>> Muon mang nao quet cung vao duoc: xem README muc 'Chay qua Internet'\n")
    app.run(host="0.0.0.0", port=PORT, debug=not os.environ.get("PUBLIC_URL"))
