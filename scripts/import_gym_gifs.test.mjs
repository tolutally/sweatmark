// Run: node --test scripts/import_gym_gifs.test.mjs
import {test} from "node:test";
import assert from "node:assert/strict";
import {convert, exerciseType, RELEASE} from "./import_gym_gifs.mjs";

const item = (overrides = {}) => ({
  id: "biceps/barbell-curl",
  name: "Barbell Curl",
  muscle: "biceps",
  equipment: "barbell",
  category: "strength",
  instructions: ["Stand tall.", "Curl."],
  gifUrl: `https://cdn.jsdelivr.net/gh/x/y@${RELEASE}/biceps/barbell-curl.gif`,
  ...overrides,
});
const many = (first) => [first, ...Array.from({length: 1000}, (_, i) =>
  item({id: `biceps/curl-${i}`, name: `Curl ${i}`}))];

test("maps fields into the app model", () => {
  const [curl] = convert(many(item()));
  assert.equal(curl.id, "gg:biceps/barbell-curl");
  assert.equal(curl.muscleGroup, "Biceps");
  assert.equal(curl.equipment, "Barbell");
  assert.equal(curl.exerciseType, "weightedStrength");
  assert.equal(curl.instructions, "Stand tall.\nCurl.");
});

test("infers tracking type", () => {
  assert.equal(exerciseType(item({category: "stretching"})), "timedHold");
  assert.equal(exerciseType(item({name: "Front Plank"})), "timedHold");
  assert.equal(exerciseType(item({equipment: "bodyweight"})), "bodyweightReps");
  assert.equal(exerciseType(item({category: "cardio", name: "Run"})), "cardio");
  assert.equal(
    exerciseType(item({category: "cardio", name: "Burpee"})), "bodyweightReps");
});

test("rejects drift instead of importing it", () => {
  assert.throws(() => convert([item()]), /full catalog/);
  assert.throws(() => convert(many(item({muscle: "wings"}))), /unknown muscle/);
  assert.throws(
    () => convert(many(item({gifUrl: "https://example.com/a.gif"}))),
    /not pinned/);
});
