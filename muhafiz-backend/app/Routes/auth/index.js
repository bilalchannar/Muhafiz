const express = require("express");
const crypto = require("crypto");
const router = express.Router();

const { getDB } = require("../../db");
const { validatePhone, validateOtp } = require("../../utils/validation");

const WHATSAPP_BOT_URL = process.env.WHATSAPP_BOT_URL || "http://localhost:3000";
const BOT_API_KEY = process.env.BOT_API_KEY || "muhafiz-bot-secret-key";

/**
 * Generate a random 6-digit OTP.
 */
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// ── POST /auth/reqOTP ──────────────────────────────────────────────────
router.post("/reqOTP", async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      return res
        .status(400)
        .json({ success: false, message: "phone is required" });
    }

    if (!validatePhone(phone)) {
      return res
        .status(400)
        .json({ success: false, message: "Invalid phone number format. Use international format (e.g. 923001234567)" });
    }

    const phoneStr = String(phone).trim();
    const db = getDB();
    if (!db) {
      return res.status(503).json({ success: false, message: "Database not available" });
    }

    // Rate Limiting Check: Check if an OTP was requested for this phone in the last 60 seconds
    const existing = await db.collection("otps").findOne({ phone: phoneStr });
    if (existing) {
      const diffMs = Date.now() - new Date(existing.createdAt).getTime();
      if (diffMs < 60 * 1000) {
        const waitSec = Math.ceil((60 * 1000 - diffMs) / 1000);
        return res.status(429).json({
          success: false,
          message: `Please wait ${waitSec} seconds before requesting another OTP.`
        });
      }
    }

    const otp = generateOTP();

    // Store OTP in MongoDB with 5-minute expiry
    await db.collection("otps").updateOne(
      { phone: phoneStr },
      {
        $set: {
          otp,
          createdAt: new Date(),
          expiresAt: new Date(Date.now() + 5 * 60 * 1000),
          attempts: 0,
        }
      },
      { upsert: true }
    );

    // Send OTP via WhatsApp bot microservice
    const response = await fetch(`${WHATSAPP_BOT_URL}/sendMessage`, {
      method: "POST",
      headers: { 
        "Content-Type": "application/json",
        "x-api-key": BOT_API_KEY
      },
      body: JSON.stringify({
        phone: phoneStr,
        message: `🔐 Your Muhafiz verification code is: *${otp}*\n\nThis code expires in 5 minutes. Do not share it with anyone.`,
      }),
    });

    const result = await response.json();

    if (!result.success) {
      return res
        .status(502)
        .json({ success: false, message: result.message || "Failed to send OTP via WhatsApp" });
    }

    console.log(`📨 OTP requested and sent via WhatsApp bot to ${phoneStr}`);

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

    if (!validatePhone(phone) || !validateOtp(otp)) {
      return res
        .status(400)
        .json({ success: false, message: "Invalid phone number or OTP format" });
    }

    const phoneStr = String(phone).trim();
    const otpStr = String(otp).trim();
    const db = getDB();
    if (!db) {
      return res.status(503).json({ success: false, message: "Database not available" });
    }

    // Find the OTP document in MongoDB
    const stored = await db.collection("otps").findOne({ phone: phoneStr });

    if (!stored) {
      return res
        .status(400)
        .json({ success: false, message: "No OTP requested for this number" });
    }

    // Check expiry in case TTL index hasn't run yet
    if (new Date() > new Date(stored.expiresAt)) {
      await db.collection("otps").deleteOne({ phone: phoneStr });
      return res
        .status(400)
        .json({ success: false, message: "OTP has expired" });
    }

    // Check OTP Match
    if (stored.otp !== otpStr) {
      const nextAttempts = (stored.attempts || 0) + 1;
      const maxAttempts = 3;

      if (nextAttempts >= maxAttempts) {
        // Block and lock out by deleting OTP document
        await db.collection("otps").deleteOne({ phone: phoneStr });
        return res.status(400).json({
          success: false,
          message: "Too many incorrect attempts. This OTP has been cancelled. Please request a new one."
        });
      } else {
        // Increment attempts count
        await db.collection("otps").updateOne(
          { phone: phoneStr },
          { $set: { attempts: nextAttempts } }
        );
        return res.status(400).json({
          success: false,
          message: `Invalid OTP. You have ${maxAttempts - nextAttempts} attempts remaining.`
        });
      }
    }

    // OTP is valid — remove it so it cannot be reused
    await db.collection("otps").deleteOne({ phone: phoneStr });

    // Generate secure random session ID (32 bytes = 64 characters hex)
    const sessionId = crypto.randomBytes(32).toString("hex");

    // Save session token in MongoDB sessions collection
    await db.collection("sessions").insertOne({
      sessionId,
      phone: phoneStr,
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // Valid for 30 days
    });

    console.log(`✅ OTP verified successfully for ${phoneStr}`);

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
