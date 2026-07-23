#!/usr/bin/env node

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const https = require("node:https");
const { spawnSync } = require("node:child_process");
const packageJson = require("../../package.json");

const appPath = path.join(os.homedir(), "Applications", "Codex Pulse.app");

function fail(message) {
  console.error(`codex-pulse: ${message}`);
  process.exit(1);
}

function run(command, args) {
  const result = spawnSync(command, args, { stdio: "inherit" });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} exited with status ${result.status}`);
}

function download(url, destination, redirects = 0) {
  if (redirects > 8) return Promise.reject(new Error("too many download redirects"));
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { "User-Agent": `codex-pulse/${packageJson.version}` } }, (response) => {
      if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
        response.resume();
        download(new URL(response.headers.location, url).toString(), destination, redirects + 1).then(resolve, reject);
        return;
      }
      if (response.statusCode !== 200) {
        response.resume();
        reject(new Error(`download failed with HTTP ${response.statusCode}`));
        return;
      }
      const output = fs.createWriteStream(destination, { mode: 0o600 });
      response.pipe(output);
      output.on("finish", () => output.close(resolve));
      output.on("error", reject);
    }).on("error", reject);
  });
}

async function install(force) {
  if (process.platform !== "darwin") throw new Error("Codex Pulse supports macOS only");
  const releaseArch = process.arch === "arm64" ? "arm64" : process.arch === "x64" ? "x86_64" : null;
  if (!releaseArch) throw new Error(`unsupported architecture: ${process.arch}`);
  if (fs.existsSync(appPath) && !force) {
    throw new Error(`${appPath} already exists; pass --force to replace it`);
  }

  const workDir = fs.mkdtempSync(path.join(os.tmpdir(), "codex-pulse-"));
  const dmgPath = path.join(workDir, "Codex-Pulse.dmg");
  const mountPath = path.join(workDir, "mount");
  const releaseUrl = `https://github.com/iwecon/CodexPulse/releases/latest/download/Codex-Pulse-${releaseArch}.dmg`;

  try {
    fs.mkdirSync(mountPath);
    console.log(`Downloading Codex Pulse ${packageJson.version} for ${releaseArch}…`);
    await download(releaseUrl, dmgPath);
    run("hdiutil", ["attach", dmgPath, "-nobrowse", "-readonly", "-mountpoint", mountPath]);
    const mountedApp = path.join(mountPath, "Codex Pulse.app");
    if (!fs.existsSync(mountedApp)) throw new Error("downloaded image does not contain Codex Pulse.app");
    fs.mkdirSync(path.dirname(appPath), { recursive: true });
    if (fs.existsSync(appPath)) fs.rmSync(appPath, { recursive: true });
    run("ditto", [mountedApp, appPath]);
    console.log(`Installed ${appPath}`);
  } finally {
    if (fs.existsSync(mountPath)) {
      spawnSync("hdiutil", ["detach", mountPath], { stdio: "ignore" });
    }
    fs.rmSync(workDir, { recursive: true, force: true });
  }
}

function printHelp() {
  console.log(`Codex Pulse ${packageJson.version}

Usage:
  codex-pulse install [--force]  Install the matching app in ~/Applications
  codex-pulse open               Open the installed app
  codex-pulse --version          Print the package version
  codex-pulse --help             Show this help`);
}

async function main() {
  const [command, ...args] = process.argv.slice(2);
  if (command === "install") {
    await install(args.includes("--force"));
  } else if (command === "open") {
    if (!fs.existsSync(appPath)) throw new Error(`app not found at ${appPath}; run codex-pulse install first`);
    run("open", [appPath]);
  } else if (command === "--version" || command === "-v") {
    console.log(packageJson.version);
  } else if (!command || command === "--help" || command === "-h" || command === "help") {
    printHelp();
  } else {
    throw new Error(`unknown command: ${command}`);
  }
}

main().catch((error) => fail(error.message));
