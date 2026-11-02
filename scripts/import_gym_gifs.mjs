#!/usr/bin/env node
// Builds assets/exercises/catalog_v1.json from a pinned ExerciseGymGifsDB
// release. Run from the repository root:
//   node scripts/import_gym_gifs.mjs [path/to/exercises.json]
// Without a path it downloads the pinned English export. The output is
// committed and bundled; the app never fetches catalog data at runtime.
// Media rights: see docs/EXERCISE_LIBRARY_MIGRATION.md.

import {readFile, writeFile, mkdir} from "node:fs/promises";

export const RELEASE = "v1.1.0";
const BASE = `https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@${RELEASE}`;
const OUTPUT = "assets/exercises/catalog_v1.json";

const MUSCLES = {
  "abductors": "Abductors",
  "abs": "Abs",
  "adductors": "Adductors",
  "biceps": "Biceps",
  "calves": "Calves",
  "cardio": "Cardio",
  "delts": "Shoulders",
  "forearms": "Forearms",
  "glutes": "Glutes",
  "hamstrings": "Hamstrings",
  "lats": "Lats",
  "levator-scapulae": "Neck",
  "pectorals": "Chest",
  "quads": "Quadriceps",
  "serratus-anterior": "Serratus",
  "spine": "Lower back",
  "traps": "Traps",
  "triceps": "Triceps",
  "upper-back": "Upper back",
};

const EQUIPMENT = {
  "barbell": "Barbell",
  "dumbbell": "Dumbbell",
  "cable": "Cable",
  "machine": "Machine",
  "lever": "Machine",
  "bodyweight": "Body weight",
  "band": "Band",
  "kettlebell": "Kettlebell",
  "smith": "Smith machine",
  "ez-bar": "EZ bar",
  "sled": "Sled",
  "other": "Other",
};

const CARDIO_MACHINES =
  /\b(run|walk|walking|bike|cycle|elliptical|treadmill|stepmill|jump rope|ski step|trainer)\b/i;
const HOLDS = /\b(hold|wall sit|dead hang|isometric)\b|\bplank$/i;

export function exerciseType(item) {
  if (item.category === "cardio") {
    return CARDIO_MACHINES.test(item.name) ? "cardio" : "bodyweightReps";
  }
  if (item.category === "stretching" || HOLDS.test(item.name)) {
    return "timedHold";
  }
  if (item.category === "plyometrics" || item.equipment === "bodyweight") {
    return "bodyweightReps";
  }
  return "weightedStrength";
}

const REQUIRED = ["id", "name", "muscle", "equipment", "category", "gifUrl"];

export function convert(items) {
  if (!Array.isArray(items) || items.length < 1000) {
    throw new Error(`Expected the full catalog, got ${items?.length} items.`);
  }
  const seen = new Set();
  return items.map((item) => {
    for (const field of REQUIRED) {
      if (typeof item[field] !== "string" || !item[field].trim()) {
        throw new Error(`${item.id ?? "?"}: missing ${field}`);
      }
    }
    const muscle = MUSCLES[item.muscle];
    const equipment = EQUIPMENT[item.equipment];
    if (!muscle) throw new Error(`${item.id}: unknown muscle ${item.muscle}`);
    if (!equipment) {
      throw new Error(`${item.id}: unknown equipment ${item.equipment}`);
    }
    if (!item.gifUrl.includes(`@${RELEASE}/`)) {
      throw new Error(`${item.id}: media is not pinned to ${RELEASE}`);
    }
    const id = `gg:${item.id}`;
    if (seen.has(id)) throw new Error(`Duplicate id ${id}`);
    seen.add(id);
    return {
      id,
      name: item.name.trim(),
      muscleGroup: muscle,
      equipment,
      exerciseType: exerciseType(item),
      secondaryMuscles: (item.secondaryMuscles ?? [])
        .map((value) => MUSCLES[value] ?? value),
      instructions: (item.instructions ?? []).join("\n"),
      gifUrl: item.gifUrl,
      externalId: item.id,
      source: "gymgifs",
    };
  }).sort((a, b) => a.name.localeCompare(b.name));
}

async function main() {
  const path = process.argv[2];
  const raw = path
    ? JSON.parse(await readFile(path, "utf8"))
    : await (await fetch(`${BASE}/api/en/exercises.json`)).json();
  const exercises = convert(raw.exercises ?? raw);
  await mkdir("assets/exercises", {recursive: true});
  await writeFile(OUTPUT, JSON.stringify({
    source: "ExerciseGymGifsDB",
    release: RELEASE,
    count: exercises.length,
    exercises,
  }));
  console.log(`Wrote ${exercises.length} exercises to ${OUTPUT}`);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}
