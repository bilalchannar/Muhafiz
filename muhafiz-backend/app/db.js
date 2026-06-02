const { MongoClient } = require("mongodb");

const MONGODB_URI = process.env.MONGODB_URI;
const MONGODB_DB_NAME = process.env.MONGODB_DB_NAME || "muhafiz";

let db = null;
let client = null;

async function connectDB() {
  if (db) return db;

  if (!MONGODB_URI) {
    console.error("❌ ERROR: MONGODB_URI is not set in environment variables!");
    throw new Error("MONGODB_URI environment variable is required.");
  }

  try {
    client = new MongoClient(MONGODB_URI);
    await client.connect();
    db = client.db(MONGODB_DB_NAME);
    console.log("✅ Successfully connected to MongoDB Database");

    // Initialize Collections & TTL Indexes for Automatic Expiration
    try {
      // 1. OTPs TTL index (auto-expire documents after their expiresAt timestamp)
      await db.collection("otps").createIndex(
        { expiresAt: 1 },
        { expireAfterSeconds: 0 }
      );
      // Ensure unique index on phone for faster lookup and preventing duplicates
      await db.collection("otps").createIndex(
        { phone: 1 },
        { unique: true }
      );

      // 2. Sessions TTL index
      await db.collection("sessions").createIndex(
        { expiresAt: 1 },
        { expireAfterSeconds: 0 }
      );
      await db.collection("sessions").createIndex(
        { sessionId: 1 },
        { unique: true }
      );

      console.log("📁 MongoDB Collections & TTL Indexes verified");
    } catch (indexError) {
      console.warn("⚠️ Warning creating database indexes:", indexError.message);
    }

    return db;
  } catch (err) {
    console.error("❌ MongoDB connection failed:", err);
    throw err;
  }
}

function getDB() {
  return db;
}

module.exports = { connectDB, getDB };
