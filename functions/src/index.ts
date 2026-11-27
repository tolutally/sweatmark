import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onRequest} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {defineSecret} from "firebase-functions/params";
import {setGlobalOptions} from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {authorizeAdminHttp, requireAdmin, requireUser, searchInput, exerciseIdInput, consumeExerciseQuota} from "./security";

// Set global options for all functions
setGlobalOptions({region: "us-east1"});

admin.initializeApp();

const db = admin.firestore();

// Define the secret
const rapidApiKey = defineSecret("RAPIDAPI_KEY");

// ExerciseDB API config (v1 API)
const EXERCISEDB_HOST = "exercisedb-api1.p.rapidapi.com";
const EXERCISEDB_BASE_URL = `https://${EXERCISEDB_HOST}/api/v1`;

interface ExerciseDbResponse {
  exerciseId: string;
  name: string;
  imageUrl: string;
}

interface NormalizedExercise {
  id: string;
  externalId: string;
  name: string;
  nameLower: string;
  muscleGroup: string;
  gifUrl: string;
  source: string;
  icon: string;
  equipment: string;
  instructions: string;
  createdAt: admin.firestore.Timestamp;
}

/**
 * Normalize ExerciseDB response to our Exercise model
 * Note: New API has limited data, we'll use defaults
 */
function normalizeExercise(apiExercise: ExerciseDbResponse): NormalizedExercise {
  return {
    id: `exercisedb_${apiExercise.exerciseId}`,
    externalId: apiExercise.exerciseId,
    name: apiExercise.name,
    nameLower: apiExercise.name.toLowerCase(),
    muscleGroup: "General", // API v1 doesn't provide body part in list
    gifUrl: apiExercise.imageUrl,
    source: "exercisedb",
    icon: "💪",
    equipment: "Various",
    instructions: "",
    createdAt: admin.firestore.Timestamp.now(),
  };
}

/**
 * Search exercises - PERMANENT CACHE (no TTL)
 */
export const searchExercises = onCall(
  {
    secrets: [rapidApiKey],
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (request) => {
    const caller = requireUser(request);
    const {query, bodyPart, equipment, limit} = searchInput(request.data);
    await consumeExerciseQuota(caller.uid);

    // Try to serve from Firestore cache first
    let cachedResults: admin.firestore.QuerySnapshot | null = null;

    try {
      // If no filters specified, return all cached exercises
      if (!query && !bodyPart && !equipment) {
        cachedResults = await db
          .collection("exercisedb_exercises")
          .limit(limit)
          .get();

        if (!cachedResults.empty) {
          console.log(`Cache hit for all exercises: ${cachedResults.size} found`);
          const exercises = cachedResults.docs.map((doc) => doc.data());
          return {exercises, fromCache: true};
        }
      }

      // Search by name (prefix search)
      if (query && query.length >= 2) {
        const queryLower = query.toLowerCase();
        cachedResults = await db
          .collection("exercisedb_exercises")
          .where("nameLower", ">=", queryLower)
          .where("nameLower", "<=", queryLower + "\uf8ff")
          .limit(limit)
          .get();

        if (!cachedResults.empty) {
          console.log(`Cache hit for name search: "${query}"`);
          const exercises = cachedResults.docs.map((doc) => doc.data());
          return {exercises, fromCache: true};
        }
      }

      // Search by body part
      if (bodyPart && !query) {
        cachedResults = await db
          .collection("exercisedb_exercises")
          .where("bodyPart", "==", bodyPart.toLowerCase())
          .limit(limit)
          .get();

        if (!cachedResults.empty) {
          console.log(`Cache hit for bodyPart: "${bodyPart}"`);
          const exercises = cachedResults.docs.map((doc) => doc.data());
          return {exercises, fromCache: true};
        }
      }

      // Search by equipment
      if (equipment && !query && !bodyPart) {
        cachedResults = await db
          .collection("exercisedb_exercises")
          .where("equipmentLower", "==", equipment.toLowerCase())
          .limit(limit)
          .get();

        if (!cachedResults.empty) {
          console.log(`Cache hit for equipment: "${equipment}"`);
          const exercises = cachedResults.docs.map((doc) => doc.data());
          return {exercises, fromCache: true};
        }
      }
    } catch (cacheError) {
      console.log("Cache query failed, falling back to API:", cacheError);
    }

    // Cache miss - call ExerciseDB API v1
    const apiKey = rapidApiKey.value();
    if (!apiKey) {
      throw new HttpsError(
        "failed-precondition",
        "API key not configured"
      );
    }

    // New API uses search endpoint
    // If no search criteria provided, use a common term to get popular exercises
    const searchQuery = query || bodyPart || equipment || "press";
    const url = `${EXERCISEDB_BASE_URL}/exercises/search?search=${encodeURIComponent(searchQuery)}&limit=${Math.min(limit, 50)}`;

    console.log(`Cache miss - fetching from ExerciseDB: ${url}`);

    try {
      const response = await fetch(url, {
        method: "GET",
        headers: {
          "X-RapidAPI-Key": apiKey,
          "x-rapidapi-host": EXERCISEDB_HOST,
        },
      });

      if (!response.ok) {
        throw new Error(`ExerciseDB API error: ${response.status}`);
      }

      const apiResponse: {success: boolean; data: ExerciseDbResponse[]} = await response.json();
      const normalizedExercises: NormalizedExercise[] = [];

      // Cache each exercise PERMANENTLY
      const batch = db.batch();

      for (const apiExercise of apiResponse.data || []) {
        const normalized = normalizeExercise(apiExercise);
        normalizedExercises.push(normalized);

        const exerciseRef = db
          .collection("exercisedb_exercises")
          .doc(normalized.externalId);

        batch.set(exerciseRef, normalized, {merge: true});
      }

      if (normalizedExercises.length > 0) {
        await batch.commit();
      }

      console.log(`Cached ${normalizedExercises.length} exercises`);
      return {exercises: normalizedExercises, fromCache: false};
    } catch (error) {
      console.error("ExerciseDB API error:", error);
      throw new HttpsError(
        "internal",
        "Failed to fetch exercises from ExerciseDB"
      );
    }
  }
);

/**
 * Get exercise by external ID - PERMANENT CACHE
 */
export const getExerciseById = onCall(
  {
    secrets: [rapidApiKey],
    timeoutSeconds: 15,
    memory: "256MiB",
  },
  async (request) => {
    const caller = requireUser(request);
    const externalId = exerciseIdInput(request.data, "externalId");
    await consumeExerciseQuota(caller.uid);

    // Check cache first
    const exerciseRef = db.collection("exercisedb_exercises").doc(externalId);
    const exerciseDoc = await exerciseRef.get();

    if (exerciseDoc.exists) {
      console.log(`Cache hit for exercise: ${externalId}`);
      return {exercise: exerciseDoc.data(), fromCache: true};
    }

    // Cache miss - fetch from API
    const apiKey = rapidApiKey.value();
    if (!apiKey) {
      throw new HttpsError("failed-precondition", "API key not configured");
    }

    const url = `${EXERCISEDB_BASE_URL}/exercises/${externalId}`;

    try {
      const response = await fetch(url, {
        method: "GET",
        headers: {
          "X-RapidAPI-Key": apiKey,
          "x-rapidapi-host": EXERCISEDB_HOST,
        },
      });

      if (!response.ok) {
        throw new Error(`ExerciseDB API error: ${response.status}`);
      }

      const apiResponse: {success: boolean; data: ExerciseDbResponse} = await response.json();
      const normalized = normalizeExercise(apiResponse.data);

      await exerciseRef.set(normalized, {merge: true});

      console.log(`Cached exercise: ${externalId}`);
      return {exercise: normalized, fromCache: false};
    } catch (error) {
      console.error("ExerciseDB API error:", error);
      throw new HttpsError("internal", "Failed to fetch exercise");
    }
  }
);

// Extended interface for full API response
interface ExerciseDbFullResponse {
  exerciseId: string;
  name: string;
  imageUrl: string;
  bodyParts?: string[];
  equipments?: string[];
  exerciseType?: string;
  targetMuscles?: string[];
  secondaryMuscles?: string[];
  keywords?: string[];
}

interface ApiPaginatedResponse {
  success: boolean;
  meta: {
    total: number;
    hasNextPage: boolean;
    hasPreviousPage: boolean;
    nextCursor?: string;
  };
  data: ExerciseDbFullResponse[];
}

/**
 * Normalize full ExerciseDB response with all available data
 */
function normalizeFullExercise(apiExercise: ExerciseDbFullResponse): NormalizedExercise {
  // Get primary body part
  const bodyPart = apiExercise.bodyParts?.[0]?.toLowerCase()
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase()) || "General";

  // Get equipment
  const equipment = apiExercise.equipments?.[0]?.toLowerCase()
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase()) || "Various";

  // Get target muscles for description
  const targetMuscles = apiExercise.targetMuscles?.map((m) =>
    m.toLowerCase().replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase())
  ).join(", ") || "";

  return {
    id: `exercisedb_${apiExercise.exerciseId}`,
    externalId: apiExercise.exerciseId,
    name: apiExercise.name,
    nameLower: apiExercise.name.toLowerCase(),
    muscleGroup: bodyPart,
    gifUrl: apiExercise.imageUrl,
    source: "exercisedb",
    icon: "💪",
    equipment: equipment,
    instructions: targetMuscles ? `Target muscles: ${targetMuscles}` : "",
    createdAt: admin.firestore.Timestamp.now(),
  };
}

