"use strict";
const {
  default: makeWASocket,
  useMultiFileAuthState,
  DisconnectReason,
  fetchLatestBaileysVersion,
  isJidUser,
} = require("@whiskeysockets/baileys");
const pino = require("pino");
const path = require("path");
const fs = require("fs");
const qrcode = require("qrcode");
const qrcodeTerminal = require("qrcode-terminal");
const express = require("express");
require("dotenv").config();

// ── Constants ──────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3001;
const BOT_API_KEY = process.env.BOT_API_KEY || "muhafiz-bot-secret-key";
const FIREBASE_DB_URL =
  process.env.FIREBASE_DB_URL ||
  "https://start-of-firebase-default-rtdb.firebaseio.com";

// Local session dir — Baileys writes creds + keys here.
// On Render this is ephemeral, but we back up to Firebase on every save.
const SESSION_PATH = path.resolve(
  process.env.SESSION_PATH || path.join(__dirname, "auth_session")
);
fs.mkdirSync(SESSION_PATH, { recursive: true });

console.log(`🗂️  Session path : ${SESSION_PATH}`);
console.log(`🔥 Firebase URL : ${FIREBASE_DB_URL}`);

// ── Express Setup ──────────────────────────────────────────────────────
const app = express();
app.use(express.json());

// API Key middleware (skip health + QR pages)
app.use((req, res, next) => {
  if (["/health", "/qr", "/qr-code"].includes(req.path)) return next();
  const key = req.headers["x-api-key"];
  if (!key || key !== BOT_API_KEY)
    return res.status(401).json({ success: false, message: "Unauthorized: Invalid API Key" });
  next();
});

// ── State ──────────────────────────────────────────────────────────────
let sock = null;
let isReady = false;
let latestQr = null;      // raw QR string
let latestQrDataUrl = null; // base-64 PNG for the /qr page
let reconnectTimer = null;
const messageHistory = {};  // In-memory cache mapping JID -> array of messages

// ── Firebase Session Helpers ───────────────────────────────────────────
// We store each auth file as a base-64 string under /whatsapp-session/<filename>
// in Firebase Realtime DB. This lets Baileys restore the session after a
// Render redeploy without needing a new QR scan.

const FB_SESSION_BASE = `${FIREBASE_DB_URL}/whatsapp-session`;

async function fbGet(filename) {
  try {
    const res = await fetch(
      `${FB_SESSION_BASE}/${encodeURIComponent(filename)}.json`
    );
    const data = await res.json();
    return data; // null if not found
  } catch (_) {
    return null;
  }
}

async function fbSet(filename, content) {
  try {
    await fetch(`${FB_SESSION_BASE}/${encodeURIComponent(filename)}.json`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(content),
    });
  } catch (err) {
    console.error(`⚠️  Firebase write failed for ${filename}:`, err.message);
  }
}

async function fbDelete(filename) {
  try {
    await fetch(`${FB_SESSION_BASE}/${encodeURIComponent(filename)}.json`, {
      method: "DELETE",
    });
  } catch (_) {}
}

async function fbDeleteAll() {
  try {
    await fetch(`${FB_SESSION_BASE}.json`, { method: "DELETE" });
    console.log("🗑️  Firebase session cleared.");
  } catch (_) {}
}

// ── Firebase-backed Auth State ─────────────────────────────────────────
// Mirrors the Baileys `useMultiFileAuthState` API but reads/writes Firebase
// instead of (only) the local filesystem.

