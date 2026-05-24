const express = require("express");
const crypto = require("crypto");
const router = express.Router();

const WHATSAPP_BOT_URL = process.env.WHATSAPP_BOT_URL;
const SESSION_SECRET = process.env.SESSION_SECRET;

// ── In-memory OTP store ────────────────────────────────────────────────
// key: phone string, value: { otp, expiresAt }
const otpStore = new Map();

/**
 * Generate a random 6-digit OTP.
 */
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Generate a session ID using the phone number as the secret seed.
 */
function generateSessionId(phone) {
  return crypto
    .createHmac("sha256", SESSION_SECRET)
    .update(phone + Date.now().toString())
    .digest("hex");
}

/**
 * Clean up expired OTPs periodically.
 */
setInterval(() => {
  const now = Date.now();
  for (const [phone, data] of otpStore) {
    if (now > data.expiresAt) {
      otpStore.delete(phone);
    }
  }
}, 60 * 1000); // every minute

// ── POST /auth/reqOTP ──────────────────────────────────────────────────
router.post("/reqOTP", async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      return res
        .status(400)
        .json({ success: false, message: "phone is required" });
    }

    const otp = generateOTP();

    // Store OTP with 5-minute expiry
    otpStore.set(String(phone), {
      otp,
      expiresAt: Date.now() + 5 * 60 * 1000,
    });

    // Send OTP via WhatsApp bot microservice
    const response = await fetch(`${WHATSAPP_BOT_URL}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        phone: String(phone),
        message: `🔐 Your Muhafiz verification code is: *${otp}*\n\nThis code expires in 5 minutes. Do not share it with anyone.`,
      }),
    });

    const result = await response.json();

    if (!result.success) {
      return res
        .status(502)
        .json({ success: false, message: "Failed to send OTP via WhatsApp" });
    }

    console.log(`📨 OTP requested for ${phone}`);

    return res.status(200).json({
      success: true,
      message: "OTP sent successfully",
    });
  } catch (err) {
    console.error("Error in /reqOTP:", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ── POST /auth/verifyOTP ───────────────────────────────────────────────
router.post("/verifyOTP", async (req, res) => {
  try {
    const { phone, otp } = req.body;

    if (!phone || !otp) {
      return res
        .status(400)
        .json({ success: false, message: "phone and otp are required" });
    }

    const phoneKey = String(phone);
    const stored = otpStore.get(phoneKey);

    if (!stored) {
      return res
        .status(400)
        .json({ success: false, message: "No OTP requested for this number" });
    }

    // Check expiry
    if (Date.now() > stored.expiresAt) {
      otpStore.delete(phoneKey);
      return res
        .status(400)
        .json({ success: false, message: "OTP has expired" });
    }

    // Check OTP match
    if (stored.otp !== String(otp)) {
      return res
        .status(400)
        .json({ success: false, message: "Invalid OTP" });
    }

    // OTP is valid — remove it so it can't be reused
    otpStore.delete(phoneKey);

    // Generate session ID using phone as seed
    const sessionId = generateSessionId(phoneKey);

    console.log(`✅ OTP verified for ${phone}`);

    return res.status(200).json({
      success: true,
      message: "OTP verified successfully",
      sessionId,
    });
  } catch (err) {
    console.error("Error in /verifyOTP:", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
