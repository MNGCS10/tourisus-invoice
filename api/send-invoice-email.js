// api/send-invoice-email.js
// Backend relay for Resend — fixes the CORS issue from calling api.resend.com
// directly from the browser, and keeps RESEND_API_KEY off the client entirely.

export default async function handler(req, res) {
  // Allow the invoice page to call this endpoint.
  // If the invoice page is hosted on the same Vercel project, you can
  // tighten this to your real domain instead of '*'.
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { to, subject, html, pdfBase64, fileName } = req.body || {};

  if (!to || !subject || !html) {
    return res.status(400).json({ error: 'Missing required fields: to, subject, html' });
  }

  if (!process.env.RESEND_API_KEY) {
    return res.status(500).json({ error: 'RESEND_API_KEY is not configured on the server' });
  }

  if (!process.env.RESEND_FROM_EMAIL) {
    return res.status(500).json({ error: 'RESEND_FROM_EMAIL is not configured on the server' });
  }

  try {
    const resendRes = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: process.env.RESEND_FROM_EMAIL, // e.g. "Touris Us <invoice@yourdomain.com>"
        to,
        subject,
        html,
        attachments: pdfBase64
          ? [{ filename: fileName || 'invoice.pdf', content: pdfBase64 }]
          : undefined,
      }),
    });

    const data = await resendRes.json();

    if (!resendRes.ok) {
      return res.status(resendRes.status).json(data);
    }

    return res.status(200).json(data);
  } catch (err) {
    return res.status(500).json({ error: 'Failed to send email', detail: String(err) });
  }
}
