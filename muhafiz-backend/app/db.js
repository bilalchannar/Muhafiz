const FIREBASE_DB_URL = process.env.FIREBASE_DB_URL || "https://start-of-firebase-default-rtdb.firebaseio.com";

let isInitialized = false;

async function connectDB() {
  if (!FIREBASE_DB_URL) {
    console.error("❌ ERROR: FIREBASE_DB_URL is not set in environment variables!");
    throw new Error("FIREBASE_DB_URL environment variable is required.");
  }
  isInitialized = true;
  console.log(`✅ Firebase Realtime DB configured at ${FIREBASE_DB_URL}`);
  return true;
}

const getDB = () => {
  if (!isInitialized) return null;

  return {
    collection: (name) => ({
      // findOne returns a single document matching the query
      findOne: async (query) => {
        try {
          if (name === "sessions" && query.sessionId) {
            const res = await fetch(`${FIREBASE_DB_URL}/sessions/${query.sessionId}.json`);
            const data = await res.json();
            return data;
          }
          if (name === "otps" && query.phone) {
            const res = await fetch(`${FIREBASE_DB_URL}/otps/${query.phone}.json`);
            const data = await res.json();
            return data;
          }
        } catch (err) {
          console.error(`Error in Firebase findOne for ${name}:`, err);
        }
        return null;
      },

      // insertOne writes a document to a specific path
      insertOne: async (doc) => {
        try {
          if (name === "sessions" && doc.sessionId) {
            await fetch(`${FIREBASE_DB_URL}/sessions/${doc.sessionId}.json`, {
              method: "PUT",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify(doc),
            });
            return { acknowledged: true, insertedId: doc.sessionId };
          }
        } catch (err) {
          console.error(`Error in Firebase insertOne for ${name}:`, err);
          throw err;
        }
      },

      // updateOne updates properties using PATCH (partial merge)
      updateOne: async (query, update, options) => {
        try {
          if (name === "otps" && query.phone) {
            const data = update.$set || update;
            await fetch(`${FIREBASE_DB_URL}/otps/${query.phone}.json`, {
              method: "PATCH",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify(data),
            });
            return { acknowledged: true, modifiedCount: 1 };
          }
        } catch (err) {
          console.error(`Error in Firebase updateOne for ${name}:`, err);
          throw err;
        }
      },

      // deleteOne deletes the path
      deleteOne: async (query) => {
        try {
          if (name === "sessions" && query.sessionId) {
            await fetch(`${FIREBASE_DB_URL}/sessions/${query.sessionId}.json`, {
              method: "DELETE",
            });
            return { acknowledged: true, deletedCount: 1 };
          }
          if (name === "otps" && query.phone) {
            await fetch(`${FIREBASE_DB_URL}/otps/${query.phone}.json`, {
              method: "DELETE",
            });
            return { acknowledged: true, deletedCount: 1 };
          }
        } catch (err) {
          console.error(`Error in Firebase deleteOne for ${name}:`, err);
          throw err;
        }
      },

      // createIndex is a no-op in Firebase
      createIndex: async () => {
        return "mock_index";
      },
    }),
  };
};

module.exports = { connectDB, getDB };