/**
 * HTTP endpoint to download ALL exercises using pagination
 * This fetches every exercise from the API
 */
export const adminDownloadAllExercises = onRequest(
  {
    secrets: [rapidApiKey],
    timeoutSeconds: 540,
    memory: "1GiB",
    cors: false,
  },
  async (req, res) => {
    if (!await authorizeAdminHttp(req, res)) return;

    const apiKey = rapidApiKey.value();
    if (!apiKey) {
      res.status(500).json({error: "API key not configured"});
      return;
    }

    let totalExercises = 0;
    let pageCount = 0;
    let nextCursor: string | undefined;
    const errors: string[] = [];

    try {
      const beforeSnapshot = await db.collection("exercisedb_exercises").count().get();
      const beforeCount = beforeSnapshot.data().count;
      console.log(`📊 Exercises before: ${beforeCount}`);

      // Fetch all pages using cursor-based pagination
      do {
        pageCount++;
        const url = nextCursor
          ? `${EXERCISEDB_BASE_URL}/exercises?limit=100&cursor=${nextCursor}`
          : `${EXERCISEDB_BASE_URL}/exercises?limit=100`;

        console.log(`📄 Fetching page ${pageCount}...`);

        const response = await fetch(url, {
          headers: {
            "X-RapidAPI-Key": apiKey,
            "x-rapidapi-host": EXERCISEDB_HOST,
          },
        });

        if (!response.ok) {
          console.log(`❌ API error: ${response.status}`);
          errors.push(`Page ${pageCount}: ${response.status}`);
          break;
        }

        const apiResponse = await response.json() as ApiPaginatedResponse;
        const exercises = apiResponse.data || [];

        console.log(`  Got ${exercises.length} exercises, total in API: ${apiResponse.meta?.total}`);

        // Batch write to Firestore
        const batches: admin.firestore.WriteBatch[] = [];
        let currentBatch = db.batch();
        let batchCount = 0;

        for (const exercise of exercises) {
          const normalized = normalizeFullExercise(exercise);
          const docRef = db.collection("exercisedb_exercises").doc(normalized.externalId);
          currentBatch.set(docRef, normalized, {merge: true});
          batchCount++;
          totalExercises++;

          if (batchCount >= 450) {
            batches.push(currentBatch);
            currentBatch = db.batch();
            batchCount = 0;
          }
        }

        if (batchCount > 0) batches.push(currentBatch);
        for (const batch of batches) await batch.commit();

        console.log(`  ✅ Saved ${exercises.length} exercises to Firestore`);

        // Update cursor for next page
        nextCursor = apiResponse.meta?.hasNextPage ? apiResponse.meta.nextCursor : undefined;

        // Rate limiting
        await new Promise((resolve) => setTimeout(resolve, 500));
      } while (nextCursor);

      const afterSnapshot = await db.collection("exercisedb_exercises").count().get();
      const afterCount = afterSnapshot.data().count;

      console.log(`🎉 Download complete!`);
      console.log(`   Pages fetched: ${pageCount}`);
      console.log(`   Exercises before: ${beforeCount}`);
      console.log(`   Exercises after: ${afterCount}`);
      console.log(`   New exercises: ${afterCount - beforeCount}`);

      res.json({
        success: true,
        beforeCount,
        afterCount,
        newExercises: afterCount - beforeCount,
        totalProcessed: totalExercises,
        pagesFetched: pageCount,
        errors: errors.length,
        errorDetails: errors,
      });
    } catch (error) {
      console.error("❌ Error:", error);
      res.status(500).json({error: String(error)});
    }
  }
);

