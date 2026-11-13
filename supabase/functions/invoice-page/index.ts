// GET /invoice-page/<token>[?paid=1]   — the public "view & pay" page (Daylit style).
// Logs a "viewed" read receipt and lets the client pay via Stripe Checkout or Razorpay Checkout.
import { adminClient, env, html } from "../_shared/env.ts";

const esc = (s: unknown) => String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const money = (v: number, cur: string) => new Intl.NumberFormat("en", { style: "currency", currency: cur }).format(v);

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const token = url.pathname.split("/").filter(Boolean).pop() ?? "";
  const admin = adminClient();
  const { data: inv } = await admin.rpc("public_invoice", { p_token: token });
  if (!inv) return html(page("Invoice not found", `<p class="muted">This link is not valid. Ask the sender for a new one.</p>`), 404);

  await admin.rpc("mark_invoice_viewed", { p_token: token });

  const cur = String(inv.currency).toUpperCase();
  const paidNow = url.searchParams.get("paid") === "1";
  const balance = Number(inv.balance);
  const isPaid = inv.status === "paid" || balance <= 0;
  const canPay = inv.business.payments_enabled && !isPaid;
  const fnBase = `${env("SUPABASE_URL")}/functions/v1`;

  const rows = (inv.items as { name: string; qty: number; rate: number }[])
    .map((it) => `<tr><td>${esc(it.name)}</td><td class="num">${Number(it.qty)}</td><td class="num">${money(Number(it.rate), cur)}</td><td class="num">${money(Number(it.qty) * Number(it.rate), cur)}</td></tr>`)
    .join("");

  const body = `
<div class="card">
  <div class="head">
    <div><div class="eyebrow">From</div><h2>${esc(inv.business.name)}</h2><p class="muted">${esc(inv.business.email)}</p></div>
    <div class="right"><div class="kind">INVOICE</div><span class="pill ${isPaid ? "paid" : "unpaid"}">${isPaid ? "Paid" : esc(inv.status)}</span></div>
  </div>
  <div class="meta">
    <div><div class="eyebrow">Billed to</div><strong>${esc(inv.client.name)}</strong></div>
    <div class="right"><div class="eyebrow">Invoice no.</div><code>${esc(inv.number)}</code><div class="eyebrow top">Issued · Due</div><code>${esc(inv.issued_on)} · ${esc(inv.due_on)}</code></div>
  </div>
  <table><thead><tr><th>Description</th><th class="num">Qty</th><th class="num">Rate</th><th class="num">Amount</th></tr></thead><tbody>${rows}</tbody></table>
  <div class="totals">
    <div><span>Subtotal</span><span>${money(Number(inv.subtotal), cur)}</span></div>
    ${Number(inv.discount) > 0 ? `<div><span>Discount</span><span>−${money(Number(inv.discount), cur)}</span></div>` : ""}
    ${Number(inv.tax) > 0 ? `<div><span>Tax</span><span>${money(Number(inv.tax), cur)}</span></div>` : ""}
    ${Number(inv.paid) > 0 ? `<div><span>Paid</span><span>−${money(Number(inv.paid), cur)}</span></div>` : ""}
    <div class="due"><span>${isPaid ? "Total paid" : "Balance due"}</span><span>${money(isPaid ? Number(inv.total) : balance, cur)}</span></div>
  </div>
  ${paidNow ? `<div class="banner ok">✓ Payment received — thank you! A receipt is on its way.</div>` : ""}
  ${canPay ? `<button id="pay" class="btn">Pay ${money(balance, cur)}</button><p class="muted small">Secure payment via ${inv.business.provider === "razorpay" ? "Razorpay (UPI, cards, netbanking)" : "Stripe (cards, wallets)"}.</p>` : ""}
  ${!inv.business.payments_enabled && !isPaid ? `<p class="muted small">Online payment isn't available for this invoice. Please pay by the method noted on the invoice and contact ${esc(inv.business.email)} with any questions.</p>` : ""}
