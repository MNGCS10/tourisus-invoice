# Touris Us Invoice Dashboard — Vercel + Supabase

โครงโปรเจกต์เต็มรูป: Frontend (HTML) + Vercel API routes + Supabase (RLS ปิดสนิท, เข้าผ่าน service_role เท่านั้น) + Resend email

## โครงสร้าง

```
tourisus-invoice/
├── api/
│   ├── customers.js              # GET (list/search) + POST (create)
│   ├── invoices.js                # GET (dashboard list, embeds receipts) + POST (create + items)
│   ├── invoices/[id].js           # GET (full detail) + PATCH (update status)
│   ├── payments.js                # POST (record payment)
│   ├── receipts.js                # GET (list) + POST (issue a receipt against a paid invoice) — Phase 4
│   ├── vendors.js                 # GET (list/search) + POST (create) — Phase 4, for Purchase VAT entries
│   ├── purchase-vat.js            # GET (list) + POST (record a vendor purchase / input VAT) — Phase 4
│   ├── vat-summary.js             # GET monthly output vs input VAT (v_vat_filing_summary view) — Phase 4
│   └── send-invoice-email.js      # POST — ส่งอีเมลผ่าน Resend
├── lib/
│   └── supabaseAdmin.js           # server-only Supabase client (service_role)
├── public/
│   ├── index.html                 # Invoice System จริง — ต่อ API ครบแล้ว (ไม่ใช้ localStorage อีก)
│   │                                 ⚠️ 15 ก.ย. 69: คอมมิต "Update index.html" เคยเขียนทับเป็น
│   │                                 localStorage-only prototype โดยไม่ตั้งใจ (ไม่ต่อ Supabase เลย) —
│   │                                 Cowork กู้กลับมาแล้ว โดยคง UI ตั๋วเครื่องบิน (svc-grid/X-A-B-C) ที่ถูกต้องไว้
│   └── send-invoice-email.js      # client helper สำหรับปุ่ม "ส่งอีเมล" (ยังไม่ได้ผูกเข้าใช้งานจริง — รอ verify domain)
├── database/
│   ├── touris_us_supabase_schema.sql
│   └── legacy-apps-script-reference.gs   # ของเดิม เก็บไว้อ้างอิงเฉยๆ (ไม่ได้ใช้แล้ว)
├── .env.example
├── package.json
└── vercel.json
```

## สถานะ Supabase (ตรวจสอบแล้วผ่าน MCP)

- Project: **Touris Us Invoice** (`ijhcbvctyancnnmpicux`) — ACTIVE
- Schema deploy แล้ว: `customers` (50 ราย), `invoices`, `invoice_items`, `payments`
- **RLS เปิดครบ 4 ตาราง ไม่มี public policy** — เข้าได้เฉพาะผ่าน API routes ที่ใช้ `service_role` เท่านั้น

## ขั้นตอน deploy

1. **ติดตั้ง Vercel CLI** (ถ้ายังไม่มี): `npm i -g vercel`
2. **Login**: `vercel login`
3. **Deploy**: จากในโฟลเดอร์นี้ รัน `vercel` แล้วตอบคำถามตามค่า default ได้เลย
4. **ตั้ง Environment Variables** ใน Vercel Dashboard → โปรเจกต์นี้ → Settings → Environment Variables:
   - `SUPABASE_URL` = `https://ijhcbvctyancnnmpicux.supabase.co`
   - `SUPABASE_SERVICE_ROLE_KEY` = ไปเอาจาก Supabase Dashboard → Project Settings → API → `service_role` (secret)
   - `RESEND_API_KEY` = API key จริงจาก Resend
   - `RESEND_FROM_EMAIL` = `"Touris Us <invoice@yourdomain.com>"` (ต้อง verify domain ที่ resend.com/domains ก่อน)
5. **Deploy production**: `vercel --prod`

## ขอบเขตปัจจุบัน (15 ก.ย. 69)

