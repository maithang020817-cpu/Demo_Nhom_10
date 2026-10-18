"""App goi mon tai ban (Android/Desktop) - Kivy.
Ket noi toi server Flask qua API JSON. Chay thu tren may tinh:  python main.py
"""
import io
import json
import re

import qrcode
from kivy.app import App
from kivy.clock import Clock
from kivy.core.image import Image as CoreImage
from kivy.core.window import Window
from kivy.lang import Builder
from kivy.network.urlrequest import UrlRequest
from kivy.properties import StringProperty
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.button import Button
from kivy.uix.label import Label
from kivy.uix.popup import Popup
from kivy.uix.screenmanager import Screen, ScreenManager
from kivy.uix.spinner import Spinner

if Window.width > Window.height:          # chay tren may tinh: gia lap man hinh dien thoai
    Window.size = (400, 750)


def vnd(v):
    return f"{int(v):,}".replace(",", ".") + "đ"


KV = """
<Btn@Button>:
    size_hint_y: None
    height: dp(46)
    background_normal: ''
    background_color: .91, .35, .05, 1

<Head@Label>:
    size_hint_y: None
    height: dp(48)
    bold: True
    font_size: '18sp'
    canvas.before:
        Color:
            rgba: .91, .35, .05, 1
        Rectangle:
            pos: self.pos
            size: self.size

<ConnectScreen>:
    name: 'connect'
    BoxLayout:
        orientation: 'vertical'
        padding: dp(16)
        spacing: dp(10)
        Head:
            text: 'Goi mon QR'
        Label:
            text: 'Dan link tu ma QR tren ban\\n(vd http://192.168.1.5:5000/b/1/table/3)\\nhoac nhap tay ben duoi'
            color: .2, .2, .2, 1
            size_hint_y: None
            height: dp(70)
        TextInput:
            id: link
            hint_text: 'Link ma QR'
            multiline: False
            size_hint_y: None
            height: dp(44)
        TextInput:
            id: server
            text: 'http://192.168.1.5:5000'
            hint_text: 'Dia chi server'
            multiline: False
            size_hint_y: None
            height: dp(44)
        BoxLayout:
            size_hint_y: None
            height: dp(44)
            spacing: dp(8)
            TextInput:
                id: branch
                text: '1'
                hint_text: 'Chi nhanh'
                input_filter: 'int'
                multiline: False
            TextInput:
                id: table
                text: '1'
                hint_text: 'So ban'
                input_filter: 'int'
                multiline: False
        Btn:
            text: 'Ket noi'
            on_release: app.connect(link.text, server.text, branch.text, table.text)
        Label:
            text: root.msg
            color: .8, 0, 0, 1
        Widget:

<MenuScreen>:
    name: 'menu'
    BoxLayout:
        orientation: 'vertical'
        Head:
            id: title
            text: root.title
        ScrollView:
            BoxLayout:
                id: list
                orientation: 'vertical'
                size_hint_y: None
                height: self.minimum_height
                padding: dp(8)
                spacing: dp(6)
        TextInput:
            id: note
            hint_text: 'Ghi chu (it cay, khong hanh...)'
            multiline: False
            size_hint_y: None
            height: dp(40)
        BoxLayout:
            size_hint_y: None
            height: dp(46)
            spacing: dp(4)
            Btn:
                text: 'Goi NV'
                on_release: app.call_staff('staff')
            Btn:
                text: 'Don/TT'
                on_release: app.goto_order()
            Btn:
                id: send
                text: 'Gui don'
                on_release: app.send_order(note.text)

<OrderScreen>:
    name: 'order'
    BoxLayout:
        orientation: 'vertical'
        Head:
            id: title
            text: 'Don hang'
        ScrollView:
            BoxLayout:
                id: body
                orientation: 'vertical'
                size_hint_y: None
                height: self.minimum_height
                padding: dp(10)
                spacing: dp(6)
        BoxLayout:
            id: actions
            size_hint_y: None
            height: dp(46)
            spacing: dp(4)

<PayScreen>:
    name: 'pay'
    BoxLayout:
        orientation: 'vertical'
        padding: dp(8)
        spacing: dp(6)
        Head:
            text: 'Thanh toan VietQR'
        Label:
            id: info
            color: .1, .1, .1, 1
            size_hint_y: None
            height: dp(70)
            halign: 'center'
            text_size: self.width, None
        Image:
            id: qr
        BoxLayout:
            size_hint_y: None
            height: dp(46)
            spacing: dp(4)
            Btn:
                text: 'Quay lai'
                on_release: app.root.current = 'menu'
            Btn:
                text: 'Da chuyen khoan'
                on_release: app.call_staff('pay')
"""


