import { buildWeeklyReportHtml } from "./resend";

export interface Env {
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  RESEND_API_KEY: string;
}

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Token",
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const path = url.pathname;
    const prefix = "/cpac-trust-db/api";

    if (!path.startsWith(prefix)) {
      return json({ error: "Not found" }, 404);
    }

    const route = path.slice(prefix.length);

    // ── AUR proxy: /cpac-trust-db/api/aur/info/<pkg> ──
    // Proxies AUR RPC info endpoint (browser can't fetch directly due to CORS)
    if (route.startsWith("/aur/info/")) {
      const pkg = route.slice("/aur/info/".length);
      return proxyAur(`https://aur.archlinux.org/rpc/v5/info/${encodeURIComponent(pkg)}`);
    }

    // ── AUR proxy: /cpac-trust-db/api/aur/pkgbuild/<pkg> ──
    // Proxies PKGBUILD fetch (browser can't fetch directly due to CORS)
    if (route.startsWith("/aur/pkgbuild/")) {
      const pkg = route.slice("/aur/pkgbuild/".length);
      return proxyAur(`https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=${encodeURIComponent(pkg)}`, true);
    }

    // ── Account creation: POST /cpac-trust-db/api/accounts/create ──
    // Admin-only: creates auth user, inserts profile, sends welcome email
    if (route === "/accounts/create" && request.method === "POST") {
      return handleAccountCreate(request, env);
    }

    // ── Report generation: POST /cpac-trust-db/api/reports/generate ──
    // Generates weekly reports for volunteers whose report day is today
    if (route === "/reports/generate" && request.method === "POST") {
      return handleReportGenerate(env);
    }

    // ── Report sending: POST /cpac-trust-db/api/reports/send ──
    // Sends queued reports via Resend, logs in email_log, deletes from queue
    if (route === "/reports/send" && request.method === "POST") {
      return handleReportSend(env);
    }

    // ── Supabase proxy: /cpac-trust-db/api/... → /rest/v1/... ──
    const supabasePath = "/rest/v1" + route;
    const supabaseUrl = new URL(supabasePath, env.SUPABASE_URL);
    url.searchParams.forEach((v, k) => supabaseUrl.searchParams.set(k, v));

    const headers = new Headers();
    headers.set("apikey", env.SUPABASE_ANON_KEY);
    headers.set("Authorization", `Bearer ${env.SUPABASE_ANON_KEY}`);
    headers.set("Content-Type", "application/json");

    const clientToken = request.headers.get("X-Client-Token");
    if (clientToken) {
      headers.set("X-Client-Token", clientToken);
    }

    try {
      const res = await fetch(supabaseUrl.toString(), {
        method: request.method,
        headers,
        body: request.method !== "GET" && request.method !== "HEAD"
          ? await request.text()
          : undefined,
      });

      return new Response(res.body, {
        status: res.status,
        headers: { "Content-Type": "application/json", ...CORS_HEADERS },
      });
    } catch (e) {
      return json({ error: "Upstream error", detail: String(e) }, 502);
    }
  },
};