async function useFirebaseAuthState() {
  // 1. Pull every saved file from Firebase → write to local disk so Baileys
  //    can start from a persisted session without a new QR scan.
  console.log("📥 Restoring session from Firebase...");
  let restored = 0;
  try {
    const res = await fetch(`${FB_SESSION_BASE}.json`);
    const allFiles = await res.json();
    if (allFiles && typeof allFiles === "object") {
      for (const [filename, content] of Object.entries(allFiles)) {
        if (content) {
          const localPath = path.join(SESSION_PATH, filename);
          fs.mkdirSync(path.dirname(localPath), { recursive: true });
          fs.writeFileSync(localPath, JSON.stringify(content), "utf8");
          restored++;
        }
      }
    }
  } catch (_) {}
  console.log(
    restored > 0
      ? `✅ Restored ${restored} session file(s) from Firebase.`
      : "ℹ️  No existing Firebase session found — fresh start."
  );

  // 2. Now use the standard multi-file auth with the local path.
  const { state, saveCreds } = await useMultiFileAuthState(SESSION_PATH);

  // 3. Wrap saveCreds to also push updates to Firebase.
  const saveCredsAndSync = async () => {
    await saveCreds(); // write to local disk first
    // Then mirror every file in SESSION_PATH to Firebase
    try {
      const files = fs.readdirSync(SESSION_PATH);
      for (const file of files) {
        const filePath = path.join(SESSION_PATH, file);
        if (fs.statSync(filePath).isFile()) {
          const raw = fs.readFileSync(filePath, "utf8");
          try {
            await fbSet(file, JSON.parse(raw));
          } catch (_) {
            await fbSet(file, raw); // store as plain string if not JSON
          }
        }
      }
    } catch (err) {
      console.error("⚠️  Session sync to Firebase failed:", err.message);
    }
  };

  return { state, saveCreds: saveCredsAndSync };
}

// ── WhatsApp Connection ────────────────────────────────────────────────

async function connect() {
  // Clear any pending reconnect timer
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }

  const { state, saveCreds } = await useFirebaseAuthState();
  const { version } = await fetchLatestBaileysVersion();
  console.log(`📦 Using Baileys WA version: ${version.join(".")}`);

  sock = makeWASocket({
    version,
    auth: state,
    // Suppress verbose Baileys logs in production
    logger: pino({ level: process.env.LOG_LEVEL || "silent" }),
    // Keep alive so Render doesn't drop the WebSocket
    keepAliveIntervalMs: 30_000,
    // Retry sending on failure
    retryRequestDelayMs: 250,
    // Don't download media messages (saves memory)
    downloadHistory: false,
    syncFullHistory: false,
    markOnlineOnConnect: false,
    generateHighQualityLinkPreview: false,
  });

  // ── Events ──

  sock.ev.on("creds.update", saveCreds);

  // Listen for message upserts to populate the local messageHistory cache
  sock.ev.on("messages.upsert", (m) => {
    if (m.type === "notify" || m.type === "append") {
      for (const msg of m.messages) {
        const jid = msg.key.remoteJid;
        if (!jid) continue;
        if (!messageHistory[jid]) {
          messageHistory[jid] = [];
        }
        messageHistory[jid].push(msg);
        if (messageHistory[jid].length > 20) {
          messageHistory[jid].shift();
        }
      }
    }
  });

  sock.ev.on("connection.update", async (update) => {
    const { connection, lastDisconnect, qr } = update;

    if (qr) {
      latestQr = qr;
      qrcodeTerminal.generate(qr, { small: true });
      console.log("📲 QR code generated — scan with WhatsApp.");
      try {
        latestQrDataUrl = await qrcode.toDataURL(qr);
      } catch (_) {}
    }

    if (connection === "open") {
      isReady = true;
      latestQr = null;
      latestQrDataUrl = null;
      console.log("✅ WhatsApp connected and ready!");
    }

    if (connection === "close") {
      isReady = false;
      const statusCode = lastDisconnect?.error?.output?.statusCode;
      const reason = DisconnectReason[statusCode] || statusCode;
      console.log(`❌ WhatsApp disconnected. Reason: ${reason}`);

      const shouldLogOut =
        statusCode === DisconnectReason.loggedOut ||
        statusCode === DisconnectReason.forbidden;

      if (shouldLogOut) {
        console.log("🗑️  Clearing session (logged out / forbidden)...");
        // Delete local session
        try { fs.rmSync(SESSION_PATH, { recursive: true, force: true }); } catch (_) {}
        fs.mkdirSync(SESSION_PATH, { recursive: true });
        // Delete Firebase session
        await fbDeleteAll();
        console.log("🔄 Reconnecting for fresh QR...");
        reconnectTimer = setTimeout(connect, 3000);
      } else {
        // Temporary disconnect (network blip, server restart) — just reconnect
        console.log("🔄 Reconnecting in 8s...");
        reconnectTimer = setTimeout(connect, 8000);
      }
    }
  });
}

