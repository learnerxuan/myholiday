import { query } from '@/lib/supabase/db'

export async function GET() {
  try {
    const result = await query('SELECT COUNT(*) FROM destinations')
    return Response.json({ 
      success: true, 
      destinations: result.rows[0].count 
    })
  } catch (error) {
    return Response.json({ success: false, error: String(error) }, { status: 500 })
  }
}