// ============================================================
// TOURIS US — Google Apps Script Backend
// เชื่อม Invoice System HTML → Google Sheets
// ============================================================
// วิธีใช้:
// 1. เปิด Google Sheet ใหม่
// 2. Extensions → Apps Script → วาง code นี้
// 3. Deploy → New deployment → Web app
//    Execute as: Me | Who has access: Anyone
// 4. Copy deployment URL → วางใน Invoice System
// ============================================================

const SHEET_ID = SpreadsheetApp.getActiveSpreadsheet().getId();

// ── MAIN HANDLER ──
function doPost(e) {
  const data = JSON.parse(e.postData.contents);
  let result;
  try {
    switch (data.action) {
      case 'saveInvoice':   result = saveInvoice(data.payload);   break;
      case 'getInvoices':   result = getInvoices();               break;
      case 'saveCustomer':  result = saveCustomer(data.payload);  break;
      case 'getCustomers':  result = getCustomers();              break;
      case 'updateStatus':  result = updateStatus(data.payload);  break;
      case 'savePayment':   result = savePayment(data.payload);   break;
      default: result = { error: 'Unknown action: ' + data.action };
    }
  } catch(err) {
    result = { error: err.message };
  }
  return ContentService
    .createTextOutput(JSON.stringify(result))
    .setMimeType(ContentService.MimeType.JSON);
}

function doGet(e) {
  const action = e.parameter.action;
  let result;
  try {
    if (action === 'getInvoices') result = getInvoices();
    else if (action === 'getCustomers') result = getCustomers();
    else result = { status: 'Touris Us Invoice API — OK', timestamp: new Date().toISOString() };
  } catch(err) {
    result = { error: err.message };
  }
  return ContentService
    .createTextOutput(JSON.stringify(result))
    .setMimeType(ContentService.MimeType.JSON);
}

// ── INVOICES ──
function saveInvoice(inv) {
  const ss = SpreadsheetApp.openById(SHEET_ID);
  
  // Sheet: Invoices
  let sheet = ss.getSheetByName('Invoices');
  if (!sheet) {
    sheet = ss.insertSheet('Invoices');
    const headers = ['Invoice No', 'วันที่', 'ครบกำหนด', 'Credit Term', 'ชื่อลูกค้า',
      'ที่อยู่ 1', 'ที่อยู่ 2', 'ที่อยู่ 3', 'Tax ID', 'ยอดก่อน VAT',
      'VAT', 'ยอดรวม', 'หัก ณ ที่จ่าย', 'ยอดสุทธิ', 'สถานะ', 'หมายเหตุ', 'บันทึกเมื่อ'];
    sheet.appendRow(headers);
    sheet.getRange(1, 1, 1, headers.length)
      .setBackground('#1B6AC9').setFontColor('#FFFFFF').setFontWeight('bold');
    sheet.setFrozenRows(1);
  }
  
  sheet.appendRow([
    inv.invoiceNo, inv.date, inv.dueDate, inv.creditTerm,
    inv.custName, inv.custAddr1, inv.custAddr2, inv.custAddr3, inv.custTaxId,
    inv.subtotal, inv.vatAmount, inv.total, inv.whtAmount, inv.netAmount,
    inv.status || 'draft', inv.note || '', new Date().toISOString()
  ]);

  // Sheet: Invoice_Items
  let itemSheet = ss.getSheetByName('Invoice_Items');
  if (!itemSheet) {
    itemSheet = ss.insertSheet('Invoice_Items');
    const itemHeaders = ['Invoice No', 'ลำดับ', 'คำอธิบาย', 'จำนวนเงิน', 'Qty', 'VAT%', 'หัก ณ ที่จ่าย%', 'ยอดรวม'];
    itemSheet.appendRow(itemHeaders);
    itemSheet.getRange(1, 1, 1, itemHeaders.length)
      .setBackground('#1B6AC9').setFontColor('#FFFFFF').setFontWeight('bold');
    itemSheet.setFrozenRows(1);
  }
  
  (inv.items || []).forEach((item, i) => {
    itemSheet.appendRow([
      inv.invoiceNo, i + 1, item.desc, item.amount, item.qty,
      item.vat || 0, item.wht || 0,
      (item.amount || 0) * (item.qty || 1)
    ]);
  });

  return { success: true, invoiceNo: inv.invoiceNo };
}