/**
 * Download ALL exercises from ExerciseDB and store to Firestore
 * This is an admin endpoint that fetches the complete exercise database
 */
export const downloadAllExercisesComplete = onCall(
  {
    secrets: [rapidApiKey],
    timeoutSeconds: 540, // 9 minutes max
    memory: "1GiB",
  },
  async (request) => {
    const caller = await requireAdmin(request);

    console.log(`🚀 Starting FULL exercise download for user: ${caller.uid}`);

    const apiKey = rapidApiKey.value();
    if (!apiKey) {
      throw new HttpsError("failed-precondition", "API key not configured");
    }

    // Comprehensive search terms to get ALL exercises
    const searchTerms = [
      // Alphabet - single letters to catch everything
      "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
      "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
      // Numbers (some exercises have numbers)
      "1", "2", "3", "4", "5",
      // Body parts
      "chest", "back", "shoulder", "bicep", "tricep", "forearm", "leg",
      "quad", "hamstring", "glute", "calf", "ab", "core", "neck", "trap",
      "lat", "delt", "pec", "hip", "thigh", "arm", "upper", "lower",
      // Equipment
      "barbell", "dumbbell", "cable", "machine", "kettlebell", "bodyweight",
      "band", "ez bar", "smith", "bench", "pull up", "dip",
      // Exercise types
      "press", "curl", "extension", "fly", "raise", "row", "pull",
      "squat", "lunge", "deadlift", "thrust", "crunch", "plank",
      // Common words
      "seated", "standing", "lying", "incline", "decline", "reverse",
      "wide", "close", "grip", "single", "double", "alternate",
    ];

    let totalExercises = 0;
    let newExercises = 0;
    const processedIds = new Set<string>();
    const errors: string[] = [];

    try {
      // Get existing exercise count
      const beforeSnapshot = await db.collection("exercisedb_exercises").count().get();
      const beforeCount = beforeSnapshot.data().count;
      console.log(`📊 Exercises before: ${beforeCount}`);

      for (let i = 0; i < searchTerms.length; i++) {
        const term = searchTerms[i];
        console.log(`🔍 [${i + 1}/${searchTerms.length}] Searching: "${term}"`);

        try {
          const url = `${EXERCISEDB_BASE_URL}/exercises/search?search=${encodeURIComponent(term)}&limit=500`;

          const response = await fetch(url, {
            method: "GET",
            headers: {
              "X-RapidAPI-Key": apiKey,
              "x-rapidapi-host": EXERCISEDB_HOST,
            },
          });

          if (!response.ok) {
            console.log(`⚠️ Failed for "${term}": ${response.status}`);
            errors.push(term);
            continue;
          }

          const apiResponse: {success: boolean; data: ExerciseDbResponse[]} = await response.json();
          const exercises = apiResponse.data || [];

          // Process in batches
          const batches: admin.firestore.WriteBatch[] = [];
          let currentBatch = db.batch();
          let batchCount = 0;
          let termNewCount = 0;

          for (const exercise of exercises) {
            if (processedIds.has(exercise.exerciseId)) continue;
            processedIds.add(exercise.exerciseId);

            const normalized = normalizeExercise(exercise);
            const docRef = db.collection("exercisedb_exercises").doc(normalized.externalId);

            currentBatch.set(docRef, normalized, {merge: true});
            batchCount++;
            termNewCount++;
            totalExercises++;

            if (batchCount >= 450) {
              batches.push(currentBatch);
              currentBatch = db.batch();
              batchCount = 0;
            }
          }

          if (batchCount > 0) {
            batches.push(currentBatch);
          }

          for (const batch of batches) {
            await batch.commit();
          }

          if (termNewCount > 0) {
            newExercises += termNewCount;
            console.log(`✅ Added ${termNewCount} new from "${term}"`);
          }

          // Rate limit - be nice to the API
          await new Promise((resolve) => setTimeout(resolve, 800));
        } catch (termError) {
          console.log(`❌ Error for "${term}": ${termError}`);
          errors.push(term);
        }
      }

      // Get final count
      const afterSnapshot = await db.collection("exercisedb_exercises").count().get();
      const afterCount = afterSnapshot.data().count;

      console.log(`🎉 Download complete!`);
      console.log(`   Before: ${beforeCount}`);
      console.log(`   After: ${afterCount}`);
      console.log(`   New: ${afterCount - beforeCount}`);
      console.log(`   Unique processed: ${processedIds.size}`);

      return {
        success: true,
        beforeCount,
        afterCount,
        newExercises: afterCount - beforeCount,
        totalProcessed: processedIds.size,
        searchTermsUsed: searchTerms.length,
        errors: errors.length,
        errorTerms: errors.slice(0, 10), // First 10 errors
        message: `Downloaded ${afterCount - beforeCount} new exercises. Total: ${afterCount}`,
      };
    } catch (error) {
      console.error("❌ Fatal error:", error);
      throw new HttpsError("internal", `Download failed: ${error}`);
    }
  }
);

/**
 * Admin callable function to trigger exercise download
 * Requires a verified administrator account
 */