async function proxyAur(targetUrl: string, text = false): Promise<Response> {
  try {
    const res = await fetch(targetUrl, {
      headers: { "User-Agent": "cpac-trust-db/1.0" },
    });
    const contentType = text ? "text/plain" : "application/json";
    return new Response(res.body, {
      status: res.status,
      headers: { "Content-Type": contentType, ...CORS_HEADERS },
    });
  } catch (e) {
    return json({ error: "AUR proxy error", detail: String(e) }, 502);
  }
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

// ── Account creation handler ──
function generatePassword(length = 16): string {
  const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*";
  const array = new Uint8Array(length);
  crypto.getRandomValues(array);
  return Array.from(array, (b) => chars[b % chars.length]).join("");
}

async function handleAccountCreate(request: Request, env: Env): Promise<Response> {
  const body = await request.json() as { email: string; role: string; display_name: string };

  if (!body.email || !body.role || !body.display_name) {
    return json({ error: "Missing required fields: email, role, display_name" }, 400);
  }
  if (!["volunteer", "maintainer", "admin"].includes(body.role)) {
    return json({ error: "Role must be volunteer, maintainer, or admin" }, 400);
  }

  const password = generatePassword();

  // Step 1: Create auth user via Supabase Management API
  const createRes = await fetch(`${env.SUPABASE_URL}/auth/v1/admin/users`, {
    method: "POST",
    headers: {
      "apikey": env.SUPABASE_SERVICE_ROLE_KEY,
      "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      email: body.email,
      password: password,
      email_confirm: true,
    }),
  });

  const createData = await createRes.json() as { id?: string; msg?: string; error?: string; error_description?: string };
  if (!createRes.ok || !createData.id) {
    return json({ error: "Failed to create auth user", detail: createData }, 400);
  }

  const userId = createData.id;

  // Step 2: Insert profile
  const profileRes = await fetch(`${env.SUPABASE_URL}/rest/v1/profiles`, {
    method: "POST",
    headers: {
      "apikey": env.SUPABASE_ANON_KEY,
      "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      "Prefer": "return=representation",
    },
    body: JSON.stringify({
      id: userId,
      role: body.role,
      display_name: body.display_name,
    }),
  });

  if (!profileRes.ok) {
    const profileErr = await profileRes.json();
    return json({ error: "Failed to create profile", detail: profileErr }, 400);
  }

  // Step 3: Send welcome email
  const loginUrl = "https://thecinderproject.qd.je/cpac-trust-db/web/panel/login/";
  const html = `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family:sans-serif;color:#333;max-width:600px;margin:0 auto;padding:20px;">
  <p>Hi ${body.display_name},</p>
  <p>An admin account has been created for you on the <strong>CPAC Trust DB</strong>.</p>
  <p><strong>Login URL:</strong> <a href="${loginUrl}">${loginUrl}</a></p>
  <p><strong>Email:</strong> ${body.email}</p>
  <p><strong>Temporary Password:</strong> <code style="background:#1a1a1a;color:#86efac;padding:2px 6px;border-radius:4px;">${password}</code></p>
  <p><strong>Role:</strong> ${body.role}</p>
  <p style="margin-top:16px;">Please log in and change your password immediately via the panel.</p>
  <p style="color:#888;font-size:12px;margin-top:24px;">The Cinder Project<br>THIS MAILBOX IS NOT MONITORED</p>
</body>
</html>`;

  try {
    await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${env.RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "CPAC Trust DB <no-reply@thecinderproject.qd.je>",
        to: [body.email],
        subject: "Your CPAC Trust DB Account",
        html: html,
      }),
    });
  } catch (e) {
    // Email failure is non-fatal — account is still created
  }

  return json({ userId, email: body.email, role: body.role, tempPassword: password });
}

// ── Report generation handler ──
async function handleReportGenerate(env: Env): Promise<Response> {
  // Step 1: Get volunteers due for reports today
  const volunteersRes = await fetch(
    `${env.SUPABASE_URL}/rest/v1/rpc/get_volunteers_for_today`,
    {
      method: "POST",
      headers: {
        "apikey": env.SUPABASE_ANON_KEY,
        "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
        "Content-Type": "application/json",
      },
    }
  );

  if (!volunteersRes.ok) {
    return json({ error: "Failed to fetch volunteers", detail: await volunteersRes.text() }, 500);
  }

  const volunteers = await volunteersRes.json() as Array<{
    volunteer_id: string;
    email: string;
    display_name: string;
    created_at: string;
    account_age_days: number;
  }>;

  const generated: string[] = [];
  const skipped: string[] = [];

  // Step 2: For each volunteer, get their weekly submissions and generate report
  for (const vol of volunteers) {
    // Calculate week range (last 7 days)
    const weekEnd = new Date();
    const weekStart = new Date();
    weekStart.setDate(weekStart.getDate() - 7);

    // Get submissions for this volunteer in the past week
    const subsRes = await fetch(
      `${env.SUPABASE_URL}/rest/v1/rpc/get_weekly_submissions`,
      {
        method: "POST",
        headers: {
          "apikey": env.SUPABASE_ANON_KEY,
          "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          p_volunteer_id: vol.volunteer_id,
          p_week_start: weekStart.toISOString().split("T")[0],
          p_week_end: weekEnd.toISOString().split("T")[0],
        }),
      }
    );

    if (!subsRes.ok) {
      skipped.push(vol.email);
      continue;
    }

    const submissions = await subsRes.json() as Array<{
      package: string;
      severity: string;
      status: string;
      review_status: string;
      submitted_date: string;
    }>;

    // Skip if no activity this week
    if (submissions.length === 0) {
      skipped.push(vol.email);
      continue;
    }

    // Get reputation stats
    const repRes = await fetch(
      `${env.SUPABASE_URL}/rest/v1/volunteer_reputation?id=eq.${vol.volunteer_id}&select=*`,
      {
        headers: {
          "apikey": env.SUPABASE_ANON_KEY,
          "Authorization": `Bearer ${env.SUPABASE_ANON_KEY}`,
        },
      }
    );

    let trustTier = "standard";
    let approvalRate = 0;
    if (repRes.ok) {
      const repData = await repRes.json() as Array<{ trust_tier: string; approval_rate: number }>;
      if (repData.length > 0) {
        trustTier = repData[0].trust_tier || "standard";
        approvalRate = repData[0].approval_rate || 0;
      }
    }

    // Build report HTML
    const summary = {
      total: submissions.length,
      approved: submissions.filter(s => s.review_status === "approved").length,
      rejected: submissions.filter(s => s.review_status === "rejected").length,
      pending: submissions.filter(s => s.review_status === "pending").length,
    };

    const reportHtml = buildWeeklyReportHtml({
      volunteerName: vol.display_name,
      weekStart: weekStart.toISOString().split("T")[0],
      weekEnd: weekEnd.toISOString().split("T")[0],
      submissions: submissions.map(s => ({
        package: s.package,
        status: s.review_status,
        severity: s.severity,
        date: s.submitted_date,
      })),
      summary,
      approvalRate,
      trustTier,
    });

    // Insert into report_queue
    const queueRes = await fetch(`${env.SUPABASE_URL}/rest/v1/report_queue`, {
      method: "POST",
      headers: {
        "apikey": env.SUPABASE_ANON_KEY,
        "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        volunteer_id: vol.volunteer_id,
        volunteer_email: vol.email,
        volunteer_name: vol.display_name,
        report_html: reportHtml,
        week_start: weekStart.toISOString().split("T")[0],
        week_end: weekEnd.toISOString().split("T")[0],
        status: "pending",
      }),
    });

    if (queueRes.ok) {
      generated.push(vol.email);
    } else {
      skipped.push(vol.email);
    }
  }

  return json({ generated: generated.length, skipped: skipped.length, details: { generated, skipped } });
}

