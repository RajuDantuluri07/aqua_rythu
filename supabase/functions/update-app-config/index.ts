import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'jsr:@supabase/supabase-js@2'

interface UpdateConfigRequest {
  key: string;
  value: any;
}

interface UpdateConfigResponse {
  success: boolean;
  message: string;
  data?: any;
  error?: string;
}

// Simple in-memory rate limiting store (for production, use Redis or similar)
const rateLimitStore = new Map<string, number>();

function checkRateLimit(userId: string, cooldownMs: number = 2000): boolean {
  const now = Date.now();
  const lastRequest = rateLimitStore.get(userId) || 0;
  
  if (now - lastRequest < cooldownMs) {
    return false; // Rate limited
  }
  
  rateLimitStore.set(userId, now);
  return true; // Allowed
}

// Validation function for// Validate input types
function validateFeedEngineConfig(config: any): string | null {
  const rules = {
    smartFeedEnabled: 'boolean',
    blindFeedDocLimit: 'number',
    globalFeedMultiplier: 'number',
    feedKillSwitch: 'boolean',
  };

  for (const [key, expectedType] of Object.entries(rules)) {
    const value = config[key];
    const actualType = typeof value;
    const expectedType = expectedType;

    if (actualType !== expectedType) {
      return `Invalid ${key}: expected ${expectedType}, got ${actualType}`;
    }
  }

  return null;
}

// Validate shrimp pricing data
function validateShrimpPricing(pricing: any): string | null {
  if (!pricing || typeof pricing !== 'object') {
    return 'Shrimp pricing data is required and must be an object';
  }

  if (!Array.isArray(pricing.pricing_tiers)) {
    return 'Pricing tiers must be an array';
  }

  const validCounts = [100, 90, 80, 70, 60, 50, 45, 40, 35, 30, 25];
  const seen = new Set();

  for (const tier of pricing.pricing_tiers) {
    if (typeof tier.count !== 'number') {
      return `Invalid count: expected number, got ${typeof tier.count}`;
    }

    if (typeof tier.price !== 'number') {
      return `Invalid price for count ${tier.count}: expected number, got ${typeof tier.price}`;
    }

    if (!Number.isInteger(tier.count)) {
      return `Invalid count: ${tier.count} must be an integer`;
    }

    if (!validCounts.includes(tier.count)) {
      return `Invalid count: ${tier.count}. Valid counts: ${validCounts.join(', ')}`;
    }

    if (seen.has(tier.count)) {
      return `Duplicate count value: ${tier.count}`;
    }

    if (tier.price < 100 || tier.price > 10000) {
      return `Invalid price for count ${tier.count}: must be between 100 and 10000, got ${tier.price}`;
    }

    seen.add(tier.count);
    validatePrice(tier.price);
  }

  // MANDATORY ORDER RULE: Count must decrease, Price must increase
  for (let i = 0; i < pricing.pricing_tiers.length - 1; i++) {
    const current = pricing.pricing_tiers[i];
    const next = pricing.pricing_tiers[i + 1];

    // Rule 1: Count must decrease (100 -> 90 -> 80)
    if (current.count <= next.count) {
      return "Counts must be in descending order (100 -> 90 -> 80)";
    }

    // Rule 2: Price must increase as count decreases
    if (current.price >= next.price) {
      return "Price must increase as count decreases (Count: " + current.count + " -> " + next.count + ", Price: " + current.price + " -> " + next.price + ")";
    }
  }

  return null;
}

// Validate price value
function validatePrice(price: any): string | null {
  if (typeof price !== 'number') {
    return 'Invalid price: expected number, got ${typeof price}';
  }

  if (!Number.isFinite(price)) {
    return 'Invalid price: must be a finite number';
  }

  return null;
}

