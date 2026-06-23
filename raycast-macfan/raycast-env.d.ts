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
  /** Preferences accessible in the `all-auto` command */
  export type AllAuto = ExtensionPreferences & {}
  /** Preferences accessible in the `all-max` command */
  export type AllMax = ExtensionPreferences & {}
}

declare namespace Arguments {
  /** Arguments passed to the `control-fans` command */
  export type ControlFans = {}
  /** Arguments passed to the `all-auto` command */
  export type AllAuto = {}
  /** Arguments passed to the `all-max` command */
  export type AllMax = {}
}