// ── Report sending handler ──
async function handleReportSend(env: Env): Promise<Response> {
  // Step 1: Get all pending reports
  const pendingRes = await fetch(
    `${env.SUPABASE_URL}/rest/v1/report_queue?status=eq.pending&select=*`,
    {
      headers: {
        "apikey": env.SUPABASE_ANON_KEY,
        "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
      },
    }
  );

  if (!pendingRes.ok) {
    return json({ error: "Failed to fetch pending reports" }, 500);
  }

  const reports = await pendingRes.json() as Array<{
    id: string;
    volunteer_id: string;
    volunteer_email: string;
    volunteer_name: string;
    report_html: string;
    week_start: string;
    week_end: string;
  }>;

  const sent: string[] = [];
  const failed: string[] = [];

  for (const report of reports) {
    // Send email via Resend
    try {
      const emailRes = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${env.RESEND_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: "CPAC Trust DB <no-reply@thecinderproject.qd.je>",
          to: [report.volunteer_email],
          subject: "Your Weekly CPAC Trust DB Report",
          html: report.report_html,
        }),
      });

      if (emailRes.ok) {
        // Mark as sent
        await fetch(`${env.SUPABASE_URL}/rest/v1/report_queue?id=eq.${report.id}`, {
          method: "PATCH",
          headers: {
            "apikey": env.SUPABASE_ANON_KEY,
            "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ status: "sent", sent_at: new Date().toISOString() }),
        });

        // Log in email_log
        await fetch(`${env.SUPABASE_URL}/rest/v1/email_log`, {
          method: "POST",
          headers: {
            "apikey": env.SUPABASE_ANON_KEY,
            "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            recipient_id: report.volunteer_id,
            recipient_email: report.volunteer_email,
            email_type: "weekly_report",
            subject: "Your Weekly CPAC Trust DB Report",
            status: "sent",
            metadata: { week_start: report.week_start, week_end: report.week_end },
          }),
        });

        sent.push(report.volunteer_email);
      } else {
        // Mark as failed
        await fetch(`${env.SUPABASE_URL}/rest/v1/report_queue?id=eq.${report.id}`, {
          method: "PATCH",
          headers: {
            "apikey": env.SUPABASE_ANON_KEY,
            "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ status: "failed" }),
        });

        // Log failure
        await fetch(`${env.SUPABASE_URL}/rest/v1/email_log`, {
          method: "POST",
          headers: {
            "apikey": env.SUPABASE_ANON_KEY,
            "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            recipient_id: report.volunteer_id,
            recipient_email: report.volunteer_email,
            email_type: "weekly_report",
            subject: "Your Weekly CPAC Trust DB Report",
            status: "failed",
          }),
        });

        failed.push(report.volunteer_email);
      }
    } catch (e) {
      failed.push(report.volunteer_email);
    }
  }

  return json({ sent: sent.length, failed: failed.length, details: { sent, failed } });
}