// Validation function for config inputs
function validateConfigInput(key: string, value: any): { isValid: boolean; error?: string } {
  switch (key) {
    case 'pricing':
      if (typeof value !== 'object' || value === null) {
        return { isValid: false, error: 'Pricing config must be an object' }
      }
      
      if (value.feed_price !== undefined) {
        const feedPrice = Number(value.feed_price)
        if (isNaN(feedPrice) || feedPrice < 0 || feedPrice > 200) {
          return { isValid: false, error: 'feed_price must be between 0 and 200' }
        }
      }
      
      if (value.max_feed_limit !== undefined) {
        const maxFeedLimit = Number(value.max_feed_limit)
        if (isNaN(maxFeedLimit) || maxFeedLimit < 0 || maxFeedLimit > 10000) {
          return { isValid: false, error: 'max_feed_limit must be between 0 and 10000' }
        }
      }
      break
      
    case 'feed_engine':
      if (typeof value !== 'object' || value === null) {
        return { isValid: false, error: 'Feed engine config must be an object' }
      }
      
      if (value.smart_feed_enabled !== undefined && typeof value.smart_feed_enabled !== 'boolean') {
        return { isValid: false, error: 'smart_feed_enabled must be a boolean' }
      }
      
      if (value.feed_kill_switch !== undefined && typeof value.feed_kill_switch !== 'boolean') {
        return { isValid: false, error: 'feed_kill_switch must be a boolean' }
      }
      
      if (value.blind_feed_doc_limit !== undefined) {
        const limit = Number(value.blind_feed_doc_limit)
        if (isNaN(limit) || limit < 0 || limit > 1000) {
          return { isValid: false, error: 'blind_feed_doc_limit must be between 0 and 1000' }
        }
      }
      
      if (value.global_feed_multiplier !== undefined) {
        const multiplier = Number(value.global_feed_multiplier)
        if (isNaN(multiplier) || multiplier < 0.1 || multiplier > 5.0) {
          return { isValid: false, error: 'global_feed_multiplier must be between 0.1 and 5.0' }
        }
      }
      break
      
    case 'features':
      if (typeof value !== 'object' || value === null) {
        return { isValid: false, error: 'Features config must be an object' }
      }
      
      // Validate all feature flags are booleans
      const featureFlags = ['feature_smart_feed', 'feature_sampling', 'feature_growth', 'feature_profit']
      for (const flag of featureFlags) {
        if (value[flag] !== undefined && typeof value[flag] !== 'boolean') {
          return { isValid: false, error: `${flag} must be a boolean` }
        }
      }
      break
      
    case 'announcement':
      if (typeof value !== 'object' || value === null) {
        return { isValid: false, error: 'Announcement config must be an object' }
      }
      
      if (value.banner_enabled !== undefined && typeof value.banner_enabled !== 'boolean') {
        return { isValid: false, error: 'banner_enabled must be a boolean' }
      }
      
      if (value.banner_message !== undefined && typeof value.banner_message !== 'string') {
        return { isValid: false, error: 'banner_message must be a string' }
      }
      
      if (value.banner_message !== undefined && value.banner_message.length > 500) {
        return { isValid: false, error: 'banner_message must be less than 500 characters' }
      }
      break
      
    case 'debug':
      if (typeof value !== 'object' || value === null) {
        return { isValid: false, error: 'Debug config must be an object' }
      }
      
      if (value.debug_mode_enabled !== undefined && typeof value.debug_mode_enabled !== 'boolean') {
        return { isValid: false, error: 'debug_mode_enabled must be a boolean' }
      }
      break
      
    case 'admin_security':
      if (typeof value !== 'object' || value === null) {
        return { isValid: false, error: 'Admin security config must be an object' }
      }
      
      if (value.admin_passcode !== undefined) {
        if (typeof value.admin_passcode !== 'string' || !/^\d{4}$/.test(value.admin_passcode)) {
          return { isValid: false, error: 'admin_passcode must be a 4-digit string' }
        }
      }
      
      if (value.admin_user_id !== undefined && typeof value.admin_user_id !== 'string') {
        return { isValid: false, error: 'admin_user_id must be a string' }
      }
      break
      
    case 'shrimp_pricing':
      const shrimpValidation = validateShrimpPricing(value);
      if (shrimpValidation) {
        return { isValid: false, error: shrimpValidation }
      }
      break
      
    default:
      return { isValid: false, error: `Unknown config key: ${key}` }
  }
  
  return { isValid: true }
}