class ConnectScreen(Screen):
    msg = StringProperty("")


class MenuScreen(Screen):
    title = StringProperty("Thuc don")


class OrderScreen(Screen):
    pass


class PayScreen(Screen):
    pass


def row_label(text, **kw):
    lb = Label(text=text, color=(.1, .1, .1, 1), size_hint_y=None,
               halign="left", valign="middle", **kw)
    lb.bind(width=lambda w, v: setattr(w, "text_size", (v, None)),
            texture_size=lambda w, s: setattr(w, "height", max(s[1], 30)))
    return lb


class QROrderApp(App):
    server = ""
    branch = 1
    table = 1
    menu_items = []
    cart = {}
    qty_labels = {}
    order_id = None
    last_status = None
    poll = None

    def build(self):
        Window.clearcolor = (.96, .96, .97, 1)
        sm = ScreenManager()
        for s in (ConnectScreen(), MenuScreen(), OrderScreen(), PayScreen()):
            sm.add_widget(s)
        return sm

    # ---------- tien ich ----------
    def popup(self, text, title="Thong bao"):
        Popup(title=title, content=Label(text=text, halign="center"),
              size_hint=(.85, .3)).open()

    def fail(self, req, err=None):
        self.popup(f"Loi ket noi server\n{self.server}\nKiem tra cung WiFi / dia chi IP.")

    def api(self, path, ok, body=None, method=None):
        headers = {"Content-Type": "application/json"}
        UrlRequest(self.server + path, on_success=lambda r, res: ok(res),
                   on_failure=lambda r, res: self.http_fail(res),
                   on_error=self.fail, req_headers=headers,
                   req_body=json.dumps(body) if body is not None else None,
                   method=method or ("POST" if body is not None else "GET"),
                   timeout=10)

    def http_fail(self, res):
        msg = res.get("error") if isinstance(res, dict) else None
        self.popup(msg or "Server tra loi loi")

    # ---------- ket noi ----------
    def connect(self, link, server, branch, table):
        m = re.match(r"(https?://[^/]+)/b/(\d+)/table/(\d+)", link.strip())
        if m:
            server, branch, table = m.groups()
        self.server = server.strip().rstrip("/")
        if not self.server.startswith("http"):
            self.server = "http://" + self.server
        self.branch, self.table = int(branch or 1), int(table or 1)
        self.api(f"/api/b/{self.branch}/menu", self.show_menu)

    def show_menu(self, data):
        self.menu_items = data["items"]
        self.cart, self.qty_labels = {}, {}
        scr = self.root.get_screen("menu")
        scr.title = f"{data['branch']} - Ban {self.table}"
        box = scr.ids.list
        box.clear_widgets()
        cat = None
        for it in self.menu_items:
            if it["category"] != cat:
                cat = it["category"]
                box.add_widget(row_label(f"[b]{cat}[/b]", markup=True,
                                         font_size="16sp"))
            box.add_widget(self.make_row(it))
        self.root.current = "menu"

    def make_row(self, it):
        row = BoxLayout(size_hint_y=None, height=60, spacing=4)
        star = f"  *{it['avg']:.1f}" if it.get("avg") else ""
        txt = f"{it['name']}\n{vnd(it['price'])}{star}"
        row.add_widget(row_label(txt, font_size="14sp"))
        if not it["available"]:
            row.add_widget(Label(text="Het mon", color=(.8, 0, 0, 1),
                                 size_hint_x=None, width=90))
            return row
        minus = Button(text="-", size_hint=(None, None), size=(44, 44))
        plus = Button(text="+", size_hint=(None, None), size=(44, 44))
        qty = Label(text="0", color=(.1, .1, .1, 1), size_hint_x=None, width=30)
        self.qty_labels[it["id"]] = qty
        minus.bind(on_release=lambda *_: self.change(it["id"], -1))
        plus.bind(on_release=lambda *_: self.change(it["id"], 1))
        for w in (minus, qty, plus):
            row.add_widget(w)
        return row

    def change(self, mid, d):
        self.cart[mid] = max(0, self.cart.get(mid, 0) + d)
        self.qty_labels[mid].text = str(self.cart[mid])
        total = sum(it["price"] * self.cart.get(it["id"], 0)
                    for it in self.menu_items)
        self.root.get_screen("menu").ids.send.text = f"Gui {vnd(total)}" if total else "Gui don"

    # ---------- dat mon ----------
    def send_order(self, note):
        items = [{"id": k, "qty": v} for k, v in self.cart.items() if v > 0]
        if not items:
            return self.popup("Ban chua chon mon!")
        body = {"branch": self.branch, "table": self.table, "items": items,
                "note": note}
        self.api("/api/order", self.order_sent, body)

    def order_sent(self, res):
        self.order_id = res["order_id"]
        for mid in list(self.cart):
            self.cart[mid] = 0
            if mid in self.qty_labels:
                self.qty_labels[mid].text = "0"
        self.root.get_screen("menu").ids.send.text = "Gui don"
        self.root.get_screen("menu").ids.note.text = ""
        self.goto_order()

    def call_staff(self, kind):
        self.api("/api/call", lambda r: self.popup(
            "Da bao nhan vien!"), {"branch": self.branch, "table": self.table,
                                   "kind": kind})

    # ---------- theo doi don + danh gia ----------
    def goto_order(self):
        if not self.order_id:
            return self.popup("Ban chua co don nao.")
        self.root.current = "order"
        self.last_status = None
        self.refresh_order()
        if self.poll:
            self.poll.cancel()
        self.poll = Clock.schedule_interval(lambda dt: self.refresh_order(), 4)

    def refresh_order(self):
        if self.root.current != "order":
            if self.poll:
                self.poll.cancel()
            return
        self.api(f"/api/order/{self.order_id}", self.draw_order)

    def draw_order(self, o):
        scr = self.root.get_screen("order")
        scr.ids.title.text = f"Don #{self.order_id} - {o['status_text']}"
        body, act = scr.ids.body, scr.ids.actions
        sig = (o["status"], o["rated"])
        if sig == self.last_status:      # khong ve lai neu khong doi (giu lua chon sao)
            return
        self.last_status = sig
        body.clear_widgets()
        act.clear_widgets()
        for i in o["items"]:
            body.add_widget(row_label(
                f"{i['qty']} x {i['name']}  -  {vnd(i['price'] * i['qty'])}"))
        body.add_widget(row_label(f"[b]Tong: {vnd(o['total'])}[/b]", markup=True))
        self.spinners = {}
        if o["status"] == "served" and not o["rated"]:
            body.add_widget(row_label("[b]Danh gia mon (so sao):[/b]", markup=True))
            for i in o["items"]:
                r = BoxLayout(size_hint_y=None, height=44)
                r.add_widget(row_label(i["name"]))
                sp = Spinner(text="5", values=("5", "4", "3", "2", "1"),
                             size_hint_x=None, width=70)
                self.spinners[i["name"]] = sp
                r.add_widget(sp)
                body.add_widget(r)
            act.add_widget(self.mk_btn("Gui danh gia", self.send_rating))
        elif o["rated"]:
            body.add_widget(row_label("Cam on ban da danh gia!"))
        if o["status"] == "new":
            act.add_widget(self.mk_btn("Huy don", self.cancel_order))
        act.add_widget(self.mk_btn("Thanh toan", self.goto_pay))
        act.add_widget(self.mk_btn("Goi them", self.back_menu))

    def mk_btn(self, text, fn):
        b = Button(text=text, background_normal="",
                   background_color=(.91, .35, .05, 1))
        b.bind(on_release=lambda *_: fn())
        return b

    def back_menu(self):
        self.last_status = None
        self.root.current = "menu"

    def cancel_order(self):
        self.api(f"/api/order/{self.order_id}/cancel",
                 lambda r: (setattr(self, "last_status", None),
                            self.refresh_order()), {})

    def send_rating(self):
        ratings = [{"name": n, "stars": int(s.text)}
                   for n, s in self.spinners.items()]
        self.api("/api/rating", lambda r: (setattr(self, "last_status", None),
                                            self.refresh_order()),
                 {"order_id": self.order_id, "ratings": ratings})

    # ---------- thanh toan VietQR ----------
    def goto_pay(self):
        self.api(f"/api/b/{self.branch}/table/{self.table}/pay", self.show_pay)

    def show_pay(self, d):
        scr = self.root.get_screen("pay")
        if d["total"] == 0:
            scr.ids.info.text = "Ban khong co khoan can thanh toan."
            scr.ids.qr.texture = None
        else:
            scr.ids.info.text = (f"{vnd(d['total'])}\n{d['bank']} - {d['account']}\n"
                                 f"{d['holder']}")
            buf = io.BytesIO()
            qrcode.make(d["payload"]).save(buf, format="PNG")
            buf.seek(0)
            scr.ids.qr.texture = CoreImage(buf, ext="png").texture
        self.root.current = "pay"


if __name__ == "__main__":
    QROrderApp().run()
