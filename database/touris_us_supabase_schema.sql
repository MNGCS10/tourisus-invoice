-- ============================================================
-- TOURIS US LTD. — Invoice Management System
-- Supabase PostgreSQL Schema
-- Last Invoice: TK00004421 → Next: TK00004422
-- ============================================================

-- ────────────────────────────────────────────────
-- 1. CUSTOMERS TABLE
-- ────────────────────────────────────────────────
CREATE TABLE customers (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  code          TEXT,                        -- ย่อชื่อใช้ภายใน เช่น VB, VP, UNC
  type          TEXT CHECK (type IN ('company', 'individual', 'university', 'government')),
  name_th       TEXT NOT NULL,
  name_en       TEXT,
  address1      TEXT,
  address2      TEXT,
  address3      TEXT,
  tax_id        TEXT,
  phone         TEXT,
  email         TEXT,
  credit_term_days INT DEFAULT 0,
  is_active     BOOLEAN DEFAULT TRUE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ────────────────────────────────────────────────
-- 2. INVOICE NUMBER SEQUENCE
-- Auto-generate TK000XXXXX format
-- Current latest: TK00004421 → sequence starts at 4422
-- ────────────────────────────────────────────────
CREATE SEQUENCE invoice_number_seq START WITH 4422 INCREMENT BY 1;

CREATE OR REPLACE FUNCTION generate_invoice_no()
RETURNS TEXT AS $$
BEGIN
  RETURN 'TK' || LPAD(nextval('invoice_number_seq')::TEXT, 8, '0');
END;
$$ LANGUAGE plpgsql;

-- ────────────────────────────────────────────────
-- 3. INVOICES TABLE
-- ────────────────────────────────────────────────
CREATE TABLE invoices (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  invoice_no      TEXT UNIQUE NOT NULL DEFAULT generate_invoice_no(),
  invoice_date    DATE NOT NULL DEFAULT CURRENT_DATE,
  customer_id     UUID NOT NULL REFERENCES customers(id),
  
  -- Financial
  subtotal        NUMERIC(14,2) NOT NULL DEFAULT 0,
  service_fee     NUMERIC(14,2) NOT NULL DEFAULT 0,
  vat_rate        NUMERIC(5,2) NOT NULL DEFAULT 0,   -- 0.00 หรือ 7.00
  vat_amount      NUMERIC(14,2) GENERATED ALWAYS AS (
                    ROUND((subtotal + service_fee) * vat_rate / 100, 2)
                  ) STORED,
  total_amount    NUMERIC(14,2) GENERATED ALWAYS AS (
                    ROUND((subtotal + service_fee) * (1 + vat_rate / 100), 2)
                  ) STORED,
  
  -- Terms
  credit_term_days INT NOT NULL DEFAULT 0,
  due_date        DATE,
  
  -- Status
  status          TEXT NOT NULL DEFAULT 'draft'
                  CHECK (status IN ('draft', 'pending', 'paid', 'cancelled')),
  paid_date       DATE,
  paid_amount     NUMERIC(14,2),
  payment_method  TEXT,                              -- transfer, cheque, cash
  
  -- Meta
  note            TEXT,
  created_by      TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ────────────────────────────────────────────────
-- 4. INVOICE ITEMS TABLE
-- ────────────────────────────────────────────────
CREATE TABLE invoice_items (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  invoice_id      UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  line_no         INT NOT NULL DEFAULT 1,
  
  -- Service Classification
  service_type    TEXT NOT NULL
                  CHECK (service_type IN (
                    'airline_ticket',
                    'airline_date_change',
                    'hotel',
                    'travel_insurance',
                    'service_fee',
                    'other'
                  )),
  
  -- Description
  description     TEXT NOT NULL,
  
  -- Airline-specific (nullable)
  airline         TEXT,                              -- THAI AIRWAYS, BANGKOK AIRWAYS, etc.
  flight_no       TEXT,                              -- TG652, PG278, etc.
  route_from      TEXT,                              -- BKK
  route_to        TEXT,                              -- ICN
  travel_date     DATE,
  return_date     DATE,                              -- สำหรับ round trip
  return_flight_no TEXT,
  return_route_from TEXT,
  return_route_to   TEXT,
  ticket_no       TEXT,                              -- เลข ticket
  
  -- Insurance-specific (nullable)
  policy_no       TEXT,
  insurance_plan  TEXT,                              -- Silver, Gold, etc.
  coverage_start  DATE,
  coverage_end    DATE,
  
  -- Hotel-specific (nullable)
  hotel_name      TEXT,
  check_in        DATE,
  check_out       DATE,
  room_type       TEXT,
  num_rooms       INT,
  num_nights      INT,
  
  -- Passenger(s)
  passengers      JSONB,
  -- รูปแบบ: [{"name": "SUPRASERT/KARDKUMHAENG", "ticket_no": "829-4853090756"}]
  
  -- Amount
  unit_price      NUMERIC(14,2) NOT NULL DEFAULT 0,
  quantity        INT NOT NULL DEFAULT 1,
  amount          NUMERIC(14,2) GENERATED ALWAYS AS (unit_price * quantity) STORED,
  
  -- VAT ระดับ item (บางรายการ VAT 0%, บางรายการ 7%)
  item_vat_rate   NUMERIC(5,2) DEFAULT 0,
  
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ────────────────────────────────────────────────
-- 5. PAYMENT TRACKING TABLE
-- รองรับการชำระแบบงวด (partial payment)
-- ────────────────────────────────────────────────
CREATE TABLE payments (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  invoice_id      UUID NOT NULL REFERENCES invoices(id),
  paid_date       DATE NOT NULL DEFAULT CURRENT_DATE,
  amount          NUMERIC(14,2) NOT NULL,
  payment_method  TEXT CHECK (payment_method IN ('transfer', 'cheque', 'cash', 'other')),
  reference_no    TEXT,                              -- เลข slip / เช็ค
  note            TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ────────────────────────────────────────────────
-- 6. INDEXES สำหรับ Performance
-- ────────────────────────────────────────────────
CREATE INDEX idx_invoices_customer    ON invoices(customer_id);
CREATE INDEX idx_invoices_status      ON invoices(status);
CREATE INDEX idx_invoices_due_date    ON invoices(due_date);
CREATE INDEX idx_invoices_date        ON invoices(invoice_date);
CREATE INDEX idx_invoice_items_inv    ON invoice_items(invoice_id);
CREATE INDEX idx_payments_invoice     ON payments(invoice_id);

-- ────────────────────────────────────────────────
-- 7. TRIGGER — auto update updated_at
-- ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_invoices_updated_at
  BEFORE UPDATE ON invoices
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_customers_updated_at
  BEFORE UPDATE ON customers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ────────────────────────────────────────────────
-- 8. TRIGGER — auto update invoice status เมื่อชำระครบ
-- ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sync_invoice_payment_status()
RETURNS TRIGGER AS $$
DECLARE
  v_total     NUMERIC;
  v_paid      NUMERIC;
BEGIN
  SELECT total_amount INTO v_total FROM invoices WHERE id = NEW.invoice_id;
  SELECT COALESCE(SUM(amount), 0) INTO v_paid FROM payments WHERE invoice_id = NEW.invoice_id;

  IF v_paid >= v_total THEN
    UPDATE invoices
    SET status = 'paid', paid_date = NEW.paid_date, paid_amount = v_paid
    WHERE id = NEW.invoice_id AND status != 'cancelled';
  ELSE
    UPDATE invoices
    SET status = 'pending'
    WHERE id = NEW.invoice_id AND status = 'draft';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_payment_sync_status
  AFTER INSERT ON payments
  FOR EACH ROW EXECUTE FUNCTION sync_invoice_payment_status();

-- ────────────────────────────────────────────────
-- 9. VIEW — Invoice Summary (ใช้แสดงใน Dashboard)
-- ────────────────────────────────────────────────
CREATE VIEW v_invoice_summary AS
SELECT
  i.invoice_no,
  i.invoice_date,
  i.due_date,
  c.name_th        AS customer_name,
  c.code           AS customer_code,
  i.subtotal,
  i.service_fee,
  i.vat_amount,
  i.total_amount,
  COALESCE(p.paid_total, 0) AS paid_amount,
  i.total_amount - COALESCE(p.paid_total, 0) AS balance_due,
  i.status,
  CASE
    WHEN i.status = 'paid'      THEN '✅ ชำระแล้ว'
    WHEN i.status = 'cancelled' THEN '❌ ยกเลิก'
    WHEN i.due_date < CURRENT_DATE AND i.status = 'pending' THEN '🔴 เกินกำหนด'
    WHEN i.status = 'pending'   THEN '🟡 รอชำระ'
    ELSE '⚪ Draft'
  END AS status_label,
  i.id             AS invoice_id
FROM invoices i
JOIN customers c ON c.id = i.customer_id
LEFT JOIN (
  SELECT invoice_id, SUM(amount) AS paid_total FROM payments GROUP BY invoice_id
) p ON p.invoice_id = i.id;

-- ────────────────────────────────────────────────
-- 10. INSERT CUSTOMERS — จากฐานข้อมูลที่ให้มา
-- ────────────────────────────────────────────────
INSERT INTO customers (code, type, name_th, address1, address2, address3, tax_id, credit_term_days) VALUES
('VB',      'company',    'บริษัท วี.บิวเดอร์ จำกัด',                     '888 หมู่ 13 ซอย 45 ถนนบางนา-ตราด',            'ตำบลบางแก้ว อำเภอบางพลี',    'จังหวัดสมุทรปราการ 10540',      '0105534012331', 18),
('VP',      'company',    'บริษัท วิสแพค จำกัด',                          '888 หมู่ 13 ซอย 45 ถนนบางนา-ตราด',            'ตำบลบางแก้ว อำเภอบางพลี',    'จังหวัดสมุทรปราการ 10540',      '0115550007265', 18),
('ARDEX',   'company',    'บริษัท อาร์เด็กซ์ (ประเทศไทย) จำกัด',         '969 ชั้น 2 หมู่ 13 ซอย 45 ถนนบางนา-ตราด',    'ตำบลบางแก้ว อำเภอบางพลี',    'จังหวัดสมุทรปราการ 10540',      '0105530042995', 0),
('UNICOM',  'company',    'บริษัท ยูนิคอม อิมพอร์ต-เอ็กซ์พอร์ต จำกัด',  '888 หมู่ 13 ซอย 45 ถนนบางนา-ตราด',            'ตำบลบางแก้ว อำเภอบางพลี',    'จังหวัดสมุทรปราการ 10540',      '0115556021880', 0),
('CYTEC',   'company',    'บริษัท ไซเทคเอเซีย โซลูชั่น จำกัด',           'เลขที่ 2 เพลินจิตเซ็นเตอร์ ชั้น 11',         'ถนนสุขุมวิท แขวงคลองเตย',   'เขตคลองเตย กรุงเทพมหานคร 10110','0105494000477', 0),
('UNC',     'company',    'บริษัท ยูเนี่ยนนิฟโก้ จำกัด',                 '99/11 หมู่ 5 ถนนบางนา-ตราด (กม.38)',          'ตำบลบางสมัคร อำเภอบางปะกง',  'จังหวัดฉะเชิงเทรา 24180',       '0105531086805', 15),
('ZY',      'company',    'บริษัท แซด วาย พลาสติก (ไทยแลนด์) จำกัด',     'เลขที่ 77/88 หมู่ 5 ซอยสายไหม 7',            'แขวงสายไหม เขตสายไหม',      'กรุงเทพฯ 10220',                '0105555156072', 0),
('BDMS',    'company',    'บริษัท กรุงเทพดุสิตเวชการ จำกัด (มหาชน)',      'เลขที่ 2 ซอยศูนย์วิจัย 7 ถนนเพชรบุรีตัดใหม่','แขวงบางกะปิ เขตห้วยขวาง',   'กรุงเทพฯ 10310',                '0107537000025', 0),
('CU-INT',  'university', 'กลุ่มภารกิจสื่อสารนานาชาติ จุฬาลงกรณ์มหาวิทยาลัย','เลขที่ 254 อาคารจามจุรี 1 ถนนพญาไท',     'แขวงวังใหม่ เขตปทุมวัน',    'กรุงเทพฯ 10330',                NULL, 0),
('Nitade',  'university', 'คณะนิเทศศาสตร์ จุฬาลงกรณ์มหาวิทยาลัย',        '254 ถนนพญาไท',                                'แขวงวังใหม่ เขตปทุมวัน',    'กรุงเทพฯ 10330',                NULL, 0),
('CU-COM',  'university', 'คณะพาณิชยศาสตร์และการบัญชี จุฬาลงกรณ์มหาวิทยาลัย','254 ถนนพญาไท',                           'แขวงวังใหม่ เขตปทุมวัน',    'กรุงเทพฯ 10330',                '0994000864060', 0),
('WMS',     'company',    'บริษัท เวสท์ แมเนจเม้นท์ สยาม จำกัด',         '589/142 อาคารเซ็นทรัลซิตี้ ทาวเวอร์ 1',      'ชั้นที่ 25 ถนนบางนา-ตราด',   'แขวงบางนา เขตบางนา กรุงเทพฯ 10260','0115557015506', 0),
(NULL,      'individual', 'Mrs. Suphinya Seila',                           '25/567 Moo 3 Soi 2 Moobaan Mahachai Muangthong','Sahakorn Road, Bangpapreak',  'Muang, Samutsakhon 74000',      '3101700069423', 0),
(NULL,      'individual', 'นางสาวสุภิญญา สุขแดง',                          '115 ซอยวัดอัมพวัน',                           'แขวงนครไชยศรี เขตดุสิต',    'กรุงเทพมหานคร 10300',           '3100800121094', 0),
(NULL,      'individual', 'นางสาวเกศินี พิพัฒนบวร',                        '83/205 หมู่บ้านสัมมากร มีนบุรี 2 ซอยสามวา 20','ถนนสามวา เขตคลองสามวา',    'กรุงเทพฯ 10510',                '3100400474402', 0),
(NULL,      'individual', 'นางสาวสารดี จิวสุวรรณ',                         '299 ถนนสิโรรส',                               'ตำบลสเต็ง อำเภอเมือง',       'จังหวัดยะลา 95000',             '3570900104236', 0),
(NULL,      'individual', 'Miss. Nuanchawee Wetprasit',                     'คณะวิทยาศาสตร์ มหาวิทยาลัยรามคำแหง',         'ถนนรามคำแหง แขวงหัวหมาก',   'เขตบางกะปิ กรุงเทพฯ 10240',    '3510100048889', 0),
('ABBRA',   'company',    'บริษัท แอบบรา จำกัด',                          '206 ซอยพหลโยธิน 14 ถนนพหลโยธิน',             'แขวงสามเสนใน เขตพญาไท',     'กรุงเทพฯ 10400',                '0105529032108', 0),
('VPE',     'company',    'บริษัท วี แอนด์ พี เอ็กซ์แพนด์ เมททัล จำกัด', '49/12 หมู่ 4 ซอยกิ่งแก้ว 30 ถนนกิ่งแก้ว',   'ตำบลราชาเทวะ อำเภอบางพลี',  'จังหวัดสมุทรปราการ 10540',      '0105555024125', 0),
(NULL,      'individual', 'รศ.ดร.ดุษฎี อุตภาพ',                            'สาขาวิชาเทคโนโลยีชีวเคมี คณะทรัพยากรชีวภาพฯ KMUTT','49 ซอยเทียนทะเล 25',   'เขตบางขุนเทียน กรุงเทพฯ 10150',NULL, 0),
(NULL,      'individual', 'Mrs.Nutsima Sripand',                            '1875/39 Soi Sermsuk',                         'Jarunsanitwong 69 Road, Bangplad','Bangkok 10700',              '3102002450980', 0),
(NULL,      'individual', 'นายสุเชษฐ์ สุนทรเวช',                           '2/117 ซอยแจ้งวัฒนะ 14 ถนนแจ้งวัฒนะ',         'แขวงทุ่งสองห้อง เขตหลักสี่', 'กรุงเทพฯ 10210',               '3100502482536', 0),
(NULL,      'individual', 'Mr.Chate Potivongsajarn',                        '888 Moo 13 Soi 45 Bangna-Trad Road',          'Bangkaew, Bangplee',          'Samutprakarn 10540',            '3100100381565', 0),
(NULL,      'individual', 'นางสาวพรรณลิการ์ ชุ่มบุญชู',                     'คณะนิเทศศาสตร์ จุฬาลงกรณ์มหาวิทยาลัย',      '254 ถนนพญาไท แขวงวังใหม่',  'เขตปทุมวัน กรุงเทพฯ 10330',    '3730101301535', 0),
(NULL,      'individual', 'ศ.ดร.วรวรรณ องค์ครุฑรักษา',                     'คณะนิเทศศาสตร์ จุฬาลงกรณ์มหาวิทยาลัย',      '254 ถนนพญาไท แขวงวังใหม่',  'เขตปทุมวัน กรุงเทพฯ 10330',    '3509900153090', 0),
('TKF',     'company',    'บริษัท ทีเคแฟลตฟลอร์ จำกัด',                   '309 หมู่ 6 ถนนพหลโยธิน',                     'แขวงสายไหม เขตสายไหม',      'กรุงเทพฯ 10220',                '0105548099514', 0),
('SRF',     'company',    'บริษัท เอส.อาร์.ไฟเบอร์ จำกัด',                '309 หมู่ 6',                                  'แขวงสายไหม เขตสายไหม',      'กรุงเทพฯ 10220',                '0105542073611', 0),
(NULL,      'individual', 'Mr.James Robert Haft',                           'Faculty of Communication Arts, Chulalongkorn University','254 Phayathai Road, Wangmai','Patumwan Bangkok 10330', NULL, 0),
('CRC',     'company',    'บริษัท ซี อาร์ ซี สปอร์ต จำกัด',              '919/555 ชั้น 13 อาคารเซาท์ทาวเวอร์ ถนนสีลม',  'แขวงสีลม เขตบางรัก',        'กรุงเทพฯ 10500',                '0105539138812', 0),
(NULL,      'individual', 'Mr.Nattaphat Sukdang',                           '115 Soi Wat Amphawan, Rama V Road',           'Nakhon Chai Si, Dusit',       'Bangkok 10300',                 '3101400631151', 0),
(NULL,      'individual', 'Miss Thanatta Chaiwongwat',                      '36 Soi Sukhumvit 62, Sukhumvit Road',         'Bangchak, Phra Khanong',      'Bangkok 10250',                 '3100900984663', 0),
(NULL,      'individual', 'Mr.Pradub Sukhum',                               '2 Soi Soonvijai 7, New Petchburi Road',       'Bangkapi, Huai Khwang',       'Bangkok 10310',                 NULL, 0),
(NULL,      'individual', 'Mrs. Netrsuda Pokkasorn',                        '28/19 Soi Lardprao 23, Lardprao Road',        'Chandrakasem, Chatuchak',     'Bangkok 10900',                 '3100500441875', 0),
(NULL,      'individual', 'น.ส.อารยา อารยะวงศ์',                            '99/88 หมู่ 5 ตำบลบางเมือง',                  'อำเภอเมือง',                 'จังหวัดสมุทรปราการ 10270',      '3800800025820', 0),
(NULL,      'individual', 'นายโชติ โพธิวงศาจารย์',                          '100/395 ซอยคุ้มเกล้า 7',                     'แขวงลำปลาทิว เขตลาดกระบัง', 'กรุงเทพฯ 10520',                '3100100381549', 0),
(NULL,      'individual', 'Mr.Ioannis Mourtzinos',                          'มหาวิทยาลัยเทคโนโลยีพระจอมเกล้าธนบุรี',      '49 ซอยเทียนทะเล 25 บางขุนเทียน','กรุงเทพฯ 10150',             NULL, 0),
(NULL,      'individual', 'น.ส.นวลประไพ ประกิตสุวรรณ',                      '199/203 หมู่บ้านมัณฑนา ถนนนครอินทร์',        'ตำบลบางขุนกอง อำเภอบางกรวย', 'จังหวัดนนทบุรี 11130',          '3640100663311', 0),
(NULL,      'individual', 'น.ส.สมบูรณ์ โสตถิเสาวภาคย์',                    '299 ถนนสิโรรส',                               'ตำบลสเต็ง อำเภอเมือง',       'จังหวัดยะลา 95000',             '3101201486810', 0),
(NULL,      'individual', 'น.ส.ขวัญชนก จินะการ',                            '888 หมู่ 13 ซอย 45 ถนนบางนา-ตราด',           'ตำบลบางแก้ว อำเภอบางพลี',    'จังหวัดสมุทรปราการ 10540',      NULL, 0),
(NULL,      'individual', 'นายอรัญ ปันครอง',                                '93 หมู่ที่ 8',                                'ตำบลหนองแก้ว อำเภอหางดง',   'จังหวัดเชียงใหม่ 50230',        '3501500151123', 0),
(NULL,      'individual', 'น.ส.สมฤดี แซ่อึ้ง',                              '2034/78 ถนนจันทร์',                           'แขวงช่องนนทรี เขตยานนาวา',  'กรุงเทพฯ 10120',                '3101202711212', 0),
('MEYER',   'company',    'บริษัท เมเยอร์เรซิ่น จำกัด',                    '969 หมู่ที่ 13 ซอย 45 ถนนบางนาตราด',         'ตำบลบางแก้ว อำเภอบางพลี',    'จังหวัดสมุทรปราการ 10540',      '0115556008417', 0),
('SNAP',    'company',    'บริษัท ซาแนป ฟิล์มแล็บ จำกัด',                 '122/94 หมู่ที่ 1 ตำบลเสม็ด',                 'อำเภอเมืองชลบุรี',           'จังหวัดชลบุรี 20000',           '0205562016514', 0),
('BRENT',   'company',    'บริษัท เบรนท์โจ โคเซนส์ คอนซัลติ้ง จำกัด',    '17/1 ซอยสุขุมวิท 64/1 ถนนสุขุมวิท',         'แขวงพระโขนงใต้ เขตพระโขนง',  'กรุงเทพฯ 10260',                '0105547121770', 0),
('PROLIFE', 'company',    'บริษัท โปรไลฟ์ จำกัด',                         '2/164 ซอยกรุงเทพกรีฑา 7',                    'แขวงหัวหมาก เขตบางกะปี',    'กรุงเทพฯ 10240',                '0105548071024', 0),
('ANP',     'company',    'บริษัท อรรถพงษ์-ณัฐพร วิศวกรรม จำกัด',         '99/8 หมู่ 20',                               'ตำบลลำลูกกา อำเภอลำลูกกา',   'จังหวัดปทุมธานี 12150',         '0105548143475', 0),
(NULL,      'individual', 'นายวรวิทย์ กวีวัจน์',                            '1088/5 ซอย ส.ธรนินทร์ 10',                   'แขวงห้วยขวาง เขตห้วยขวาง',  'กรุงเทพฯ 10310',                '3102001838585', 0),
(NULL,      'individual', 'นางสาวเบญจวรรณ อ่องศรี',                         '6/8 หมู่ 13 ซอยสตรีวิทยา 2',                 'แขวงลาดพร้าว เขตลาดพร้าว',  'กรุงเทพฯ 10230',                '3100602124984', 0),
(NULL,      'individual', 'น.ส. ชาลัคร์กมล ภัชชะภวะกุลด์',                  '1500/12 ซอยลาดพร้าว 87',                     'แขวงคลองจั่น เขตบางกะปิ',   'กรุงเทพฯ 10240',                '3100602124984', 0),
('CU-ART',  'university', 'สำนักบริหารศิลปวัฒนธรรม จุฬาลงกรณ์มหาวิทยาลัย','254 ถนนพญาไท',                              'แขวงวังใหม่ เขตปทุมวัน',    'กรุงเทพฯ 10330',                '0994000159072', 0);

-- ────────────────────────────────────────────────
-- DONE ✅
-- Next Invoice No: TK00004422 (auto-generated)
-- Total Customers Inserted: 51 records
-- ────────────────────────────────────────────────