</div>
<script src="https://checkout.razorpay.com/v1/checkout.js"></script>
<script>
const btn = document.getElementById('pay');
if (btn) btn.onclick = async () => {
  btn.disabled = true; btn.textContent = 'Opening secure checkout…';
  try {
    const r = await fetch('${fnBase}/create-checkout', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ token: '${esc(token)}' }) });
    const d = await r.json();
    if (!r.ok) throw new Error(d.error || 'Could not start checkout');
    if (d.provider === 'stripe') { location.href = d.url; return; }
    const rzp = new Razorpay({ key: d.keyId, amount: d.amount, currency: d.currency, name: d.name, description: d.description, order_id: d.orderId,
      theme: { color: '#4d1520' }, handler: () => { location.href = location.pathname + '?paid=1'; } });
    rzp.open(); btn.disabled = false; btn.textContent = 'Pay ${money(balance, cur)}';
  } catch (e) { alert(e.message); btn.disabled = false; btn.textContent = 'Pay ${money(balance, cur)}'; }
};
</script>`;
  return html(page(`${inv.number} · ${inv.business.name}`, body));
});

const page = (title: string, body: string) => `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Hanken+Grotesk:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;600&display=swap">
<style>
:root{--wine:#4d1520;--parchment:#fbf9f6;--mauve:#825b63;--linen:#f2eee7;--lemon:#faffa7;--paidbg:#dcebdc;--paid:#2f5d34}
*{box-sizing:border-box}body{margin:0;background:var(--parchment);color:var(--wine);font-family:'Hanken Grotesk',system-ui,sans-serif}
main{max-width:640px;margin:0 auto;padding:28px 16px 60px}.card{background:#fff;border:1px solid var(--linen);border-radius:20px;padding:26px;box-shadow:0 18px 40px rgba(77,21,32,.10)}
.head,.meta{display:flex;justify-content:space-between;gap:16px;align-items:flex-start}.meta{margin-top:20px}.right{text-align:right}
h2{margin:2px 0;font-size:20px;letter-spacing:-.02em}.kind{font-family:'JetBrains Mono',monospace;font-size:20px;letter-spacing:.04em}
.eyebrow{font-family:'JetBrains Mono',monospace;font-size:10px;letter-spacing:.08em;text-transform:uppercase;color:var(--mauve)}.eyebrow.top{margin-top:8px}
code{font-family:'JetBrains Mono',monospace;font-size:13px}.muted{color:var(--mauve);margin:4px 0 0}.small{font-size:12.5px;text-align:center;margin-top:10px}
.pill{display:inline-block;margin-top:6px;padding:4px 10px;border-radius:999px;font-family:'JetBrains Mono',monospace;font-size:10px;font-weight:600;text-transform:uppercase}
.pill.unpaid{background:var(--lemon)}.pill.paid{background:var(--paidbg);color:var(--paid)}
table{width:100%;border-collapse:collapse;margin-top:22px;font-size:14px}th{font-family:'JetBrains Mono',monospace;font-size:9px;letter-spacing:.07em;text-transform:uppercase;color:var(--mauve);text-align:left;padding:8px 0;border-bottom:1px solid var(--linen)}
td{padding:10px 0;border-bottom:1px solid var(--linen)}.num{text-align:right;font-family:'JetBrains Mono',monospace;font-size:13px}
.totals{margin-left:auto;width:min(100%,260px);margin-top:14px;font-size:14px}.totals>div{display:flex;justify-content:space-between;padding:4px 0;color:var(--mauve)}.totals>div span:last-child{font-family:'JetBrains Mono',monospace;color:var(--wine)}
.totals .due{background:var(--lemon);border-radius:10px;padding:10px 12px;margin-top:8px;color:var(--wine);font-weight:700}.totals .due span:last-child{font-weight:800;font-size:16px}
.btn{display:block;width:100%;margin-top:22px;height:54px;border:0;border-radius:999px;background:var(--wine);color:#fff;font:700 16px 'Hanken Grotesk',sans-serif;cursor:pointer}.btn:disabled{opacity:.6}
.banner{margin-top:18px;padding:12px 14px;border-radius:12px;font-weight:600}.banner.ok{background:var(--paidbg);color:var(--paid)}
footer{text-align:center;margin-top:18px;font-family:'JetBrains Mono',monospace;font-size:10px;letter-spacing:.06em;color:var(--mauve)}
</style></head><body><main>${body}<footer>MADE WITH INVONCE</footer></main></body></html>`;
