import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'jsr:@supabase/supabase-js@2'

interface ValidatePasscodeRequest {
  passcode: string;
}

interface ValidatePasscodeResponse {
  success: boolean;
  message: string;
  user_id?: string;
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
        } as ValidatePasscodeResponse),
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
        } as ValidatePasscodeResponse),
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

    // Client with user token for JWT validation
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      },
    })

    // Validate JWT and get user
    const { data: { user }, error: userError } = await userClient.auth.getUser()
    
    if (userError || !user) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Invalid or expired token',
          error: userError?.message 
        } as ValidatePasscodeResponse),
        {
          status: 401,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Parse request body
    const body: ValidatePasscodeRequest = await req.json()
    
    if (!body.passcode) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Missing passcode' 
        } as ValidatePasscodeResponse),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Validate passcode format (4 digits)
    if (!/^\d{4}$/.test(body.passcode)) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Invalid passcode format' 
        } as ValidatePasscodeResponse),
        {
          status: 400,
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
        } as ValidatePasscodeResponse),
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
        } as ValidatePasscodeResponse),
        {
          status: 403,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Fetch admin security config from Supabase
    const { data: configData, error: configError } = await userClient
      .from('app_config')
      .select('value')
      .eq('key', 'admin_security')
      .single()

    if (configError || !configData) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Admin security configuration not found',
          error: configError?.message 
        } as ValidatePasscodeResponse),
        {
          status: 500,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    const adminConfig = configData.value as any
    const correctPasscode = adminConfig.admin_passcode as string
    const allowedUserId = adminConfig.admin_user_id as string

    // Validate passcode and user ID
    if (body.passcode !== correctPasscode || user.id !== allowedUserId) {
      // Log failed attempt for security
      console.warn(`Failed admin login attempt: user=${user.id}, passcode=${body.passcode}`)
      
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Invalid passcode or unauthorized user' 
        } as ValidatePasscodeResponse),
        {
          status: 403,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Success - return user info for session management
    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Admin access granted',
        user_id: user.id
      } as ValidatePasscodeResponse),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )

  } catch (error) {
    console.error('Admin passcode validation error:', error)
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        message: 'Internal server error',
        error: error.message 
      } as ValidatePasscodeResponse),
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
