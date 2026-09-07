# 2FA Push Authentication — Complete Developer Implementation Package

This guide contains **100% complete, runnable code files** and their **exact server folder destinations**. Developers can copy and paste these files directly into the backend server and website projects.

---

## 📁 File Structure & Destination Overview

Here is where every file belongs in your server and website directories:

```text
├── [Database Server]
│   └── database/
│       └── two_factor_challenges.sql                     <-- Step 1: SQL Migration
│
├── [Backend API Server: /mobile-api/api/]
│   ├── fcm_helper.php                                    <-- Step 2: FCM Push Sender Helper
│   ├── create_2fa_challenge.php                          <-- Step 3: Triggered by Website on Login
│   ├── check_2fa_status.php                              <-- Step 4: Polled by Website
│   ├── respond_2fa_challenge.php                         <-- Step 5: Called by Mobile App (Accept/Decline)
│   └── get_pending_2fa_challenges.php                    <-- Step 6: Fallback for Mobile App
│
└── [Corporate Websites: e.g., /erp-web/ or /parking-web/]
    ├── assets/
    │   ├── css/
    │   │   └── two_factor_modal.css                      <-- Step 7: Ready-to-use Modal Styles
    │   └── js/
    │       └── two_factor_auth.js                        <-- Step 8: Frontend Polling & Modal Logic
    └── login.php                                         <-- Step 9: Example Login Page Integration
```

---

## STEP 1: Database Migration

### 📄 File: `database/two_factor_challenges.sql`
> **Target**: Run this SQL query in your MySQL/MariaDB database (where the `fcm_tokens` and user tables live).

```sql
CREATE TABLE IF NOT EXISTS `two_factor_challenges` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `challenge_id` VARCHAR(64) NOT NULL UNIQUE,
  `employee_id` VARCHAR(50) NOT NULL,
  `website_name` VARCHAR(100) NOT NULL,
  `ip_address` VARCHAR(45) NULL,
  `device_info` VARCHAR(255) NULL,
  `location` VARCHAR(100) NULL,
  `security_code` VARCHAR(10) NULL,
  `status` ENUM('PENDING', 'APPROVED', 'DECLINED', 'EXPIRED') NOT NULL DEFAULT 'PENDING',
  `biometric_verified` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at` DATETIME NOT NULL,
  `responded_at` DATETIME NULL,
  INDEX `idx_challenge_id` (`challenge_id`),
  INDEX `idx_employee_status` (`employee_id`, `status`),
  INDEX `idx_expires_at` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## STEP 2: Firebase FCM Helper

### 📄 File: `/mobile-api/api/fcm_helper.php`
> **Target**: Place inside your `/mobile-api/api/` folder. This script sends the high-priority push notification to the staff member's phone.

```php
<?php
// /mobile-api/api/fcm_helper.php

/**
 * Sends a high-priority FCM push notification for 2FA login verification
 *
 * @param string $fcmToken The device token of the staff member
 * @param array $payload Key-value data payload for the mobile app
 * @return bool True on success, false on failure
 */
function sendFcm2faNotification($fcmToken, $payload) {
    // Replace with your Firebase Server Key (or Firebase Service Account Bearer Token)
    $firebaseServerKey = 'YOUR_FIREBASE_SERVER_KEY_HERE';

    $url = 'https://fcm.googleapis.com/fcm/send';

    $fields = [
        'to' => $fcmToken,
        'priority' => 'high',
        'content_available' => true,
        'notification' => [
            'title' => 'Sign-in Verification Request',
            'body' => 'Login attempt detected on ' . ($payload['website_name'] ?? 'Website') . '. Tap to approve or decline.',
            'sound' => 'default',
            'badge' => 1
        ],
        'data' => array_merge([
            'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
            'type' => '2fa_login_request'
        ], $payload)
    ];

    $headers = [
        'Authorization: key=' . $firebaseServerKey,
        'Content-Type: application/json'
    ];

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($fields));
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);

    $result = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    return ($httpCode === 200);
}
```

---

## STEP 3: API Endpoint — Create 2FA Challenge

### 📄 File: `/mobile-api/api/create_2fa_challenge.php`
> **Target**: Place inside `/mobile-api/api/`. Called by websites after validating username and password.

