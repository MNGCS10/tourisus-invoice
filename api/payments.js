// api/payments.js
// POST /api/payments -> record a payment, mark invoice as paid

import { supabaseAdmin } from '../lib/supabaseAdmin.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const { invoiceId, paidDate, amount, paymentMethod, referenceNo, note } = req.body || {};

  if (!invoiceId) return res.status(400).json({ error: 'invoiceId is required' });
  if (!amount) return res.status(400).json({ error: 'amount is required' });

  const { data: payment, error: payErr } = await supabaseAdmin
    .from('payments')
    .insert([{
      invoice_id: invoiceId,
      paid_date: paidDate || new Date().toISOString().split('T')[0],
      amount,
      payment_method: paymentMethod || 'transfer',
      reference_no: referenceNo || null,
      note: note || null,
    }])
    .select()
    .single();

  if (payErr) return res.status(500).json({ error: payErr.message });

  // Mark the invoice itself as paid (trigger `sync_invoice_payment_status`
  // in the schema may already do this — this call is a safe, explicit fallback).
  const { error: invErr } = await supabaseAdmin
    .from('invoices')
    .update({
      status: 'paid',
      paid_date: payment.paid_date,
      paid_amount: amount,
      payment_method: paymentMethod || 'transfer',
    })
    .eq('id', invoiceId);

  if (invErr) return res.status(500).json({ error: invErr.message });

  return res.status(201).json({ payment });
}
