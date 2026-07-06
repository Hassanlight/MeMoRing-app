/// Backend (Supabase) connection. The anon/public key is SAFE to ship — Row
/// Level Security limits it to inserting telemetry/feedback and reading
/// announcements. Never put the service_role / secret key here.
library;

const String kSupabaseUrl = 'https://gkpxxdotubmgsqotjqst.supabase.co';
const String kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdrcHh4ZG90dWJtZ3Nxb3RqcXN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMxNjA5MDgsImV4cCI6MjA5ODczNjkwOH0.2U9-HsKopYuCAUBOyvpu4vZK7ckAJwSYCqpJ7U8d4qQ';

/// Current app version, sent with telemetry so the dashboard can segment by build.
const String kAppVersion = '1.0.1+3';