// ── Phone Number Helpers ───────────────────────────────────────────────

/**
 * Normalise a phone number to the Baileys JID format.
 * Strips leading "+", "00", spaces, dashes, etc.
 * Result: "<countryCode><number>@s.whatsapp.net"
 */
function formatJid(phone) {
  let cleaned = String(phone).replace(/[\s\-\(\)]/g, "");
  if (cleaned.startsWith("+")) cleaned = cleaned.slice(1);
  if (cleaned.startsWith("00")) cleaned = cleaned.slice(2);
  return `${cleaned}@s.whatsapp.net`;
}

/** Returns true if the number is registered on WhatsApp */
async function checkNumberOnWhatsApp(phone) {
  const jid = formatJid(phone);
  const [result] = await sock.onWhatsApp(jid);
  return !!(result && result.exists);
}

// ── Routes ────────────────────────────────────────────────────────────

// GET /health
app.get("/health", (_req, res) => {
  const mem = process.memoryUsage();
  res.json({
    status: "ok",
    whatsappReady: isReady,
    memoryMB: {
      rss: (mem.rss / 1024 / 1024).toFixed(1),
      heapUsed: (mem.heapUsed / 1024 / 1024).toFixed(1),
    },
  });
});

// GET /qr-code — JSON endpoint (used by the main app)
app.get("/qr-code", (_req, res) => {
  res.json({ qr: latestQr, ready: isReady });
});