export const triggerExerciseDownload = onCall(
  {
    secrets: [rapidApiKey],
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async (request) => {
    const caller = await requireAdmin(request);

    console.log(`Exercise download triggered by user: ${caller.uid}`);

    const searchTerms = [
      // Body parts - Primary
      "back", "chest", "legs", "arms", "shoulders", "core", "abs", "biceps", "triceps",
      "calves", "forearms", "glutes", "hamstrings", "quads", "lats", "traps",
      // Exercise types
      "strength", "cardio", "stretch", "flexibility",
      // Equipment
      "barbell", "dumbbell", "kettlebell", "cable", "machine", "bodyweight",
      // Common exercises
      "press", "pull", "row", "curl", "extension", "fly", "raise",
      "squat", "lunge", "deadlift", "plank", "crunch",
      // Position modifiers
      "incline", "decline", "seated", "standing",
    ];

    const apiKey = rapidApiKey.value();
    if (!apiKey) {
      throw new HttpsError("failed-precondition", "API key not configured");
    }

    let totalExercises = 0;
    const errors: string[] = [];
    const processedIds = new Set<string>();

    try {
      for (const term of searchTerms) {
        const url = `${EXERCISEDB_BASE_URL}/exercises/search?search=${encodeURIComponent(term)}&limit=100`;

        const response = await fetch(url, {
          method: "GET",
          headers: {
            "X-RapidAPI-Key": apiKey,
            "x-rapidapi-host": EXERCISEDB_HOST,
          },
        });

        if (!response.ok) {
          errors.push(`Failed for ${term}`);
          continue;
        }

        const apiResponse: {success: boolean; data: ExerciseDbResponse[]} = await response.json();
        const apiExercises = apiResponse.data || [];

        const batch = db.batch();
        let operationCount = 0;

        for (const apiExercise of apiExercises) {
          if (processedIds.has(apiExercise.exerciseId)) continue;
          processedIds.add(apiExercise.exerciseId);

          const normalized = normalizeExercise(apiExercise);
          const exerciseRef = db
            .collection("exercisedb_exercises")
            .doc(normalized.externalId);

          batch.set(exerciseRef, normalized, {merge: true});
          operationCount++;
          totalExercises++;

          if (operationCount >= 450) {
            await batch.commit();
            operationCount = 0;
          }
        }

        if (operationCount > 0) {
          await batch.commit();
        }

        // Rate limit
        await new Promise((resolve) => setTimeout(resolve, 1000));
      }

      return {
        success: true,
        totalExercises,
        errors: errors.length,
        message: `Downloaded ${totalExercises} exercises`,
      };
    } catch (error) {
      console.error("Download error:", error);
      throw new HttpsError("internal", `Download failed: ${error}`);
    }
  }
);

/**
 * ADMIN: Bulk download ALL exercises from ExerciseDB
 * Requires a verified Firebase ID token with the admin custom claim
 */
export const bulkDownloadExercises = onRequest(
  {
    secrets: [rapidApiKey],
    timeoutSeconds: 540,
    memory: "1GiB",
    // Preserve existing invoker IAM; application authorization requires an admin token.
  },
  async (req, res) => {
    if (!await authorizeAdminHttp(req, res)) return;
    const apiKey = rapidApiKey.value();
    if (!apiKey) {
      res.status(500).json({error: "API key not configured"});
      return;
    }

    const searchTerms = [
      // Body parts - Primary
      "back", "chest", "legs", "arms", "shoulders", "core", "abs", "biceps", "triceps",
      "calves", "forearms", "glutes", "hamstrings", "quads", "lats", "traps", "delts",
      // Body parts - Secondary
      "neck", "obliques", "hip", "thigh", "calf", "wrist", "ankle", "knee",
      "lower back", "upper back", "mid back", "pectorals", "serratus",
      // Exercise types
      "strength", "cardio", "stretch", "flexibility", "mobility", "warm", "cool",
      "endurance", "power", "speed", "balance", "stability", "athletic", "plyometric",
      // Equipment - Primary
      "barbell", "dumbbell", "kettlebell", "cable", "machine", "bodyweight",
      "band", "resistance", "bench", "ez bar", "trap bar", "smith machine",
      // Equipment - Secondary
      "medicine ball", "stability ball", "bosu", "foam roller", "suspension", "trx",
      "rope", "chain", "plate", "pull up bar", "dip bars", "rings",
      // Common exercises - Upper body
      "press", "pull", "row", "curl", "extension", "fly", "raise", "shrug",
      "pushup", "pullup", "chinup", "dip", "pushdown", "kickback",
      // Common exercises - Lower body
      "squat", "lunge", "deadlift", "leg press", "leg curl", "leg extension",
      "hip thrust", "glute bridge", "step up", "calf raise", "romanian",
      // Common exercises - Core
      "plank", "crunch", "sit up", "russian twist", "leg raise", "ab wheel",
      "mountain climber", "bicycle", "v-up", "hollow", "dead bug",
      // Movement patterns
      "push", "pull", "hinge", "squat", "carry", "rotate", "lunge",
      // Position modifiers
      "overhead", "lateral", "front", "rear", "incline", "decline", "seated",
      "standing", "lying", "kneeling", "single", "double", "alternate",
      // Intensity modifiers
      "heavy", "light", "explosive", "slow", "pause", "tempo", "drop set",
      // Cardio exercises
      "jump", "sprint", "walk", "run", "jog", "burpee", "jump rope", "box jump",
      "jumping jack", "high knees", "butt kicks", "skater",
      // Specific muscle exercises
      "hammer curl", "preacher curl", "concentration curl", "spider curl",
      "skull crusher", "tricep dip", "diamond pushup", "close grip",
      "face pull", "upright row", "arnold press", "military press",
      "bent over row", "t-bar row", "pendlay row", "cable row", "lat pulldown",
      "chest fly", "pec deck", "cable crossover", "dumbbell press",
      "sumo", "conventional", "deficit", "rack pull", "good morning",
      "goblet squat", "front squat", "hack squat", "sissy squat", "split squat",
      "reverse lunge", "walking lunge", "curtsy lunge", "lateral lunge",
      // Stretching
      "stretch", "dynamic", "static", "foam roll", "release", "mobility",
      // Additional terms to capture more exercises
      "grip", "wrist", "finger", "forearm", "adductor", "abductor",
      "external rotation", "internal rotation", "scapula", "rotator cuff",
      "farmer", "suitcase", "overhead carry", "loaded carry",
      "clean", "snatch", "jerk", "thruster", "wall ball", "battle rope",
    ];

    let totalExercises = 0;
    const errors: string[] = [];
    const processedIds = new Set<string>();

    try {
      for (const term of searchTerms) {
        console.log(`Fetching exercises for: ${term}`);

        // Try to get more exercises by increasing the limit
        const url = `${EXERCISEDB_BASE_URL}/exercises/search?search=${encodeURIComponent(term)}&limit=200`;

        const response = await fetch(url, {
          method: "GET",
          headers: {
            "X-RapidAPI-Key": apiKey,
            "x-rapidapi-host": EXERCISEDB_HOST,
          },
        });

        if (!response.ok) {
          errors.push(`Failed for ${term}: ${response.status}`);
          continue;
        }

        const apiResponse: {success: boolean; data: ExerciseDbResponse[]} = await response.json();
        const apiExercises = apiResponse.data || [];
        console.log(`Got ${apiExercises.length} exercises for ${term}`);

        const batches: admin.firestore.WriteBatch[] = [];
        let currentBatch = db.batch();
        let operationCount = 0;

        for (const apiExercise of apiExercises) {
          // Skip duplicates
          if (processedIds.has(apiExercise.exerciseId)) {
            continue;
          }
          processedIds.add(apiExercise.exerciseId);

          const normalized = normalizeExercise(apiExercise);
          const exerciseRef = db
            .collection("exercisedb_exercises")
            .doc(normalized.externalId);

          currentBatch.set(exerciseRef, normalized, {merge: true});

          operationCount++;
          totalExercises++;

          if (operationCount >= 450) {
            batches.push(currentBatch);
            currentBatch = db.batch();
            operationCount = 0;
          }
        }

        if (operationCount > 0) {
          batches.push(currentBatch);
        }

        for (const batch of batches) {
          await batch.commit();
        }

        console.log(`Committed exercises for ${term}`);
        // Rate limit: wait between requests to avoid hitting API limits
        await new Promise((resolve) => setTimeout(resolve, 1500));
      }

      const message = `Downloaded ${totalExercises} unique exercises from ${searchTerms.length} search terms.${
        errors.length > 0 ? ` Errors: ${errors.join(", ")}` : ""
      }`;
      res.status(200).send(message);
    } catch (error) {
      console.error("Bulk download error:", error);
      res.status(500).send(`Error: ${error}`);
    }
  }
);

/**
 * ADMIN: Download ALL exercises using alphabet search
 * This tries to get comprehensive coverage by searching a-z
 */
export const downloadAllExercises = onRequest(
  {
    secrets: [rapidApiKey],
    timeoutSeconds: 540,
    memory: "1GiB",
    // Preserve existing invoker IAM; application authorization requires an admin token.
  },
  async (req, res) => {
    if (!await authorizeAdminHttp(req, res)) return;
    const apiKey = rapidApiKey.value();
    if (!apiKey) {
      res.status(500).json({error: "API key not configured"});
      return;
    }

    // Search using every letter and common prefixes
    const searchTerms = [
      // Alphabet search
      "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
      "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
      // Common two-letter starts
      "ab", "ad", "al", "ar", "ba", "be", "bi", "bo", "br", "bu",
      "ca", "ch", "cl", "co", "cr", "cu", "de", "di", "do", "dr",
      "el", "ex", "fl", "fr", "gl", "gr", "ha", "he", "hi", "ho",
      "in", "is", "ju", "kn", "la", "le", "li", "lo", "lu", "ma",
      "me", "mi", "mo", "mu", "ne", "ob", "on", "ov", "pa", "pe",
      "pl", "po", "pr", "pu", "qu", "ra", "re", "ri", "ro", "ru",
      "sc", "se", "sh", "si", "sl", "sm", "sn", "sp", "sq", "st",
      "str", "su", "sw", "th", "ti", "to", "tr", "tw", "un", "up",
      "wa", "we", "wh", "wi", "wr",
    ];

    let totalExercises = 0;
    const errors: string[] = [];
    const processedIds = new Set<string>();

    try {
      for (const term of searchTerms) {
        console.log(`Searching for: "${term}"`);

        const url = `${EXERCISEDB_BASE_URL}/exercises/search?search=${encodeURIComponent(term)}&limit=200`;

        const response = await fetch(url, {
          method: "GET",
          headers: {
            "X-RapidAPI-Key": apiKey,
            "x-rapidapi-host": EXERCISEDB_HOST,
          },
        });

        if (!response.ok) {
          errors.push(`Failed for "${term}": ${response.status}`);
          continue;
        }

        const apiResponse: {success: boolean; data: ExerciseDbResponse[]} = await response.json();
        const apiExercises = apiResponse.data || [];

        let newCount = 0;
        const batches: admin.firestore.WriteBatch[] = [];
        let currentBatch = db.batch();
        let operationCount = 0;

        for (const apiExercise of apiExercises) {
          if (processedIds.has(apiExercise.exerciseId)) {
            continue;
          }
          processedIds.add(apiExercise.exerciseId);

          const normalized = normalizeExercise(apiExercise);
          const exerciseRef = db
            .collection("exercisedb_exercises")
            .doc(normalized.externalId);

          currentBatch.set(exerciseRef, normalized, {merge: true});

          operationCount++;
          newCount++;
          totalExercises++;

          if (operationCount >= 450) {
            batches.push(currentBatch);
            currentBatch = db.batch();
            operationCount = 0;
          }
        }

        if (operationCount > 0) {
          batches.push(currentBatch);
        }

        for (const batch of batches) {
          await batch.commit();
        }

        if (newCount > 0) {
          console.log(`Added ${newCount} new exercises from "${term}"`);
        }

        // Rate limiting
        await new Promise((resolve) => setTimeout(resolve, 1000));
      }

      const message = `Downloaded ${totalExercises} unique exercises total.${
        errors.length > 0 ? ` Errors: ${errors.length}` : ""
      }`;
      console.log(message);
      res.status(200).send(message);
    } catch (error) {
      console.error("Download error:", error);
      res.status(500).send(`Error: ${error}`);
    }
  }
);

/**
 * Get count of cached exercises
 */
export const getCacheStats = onCall(async (request) => {
  requireUser(request);

  const snapshot = await db.collection("exercisedb_exercises").count().get();
  const count = snapshot.data().count;

  return {
    cachedExercises: count,
    message: count > 0
      ? `You have ${count} exercises cached.`
      : "No exercises cached yet.",
  };
});

/**
 * Get available body parts
 */
export const getBodyParts = onCall(async (request) => {
  requireUser(request);

  return {
    bodyParts: [
      "back", "cardio", "chest", "lower arms", "lower legs",
      "neck", "shoulders", "upper arms", "upper legs", "waist",
    ],
  };
});

/**
 * Get available equipment
 */
export const getEquipmentList = onCall(async (request) => {
  requireUser(request);

  return {
    equipment: [
      "assisted", "band", "barbell", "body weight", "bosu ball",
      "cable", "dumbbell", "elliptical machine", "ez barbell",
      "hammer", "kettlebell", "leverage machine", "medicine ball",
      "olympic barbell", "resistance band", "roller", "rope",
      "skierg machine", "sled machine", "smith machine",
      "stability ball", "stationary bike", "stepmill machine",
      "tire", "trap bar", "upper body ergometer", "weighted", "wheel roller",
    ],
  };
});

// ============================================================================
// STREAK TRACKING FUNCTIONS
// ============================================================================

interface StreakData {
  current: number;
  best: number;
  lastCompletedLocalDate: string | null;
  timezone: string;
  type: "daily" | "weekly" | "custom";
  weeklyGoal: number;
  currentWeekWorkouts: number;
  weekStartDate: string | null;
  scheduledDays: number[];
  graceDeadline: admin.firestore.Timestamp | null;
  wasStreakBroken: boolean;
  updatedAt: admin.firestore.Timestamp;
}

interface WorkoutData {
  completedAt?: admin.firestore.Timestamp;
  timestamp?: string; // ISO string format from Flutter
  userId?: string;
}

/**
 * Parse workout completion time from either completedAt or timestamp field
 */
function getWorkoutTimestamp(workoutData: WorkoutData): admin.firestore.Timestamp | null {
  // Check for completedAt (Timestamp)
  if (workoutData.completedAt) {
    return workoutData.completedAt;
  }
  
  // Check for timestamp (ISO string from Flutter)
  if (workoutData.timestamp) {
    try {
      const date = new Date(workoutData.timestamp);
      return admin.firestore.Timestamp.fromDate(date);
    } catch (e) {
      console.error("Failed to parse timestamp:", e);
      return null;
    }
  }
  
  return null;
}

/**
 * Convert UTC timestamp to local date string (YYYY-MM-DD)
 */
function toLocalDate(timestamp: admin.firestore.Timestamp, timezone: string): string {
  const date = timestamp.toDate();
  return date.toLocaleDateString("en-CA", {timeZone: timezone}); // en-CA gives YYYY-MM-DD
}

/**
 * Get start of week (Monday) for a given date
 */
function getWeekStart(dateStr: string): string {
  const date = new Date(dateStr + "T00:00:00");
  const day = date.getDay();
  const diff = day === 0 ? -6 : 1 - day; // Adjust to Monday
  date.setDate(date.getDate() + diff);
  return date.toISOString().split("T")[0];
}

/**
 * Calculate grace deadline (6 hours after midnight local time)
 */
function calculateGraceDeadline(
  lastCompletedDate: string,
  timezone: string,
  streakType: "daily" | "weekly" | "custom",
  scheduledDays: number[] = []
): Date {
  const lastDate = new Date(lastCompletedDate + "T00:00:00Z");

  if (streakType === "daily") {
    // Daily: next day at 6 AM local time
    lastDate.setDate(lastDate.getDate() + 1);
    lastDate.setHours(6, 0, 0, 0);
  } else if (streakType === "weekly") {
    // Weekly: Sunday 6 AM local time (end of week)
    const weekStart = getWeekStart(lastCompletedDate);
    const weekStartDate = new Date(weekStart + "T00:00:00Z");
    weekStartDate.setDate(weekStartDate.getDate() + 6); // Sunday
    weekStartDate.setHours(6, 0, 0, 0);
    lastDate.setTime(weekStartDate.getTime());
  } else {
    // Custom: next scheduled day at 6 AM
    const lastDay = lastDate.getDay() || 7; // Convert Sunday (0) to 7
    const nextScheduledDay = scheduledDays.find((d) => d > lastDay) || scheduledDays[0];
    const daysToAdd = nextScheduledDay > lastDay ?
      nextScheduledDay - lastDay :
      7 - lastDay + nextScheduledDay;
    lastDate.setDate(lastDate.getDate() + daysToAdd);
    lastDate.setHours(6, 0, 0, 0);
  }

  return lastDate;
}

/**
 * Update streak when a workout is completed
 * Triggered on: users/{userId}/workouts/{workoutId} creation
 */
export const updateStreakOnWorkout = onDocumentCreated(
  {
    document: "users/{userId}/workouts/{workoutId}",
    region: "us-east1",
  },
  async (event) => {
    const workoutData = event.data?.data() as WorkoutData;
    const userId = event.params.userId;

    // Get timestamp from either completedAt or timestamp field
    const completedAt = getWorkoutTimestamp(workoutData);
    
    if (!workoutData || !completedAt) {
      console.log("No workout data or timestamp found. Data:", JSON.stringify(workoutData));
      return;
    }

    console.log(`Processing streak update for user ${userId}, workout at ${completedAt.toDate()}`);

    const streakRef = db.collection("users").doc(userId).collection("streak").doc("data");
    const achievementsRef = db.collection("users").doc(userId).collection("achievements");

    try {
      await db.runTransaction(async (transaction) => {
        const streakDoc = await transaction.get(streakRef);

        // Initialize streak if doesn't exist
        if (!streakDoc.exists) {
          console.log("Creating initial streak for user");
          const initialStreak: StreakData = {
            current: 1,
            best: 1,
            lastCompletedLocalDate: toLocalDate(completedAt, "UTC"),
            timezone: "UTC",
            type: "daily",
            weeklyGoal: 3,
            currentWeekWorkouts: 1,
            weekStartDate: getWeekStart(toLocalDate(completedAt, "UTC")),
            scheduledDays: [],
            graceDeadline: admin.firestore.Timestamp.fromDate(
              calculateGraceDeadline(
                toLocalDate(completedAt, "UTC"),
                "UTC",
                "daily"
              )
            ),
            wasStreakBroken: false,
            updatedAt: admin.firestore.Timestamp.now(),
          };
          transaction.set(streakRef, initialStreak);
          console.log("Initial streak created successfully");
          return;
        }

        const streakData = streakDoc.data() as StreakData;
        const workoutLocalDate = toLocalDate(completedAt, streakData.timezone);
        const lastCompletedDate = streakData.lastCompletedLocalDate;

        // Don't update if workout is on same day
        if (lastCompletedDate === workoutLocalDate) {
          console.log("Workout already logged for today");
          return;
        }

        const now = new Date();
        const graceDeadline = streakData.graceDeadline?.toDate();
        let newCurrent = streakData.current;
        let wasStreakBroken = false;

        // Check if streak was broken (past grace deadline)
        if (graceDeadline && now > graceDeadline) {
          console.log("Streak broken - past grace deadline");
          newCurrent = 1;
          wasStreakBroken = true;
        } else {
          // Streak continues
          if (streakData.type === "daily") {
            newCurrent = streakData.current + 1;
          } else if (streakData.type === "weekly") {
            const currentWeekStart = getWeekStart(workoutLocalDate);
            if (currentWeekStart === streakData.weekStartDate) {
              // Same week
              newCurrent = streakData.current;
            } else {
              // New week - check if previous week met goal
              if (streakData.currentWeekWorkouts >= streakData.weeklyGoal) {
                newCurrent = streakData.current + 1;
              } else {
                newCurrent = 1;
                wasStreakBroken = true;
              }
            }
          } else {
            // Custom type
            newCurrent = streakData.current + 1;
          }
        }

        // Calculate new week workouts
        const currentWeekStart = getWeekStart(workoutLocalDate);
        const newWeekWorkouts = currentWeekStart === streakData.weekStartDate ?
          streakData.currentWeekWorkouts + 1 : 1;

        // Calculate new grace deadline
        const newGraceDeadline = calculateGraceDeadline(
          workoutLocalDate,
          streakData.timezone,
          streakData.type,
          streakData.scheduledDays
        );

        // Update streak
        const updatedStreak: StreakData = {
          current: newCurrent,
          best: Math.max(newCurrent, streakData.best),
          lastCompletedLocalDate: workoutLocalDate,
          timezone: streakData.timezone,
          type: streakData.type,
          weeklyGoal: streakData.weeklyGoal,
          currentWeekWorkouts: newWeekWorkouts,
          weekStartDate: currentWeekStart,
          scheduledDays: streakData.scheduledDays,
          graceDeadline: admin.firestore.Timestamp.fromDate(newGraceDeadline),
          wasStreakBroken: wasStreakBroken,
          updatedAt: admin.firestore.Timestamp.now(),
        };

        transaction.update(streakRef, updatedStreak as any);

        // Log achievements for milestone streaks
        const milestones = [7, 30, 100, 365];
        if (milestones.includes(newCurrent)) {
          const achievementDoc = achievementsRef.doc(`streak_${newCurrent}`);
          transaction.set(achievementDoc, {
            type: "streak",
            milestone: newCurrent,
            achievedAt: admin.firestore.Timestamp.now(),
          });
          console.log(`Achievement unlocked: ${newCurrent}-day streak`);
        }
      });

      console.log("Streak updated successfully");
    } catch (error) {
      console.error("Error updating streak:", error);
    }
  }
);

/**
 * Schedule streak reminder notifications
 * Runs every hour to check for upcoming deadlines
 */
export const scheduleStreakReminders = onSchedule(
  {
    schedule: "0 * * * *", // Every hour at minute 0
    timeZone: "UTC",
    region: "us-east1",
  },
  async () => {
    // Retired: weekly goals have no countdown, urgency, or loss notifications.
    // Keep the deployed function name compatible until scheduled cleanup.
    return;

  }
);

// ============================================================================
// GYMFIT API DOWNLOAD
// ============================================================================

/**
 * Download ALL exercises from GymFit API using search endpoint
 * Has detailed exercises with images and instructions
 */
export const downloadFromGymFit = onRequest(
  {
    timeoutSeconds: 540,
    memory: "1GiB",
    region: "us-east1",
    cors: true,
  },
  async (req, res) => {
    if (!await authorizeAdminHttp(req, res)) return;

    const apiKey = "d00e13bfe2mshc9670e0851f041fp17f504jsn603615b24850";
    const apiHost = "gym-fit.p.rapidapi.com";

    try {
      console.log("🏋️ Starting GymFit exercise download...");

      // Get before count
      const beforeSnapshot = await db.collection("exercisedb_exercises").count().get();
      const beforeCount = beforeSnapshot.data().count;

      // Use search endpoint with many different terms to get all exercises
      const searchTerms = [
        // Alphabet
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
        "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
        // Body parts
        "chest", "back", "shoulder", "bicep", "tricep", "leg", "glute",
        "quad", "hamstring", "calf", "ab", "core", "arm", "forearm",
        // Equipment
        "barbell", "dumbbell", "cable", "machine", "kettlebell", "band",
        // Exercise types
        "press", "curl", "row", "fly", "raise", "extension", "pulldown",
        "squat", "lunge", "deadlift", "crunch", "plank", "pull", "push",
      ];

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const allExercises = new Map<string, any>(); // Use Map to dedupe by ID

      for (let i = 0; i < searchTerms.length; i++) {
        const term = searchTerms[i];
        console.log(`🔍 [${i + 1}/${searchTerms.length}] Searching: "${term}"`);

        try {
          const searchUrl = `https://gym-fit.p.rapidapi.com/v1/exercises/search?query=${encodeURIComponent(term)}`;

          const response = await fetch(searchUrl, {
            headers: {
              "x-rapidapi-key": apiKey,
              "x-rapidapi-host": apiHost,
            },
          });

          if (!response.ok) {
            console.error(`GymFit API error for "${term}": ${response.status}`);
            if (response.status === 429) {
              console.log("Rate limited, waiting 3 seconds...");
              await new Promise((resolve) => setTimeout(resolve, 3000));
            }
            continue;
          }

          const data = await response.json();
          const results = data.results || [];

          // Add to map (dedupes by ID)
          for (const ex of results) {
            if (ex.id && !allExercises.has(ex.id)) {
              allExercises.set(ex.id, ex);
            }
          }

          console.log(`   Found ${results.length} results (total unique: ${allExercises.size})`);

          // Rate limiting
          await new Promise((resolve) => setTimeout(resolve, 300));
        } catch (e) {
          console.error(`Error searching "${term}":`, e);
        }
      }

      console.log(`📊 Total unique exercises found: ${allExercises.size}`);

      // Now fetch full details for each exercise and store
      const exerciseIds = Array.from(allExercises.keys());
      let newExercises = 0;
      let errors = 0;

      // Process in batches
      const batchSize = 50;
      for (let i = 0; i < exerciseIds.length; i += batchSize) {
        const batch = db.batch();
        const chunk = exerciseIds.slice(i, i + batchSize);
        let batchNewCount = 0;

        for (const exerciseId of chunk) {
          try {
            // Check if already exists
            const docId = `gymfit_${exerciseId}`;
            const docRef = db.collection("exercisedb_exercises").doc(docId);
            const existing = await docRef.get();
            if (existing.exists) continue;

            // Fetch full exercise details
            const detailUrl = `https://gym-fit.p.rapidapi.com/v1/exercises/${exerciseId}`;
            const detailResponse = await fetch(detailUrl, {
              headers: {
                "x-rapidapi-key": apiKey,
                "x-rapidapi-host": apiHost,
              },
            });

            if (!detailResponse.ok) {
              errors++;
              continue;
            }

            const exercise = await detailResponse.json();

            // Extract instructions text
            const instructions = (exercise.instructions || [])
              .sort((a: {order: number}, b: {order: number}) => a.order - b.order)
              .map((i: {description: string}) => i.description);

            // Extract target and secondary muscles
            const targetMuscles = (exercise.targetMuscles || [])
              .map((m: {name: string}) => m.name);
            const secondaryMuscles = (exercise.secondaryMuscles || [])
              .map((m: {name: string}) => m.name);

            const exerciseData = {
              externalId: docId,
              name: exercise.name,
              nameLower: exercise.name.toLowerCase(),
              bodyPart: normalizeGymFitBodyPart(exercise.bodyPart || ""),
              equipment: (exercise.equipment || "body weight").toLowerCase(),
              gifUrl: exercise.image || "",
              target: targetMuscles[0] || exercise.bodyPart || "",
              secondaryMuscles: secondaryMuscles,
              instructions: instructions,
              exerciseType: exercise.type || "strength",
              source: "gymfit",
              cachedAt: admin.firestore.FieldValue.serverTimestamp(),
            };

            batch.set(docRef, exerciseData);
            batchNewCount++;
            newExercises++;

            // Small delay between detail fetches
            await new Promise((resolve) => setTimeout(resolve, 100));
          } catch (e) {
            errors++;
          }
        }

        if (batchNewCount > 0) {
          await batch.commit();
        }
        console.log(`✅ Batch ${Math.floor(i / batchSize) + 1}: ${batchNewCount} new exercises saved`);
      }

      const afterSnapshot = await db.collection("exercisedb_exercises").count().get();
      const afterCount = afterSnapshot.data().count;

      console.log(`🎉 GymFit download complete!`);
      console.log(`   Before: ${beforeCount}, After: ${afterCount}, New: ${newExercises}`);

      res.status(200).json({
        success: true,
        source: "gymfit",
        beforeCount,
        afterCount,
        newExercises,
        totalSearched: allExercises.size,
        errors,
      });
    } catch (error) {
      console.error("❌ GymFit download error:", error);
      res.status(500).json({
        error: "Failed to download from GymFit",
        details: error instanceof Error ? error.message : String(error),
      });
    }
  }
);

/**
 * Refresh GymFit exercise image URL
 * GymFit images are signed S3 URLs that expire after 24 hours
 * This function fetches fresh URLs for specific exercises
 */
export const refreshGymFitImage = onCall(
  {
    region: "us-east1",
    timeoutSeconds: 30,
  },
  async (request) => {
    const caller = requireUser(request);
    const exerciseId = exerciseIdInput(request.data, "exerciseId", true);
    await consumeExerciseQuota(caller.uid);

    // Extract the GymFit ID from our doc ID format (gymfit_xxx)
    const gymfitId = exerciseId.replace("gymfit_", "");

    const apiKey = "d00e13bfe2mshc9670e0851f041fp17f504jsn603615b24850";
    const apiHost = "gym-fit.p.rapidapi.com";

    try {
      const response = await fetch(
        `https://gym-fit.p.rapidapi.com/v1/exercises/${gymfitId}`,
        {
          headers: {
            "x-rapidapi-key": apiKey,
            "x-rapidapi-host": apiHost,
          },
        }
      );

      if (!response.ok) {
        throw new HttpsError("not-found", `GymFit exercise not found: ${gymfitId}`);
      }

      const exercise = await response.json();
      const imageUrl = exercise.image || "";

      // Update Firestore with fresh image URL
      if (imageUrl) {
        await db.collection("exercisedb_exercises").doc(exerciseId).update({
          gifUrl: imageUrl,
          imageRefreshedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      return {
        success: true,
        exerciseId,
        imageUrl,
      };
    } catch (error) {
      console.error("Error refreshing GymFit image:", error);
      throw new HttpsError(
        "internal",
        error instanceof Error ? error.message : "Failed to refresh image"
      );
    }
  }
);

/**
 * Batch refresh all GymFit images (admin only)
 * Refreshes image URLs for all GymFit exercises in the database
 */
export const refreshAllGymFitImages = onRequest(
  {
    region: "us-east1",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async (req, res) => {
    if (!await authorizeAdminHttp(req, res)) return;

    const apiKey = "d00e13bfe2mshc9670e0851f041fp17f504jsn603615b24850";
    const apiHost = "gym-fit.p.rapidapi.com";

    try {
      console.log("🔄 Starting GymFit image refresh...");

      // Get all GymFit exercises
      const snapshot = await db
        .collection("exercisedb_exercises")
        .where("source", "==", "gymfit")
        .get();

      console.log(`Found ${snapshot.size} GymFit exercises`);

      let updated = 0;
      let errors = 0;

      for (const doc of snapshot.docs) {
        try {
          const gymfitId = doc.id.replace("gymfit_", "");

          const response = await fetch(
            `https://gym-fit.p.rapidapi.com/v1/exercises/${gymfitId}`,
            {
              headers: {
                "x-rapidapi-key": apiKey,
                "x-rapidapi-host": apiHost,
              },
            }
          );

          if (response.ok) {
            const exercise = await response.json();
            const imageUrl = exercise.image || "";

            if (imageUrl) {
              await doc.ref.update({
                gifUrl: imageUrl,
                imageRefreshedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
              updated++;
            }
          } else {
            errors++;
          }

          // Rate limiting
          await new Promise((resolve) => setTimeout(resolve, 100));
        } catch (e) {
          errors++;
        }
      }

      console.log(`✅ Refresh complete: ${updated} updated, ${errors} errors`);

      res.status(200).json({
        success: true,
        total: snapshot.size,
        updated,
        errors,
      });
    } catch (error) {
      console.error("❌ Error refreshing GymFit images:", error);
      res.status(500).json({
        error: "Failed to refresh images",
        details: error instanceof Error ? error.message : String(error),
      });
    }
  }
);

/**
 * Normalize body part names from GymFit to match our standard
 */
function normalizeGymFitBodyPart(bodyPart: string): string {
  if (!bodyPart) return "";
  const normalized = bodyPart.toLowerCase().trim();
  const mapping: Record<string, string> = {
    "abs": "waist",
    "abdominals": "waist",
    "core": "waist",
    "biceps": "upper arms",
    "triceps": "upper arms",
    "arms": "upper arms",
    "forearms": "lower arms",
    "quads": "upper legs",
    "quadriceps": "upper legs",
    "hamstrings": "upper legs",
    "glutes": "upper legs",
    "legs": "upper legs",
    "calves": "lower legs",
    "lats": "back",
    "traps": "back",
    "pecs": "chest",
    "delts": "shoulders",
    "deltoids": "shoulders",
  };
  return mapping[normalized] || normalized;
}

// AI workers (see src/ai/registry.ts)
export {runAiWorker} from "./ai";

export {deleteAccount} from "./account";
