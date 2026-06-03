let dbUrl = process.env.FIREBASE_DB_URL;
if (dbUrl) {
  dbUrl = dbUrl.trim();
  if (dbUrl.endsWith("/")) {
    dbUrl = dbUrl.slice(0, -1);
  }
}
const FIREBASE_DB_URL = dbUrl || "https://start-of-firebase-default-rtdb.firebaseio.com";

let isInitialized = false;
const localMockDb = {
  sessions: {},
  otps: {}
};

async function connectDB() {
  isInitialized = true;
  if (!FIREBASE_DB_URL || FIREBASE_DB_URL === "https://start-of-firebase-default-rtdb.firebaseio.com") {
    console.log("ℹ️  FIREBASE_DB_URL is not set or is using default placeholder. Using local in-memory database fallback.");
  } else {
    console.log(`✅ Firebase Realtime DB configured at ${FIREBASE_DB_URL}`);
  }
  return true;
}

const getDB = () => {
  if (!isInitialized) return null;

  // Use local in-memory mock database if FIREBASE_DB_URL is not configured or uses default
  if (!FIREBASE_DB_URL || FIREBASE_DB_URL === "https://start-of-firebase-default-rtdb.firebaseio.com") {
    return {
      collection: (name) => ({
        findOne: async (query) => {
          if (name === "sessions" && query.sessionId) {
            return localMockDb.sessions[query.sessionId] || null;
          }
          if (name === "otps" && query.phone) {
            return localMockDb.otps[query.phone] || null;
          }
          return null;
        },
        insertOne: async (doc) => {
          if (name === "sessions" && doc.sessionId) {
            localMockDb.sessions[doc.sessionId] = doc;
            return { acknowledged: true, insertedId: doc.sessionId };
          }
        },
        updateOne: async (query, update, options) => {
          if (name === "otps" && query.phone) {
            const data = update.$set || update;
            localMockDb.otps[query.phone] = {
              ...(localMockDb.otps[query.phone] || {}),
              ...data
            };
            return { acknowledged: true, modifiedCount: 1 };
          }
        },
        deleteOne: async (query) => {
          if (name === "sessions" && query.sessionId) {
            delete localMockDb.sessions[query.sessionId];
            return { acknowledged: true, deletedCount: 1 };
          }
          if (name === "otps" && query.phone) {
            delete localMockDb.otps[query.phone];
            return { acknowledged: true, deletedCount: 1 };
          }
        },
        createIndex: async () => {
          return "mock_index";
        },
      }),
    };
  }

  // Firebase Realtime DB implementation
  return {
    collection: (name) => ({
      findOne: async (query) => {
        try {
          if (name === "sessions" && query.sessionId) {
            const res = await fetch(`${FIREBASE_DB_URL}/sessions/${query.sessionId}.json`);
            if (!res.ok) return null;
            const data = await res.json();
            if (data && data.error) return null; // Avoid returning error objects like { error: "Permission denied" }
            return data;
          }
          if (name === "otps" && query.phone) {
            const res = await fetch(`${FIREBASE_DB_URL}/otps/${query.phone}.json`);
            if (!res.ok) return null;
            const data = await res.json();
            if (data && data.error) return null; // Avoid returning error objects like { error: "Permission denied" }
            return data;
          }
        } catch (err) {
          console.error(`Error in Firebase findOne for ${name}:`, err);
        }
        return null;
      },
      insertOne: async (doc) => {
        try {
          if (name === "sessions" && doc.sessionId) {
            const res = await fetch(`${FIREBASE_DB_URL}/sessions/${doc.sessionId}.json`, {
              method: "PUT",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify(doc),
            });
            if (!res.ok) throw new Error(`HTTP error ${res.status}`);
            return { acknowledged: true, insertedId: doc.sessionId };
          }
        } catch (err) {
          console.error(`Error in Firebase insertOne for ${name}:`, err);
          throw err;
        }
      },
      updateOne: async (query, update, options) => {
        try {
          if (name === "otps" && query.phone) {
            const data = update.$set || update;
            const res = await fetch(`${FIREBASE_DB_URL}/otps/${query.phone}.json`, {
              method: "PATCH",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify(data),
            });
            if (!res.ok) throw new Error(`HTTP error ${res.status}`);
            return { acknowledged: true, modifiedCount: 1 };
          }
        } catch (err) {
          console.error(`Error in Firebase updateOne for ${name}:`, err);
          throw err;
        }
      },
      deleteOne: async (query) => {
        try {
          if (name === "sessions" && query.sessionId) {
            const res = await fetch(`${FIREBASE_DB_URL}/sessions/${query.sessionId}.json`, {
              method: "DELETE",
            });
            if (!res.ok) throw new Error(`HTTP error ${res.status}`);
            return { acknowledged: true, deletedCount: 1 };
          }
          if (name === "otps" && query.phone) {
            const res = await fetch(`${FIREBASE_DB_URL}/otps/${query.phone}.json`, {
              method: "DELETE",
            });
            if (!res.ok) throw new Error(`HTTP error ${res.status}`);
            return { acknowledged: true, deletedCount: 1 };
          }
        } catch (err) {
          console.error(`Error in Firebase deleteOne for ${name}:`, err);
          throw err;
        }
      },
      createIndex: async () => {
        return "mock_index";
      },
    }),
  };
};

module.exports = { connectDB, getDB };
