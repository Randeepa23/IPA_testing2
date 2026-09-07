// assets/js/two_factor_auth.js

const TwoFactorAuth = {
  // Points to your live API server
  apiBaseUrl: "https://exploresuite.lk/mobile-api/api",
  pollTimer: null,
  countdownTimer: null,
  remainingSeconds: 90,

  /**
   * Starts the 2FA approval flow
   * @param {string|number} employeeId - The employee ID (e.g. 19 or EMP1004)
   * @param {string} websiteName - Name of the portal (e.g. "Terminal Prime")
   * @param {Function} onApproved - Callback executed when user taps Accept on mobile
   * @param {Function} onError - Callback executed on decline, timeout, or network error
   */
  start: async function(employeeId, websiteName, onApproved, onError) {
    try {
      // 1. Request 2FA challenge and push notification from backend
      const res = await fetch(`${this.apiBaseUrl}/create_2fa_challenge.php`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          employee_id: String(employeeId),
          website_name: websiteName || "Corporate Portal",
          device_info: navigator.userAgent
        })
      });

      const data = await res.json();
      if (!data.success) {
        if (onError) onError(data.message || "Failed to initiate 2FA login verification.");
        return;
      }

      this.remainingSeconds = data.expires_in || 90;
      
      // 2. Show the waiting popup with the matching code
      this._showModal(data.security_code);
      this._startCountdown();
      
      // 3. Start polling the live status endpoint
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
          if (onError) onError("Login request was DECLINED on your phone.");
        } else if (data.status === "EXPIRED") {
          this.close();
          if (onError) onError("Sign-in request TIMED OUT. Please try again.");
        }
      } catch (err) {
        console.warn("2FA Polling warning:", err);
      }
    }, 1500); // Checks every 1.5 seconds
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
          An approval request was sent to your <strong>Explore Enterprise Suite</strong> mobile app.
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
