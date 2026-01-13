#!/bin/bash
set -euxo pipefail

# --- Package manager compatibility (Amazon Linux 2 uses yum, AL2023 uses dnf) ---
if command -v yum >/dev/null 2>&1; then
  PM="yum"
else
  PM="dnf"
fi

# --- Install Nginx ---
$PM -y update
$PM -y install nginx

# --- Write the frontend files ---
WEB_ROOT="/usr/share/nginx/html"
mkdir -p "${WEB_ROOT}"

cat > "${WEB_ROOT}/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Paymentology Demo Handson</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; }
    .card { max-width: 820px; border: 1px solid #ddd; padding: 24px; border-radius: 10px; }
    h1 { margin: 0 0 8px 0; font-size: 28px; }
    p  { margin: 0 0 16px 0; color: #444; }
    .row { display: flex; gap: 12px; margin: 16px 0; }
    button {
      padding: 10px 14px;
      border: 1px solid #333;
      background: #fff;
      border-radius: 8px;
      cursor: pointer;
      font-size: 14px;
    }
    button:disabled { opacity: 0.6; cursor: not-allowed; }
    .out {
      margin-top: 18px;
      padding: 14px;
      border-radius: 8px;
      background: #f6f6f6;
      border: 1px solid #e6e6e6;
      min-height: 60px;
      white-space: pre-wrap;
    }
    .hint { font-size: 12px; color: #666; margin-top: 10px; }
    code { background: #eee; padding: 2px 6px; border-radius: 6px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Paymentology Demo Handson</h1>
    <p>Basic EC2-hosted UI with two demo endpoints (About, Tools). API Gateway can be wired later.</p>

    <div class="row">
      <button id="btnAbout">About</button>
      <button id="btnTools">Tools</button>
    </div>

    <div id="output" class="out">Click a button to load content.</div>

    <div class="hint">
      Health check: <code>/health</code>. Demo endpoints: <code>/about</code>, <code>/tools</code>.
      To point UI to API Gateway later, edit <code>config.js</code> (API_BASE_URL).
    </div>
  </div>

  <script src="/config.js"></script>
  <script src="/app.js"></script>
</body>
</html>
HTML

cat > "${WEB_ROOT}/config.js" <<'JS'
// If API_BASE_URL is "", the frontend calls the same host (EC2/Nginx).
// Later, set this to your API Gateway invoke URL, e.g.:
// "https://{restApiId}.execute-api.{region}.amazonaws.com/prod"
window.APP_CONFIG = {
  API_BASE_URL: ""
};
JS

cat > "${WEB_ROOT}/app.js" <<'JS'
(function () {
  const out = document.getElementById("output");
  const btnAbout = document.getElementById("btnAbout");
  const btnTools = document.getElementById("btnTools");

  const apiBase = (window.APP_CONFIG && typeof window.APP_CONFIG.API_BASE_URL === "string")
    ? window.APP_CONFIG.API_BASE_URL.trim().replace(/\/+$/, "")
    : "";

  function setLoading(isLoading) {
    btnAbout.disabled = isLoading;
    btnTools.disabled = isLoading;
  }

  async function callApi(path) {
    const url = `${apiBase}${path}`;
    setLoading(true);
    out.textContent = `Loading from: ${url} ...`;

    try {
      const res = await fetch(url, { method: "GET" });
      const text = await res.text();

      // Try to parse JSON; fall back to raw text
      let payload;
      try { payload = JSON.parse(text); } catch { payload = text; }

      if (!res.ok) {
        out.textContent = `Request failed (${res.status}). Response:\n\n${typeof payload === "string" ? payload : JSON.stringify(payload, null, 2)}`;
        return;
      }

      // Render based on endpoint
      if (path === "/about" && payload && payload.message) {
        out.textContent = payload.message;
        return;
      }

      if (path === "/tools" && payload && Array.isArray(payload.tools)) {
        out.textContent = payload.tools.join("\n");
        return;
      }

      // Default render
      out.textContent = (typeof payload === "string") ? payload : JSON.stringify(payload, null, 2);
    } catch (err) {
      out.textContent = `Error calling ${url}\n\n${err}`;
    } finally {
      setLoading(false);
    }
  }

  btnAbout.addEventListener("click", () => callApi("/about"));
  btnTools.addEventListener("click", () => callApi("/tools"));
})();
JS

# --- Configure Nginx to listen on 8080 and serve the endpoints ---
rm -f /etc/nginx/conf.d/default.conf || true

cat > /etc/nginx/conf.d/paymentology-demo.conf <<'NGINX'
server {
    listen 8080 default_server;
    listen [::]:8080 default_server;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    # Health check for ASG / Target Groups
    location = /health {
        default_type text/plain;
        return 200 'ok';
    }

    # Demo "API" endpoints (placeholder until API Gateway is added)
    location = /about {
        default_type application/json;
        return 200 '{"message":"Project Assesment as Job Interview Process For Paymentology"}';
    }

    location = /tools {
        default_type application/json;
        return 200 '{"tools":["Terraform","AWS","GitHub","GitHub Actions"]}';
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

# --- Enable and start Nginx ---
systemctl enable nginx
systemctl restart nginx

# --- Install and Configure CloudWatch Agent ---
echo "Installing CloudWatch Agent..."
$PM -y install amazon-cloudwatch-agent

# Fetch configuration from SSM Parameter Store
echo "Configuring CloudWatch Agent from SSM..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c ssm:/pay-app/cw-agent-config

# Enable and start CloudWatch Agent
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

echo "CloudWatch Agent installed and started"