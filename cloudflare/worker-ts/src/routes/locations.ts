import { Hono } from 'hono';
import { INDIAN_LOCATIONS } from '../data/india_locations.js';
import type { Env } from '../types/env.js';

export const locationsRouter = new Hono<{ Bindings: Env }>();

// Get list of all Indian states
locationsRouter.get('/states', (c) => {
  const states = INDIAN_LOCATIONS.states.map((s) => s.name);
  return c.json({
    states,
    count: states.length,
    snapshot_date: INDIAN_LOCATIONS.snapshot_date,
  });
});

// Get districts for a given state
locationsRouter.get('/districts/:state', (c) => {
  const stateParam = decodeURIComponent(c.req.param('state')).toLowerCase();
  const matched = INDIAN_LOCATIONS.states.find(
    (s) => s.name.toLowerCase() === stateParam
  );

  if (!matched) {
    return c.json(
      {
        error: 'Not Found',
        message: `State '${c.req.param('state')}' not found in location master`,
      },
      404
    );
  }

  return c.json({
    state: matched.name,
    districts: matched.districts,
    count: matched.districts.length,
  });
});

// Check PIN code delivery serviceability from D1
locationsRouter.get('/serviceability/:pincode', async (c) => {
  const pincode = c.req.param('pincode').trim();
  if (!/^[1-8][0-9]{5}$/.test(pincode)) {
    return c.json({
      pincode,
      is_serviceable: false,
      cod_available: false,
      prepaid_available: false,
      delivery_fee_minor: 0,
      delivery_days_min: 0,
      delivery_days_max: 0,
      message: 'Invalid 6-digit Indian PIN code format',
    });
  }

  try {
    const hint = await c.env.DB.prepare(
      `SELECT city, state, is_serviceable, delivery_fee_minor, delivery_days_min, delivery_days_max
       FROM serviceable_pincodes WHERE pincode = ?`
    )
      .bind(pincode)
      .first<{
        city: string;
        state: string;
        is_serviceable: number;
        delivery_fee_minor: number;
        delivery_days_min: number;
        delivery_days_max: number;
      }>();

    if (hint && hint.is_serviceable) {
      return c.json({
        pincode,
        city: hint.city || '',
        state: hint.state || '',
        is_serviceable: true,
        cod_available: true,
        prepaid_available: true,
        delivery_fee_minor: hint.delivery_fee_minor || 0,
        delivery_days_min: hint.delivery_days_min || 2,
        delivery_days_max: hint.delivery_days_max || 4,
      });
    }

    // Secondary check: delivery_pincode_rules
    const rule = await c.env.DB.prepare(
      `SELECT city, state, is_serviceable, cod_available, prepaid_available, delivery_charge_minor
       FROM delivery_pincode_rules WHERE pincode = ?`
    )
      .bind(pincode)
      .first<{
        city: string;
        state: string;
        is_serviceable: number;
        cod_available: number;
        prepaid_available: number;
        delivery_charge_minor: number;
      }>();

    if (rule && rule.is_serviceable) {
      return c.json({
        pincode,
        city: rule.city || '',
        state: rule.state || '',
        is_serviceable: true,
        cod_available: Boolean(rule.cod_available),
        prepaid_available: Boolean(rule.prepaid_available),
        delivery_fee_minor: rule.delivery_charge_minor || 0,
        delivery_days_min: 2,
        delivery_days_max: 5,
      });
    }

    return c.json({
      pincode,
      city: hint?.city || rule?.city || '',
      state: hint?.state || rule?.state || '',
      is_serviceable: false,
      cod_available: false,
      prepaid_available: false,
      delivery_fee_minor: 0,
      delivery_days_min: 0,
      delivery_days_max: 0,
      message: 'PIN code is currently outside our direct farm delivery network',
    });
  } catch (err) {
    return c.json(
      {
        pincode,
        is_serviceable: false,
        error: (err as Error).message,
      },
      500
    );
  }
});
