// api/invoices/[id].js
// GET   /api/invoices/:id           -> full invoice detail + line items + customer
// PATCH /api/invoices/:id           -> update status (draft->pending on confirm, or ->cancelled)

import { supabaseAdmin } from '../../lib/supabaseAdmin.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, PATCH, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();

  const { id } = req.query;
  if (!id) return res.status(400).json({ error: 'Missing invoice id' });

  if (req.method === 'GET') {
    const { data: invoice, error: invErr } = await supabaseAdmin
      .from('invoices')
      .select('*, customers(*)')
      .eq('id', id)
      .single();
    if (invErr) return res.status(404).json({ error: invErr.message });

    const { data: items, error: itemsErr } = await supabaseAdmin
      .from('invoice_items')
      .select('*')
      .eq('invoice_id', id)
      .order('line_no', { ascending: true });
    if (itemsErr) return res.status(500).json({ error: itemsErr.message });

    return res.status(200).json({ invoice, items });
  }

  if (req.method === 'PATCH') {
    const { status } = req.body || {};
    const allowed = ['draft', 'pending', 'paid', 'cancelled'];
    if (!allowed.includes(status)) {
      return res.status(400).json({ error: `status must be one of: ${allowed.join(', ')}` });
    }

    const { data, error } = await supabaseAdmin
      .from('invoices')
      .update({ status })
      .eq('id', id)
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });
    return res.status(200).json({ invoice: data });
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
