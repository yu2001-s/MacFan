import { getPreferenceValues } from "@raycast/api";
import { execFile } from "node:child_process";

const DEFAULT_HELPER_PATH = "/Library/PrivilegedHelperTools/com.shaoyuhuang.MacFan.macfanctl";

type ExtensionPreferences = {
  helperPath: string;
};

export type FanInfo = {
  id: number;
  name: string;
  currentRPM: number;
  minimumRPM: number;
  maximumRPM: number;
  targetRPM: number | null;
  mode: number;
};

export function displayName(fan: FanInfo): string {
  return fan.name.trim().length > 0 ? fan.name : `Fan ${fan.id + 1}`;
}

export function modeTitle(mode: number): string {
  return mode === 1 ? "Manual" : "Auto";
}

export function safeMinimumRPM(fan: FanInfo): number {
  return Math.max(0, fan.minimumRPM);
}

export function safeMaximumRPM(fan: FanInfo): number {
  return Math.max(safeMinimumRPM(fan) + 100, fan.maximumRPM);
}

export function defaultTargetRPM(fan: FanInfo): number {
  return clamp(fan.targetRPM ?? fan.currentRPM, safeMinimumRPM(fan), safeMaximumRPM(fan));
}

export function percentOfRange(fan: FanInfo): number {
  const minimum = safeMinimumRPM(fan);
  const maximum = safeMaximumRPM(fan);

  if (maximum <= minimum) {
    return 0;
  }

  return clamp(Math.round(((fan.currentRPM - minimum) / (maximum - minimum)) * 100), 0, 100);
}

export function toErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

export async function readFans(): Promise<FanInfo[]> {
  const output = await runMacFanCtl(["fans", "--json"]);
  const parsed: unknown = JSON.parse(output);

  if (!Array.isArray(parsed)) {
    throw new Error("macfanctl returned invalid fan JSON.");
  }

  return parsed.map(normalizeFan);
}

export async function setFanSpeed(id: number, rpm: number): Promise<void> {
  await runMacFanCtl(["set-speed", "--id", String(id), "--rpm", String(rpm)]);
}

export async function setFanMode(id: number, mode: "auto" | "manual"): Promise<void> {
  await runMacFanCtl(["set-mode", "--id", String(id), "--mode", mode]);
}

export async function resetFanControl(): Promise<void> {
  await runMacFanCtl(["reset"]);
}

export async function setAllFansMaximum(): Promise<number> {
  const fans = await readFans();

  for (const fan of fans) {
    await setFanSpeed(fan.id, safeMaximumRPM(fan));
  }

  return fans.length;
}

function helperPath(): string {
  const preferences = getPreferenceValues<ExtensionPreferences>();
  const configuredPath = preferences.helperPath.trim();

  return configuredPath.length > 0 ? configuredPath : DEFAULT_HELPER_PATH;
}

function runMacFanCtl(arguments_: string[]): Promise<string> {
  return new Promise((resolve, reject) => {
    execFile(
      helperPath(),
      arguments_,
      {
        encoding: "utf8",
        maxBuffer: 1024 * 1024,
        timeout: 20_000
      },
      (error, stdout, stderr) => {
        if (error) {
          const detail = stderr.trim() || error.message;
          reject(new Error(detail));
          return;
        }

        resolve(stdout);
      }
    );
  });
}

function normalizeFan(value: unknown): FanInfo {
  if (!value || typeof value !== "object") {
    throw new Error("macfanctl returned a malformed fan entry.");
  }

  const fan = value as Record<string, unknown>;
  const targetRPM = fan.targetRPM;

  return {
    id: numberField(fan, "id"),
    name: stringField(fan, "name"),
    currentRPM: numberField(fan, "currentRPM"),
    minimumRPM: numberField(fan, "minimumRPM"),
    maximumRPM: numberField(fan, "maximumRPM"),
    targetRPM: targetRPM === null || targetRPM === undefined ? null : numberValue(targetRPM, "targetRPM"),
    mode: numberField(fan, "mode")
  };
}

function numberField(object: Record<string, unknown>, key: string): number {
  return numberValue(object[key], key);
}

function numberValue(value: unknown, key: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new Error(`macfanctl returned invalid ${key}.`);
  }

  return value;
}

function stringField(object: Record<string, unknown>, key: string): string {
  const value = object[key];

  if (typeof value !== "string") {
    throw new Error(`macfanctl returned invalid ${key}.`);
  }

  return value;
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(Math.max(value, minimum), maximum);
}
