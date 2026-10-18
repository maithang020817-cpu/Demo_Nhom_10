# -*- coding: utf-8 -*-
"""Nhap thuc don quan (tu 8 anh menu) vao server/restaurant.db

Cach dung (chay trong thu muc server, TAT server truoc khi chay):
    python import_menu.py              # THEM mon vao tat ca chi nhanh, giu mon cu
    python import_menu.py --replace    # XOA mon mau cu roi them mon moi
    python import_menu.py --branch 1   # chi them vao chi nhanh co id = 1

- Tu dong sao luu DB thanh restaurant.db.bak truoc khi sua.
- Chay lai nhieu lan khong bi trung mon (bo qua mon da co cung nhom + ten).
- Don hang / danh gia cu khong bi anh huong (chung luu theo ten mon).
"""
import argparse
import os
import shutil
import sqlite3

HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, "restaurant.db")

# (nhom, emoji nhom, [(ten mon, gia, emoji rieng - tuy chon)])
MENU = [
    ("Món ăn nhẹ", "🍜", [
        ("Bún chả", 40000),
        ("Bún chả nem rán", 50000),
        ("Bún chả nem cua bể", 65000),
        ("Bún chả đặc biệt", 75000),
    ]),
    ("Lai rai Hà Nội", "🍻", [
        ("Lạc rang húng lìu", 20000, "🥜"),
        ("Bánh đa nướng", 25000, "🫓"),
        ("Nem phùng lá sung", 65000),
        ("Nem chua Thanh Hóa", 6000),          # tren menu in "6000" (khong co dau cham)
        ("Nem tai thính", 85000),
        ("Bò một nắng muối trứng kiến", 165000, "🥩"),
        ("Trâu gác bếp", 105000, "🥩"),
        ("Bắp bò muối", 125000, "🥩"),
        ("Thịt đông dưa hành", 85000),
    ]),
    ("Khai vị", "🥢", [
        ("Đậu hũ tẩm hành", 55000, "🧈"),
        ("Đậu hũ chiên sả", 55000, "🧈"),
        ("Đậu hũ lướt ván", 45000, "🧈"),
        ("Đậu hũ chiên giòn", 45000, "🧈"),
        ("Đậu hũ cuốn giấy bạc", 125000, "🧈"),
        ("Tép đồng rang khế", 125000, "🦐"),
        ("Trứng chiên lá mơ", 55000, "🍳"),
        ("Khổ qua chà bông", 85000, "🥒"),
        ("Nem rán Hà Nội", 65000, "🥟"),
        ("Nem cua bể Hải Phòng", 75000, "🦀"),
        ("Chả mực Hạ Long", 125000, "🦑"),
        ("Cà chua chưng tóp mỡ", 85000, "🍅"),
    ]),
    ("Rau củ quả", "🥕", [
        ("Rau củ quả luộc chấm trứng hồng đào", 85000),
        ("Rau củ quả luộc chấm kho quẹt", 85000),
    ]),
    ("Nộm gỏi", "🥗", [
        ("Nộm ngan hoa chuối", 105000),
        ("Nộm cà pháo bóp thấu", 105000),
        ("Nộm lòng bóp thấu", 105000),
        ("Nộm rau muống tép đồng", 105000),
        ("Nộm bò tái chanh", 165000),
        ("Gỏi mực kiểu Thái", 125000, "🦑"),
        ("Gỏi Thái hải sản", 125000, "🦐"),
    ]),
    ("Món xào", "🍳", [
        ("Thiên lý xào tỏi", 85000, "🥬"),
        ("Thiên lý xào bò", 125000, "🥬"),
        ("Đọt xu xào tỏi", 85000, "🥬"),
        ("Đọt xu xào bò", 125000, "🥬"),
        ("Bí nụ xào tỏi", 85000, "🥬"),
        ("Bí nụ xào bò", 125000, "🥬"),
        ("Cần nước xào tỏi", 65000, "🥬"),   # gia dan de tay tren menu
        ("Cần nước xào bò", 105000, "🥬"),
        ("Rau muống xào tỏi", 65000, "🥬"),
        ("Rau muống xào bò", 105000, "🥬"),
        ("Rau lang xào tỏi", 65000, "🥬"),   # gia dan de tay tren menu
        ("Rau lang xào bò", 105000, "🥬"),
        ("Măng trúc xào tỏi", 85000, "🎋"),
        ("Măng trúc xào bò", 125000, "🎋"),
        ("Lòng xào mướp", 95000),
        ("Bao tử xào cải chua", 125000),
        ("Dồi trường xào cải chua", 165000),
        ("Dồi trường hấp hành gừng", 165000),
        ("Khổ qua xào trứng", 85000, "🥒"),
        ("Xách bò xào măng", 145000, "🥩"),
        ("Dồi trường xào măng", 165000),
        ("Nấm thập cẩm xào chay", 105000, "🍄"),
    ]),
    ("Heo tộc", "🐖", [
        ("Dồi hấp", 115000),
        ("Dồi nướng", 115000),
        ("Heo hấp", 165000),
        ("Heo nướng Tây Bắc", 165000),
        ("Heo nướng da giòn", 165000),
        ("Heo tộc om sấu", 185000),
        ("Heo nấu khoai sọ", 185000),
        ("Heo giả cầy", 185000),
        ("Heo tộc lên mẹt cuốn rau rừng", 285000),
        ("Lòng heo luộc thập cẩm (mẹt nhỏ)", 195000),
        ("Lòng heo luộc thập cẩm (mẹt lớn)", 295000),
    ]),
    # Ten co tien to "Trau"/"Da sach bo" de khong bi trung ten giua 2 nhom
    ("Trâu", "🐃", [
        ("Trâu hấp hành gừng", 165000),
        ("Trâu xào rau muống", 105000),
        ("Trâu xào cần nước", 105000),
        ("Trâu nhúng mẻ", 165000),
    ]),
    ("Dạ sách bò", "🐂", [
        ("Dạ sách bò xào măng", 145000),
        ("Dạ sách bò xào khế", 145000),
        ("Dạ sách bò hấp hành gừng", 165000),
        ("Dạ sách bò nhúng mẻ", 185000),
        ("Dạ sách bò xào cải chua", 165000),
    ]),
    ("Lươn", "🐍", [
        ("Lươn xúc bánh đa", 125000),
        ("Lươn xào xả ớt", 125000),
        ("Lươn nướng muối ớt", 125000),
        ("Lươn chiên giòn", 125000),
        ("Lươn xào lăn", 185000),
        ("Lươn om chuối đậu", 185000),
    ]),
    ("Ếch", "🐸", [
        ("Ếch chiên lá lốt", 105000),
        ("Ếch xào măng cay", 125000),
        ("Ếch xào xả ớt", 105000),
        ("Ếch chiên mắm", 105000),
        ("Ếch núp lùm", 105000),
        ("Ếch nướng muối ớt", 105000),
        ("Ếch xào lăn", 165000),
        ("Ếch om chuối đậu", 165000),
    ]),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--replace", action="store_true",
                    help="xoa het mon cu cua chi nhanh truoc khi them")
    ap.add_argument("--branch", type=int, help="chi them vao chi nhanh nay")
    args = ap.parse_args()

    if not os.path.exists(DB):
        raise SystemExit("Khong thay restaurant.db - hay chay file nay trong thu muc server")
    shutil.copyfile(DB, DB + ".bak")
    print("Da sao luu ->", DB + ".bak")

    db = sqlite3.connect(DB)
    branches = [r[0] for r in db.execute("SELECT id FROM branches ORDER BY id")]
    if args.branch:
        branches = [b for b in branches if b == args.branch]
    if not branches:
        raise SystemExit("Khong co chi nhanh nao phu hop")

    for bid in branches:
        if args.replace:
            n = db.execute("DELETE FROM menu WHERE branch_id=?", (bid,)).rowcount
            print(f"[CN {bid}] da xoa {n} mon cu")
        added = skipped = 0
        for cat, cat_emoji, items in MENU:
            for it in items:
                name, price = it[0], it[1]
                emoji = it[2] if len(it) > 2 else cat_emoji
                # mon mau cu trung ten (khac nhom) -> thay bang mon that tren menu
                n = db.execute("DELETE FROM menu WHERE branch_id=? AND name=? "
                               "AND category<>?", (bid, name, cat)).rowcount
                if n:
                    print(f"[CN {bid}] thay mon mau trung ten: {name}")
                if db.execute("SELECT 1 FROM menu WHERE branch_id=? AND category=? "
                              "AND name=?", (bid, cat, name)).fetchone():
                    skipped += 1
                    continue
                db.execute("INSERT INTO menu(branch_id,category,name,price,emoji,"
                           "available) VALUES(?,?,?,?,?,1)",
                           (bid, cat, name, price, emoji))
                added += 1
        print(f"[CN {bid}] them {added} mon, bo qua {skipped} mon da co")
    db.commit()
    db.close()


if __name__ == "__main__":
    main()
