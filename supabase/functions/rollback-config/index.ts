import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'jsr:@supabase/supabase-js@2'

interface RollbackRequest {
  key: string;
  targetVersion?: number; // Optional: if not provided, rollback to previous version
}

interface RollbackResponse {
  success: boolean;
  message: string;
  data?: any;
  error?: string;
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
        } as RollbackResponse),
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
        } as RollbackResponse),
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
        } as RollbackResponse),
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
        } as RollbackResponse),
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
        } as RollbackResponse),
        {
          status: 403,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Parse request body
    const body: RollbackRequest = await req.json()
    
    if (!body.key) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Missing required field: key' 
        } as RollbackResponse),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Validate allowed config keys
    const allowedKeys = [
      'feed_engine',
      'pricing', 
      'features',
      'announcement',
      'debug',
      'admin_security'
    ]

    if (!allowedKeys.includes(body.key)) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Invalid config key',
          error: `Allowed keys: ${allowedKeys.join(', ')}` 
        } as RollbackResponse),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Get current config
    const { data: currentConfig, error: currentError } = await serviceClient
      .from('app_config')
      .select('value, version')
      .eq('key', body.key)
      .single()

    if (currentError || !currentConfig) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Config not found',
          error: currentError?.message 
        } as RollbackResponse),
        {
          status: 404,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    const currentVersion = currentConfig.version
    let targetVersion = body.targetVersion

    // If no target version specified, rollback to previous version
    if (!targetVersion) {
      targetVersion = Math.max(1, currentVersion - 1)
    }

    // Validate target version
    if (targetVersion >= currentVersion) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Target version must be less than current version',
          error: `Current: ${currentVersion}, Target: ${targetVersion}` 
        } as RollbackResponse),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    if (targetVersion < 1) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Target version must be at least 1',
          error: `Target: ${targetVersion}` 
        } as RollbackResponse),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Find the target version in config logs
    const { data: logEntry, error: logError } = await serviceClient
      .from('config_logs')
      .select('change')
      .eq('key', body.key)
      .eq('version_after', targetVersion)
      .order('created_at', { ascending: false })
      .limit(1)
      .single()

    if (logError || !logEntry) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Target version not found in logs',
          error: logError?.message 
        } as RollbackResponse),
        {
          status: 404,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    const targetValue = logEntry.change.after

    // Perform rollback update
    const { data: rollbackData, error: rollbackError } = await serviceClient
      .from('app_config')
      .update({
        value: targetValue,
        updated_at: new Date().toISOString()
      })
      .eq('key', body.key)
      .select('key, value, version, updated_at')
      .single()

    if (rollbackError) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Failed to rollback config',
          error: rollbackError.message 
        } as RollbackResponse),
        {
          status: 500,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Log the rollback action
    await serviceClient
      .from('admin_audit_log')
      .insert({
        user_id: user.id,
        action: 'rollback_config',
        target_key: body.key,
        old_value: currentConfig.value,
        new_value: targetValue,
        old_version: currentVersion,
        new_version: rollbackData.version,
        created_at: new Date().toISOString()
      })

    await serviceClient
      .from('config_logs')
      .insert({
        changed_by: user.id,
        change: {
          type: 'config_rollback',
          key: body.key,
          before: currentConfig.value,
          after: targetValue,
          version_before: currentVersion,
          version_after: rollbackData.version,
          timestamp: new Date().toISOString(),
          rollback_target: targetVersion
        },
        created_at: new Date().toISOString()
      })

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Config rolled back successfully',
        data: {
          rolled_back_from: currentVersion,
          rolled_back_to: rollbackData.version,
          config: rollbackData
        }
      } as RollbackResponse),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )

  } catch (error) {
    console.error('Config rollback error:', error)
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        message: 'Internal server error',
        error: error.message 
      } as RollbackResponse),
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