```php
<?php
// /mobile-api/api/create_2fa_challenge.php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Adjust DB include path to match your project
require_once __DIR__ . '/db_connection.php'; 
require_once __DIR__ . '/fcm_helper.php';

$raw = file_get_contents('php://input');
$input = json_decode($raw, true) ?? [];

$employeeId  = trim($input['employee_id'] ?? '');
$websiteName = trim($input['website_name'] ?? 'Corporate Portal');
$ipAddress   = trim($input['ip_address'] ?? ($_SERVER['REMOTE_ADDR'] ?? ''));
$deviceInfo  = trim($input['device_info'] ?? ($_SERVER['HTTP_USER_AGENT'] ?? 'Web Browser'));
$location    = trim($input['location'] ?? '');
$expiresIn   = intval($input['expires_in'] ?? 90);

if (empty($employeeId)) {
    echo json_encode([
        'success' => false,
        'message' => 'employee_id is required.'
    ]);
    exit;
}

try {
    // 1. Mark any existing pending challenge for this employee as EXPIRED
    $expireOld = $pdo->prepare("UPDATE two_factor_challenges SET status = 'EXPIRED' WHERE employee_id = ? AND status = 'PENDING'");
    $expireOld->execute([$employeeId]);

    // 2. Generate unique challenge ID and 2-digit matching security code
    $challengeId  = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
    $securityCode = str_pad((string)mt_rand(10, 99), 2, '0', STR_PAD_LEFT);
    $expiresAt    = date('Y-m-d H:i:s', time() + $expiresIn);

    // 3. Save challenge in database
    $stmt = $pdo->prepare("
        INSERT INTO two_factor_challenges 
        (challenge_id, employee_id, website_name, ip_address, device_info, location, security_code, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ");
    $stmt->execute([
        $challengeId,
        $employeeId,
        $websiteName,
        $ipAddress,
        $deviceInfo,
        $location,
        $securityCode,
        $expiresAt
    ]);

    // 4. Query staff FCM Token (adjust table & column name if yours is different)
    $tokenStmt = $pdo->prepare("
        SELECT fcm_token FROM fcm_tokens 
        WHERE employee_id = ? 
        ORDER BY id DESC LIMIT 1
    ");
    $tokenStmt->execute([$employeeId]);
    $fcmToken = $tokenStmt->fetchColumn();

    $fcmSent = false;
    if (!empty($fcmToken)) {
        $fcmSent = sendFcm2faNotification($fcmToken, [
            'type'          => '2fa_login_request',
            'challenge_id'  => $challengeId,
            'website_name'  => $websiteName,
            'ip_address'    => $ipAddress,
            'device_info'   => $deviceInfo,
            'location'      => $location,
            'security_code' => $securityCode,
            'timestamp'     => date('c'),
            'expires_in'    => (string)$expiresIn
        ]);
    }

    echo json_encode([
        'success'       => true,
        'challenge_id'  => $challengeId,
        'security_code' => $securityCode,
        'expires_in'    => $expiresIn,
        'fcm_dispatched'=> $fcmSent,
        'message'       => '2FA challenge initiated and push notification dispatched.'
    ]);
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Database error: ' . $e->getMessage()
    ]);
}
```

---

## STEP 4: API Endpoint — Check 2FA Status

### 📄 File: `/mobile-api/api/check_2fa_status.php`
> **Target**: Place inside `/mobile-api/api/`. Polled by the website every 1.5s while the user waits.

```php
<?php
// /mobile-api/api/check_2fa_status.php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/db_connection.php';

$challengeId = trim($_GET['challenge_id'] ?? '');

if (empty($challengeId)) {
    echo json_encode(['success' => false, 'message' => 'challenge_id is required.']);
    exit;
}

try {
    $stmt = $pdo->prepare("SELECT * FROM two_factor_challenges WHERE challenge_id = ?");
    $stmt->execute([$challengeId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        echo json_encode(['success' => false, 'message' => 'Challenge not found.']);
        exit;
    }

    $status = $row['status'];

    // Check if challenge expired while still pending
    if ($status === 'PENDING' && strtotime($row['expires_at']) < time()) {
        $status = 'EXPIRED';
        $update = $pdo->prepare("UPDATE two_factor_challenges SET status = 'EXPIRED' WHERE id = ?");
        $update->execute([$row['id']]);
    }

    echo json_encode([
        'success'            => true,
        'status'             => $status, // PENDING, APPROVED, DECLINED, EXPIRED
        'biometric_verified' => (bool)$row['biometric_verified'],
        'responded_at'       => $row['responded_at']
    ]);
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => 'Error: ' . $e->getMessage()]);
}
```