// Function to generate diff between two config objects
function generateConfigDiff(oldValue: any, newValue: any): any {
  if (oldValue === null && newValue !== null) {
    return { type: 'created', fields: Object.keys(newValue) }
  }
  
  if (oldValue !== null && newValue === null) {
    return { type: 'deleted', fields: Object.keys(oldValue) }
  }
  
  if (oldValue === null && newValue === null) {
    return { type: 'no_change' }
  }
  
  const changes: any = { type: 'modified', changed_fields: [] }
  
  // Find all keys from both objects
  const allKeys = new Set([...Object.keys(oldValue), ...Object.keys(newValue)])
  
  for (const key of allKeys) {
    const oldVal = oldValue[key]
    const newVal = newValue[key]
    
    if (JSON.stringify(oldVal) !== JSON.stringify(newVal)) {
      changes.changed_fields.push({
        field: key,
        old: oldVal,
        new: newVal
      })
    }
  }
  
  return changes
}

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
      },
    })
  }

  try {
    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Method not allowed' 
        } as UpdateConfigResponse),
        {
          status: 405,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Get the authorization header
    const authHeader = req.headers.get('authorization')
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Missing or invalid authorization header' 
        } as UpdateConfigResponse),
        {
          status: 401,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Extract JWT token
    const token = authHeader.replace('Bearer ', '')

    // Create Supabase clients
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    // Client with user token for JWT validation
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      },
    })

    // Service role client for database operations (bypasses RLS)
    const serviceClient = createClient(supabaseUrl, supabaseServiceKey)

    // Validate JWT and get user
    const { data: { user }, error: userError } = await userClient.auth.getUser()
    
    if (userError || !user) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Invalid or expired token',
          error: userError?.message 
        } as UpdateConfigResponse),
        {
          status: 401,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Check if user has admin role in profiles table
    const { data: profile, error: profileError } = await userClient
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single()

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'User profile not found',
          error: profileError?.message 
        } as UpdateConfigResponse),
        {
          status: 403,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    if (profile.role !== 'admin') {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Access denied: Admin role required',
          error: `Current role: ${profile.role}` 
        } as UpdateConfigResponse),
        {
          status: 403,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Check rate limiting
    if (!checkRateLimit(user.id)) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Rate limit exceeded. Please wait before making another request.',
          error: '2 second cooldown between requests'
        } as UpdateConfigResponse),
        {
          status: 429,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Parse request body
    const body: UpdateConfigRequest = await req.json()
    
    if (!body.key || body.value === undefined) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Missing required fields: key and value' 
        } as UpdateConfigResponse),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Strict input validation
    const validationResult = validateConfigInput(body.key, body.value)
    if (!validationResult.isValid) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Invalid input',
          error: validationResult.error 
        } as UpdateConfigResponse),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Validate allowed config keys (whitelist approach)
    const allowedKeys = [
      'feed_engine',
      'pricing', 
      'features',
      'announcement',
      'debug',
      'admin_security',
      'shrimp_pricing'
    ]

    if (!allowedKeys.includes(body.key)) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Invalid config key',
          error: `Allowed keys: ${allowedKeys.join(', ')}` 
        } as UpdateConfigResponse),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Fetch current config for audit logging
    const { data: currentConfig, error: fetchError } = await serviceClient
      .from('app_config')
      .select('value, version')
      .eq('key', body.key)
      .single()

    const oldValue = currentConfig?.value ?? null
    const oldVersion = currentConfig?.version ?? 0

    // Use service role client to update config (bypasses RLS)
    // Enforce single config row by using upsert with key constraint
    const { data: updateData, error: updateError } = await serviceClient
      .from('app_config')
      .upsert({
        key: body.key,
        value: body.value,
        updated_at: new Date().toISOString()
      }, {
        onConflict: 'key' // Ensure only one row per key
      })
      .select('key, value, version, updated_at')
      .single()

    if (updateError) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Failed to update config',
          error: updateError.message 
        } as UpdateConfigResponse),
        {
          status: 500,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    const newVersion = updateData.version

    // Log the admin action for audit (both tables)
    const auditData = {
      user_id: user.id,
      action: 'update_config',
      target_key: body.key,
      old_value: oldValue,
      new_value: body.value,
      old_version: oldVersion,
      new_version: newVersion,
      created_at: new Date().toISOString()
    }

    // Log to admin_audit_log table
    await serviceClient
      .from('admin_audit_log')
      .insert(auditData)

    // Log to config_logs table with structured data
    await serviceClient
      .from('config_logs')
      .insert({
        changed_by: user.id,
        change: {
          type: 'config_update',
          key: body.key,
          before: oldValue,
          after: body.value,
          version_before: oldVersion,
          version_after: newVersion,
          timestamp: new Date().toISOString(),
          diff: generateConfigDiff(oldValue, body.value)
        },
        created_at: new Date().toISOString()
      })

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Config updated successfully',
        data: updateData 
      } as UpdateConfigResponse),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )

  } catch (error) {
    console.error('Edge function error:', error)
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        message: 'Internal server error',
        error: error.message 
      } as UpdateConfigResponse),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  }
})
