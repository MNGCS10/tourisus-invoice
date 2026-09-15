// api/purchase-vat.js
// GET  /api/purchase-vat                 -> list purchase VAT entries (input VAT / VAT ซื้อ), newest first
// POST /api/purchase-vat                 -> record a new vendor purchase for input VAT

import { supabaseAdmin } from '../lib/supabaseAdmin.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();

  if (req.method === 'GET') {
    const { data, error } = await supabaseAdmin
      .from('purchase_vat_entries')
      .select(`
        id, entry_date, description, doc_ref, amount, vat_amount, note, created_at,
        vendors ( id, name, tax_id )
      `)
      .order('entry_date', { ascending: false });

    if (error) return res.status(500).json({ error: error.message });
    return res.status(200).json({ entries: data });
  }

  if (req.method === 'POST') {
    const { vendorId, entryDate, description, docRef, amount, vatAmount, note } = req.body || {};

    if (!vendorId) return res.status(400).json({ error: 'vendorId is required' });
    if (!entryDate) return res.status(400).json({ error: 'entryDate is required' });
    if (amount === undefined || amount === null) return res.status(400).json({ error: 'amount is required' });

    const { data: entry, error } = await supabaseAdmin
      .from('purchase_vat_entries')
      .insert([{
        vendor_id: vendorId,
        entry_date: entryDate,
        description: description || null,
        doc_ref: docRef || null,
        amount,
        vat_amount: vatAmount || 0,
        note: note || null,
      }])
      .select(`id, entry_date, description, doc_ref, amount, vat_amount, note, vendors ( id, name, tax_id )`)
      .single();

    if (error) return res.status(500).json({ error: error.message });
    return res.status(201).json({ entry });
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
