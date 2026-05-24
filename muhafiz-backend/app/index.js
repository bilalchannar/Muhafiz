const express = require("express");
const cors = require("cors");
require("dotenv").config();

const authRoutes = require("./Routes/auth");

const app = express();
app.use(cors());
app.use(express.json());

// ── Routes ─────────────────────────────────────────────────────────────
app.use("/auth", authRoutes);

// ── Mass Message ───────────────────────────────────────────────────────
app.post("/sendMassMsg", async (req, res) => {
  try {
    const { phone, message } = req.body;

    if (!phone || !message) {
      return res.status(400).json({ success: false, message: "phone and message are required" });
    }

    if (!Array.isArray(phone) || phone.length === 0) {
      return res.status(400).json({ success: false, message: "phone must be a non-empty array of strings" });
    }

    const results = [];
    for (const p of phone) {
      try {
        const response = await fetch("http://localhost:3001/sendMessage", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ phone: p, message }),
        });
        const result = await response.json();
        results.push({ phone: p, success: result.success, response: result });
      } catch (err) {
        results.push({ phone: p, success: false, error: err.message });
      }
    }

    return res.status(200).json({ success: true, results });
  } catch (err) {
    console.error("Error in /sendMassMsg:", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ── Health check ───────────────────────────────────────────────────────
app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

// ── Start server ───────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 App server running on http://localhost:${PORT}`);
});
