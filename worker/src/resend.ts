import { Resend } from 'resend';

let resendClient: Resend | null = null;

function getClient(apiKey: string): Resend {
  if (!resendClient) {
    resendClient = new Resend(apiKey);
  }
  return resendClient;
}

// ── Automation: Create ──
export async function createAutomation(apiKey: string, config: {
  name: string;
  eventName: string;
  templateId: string;
}) {
  const resend = getClient(apiKey);
  return resend.automations.create({
    name: config.name,
    status: 'disabled',
    steps: [
      {
        key: 'start',
        type: 'trigger',
        config: { eventName: config.eventName },
      },
      {
        key: 'send_report',
        type: 'send_email',
        config: {
          template: { id: config.templateId },
        },
      },
    ],
    connections: [{ from: 'start', to: 'send_report' }],
  });
}

// ── Automation: Get ──
export async function getAutomation(apiKey: string, automationId: string) {
  const resend = getClient(apiKey);
  return resend.automations.get(automationId);
}

// ── Automation: List ──
export async function listAutomations(apiKey: string) {
  const resend = getClient(apiKey);
  return resend.automations.list();
}

// ── Automation: Stop ──
export async function stopAutomation(apiKey: string, automationId: string) {
  const resend = getClient(apiKey);
  return resend.automations.stop(automationId);
}

// ── Automation: Delete ──
export async function deleteAutomation(apiKey: string, automationId: string) {
  const resend = getClient(apiKey);
  return resend.automations.remove(automationId);
}

// ── Send email (direct, for non-automation sends) ──
export async function sendEmail(apiKey: string, params: {
  from: string;
  to: string;
  subject: string;
  html: string;
}) {
  const resend = getClient(apiKey);
  return resend.emails.send({
    from: params.from,
    to: [params.to],
    subject: params.subject,
    html: params.html,
  });
}

// ── Weekly report email template ──
export function buildWeeklyReportHtml(opts: {
  volunteerName: string;
  weekStart: string;
  weekEnd: string;
  submissions: Array<{
    package: string;
    status: string;
    severity: string;
    date: string;
  }>;
  summary: {
    total: number;
    approved: number;
    rejected: number;
    pending: number;
  };
  approvalRate: number;
  trustTier: string;
}) {
  const rows = opts.submissions.map(s => `
    <tr>
      <td style="padding:8px;border:1px solid #333;">${s.package}</td>
      <td style="padding:8px;border:1px solid #333;">${s.status}</td>
      <td style="padding:8px;border:1px solid #333;">${s.severity}</td>
      <td style="padding:8px;border:1px solid #333;">${s.date}</td>
    </tr>
  `).join('');

  return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family:sans-serif;color:#333;max-width:600px;margin:0 auto;padding:20px;">
  <p>Hi ${opts.volunteerName},</p>
  <p>Thank you for volunteering with the CPAC Trust DB this week! Your contributions help improve the security and reliability of the CPAC ecosystem for everyone.</p>
  <p>This email contains your weekly advisory report. Advisory reports summarize your activity for the current reporting period and help maintain an accurate record of your contributions.</p>
  <p>These reports are used to:</p>
  <ul>
    <li>Track submitted and reviewed advisories</li>
    <li>Record accepted and rejected submissions</li>
    <li>Help calculate contributor and maintainer trust metrics over time</li>
  </ul>
  <p>Your report for <strong>${opts.weekStart} — ${opts.weekEnd}</strong>:</p>

  <table style="width:100%;border-collapse:collapse;margin:16px 0;">
    <thead>
      <tr style="background:#1a1a1a;">
        <th style="padding:8px;border:1px solid #333;text-align:left;">Package</th>
        <th style="padding:8px;border:1px solid #333;text-align:left;">Status</th>
        <th style="padding:8px;border:1px solid #333;text-align:left;">Severity</th>
        <th style="padding:8px;border:1px solid #333;text-align:left;">Date</th>
      </tr>
    </thead>
    <tbody>
      ${rows || '<tr><td colspan="4" style="padding:8px;border:1px solid #333;text-align:center;">No submissions this week</td></tr>'}
    </tbody>
  </table>

  <p><strong>Summary:</strong> ${opts.summary.total} submitted, ${opts.summary.approved} approved, ${opts.summary.rejected} rejected, ${opts.summary.pending} pending</p>
  <p><strong>Approval rate:</strong> ${opts.approvalRate}%</p>
  <p><strong>Trust tier:</strong> ${opts.trustTier}</p>

  <p>Thank you once again for helping keep the CPAC ecosystem secure.</p>
  <p>If you believe any information in this report is incorrect, please contact a Trust DB maintainer or open an issue through the project's official channels i.e. Discord.</p>
  <p style="color:#888;font-size:12px;margin-top:24px;">The Cinder Project<br>THIS MAILBOX IS NOT MONITORED</p>
</body>
</html>`;
}
