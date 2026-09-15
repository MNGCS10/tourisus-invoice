// api/vendors.js
// GET  /api/vendors?q=search-term   -> list/search active vendors (for Purchase VAT entries)
// POST /api/vendors                  -> create a new vendor

import { supabaseAdmin } from '../lib/supabaseAdmin.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();

  if (req.method === 'GET') {
    const q = (req.query.q || '').trim();
    let query = supabaseAdmin
      .from('vendors')
      .select('id, code, name, tax_id, address, phone, email')
      .eq('is_active', true)
      .order('name', { ascending: true });

    if (q) {
      query = query.or(`name.ilike.%${q}%,code.ilike.%${q}%,tax_id.ilike.%${q}%`);
    }

    const { data, error } = await query;
    if (error) return res.status(500).json({ error: error.message });
    return res.status(200).json({ vendors: data });
  }

  if (req.method === 'POST') {
    const { code, name, taxId, address, phone, email } = req.body || {};
    if (!name) return res.status(400).json({ error: 'name is required' });

    const { data, error } = await supabaseAdmin
      .from('vendors')
      .insert([{ code: code || null, name, tax_id: taxId || null, address: address || null, phone: phone || null, email: email || null }])
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });
    return res.status(201).json({ vendor: data });
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
