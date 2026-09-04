// Drop this <script> into the existing Invoice HTML prototype (or import it),
// then call sendInvoiceEmail(...) instead of fetching api.resend.com directly.
//
// Usage from the invoice page, after generating the PDF as base64:
//
//   await sendInvoiceEmail({
//     to: customer.email,
//     subject: `ใบแจ้งหนี้ ${invoice.invoiceNo} — Touris Us`,
//     html: `<p>เรียน ${customer.contactName}</p><p>แนบใบแจ้งหนี้เลขที่ ${invoice.invoiceNo}</p>`,
//     pdfBase64: base64PdfString, // optional
//     fileName: `${invoice.invoiceNo}.pdf`,
//   });

async function sendInvoiceEmail({ to, subject, html, pdfBase64, fileName }) {
  const res = await fetch('/api/send-invoice-email', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ to, subject, html, pdfBase64, fileName }),
  });

  const data = await res.json();

  if (!res.ok) {
    throw new Error(data.error || 'ส่งอีเมลไม่สำเร็จ');
  }

  return data;
}
