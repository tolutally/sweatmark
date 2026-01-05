const admin = require('firebase-admin');
const fetch = require('node-fetch');

// Initialize Firebase Admin with service account
const serviceAccount = require('../service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'sweatmark-v1',
});

const db = admin.firestore();

// ExerciseDB API configuration
const EXERCISEDB_API_KEY = process.env.RAPIDAPI_KEY;
const EXERCISEDB_HOST = 'exercisedb-api1.p.rapidapi.com';
const BASE_URL = `https://${EXERCISEDB_HOST}/api/v1`;

async function fetchFromExerciseDB(endpoint) {
  const response = await fetch(`${BASE_URL}${endpoint}`, {
    headers: {
      'X-RapidAPI-Key': EXERCISEDB_API_KEY,
      'X-RapidAPI-Host': EXERCISEDB_HOST,
    },
  });

  if (!response.ok) {
    throw new Error(`API Error: ${response.status} ${response.statusText}`);
  }

  return response.json();
}

async function downloadAllExercises() {
  console.log('Starting comprehensive exercise download...');
  
  const exercisesRef = db.collection('exercisedb_exercises');
  
  // Get current count
  const beforeSnapshot = await exercisesRef.count().get();
  const beforeCount = beforeSnapshot.data().count;
  console.log(`Exercises before: ${beforeCount}`);

  // Comprehensive search terms
  const searchTerms = [
    // All letters
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
    'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
    // Numbers
    '1', '2', '3', '45', '90',
    // Body parts
    'chest', 'back', 'shoulders', 'biceps', 'triceps', 'forearms',
    'abs', 'core', 'quads', 'hamstrings', 'glutes', 'calves',
    'lats', 'traps', 'neck', 'waist', 'cardio',
    // Equipment
    'barbell', 'dumbbell', 'kettlebell', 'cable', 'machine', 'bodyweight',
    'band', 'smith', 'ez bar', 'rope', 'leverage', 'assisted',
    // Exercise types
    'press', 'row', 'curl', 'extension', 'fly', 'raise', 'shrug',
    'squat', 'lunge', 'deadlift', 'thrust', 'pull', 'push', 'dip',
  ];

  let totalAdded = 0;
  let totalProcessed = 0;
  const allExerciseIds = new Set();
  const errors = [];

  for (let i = 0; i < searchTerms.length; i++) {
    const term = searchTerms[i];
    console.log(`[${i + 1}/${searchTerms.length}] Searching: "${term}"`);

    try {
      const exercises = await fetchFromExerciseDB(`/exercises?search=${encodeURIComponent(term)}&limit=100`);
      
      if (exercises && exercises.length > 0) {
        // Filter out already processed exercises
        const newExercises = exercises.filter(ex => !allExerciseIds.has(ex.exerciseId));
        
        // Add to tracking set
        newExercises.forEach(ex => allExerciseIds.add(ex.exerciseId));

        // Batch write to Firestore
        const batch = db.batch();
        let batchCount = 0;

        for (const exercise of newExercises) {
          const docRef = exercisesRef.doc(exercise.exerciseId);
          batch.set(docRef, {
            ...exercise,
            cachedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
          batchCount++;
        }

        if (batchCount > 0) {
          await batch.commit();
          totalAdded += batchCount;
          console.log(`  Added ${batchCount} exercises`);
        }

        totalProcessed += exercises.length;
      }

      // Rate limiting
      await new Promise(resolve => setTimeout(resolve, 800));
    } catch (error) {
      console.error(`  Error for "${term}":`, error.message);
      errors.push(term);
    }
  }

  // Get final count
  const afterSnapshot = await exercisesRef.count().get();
  const afterCount = afterSnapshot.data().count;

  console.log('\n=== Download Complete ===');
  console.log(`Exercises before: ${beforeCount}`);
  console.log(`Exercises after: ${afterCount}`);
  console.log(`New exercises added: ${afterCount - beforeCount}`);
  console.log(`Unique exercises processed: ${allExerciseIds.size}`);
  console.log(`Errors: ${errors.length}`);

  process.exit(0);
}

downloadAllExercises().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
