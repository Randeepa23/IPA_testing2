<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . "/../assets/includes/db_connect.php";
require_once __DIR__ . "/../notifications/fcm_helper.php";

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
$conn->query("SET time_zone = '+05:30'");

function respond($ok, $msg, $extra = []) {
    echo json_encode(array_merge(["success" => $ok, "message" => $msg], $extra));
    exit;
}

try {
    if (($_SERVER["REQUEST_METHOD"] ?? "") !== "POST") {
        http_response_code(405);
        respond(false, "Method not allowed");
    }

    $raw = file_get_contents("php://input");
    $data = json_decode($raw, true);

    if (!is_array($data)) {
        http_response_code(400);
        respond(false, "Invalid JSON");
    }

    $employeeId  = trim((string)($data["employee_id"] ?? $data["employeeId"] ?? ""));
    $email       = trim((string)($data["email"] ?? ""));
    $websiteName = trim((string)($data["website_name"] ?? "Corporate Portal"));
    $ipAddress   = trim((string)($data["ip_address"] ?? $_SERVER["REMOTE_ADDR"] ?? ""));
    $deviceInfo  = trim((string)($data["device_info"] ?? $_SERVER["HTTP_USER_AGENT"] ?? "Web Browser"));
    $location    = trim((string)($data["location"] ?? ""));
    $expiresIn   = (int)($data["expires_in"] ?? 90);
    if ($expiresIn <= 0) $expiresIn = 90;

    if ($employeeId === "" && $email === "") {
        http_response_code(400);
        respond(false, "employee_id or email is required");
    }

    // 1. Resolve employee_id and fcm_token from central database
    $fcmToken = "";

    // Primary: Look up by user corporate email (works universally for any staff member on any site)
    if ($email !== "") {
        $emailStmt = $conn->prepare("
            SELECT e.employee_id, e.fcm_token 
            FROM users u 
            JOIN employees e ON e.employee_id = u.employee_id 
            WHERE u.email = ? 
            LIMIT 1
        ");
        $emailStmt->bind_param("s", $email);
        $emailStmt->execute();
        $emailRes = $emailStmt->get_result();
        if ($emailRow = $emailRes->fetch_assoc()) {
            $employeeId = (string)$emailRow["employee_id"];
            $fcmToken   = trim((string)($emailRow["fcm_token"] ?? ""));
        }
        $emailStmt->close();
    }

    // Fallback: If no match by email or email was empty, check employees table directly
    if ($fcmToken === "" && $employeeId !== "") {
        $tokenStmt = $conn->prepare("SELECT employee_id, fcm_token FROM employees WHERE employee_id = ? LIMIT 1");
        $tokenStmt->bind_param("s", $employeeId);
        $tokenStmt->execute();
        $tokenRes = $tokenStmt->get_result();
        if ($row = $tokenRes->fetch_assoc()) {
            $fcmToken = trim((string)($row["fcm_token"] ?? ""));
        }
        $tokenStmt->close();
    }

    if ($employeeId === "") {
        http_response_code(404);
        respond(false, "Employee not found for the given credentials");
    }

    // 2. Check if an active PENDING challenge already exists for this employee (within valid time)
    // This prevents generating two different security numbers between web and mobile!
    $checkStmt = $conn->prepare("
        SELECT challenge_id, security_code, expires_at,
               TIMESTAMPDIFF(SECOND, NOW(), expires_at) AS remaining_seconds
        FROM two_factor_challenges 
        WHERE employee_id = ? AND status = 'PENDING' AND expires_at > NOW()
        ORDER BY created_at DESC 
        LIMIT 1
    ");
    $checkStmt->bind_param("s", $employeeId);
    $checkStmt->execute();
    $existingRes = $checkStmt->get_result();

    if ($existingRow = $existingRes->fetch_assoc()) {
        $remaining = (int)$existingRow["remaining_seconds"];
        if ($remaining > 20) {
            $checkStmt->close();
            respond(true, "Active 2FA challenge in progress", [
                "challenge_id"   => $existingRow["challenge_id"],
                "employee_id"    => $employeeId,
                "security_code"  => $existingRow["security_code"],
                "expires_in"     => $remaining,
                "fcm_dispatched" => true,
            ]);
        }
    }
    $checkStmt->close();

    // 3. Mark any older PENDING challenges for this employee as EXPIRED
    $expStmt = $conn->prepare("UPDATE two_factor_challenges SET status = 'EXPIRED' WHERE employee_id = ? AND status = 'PENDING'");
    $expStmt->bind_param("s", $employeeId);
    $expStmt->execute();
    $expStmt->close();

    // 3. Generate UUID v4 challenge ID and 2-digit matching security code
    $challengeId = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
    $securityCode = str_pad((string)mt_rand(10, 99), 2, '0', STR_PAD_LEFT);
    $expiresAt    = date('Y-m-d H:i:s', time() + $expiresIn);

    // 4. Insert challenge record with the verified employee_id
    $insStmt = $conn->prepare("
        INSERT INTO two_factor_challenges 
        (challenge_id, employee_id, website_name, ip_address, device_info, location, security_code, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ");
    $insStmt->bind_param("ssssssss", $challengeId, $employeeId, $websiteName, $ipAddress, $deviceInfo, $location, $securityCode, $expiresAt);
    $insStmt->execute();
    $insStmt->close();

    // 5. Send High-Priority FCM Push Notification to employee phone
    $fcmDispatched = false;
    $fcmResponse = null;
    if ($fcmToken !== "") {
        $fcmResult = FcmHelper::send(
            $fcmToken,
            "Verification Code: {$securityCode}",
            "Login request for {$websiteName} (Code: {$securityCode}). Tap to approve or decline.",
            [
                "type"          => "2fa_login_request",
                "challenge_id"  => $challengeId,
                "employee_id"   => (string)$employeeId,
                "website_name"  => $websiteName,
                "ip_address"    => $ipAddress,
                "device_info"   => $deviceInfo,
                "location"      => $location,
                "security_code" => $securityCode,
                "priority"      => "high",
                "high_priority" => "1",
                "click_action"  => "FLUTTER_NOTIFICATION_CLICK",
                "timestamp"     => date('c'),
                "expires_in"    => (string)$expiresIn,
            ]
        );
        $fcmDispatched = ($fcmResult["success"] ?? false) === true;
        $fcmResponse = $fcmResult["response"] ?? null;
    }

    respond(true, "2FA challenge initiated successfully", [
        "challenge_id"   => $challengeId,
        "employee_id"    => $employeeId,
        "security_code"  => $securityCode,
        "expires_in"     => $expiresIn,
        "fcm_dispatched" => $fcmDispatched,
        "fcm_response"   => $fcmResponse,
    ]);

} catch (Throwable $e) {
    http_response_code(500);
    respond(false, "EXCEPTION: " . $e->getMessage());
}