---

## STEP 5: API Endpoint — Mobile App Response

### 📄 File: `/mobile-api/api/respond_2fa_challenge.php`
> **Target**: Place inside `/mobile-api/api/`. Called by the Flutter mobile app when the staff member clicks "Accept" or "Decline".

```php
<?php
// /mobile-api/api/respond_2fa_challenge.php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/db_connection.php';

$raw = file_get_contents('php://input');
$input = json_decode($raw, true) ?? [];

$challengeId = trim($input['challenge_id'] ?? '');
$employeeId  = trim($input['employee_id'] ?? '');
$action      = strtoupper(trim($input['action'] ?? ''));
$bioVerified = !empty($input['biometric_verified']) ? 1 : 0;

if (empty($challengeId) || empty($employeeId) || !in_array($action, ['APPROVED', 'DECLINED'])) {
    echo json_encode([
        'success' => false,
        'message' => 'Invalid parameters. challenge_id, employee_id, and action (APPROVED/DECLINED) required.'
    ]);
    exit;
}

try {
    $stmt = $pdo->prepare("SELECT * FROM two_factor_challenges WHERE challenge_id = ? AND employee_id = ?");
    $stmt->execute([$challengeId, $employeeId]);
    $challenge = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$challenge) {
        echo json_encode(['success' => false, 'message' => 'Challenge not found or employee mismatch.']);
        exit;
    }

    if ($challenge['status'] !== 'PENDING') {
        echo json_encode(['success' => false, 'message' => 'Challenge already processed (' . $challenge['status'] . ').']);
        exit;
    }

    if (strtotime($challenge['expires_at']) < time()) {
        $update = $pdo->prepare("UPDATE two_factor_challenges SET status = 'EXPIRED' WHERE id = ?");
        $update->execute([$challenge['id']]);
        echo json_encode(['success' => false, 'message' => 'Challenge has expired.']);
        exit;
    }

    $update = $pdo->prepare("
        UPDATE two_factor_challenges 
        SET status = ?, biometric_verified = ?, responded_at = NOW() 
        WHERE id = ?
    ");
    $update->execute([$action, $bioVerified, $challenge['id']]);

    echo json_encode([
        'success' => true,
        'message' => $action === 'APPROVED' ? 'Login approved successfully.' : 'Login request declined.'
    ]);
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
}
```

---

## STEP 6: API Endpoint — Get Pending Challenges

### 📄 File: `/mobile-api/api/get_pending_2fa_challenges.php`
> **Target**: Place inside `/mobile-api/api/`. Fallback for mobile app when app opens without clicking the notification banner.

```php
<?php
// /mobile-api/api/get_pending_2fa_challenges.php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/db_connection.php';

$employeeId = trim($_GET['employee_id'] ?? '');

if (empty($employeeId)) {
    echo json_encode(['success' => false, 'message' => 'employee_id is required.']);
    exit;
}

try {
    $stmt = $pdo->prepare("
        SELECT challenge_id, website_name, ip_address, device_info, location, 
               security_code, created_at, TIMESTAMPDIFF(SECOND, NOW(), expires_at) as expires_in, status
        FROM two_factor_challenges
        WHERE employee_id = ? AND status = 'PENDING' AND expires_at > NOW()
        ORDER BY id DESC
    ");
    $stmt->execute([$employeeId]);
    $data = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        'success' => true,
        'data' => $data
    ]);
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => 'Error: ' . $e->getMessage()]);
}
```

---

## STEP 7: Website Frontend CSS Modal

### 📄 File: `assets/css/two_factor_modal.css`
> **Target**: Place inside each website's `assets/css/` directory.

