import {AnyWorker} from "./worker";
import {exerciseSearch} from "./workers/exerciseSearch";
import {supersetPartner} from "./workers/supersetPartner";

/**
 * Every AI worker the app can call, by name. To add one, write it in
 * workers/ and list it here; nothing else changes.
 */
export const WORKERS: Readonly<Record<string, AnyWorker>> = {
  [exerciseSearch.name]: exerciseSearch as AnyWorker,
  [supersetPartner.name]: supersetPartner as AnyWorker,
};
