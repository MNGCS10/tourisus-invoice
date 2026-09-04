// api/customers.js
// GET  /api/customers?q=search-term   -> list/search active customers
// POST /api/customers                  -> create a new customer

import { supabaseAdmin } from '../lib/supabaseAdmin.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();

  if (req.method === 'GET') {
    const q = (req.query.q || '').trim();
    let query = supabaseAdmin
      .from('customers')
      .select('id, code, type, name_th, name_en, address1, address2, address3, tax_id, phone, email, credit_term_days')
      .eq('is_active', true)
      .order('name_th', { ascending: true });

    if (q) {
      query = query.or(`name_th.ilike.%${q}%,code.ilike.%${q}%,tax_id.ilike.%${q}%`);
    }

    const { data, error } = await query;
    if (error) return res.status(500).json({ error: error.message });
    return res.status(200).json({ customers: data });
  }

  if (req.method === 'POST') {
    const { code, type, name_th, address1, address2, address3, tax_id, phone, email, credit_term_days } = req.body || {};
    if (!name_th) return res.status(400).json({ error: 'name_th is required' });

    const { data, error } = await supabaseAdmin
      .from('customers')
      .insert([{ code, type, name_th, address1, address2, address3, tax_id, phone, email, credit_term_days: credit_term_days || 0 }])
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });
    return res.status(201).json({ customer: data });
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