- UI เลือกประเภทบริการ (svc-grid): ✈️ ตั๋วเครื่องบิน · 🏨 โรงแรม · 🛡️ ประกันภัย · 📋 วีซ่า · 🎒 ทัวร์ · 🔧 อื่นๆ
- ✈️ ตั๋วเครื่องบิน: กรอก X (ราคาตั๋ว, VAT 0%) + A (ค่าบริการรวม VAT) → ระบบสร้าง 2 invoice_items (ticket @0%, service_fee @7%) และคำนวณ Original/Copy ให้อัตโนมัติ
- อื่นๆ: กรอก A (ราคาขายรวม VAT 7%) อย่างเดียว → 1 invoice_item @7%
- **vat_amount/total_amount ไม่ใช่ generated column แล้ว** (แก้ 15 ก.ย. 69) — API (`POST /api/invoices`) คำนวณจาก invoice_items แต่ละบรรทัดเอง เพราะ header เดียวใช้ vat_rate อัตราเดียวไม่พอสำหรับใบตั๋วเครื่องบินที่มีทั้ง 0% และ 7% ในใบเดียวกัน
- Database รองรับ field ละเอียดกว่านี้อีก (`airline`, `flight_no`, `check_in`, `policy_no` ฯลฯ) — API รับไว้แล้ว แค่ยังไม่มี UI ป้อนข้อมูลระดับนั้น
- **หัก ณ ที่จ่าย (WHT)**: ยังไม่มี column ใน schema จริง — ปิดไว้ก่อน (แสดง 0) ต้องเพิ่ม column ทีหลังถ้าต้องใช้งานจริง

## Phase 4 (15 ก.ย. 69) — Receipts / Purchase VAT / VAT Filing Summary

เพิ่ม 3 แท็บใหม่ในแดชบอร์ด ต่อกับ 3 ตารางที่สร้างไว้ตั้งแต่ Phase 3 (`receipts`, `vendors` + `purchase_vat_entries`, และ view `v_vat_filing_summary`):

- **🧾 ใบเสร็จ**: แสดง Invoice ที่ `status='paid'` แต่ยังไม่มี receipt ผูกอยู่ (`invoices.receipts` embed ใน `GET /api/invoices`) → กด "ออกใบเสร็จ" เพื่อสร้างแถวใน `receipts` (เลขที่ออกอัตโนมัติจาก `generate_receipt_no()`) พร้อมประวัติใบเสร็จที่ออกแล้วทั้งหมด
- **🧮 VAT ซื้อ**: บันทึกรายการซื้อจาก vendor (สำหรับ input VAT) — ค้นหา/เพิ่ม vendor แบบเดียวกับลูกค้าใน invoice form, คำนวณ VAT 7% อัตโนมัติจากยอดซื้อ (แก้ไขเองได้)
- **📊 สรุป VAT**: อ่านจาก view `v_vat_filing_summary` (group by เดือน: output VAT จาก invoices ที่ไม่ cancelled, input VAT จาก purchase_vat_entries) แสดงยอดสุทธิ + สถานะ "ต้องนำส่ง"/"ขอคืนได้" ต่อเดือน — ยังเป็น read-only (ยังไม่ผูกกับ `vat_filing_periods` สำหรับ mark ว่ายื่นแล้ว)

ยังไม่ได้ทำ (ทำทีหลังได้): เอกสาร `tax_invoices` (ใบกำกับภาษี Original/Copy สำหรับใบเสร็จ), `credit_notes`, `ticket_refunds`, `wht_certificates` — ตารางพร้อมใน DB แล้วแต่ยังไม่มี API/UI

## Option B (ทำทีหลังได้ ไม่ต้องแก้ DB/API)

เพิ่มฟอร์มกรอกละเอียดตาม service type ที่เลือก แล้วส่ง field เพิ่มเติมไปกับ `items[]` ใน `POST /api/invoices` ตามชื่อใน `api/invoices.js` (เช่น `airline`, `flightNo`, `routeFrom`, `checkIn` ฯลฯ) — ฝั่ง API/DB พร้อมรับอยู่แล้ว

## เช็คก่อนใช้งานจริง

- [ ] Verify domain หรืออีเมลต้นทางที่ [resend.com/domains](https://resend.com/domains)
- [ ] ทดสอบสร้าง Invoice จริง 1 ใบ → ยืนยัน → บันทึกชำระเงิน → เช็คใน Supabase Table Editor ว่าข้อมูลตรง
- [ ] ทดสอบส่งอีเมลจริง 1 ฉบับก่อนใช้กับลูกค้าจริง
- [ ] ถ้าต้องใช้ WHT (หัก ณ ที่จ่าย) จริง ต้องเพิ่ม column ใน `invoices` table ก่อน

