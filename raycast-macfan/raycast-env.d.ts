/// <reference types="@raycast/api">

/* 🚧 🚧 🚧
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 * 🚧 🚧 🚧 */

/* eslint-disable @typescript-eslint/ban-types */

type ExtensionPreferences = {
  /** macfanctl Helper Path - Path to the installed privileged macfanctl helper. */
  "helperPath": string
}

/** Preferences accessible in all the extension's commands */
declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Preferences accessible in the `control-fans` command */
  export type ControlFans = ExtensionPreferences & {}
  /** Preferences accessible in the `auto-fan` command */
  export type AutoFan = ExtensionPreferences & {}
  /** Preferences accessible in the `max-fan` command */
  export type MaxFan = ExtensionPreferences & {}
}

declare namespace Arguments {
  /** Arguments passed to the `control-fans` command */
  export type ControlFans = {}
  /** Arguments passed to the `auto-fan` command */
  export type AutoFan = {}
  /** Arguments passed to the `max-fan` command */
  export type MaxFan = {}
}