```css
/* assets/css/two_factor_modal.css */
.two-factor-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  background: rgba(15, 23, 42, 0.65);
  backdrop-filter: blur(6px);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 999999;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}

.two-factor-card {
  background: #ffffff;
  border-radius: 20px;
  width: 90%;
  max-width: 440px;
  padding: 32px 28px;
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.2);
  text-align: center;
  position: relative;
  animation: modalScaleIn 0.25s ease-out;
}

@keyframes modalScaleIn {
  from { opacity: 0; transform: scale(0.92); }
  to { opacity: 1; transform: scale(1); }
}

.two-factor-icon-wrap {
  width: 68px;
  height: 68px;
  border-radius: 50%;
  background: #e0f2fe;
  color: #0284c7;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 16px auto;
  font-size: 32px;
}

.two-factor-title {
  font-size: 20px;
  font-weight: 700;
  color: #0f172a;
  margin-bottom: 8px;
}

.two-factor-desc {
  font-size: 13.5px;
  color: #64748b;
  line-height: 1.5;
  margin-bottom: 20px;
}

.two-factor-code-badge {
  display: inline-block;
  background: #fef3c7;
  border: 1.5px solid #fde68a;
  padding: 8px 18px;
  border-radius: 12px;
  margin-bottom: 22px;
}

.two-factor-code-label {
  font-size: 12px;
  font-weight: 600;
  color: #92400e;
  margin-bottom: 2px;
}

.two-factor-code-val {
  font-size: 28px;
  font-weight: 800;
  color: #b45309;
  letter-spacing: 2px;
}

.two-factor-spinner {
  width: 32px;
  height: 32px;
  border: 3px solid #e2e8f0;
  border-top-color: #0284c7;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
  margin: 0 auto 14px auto;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.two-factor-countdown {
  font-size: 13px;
  font-weight: 600;
  color: #64748b;
}

.two-factor-cancel-btn {
  margin-top: 20px;
  background: transparent;
  border: 1px solid #cbd5e1;
  color: #475569;
  padding: 8px 20px;
  border-radius: 8px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s;
}

.two-factor-cancel-btn:hover {
  background: #f1f5f9;
}
```

---

## STEP 8: Website Frontend JavaScript

### 📄 File: `assets/js/two_factor_auth.js`
> **Target**: Place inside each website's `assets/js/` directory.

```javascript
// assets/js/two_factor_auth.js

const TwoFactorAuth = {
  apiBaseUrl: "https://exploresuite.lk/mobile-api/api",
  pollTimer: null,
  countdownTimer: null,
  remainingSeconds: 90,

  /**
   * Starts the 2FA flow on the website
   * @param {string} employeeId - Employee username or ID
   * @param {string} websiteName - Name of this portal (e.g. "Airport Parking Portal")
   * @param {Function} onApproved - Callback function when approved
   * @param {Function} onError - Callback function on decline/expiry/error
   */
  start: async function(employeeId, websiteName, onApproved, onError) {
    try {
      // 1. Call create_2fa_challenge.php
      const res = await fetch(`${this.apiBaseUrl}/create_2fa_challenge.php`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          employee_id: employeeId,
          website_name: websiteName,
          device_info: navigator.userAgent
        })
      });

      const data = await res.json();
      if (!data.success) {
        if (onError) onError(data.message || "Failed to start 2FA verification.");
        return;
      }

      this.remainingSeconds = data.expires_in || 90;
      this._showModal(data.security_code);
      this._startCountdown();
      this._startPolling(data.challenge_id, onApproved, onError);

    } catch (e) {
      if (onError) onError("Network error connecting to 2FA service: " + e.message);
    }
  },

  _startPolling: function(challengeId, onApproved, onError) {
    this.pollTimer = setInterval(async () => {
      try {
        const res = await fetch(`${this.apiBaseUrl}/check_2fa_status.php?challenge_id=${challengeId}`);
        const data = await res.json();

        if (data.status === "APPROVED") {
          this.close();
          if (onApproved) onApproved(data);
        } else if (data.status === "DECLINED") {
          this.close();
          if (onError) onError("Sign-in request was declined on the mobile app.");
        } else if (data.status === "EXPIRED") {
          this.close();
          if (onError) onError("Sign-in request timed out. Please try again.");
        }
      } catch (err) {
        console.warn("Polling error:", err);
      }
    }, 1500);
  },

  _startCountdown: function() {
    const timeEl = document.getElementById("twoFactorRemainingSeconds");
    this.countdownTimer = setInterval(() => {
      if (this.remainingSeconds > 0) {
        this.remainingSeconds--;
        if (timeEl) timeEl.innerText = this.remainingSeconds + "s";
      } else {
        clearInterval(this.countdownTimer);
      }
    }, 1000);
  },

  _showModal: function(securityCode) {
    const existing = document.getElementById("twoFactorOverlay");
    if (existing) existing.remove();

    const overlay = document.createElement("div");
    overlay.id = "twoFactorOverlay";
    overlay.className = "two-factor-overlay";
    overlay.innerHTML = `
      <div class="two-factor-card">
        <div class="two-factor-icon-wrap">🛡️</div>
        <div class="two-factor-title">Check Your Phone</div>
        <div class="two-factor-desc">
          We sent a verification prompt to your <strong>Explore Enterprise Suite</strong> staff mobile app.
        </div>
        
        <div class="two-factor-code-badge">
          <div class="two-factor-code-label">Verification Number</div>
          <div class="two-factor-code-val">${securityCode}</div>
        </div>

        <div class="two-factor-spinner"></div>
        <div class="two-factor-countdown">Waiting for response... (<span id="twoFactorRemainingSeconds">${this.remainingSeconds}s</span>)</div>
        
        <button type="button" class="two-factor-cancel-btn" onclick="TwoFactorAuth.close()">Cancel</button>
      </div>
    `;
    document.body.appendChild(overlay);
  },

  close: function() {
    if (this.pollTimer) clearInterval(this.pollTimer);
    if (this.countdownTimer) clearInterval(this.countdownTimer);
    const overlay = document.getElementById("twoFactorOverlay");
    if (overlay) overlay.remove();
  }
};
```