function getInvoices() {
  const ss = SpreadsheetApp.openById(SHEET_ID);
  const sheet = ss.getSheetByName('Invoices');
  if (!sheet) return { invoices: [] };
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const invoices = data.slice(1).map(row => {
    const obj = {};
    headers.forEach((h, i) => obj[h] = row[i]);
    return obj;
  });
  return { invoices };
}

// ── STATUS UPDATE ──
function updateStatus(payload) {
  // payload: { invoiceNo, status, paidDate, paidAmount }
  const ss = SpreadsheetApp.openById(SHEET_ID);
  const sheet = ss.getSheetByName('Invoices');
  if (!sheet) return { error: 'Sheet not found' };
  
  const data = sheet.getDataRange().getValues();
  const invNoCol = 0; // Column A
  const statusCol = 14; // Column O (0-indexed)
  
  for (let i = 1; i < data.length; i++) {
    if (data[i][invNoCol] === payload.invoiceNo) {
      sheet.getRange(i + 1, statusCol + 1).setValue(payload.status);
      if (payload.paidDate) sheet.getRange(i + 1, statusCol + 2).setValue(payload.paidDate);
      return { success: true };
    }
  }
  return { error: 'Invoice not found: ' + payload.invoiceNo };
}

// ── PAYMENTS ──
function savePayment(payment) {
  const ss = SpreadsheetApp.openById(SHEET_ID);
  let sheet = ss.getSheetByName('Payments');
  if (!sheet) {
    sheet = ss.insertSheet('Payments');
    const headers = ['Invoice No', 'วันที่ชำระ', 'ยอด', 'ช่องทาง', 'เลขอ้างอิง', 'หมายเหตุ', 'บันทึกเมื่อ'];
    sheet.appendRow(headers);
    sheet.getRange(1, 1, 1, headers.length)
      .setBackground('#1B7A34').setFontColor('#FFFFFF').setFontWeight('bold');
  }
  sheet.appendRow([
    payment.invoiceNo, payment.paidDate, payment.amount,
    payment.method, payment.ref, payment.note,
    new Date().toISOString()
  ]);
  // Auto-update invoice status
  updateStatus({ invoiceNo: payment.invoiceNo, status: 'paid', paidDate: payment.paidDate });
  return { success: true };
}

// ── CUSTOMERS ──
function saveCustomer(c) {
  const ss = SpreadsheetApp.openById(SHEET_ID);
  let sheet = ss.getSheetByName('Customers');
  if (!sheet) {
    sheet = ss.insertSheet('Customers');
    const headers = ['ID', 'รหัส', 'ประเภท', 'ชื่อ', 'ที่อยู่ 1', 'ที่อยู่ 2', 'ที่อยู่ 3', 'Tax ID', 'Credit Term', 'วันที่เพิ่ม'];
    sheet.appendRow(headers);
    sheet.getRange(1, 1, 1, headers.length)
      .setBackground('#1B6AC9').setFontColor('#FFFFFF').setFontWeight('bold');
    sheet.setFrozenRows(1);
  }
  sheet.appendRow([
    c.id, c.code, c.type, c.name,
    c.addr1, c.addr2, c.addr3, c.taxid, c.credit,
    new Date().toISOString()
  ]);
  return { success: true, customerId: c.id };
}

function getCustomers() {
  const ss = SpreadsheetApp.openById(SHEET_ID);
  const sheet = ss.getSheetByName('Customers');
  if (!sheet) return { customers: [] };
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const customers = data.slice(1).map(row => {
    const obj = {};
    headers.forEach((h, i) => obj[h] = row[i]);
    return obj;
  });
  return { customers };
}