// GET /qr — Human-readable HTML page to scan QR
app.get("/qr", async (_req, res) => {
  if (isReady) {
    return res.send(`
      <!DOCTYPE html><html><head><title>WhatsApp Bot</title></head>
      <body style="font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;background:#f0f2f5;">
        <div style="background:white;padding:40px;border-radius:12px;box-shadow:0 4px 12px rgba(0,0,0,.15);text-align:center;">
          <h2 style="color:#25d366">✅ WhatsApp is Connected!</h2>
          <p>The bot is online and ready to send messages.</p>
        </div>
      </body></html>`);
  }

  if (!latestQrDataUrl) {
    return res.send(`
      <!DOCTYPE html><html>
      <head><title>WhatsApp QR</title><meta http-equiv="refresh" content="5"></head>
      <body style="font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;background:#f0f2f5;">
        <div style="background:white;padding:40px;border-radius:12px;box-shadow:0 4px 12px rgba(0,0,0,.15);text-align:center;">
          <h2>⏳ Generating QR Code...</h2>
          <p>Please wait. This page auto-refreshes every 5 seconds.</p>
        </div>
      </body></html>`);
  }

  return res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Scan WhatsApp QR</title>
      <meta http-equiv="refresh" content="30">
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          font-family: 'Segoe UI', sans-serif;
          display: flex; align-items: center; justify-content: center;
          min-height: 100vh; background: #f0f2f5;
        }
        .card {
          background: white; padding: 40px; border-radius: 16px;
          box-shadow: 0 8px 24px rgba(0,0,0,.12); text-align: center; max-width: 380px;
        }
        h2 { color: #128c7e; margin-bottom: 8px; font-size: 1.4rem; }
        p  { color: #667; margin-bottom: 20px; font-size: .9rem; }
        img { border-radius: 8px; border: 3px solid #25d366; width: 280px; height: 280px; }
        .note { margin-top: 16px; color: #999; font-size: .8rem; }
      </style>
    </head>
    <body>
      <div class="card">
        <h2>📱 Scan to Connect WhatsApp</h2>
        <p>Open WhatsApp → Linked Devices → Link a Device</p>
        <img src="${latestQrDataUrl}" alt="QR Code" />
        <p class="note">Auto-refreshes every 30 seconds · QR expires in ~60s</p>
      </div>
    </body>
    </html>`);
});

/**
 * POST /sendMessage
 * Body: { "phone": "923001234567", "message": "Hello!" }
 */
app.post("/sendMessage", async (req, res) => {
  try {
    const { phone, message } = req.body;

    if (!phone || !message)
      return res.status(400).json({ success: false, message: "phone and message are required" });

    if (!isReady || !sock)
      return res.status(503).json({ success: false, message: "WhatsApp client is not ready yet" });

    // Check if number is on WhatsApp
    const exists = await checkNumberOnWhatsApp(phone);
    if (!exists) {
      console.warn(`⚠️  ${phone} is not registered on WhatsApp.`);
      return res.status(400).json({
        success: false,
        message: `Phone number ${phone} is not registered on WhatsApp.`,
      });
    }

    const jid = formatJid(phone);
    await sock.sendMessage(jid, { text: message });
    console.log(`📨 Message sent to ${jid}`);

    return res.json({ success: true, message: "Message sent successfully" });
  } catch (err) {
    console.error("Error in /sendMessage:", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// GET /botInfo
app.get("/botInfo", (req, res) => {
  if (!isReady || !sock || !sock.user) {
    return res.json({ ready: false });
  }
  res.json({
    ready: true,
    jid: sock.user.id,
    name: sock.user.name,
  });
});

/**
 * GET /checkMessages?phone=923001234567
 * Returns the last 5 messages from the chat with that number.
 */
app.get("/checkMessages", async (req, res) => {
  try {
    const { phone } = req.query;
    if (!phone)
      return res.status(400).json({ success: false, message: "phone query param is required" });

    if (!isReady || !sock)
      return res.status(503).json({ success: false, message: "WhatsApp client is not ready yet" });

    const jid = formatJid(phone);

    const msgs = messageHistory[jid]?.slice(-5) ?? [];

    const formatted = msgs.map((m) => ({
      fromMe: m.key.fromMe,
      body: m.message?.conversation
        || m.message?.extendedTextMessage?.text
        || m.message?.imageMessage?.caption
        || m.message?.videoMessage?.caption
        || "",
      timestamp: m.messageTimestamp,
    }));

    return res.json({ success: true, jid, messages: formatted });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ── Memory Watchdog ────────────────────────────────────────────────────
// On Render free tier, Baileys uses ~60-100MB. We alert at 300MB just in case.
const MEMORY_LIMIT_MB = parseInt(process.env.MEMORY_LIMIT_MB || "300");
setInterval(() => {
  const usedMB = process.memoryUsage().rss / 1024 / 1024;
  if (usedMB > MEMORY_LIMIT_MB) {
    console.error(
      `⚠️  Memory ${usedMB.toFixed(0)}MB > limit ${MEMORY_LIMIT_MB}MB. Restarting...`
    );
    process.exit(1);
  }
}, 30_000);

// ── Graceful Shutdown ──────────────────────────────────────────────────
async function gracefulShutdown(signal) {
  console.log(`\n🛑 ${signal} received — shutting down gracefully...`);
  try {
    if (sock) await sock.logout();
  } catch (_) {}
  process.exit(0);
}
process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
process.on("SIGINT",  () => gracefulShutdown("SIGINT"));

// ── Start ──────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`🚀 WhatsApp Bot server running on http://localhost:${PORT}`);
});

// Connect WhatsApp (async, doesn't block HTTP server start)
connect().catch(console.error);