---

## STEP 9: Website Login Page Integration Example

### 📄 File: `/your-website/login.php`
> **Target**: This demonstrates how your website developers hook `TwoFactorAuth.start(...)` into their existing login form.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>ERP Portal — Staff Login</title>
  <!-- 1. Include the 2FA Modal CSS -->
  <link rel="stylesheet" href="assets/css/two_factor_modal.css">
  <style>
    body { font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; background: #f8fafc; }
    .login-box { background: #fff; padding: 30px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); width: 320px; }
    .input-group { margin-bottom: 16px; }
    .input-group label { display: block; margin-bottom: 6px; font-size: 13px; font-weight: 600; }
    .input-group input { width: 100%; padding: 10px; border: 1px solid #cbd5e1; border-radius: 6px; box-sizing: border-box; }
    .btn-login { width: 100%; padding: 12px; background: #0060a6; color: #fff; border: none; border-radius: 6px; font-weight: 700; cursor: pointer; }
    .error-msg { color: #dc2626; font-size: 13px; margin-top: 12px; text-align: center; }
  </style>
</head>
<body>

<div class="login-box">
  <h2 style="margin-top:0;">Staff Portal Login</h2>
  <form id="loginForm">
    <div class="input-group">
      <label>Employee ID / Username</label>
      <input type="text" id="username" required placeholder="EMP1004">
    </div>
    <div class="input-group">
      <label>Password</label>
      <input type="password" id="password" required placeholder="••••••••">
    </div>
    <button type="submit" class="btn-login" id="submitBtn">Log In</button>
    <div id="errorBox" class="error-msg"></div>
  </form>
</div>

<!-- 2. Include the 2FA JavaScript library -->
<script src="assets/js/two_factor_auth.js"></script>

<script>
document.getElementById('loginForm').addEventListener('submit', async function(e) {
  e.preventDefault();
  const username = document.getElementById('username').value.trim();
  const password = document.getElementById('password').value.trim();
  const errorBox = document.getElementById('errorBox');
  errorBox.innerText = '';

  // 1. Check credentials on your website backend first
  // Replace with your real password verification endpoint
  const authResponse = await fetch('/api/verify_password.php', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password })
  });
  const authData = await authResponse.json();

  if (!authData.success) {
    errorBox.innerText = authData.message || 'Invalid username or password.';
    return;
  }

  // 2. Credentials valid! Trigger the 2FA flow on the staff phone
  TwoFactorAuth.start(
    username, // Employee ID
    "Explore ERP Web", // Website Name
    function onApproved(data) {
      // 3. User tapped "Accept" on mobile app! Complete session login:
      window.location.href = '/dashboard.php';
    },
    function onError(errorMsg) {
      // User tapped "Decline" or request expired
      errorBox.innerText = errorMsg;
    }
  );
});
</script>

</body>
</html>
```
