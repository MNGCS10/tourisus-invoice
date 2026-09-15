// api/vat-summary.js
// GET /api/vat-summary[?year=2026]  -> monthly output VAT (sales) vs input VAT (purchases)
//
// Reads the v_vat_filing_summary view (built in the Phase 3 migration), which
// full-joins v_output_vat_monthly (sum of invoices.vat_amount, excluding
// cancelled invoices) and v_input_vat_monthly (sum of purchase_vat_entries.vat_amount)
// per calendar month. net_vat = output_vat - input_vat: positive means VAT
// payable to the Revenue Department (ภ.พ.30), negative means a refund position.

import { supabaseAdmin } from '../lib/supabaseAdmin.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();

  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  let query = supabaseAdmin
    .from('v_vat_filing_summary')
    .select('period_year_ad, period_month, output_vat, input_vat, net_vat')
    .order('period_year_ad', { ascending: false })
    .order('period_month', { ascending: false });

  const year = parseInt(req.query.year, 10);
  if (year) query = query.eq('period_year_ad', year);

  const { data, error } = await query;
  if (error) return res.status(500).json({ error: error.message });
  return res.status(200).json({ summary: data });
}
