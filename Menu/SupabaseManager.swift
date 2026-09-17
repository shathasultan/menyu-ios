import Foundation
import Supabase

/// The single Supabase client for the app.
///
/// `Secrets.swift` is gitignored, so a fresh clone starts from
/// `Secrets.swift.example` with both values empty. Built that way, the client
/// still constructs fine and every request then fails server-side with
/// "No API key found in request" — which surfaces as a login failure, a failed
/// restaurant load, and nothing that points at the actual cause. Stopping here,
/// loudly, costs one crash and saves that whole search.
let supabase: SupabaseClient = {
    let url = Secrets.supabaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    let key = Secrets.supabaseKey.trimmingCharacters(in: .whitespacesAndNewlines)

    var missing: [String] = []
    if url.isEmpty { missing.append("supabaseURL") }
    if key.isEmpty { missing.append("supabaseKey") }

    guard missing.isEmpty else {
        fatalError("""

        ——— إعداد ناقص في Menu/Secrets.swift ———
        القيم الناقصة: \(missing.joined(separator: " و"))

        اجلبيها من Supabase ← Project Settings ← API:
          supabaseURL = قيمة "Project URL"
          supabaseKey = مفتاح "anon public"

        الملف مستثنى من Git عمدًا، فالنسخة الجديدة تبدأ من القالب فارغة.

        """)
    }

    guard let parsed = URL(string: url), parsed.scheme?.hasPrefix("http") == true else {
        fatalError("""

        ——— supabaseURL غير صالح في Menu/Secrets.swift ———
        المتوقَّع عنوان يبدأ بـhttps مثل: https://<المشروع>.supabase.co

        """)
    }

    return SupabaseClient(supabaseURL: parsed, supabaseKey: key)
}()
