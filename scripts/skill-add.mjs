#!/usr/bin/env node
import { copyFile, mkdir, readdir, rm, stat } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const skillName = "ssh";

const usage = `Usage:
  npx skills add aspuru-guzik-group/ssh-skill
  skills add aspuru-guzik-group/ssh-skill
  skills add aspuru-guzik-group/ssh-skill --target ~/.agent/skills/ssh
  skill add codex
  skill add claudecode
  skill add openclaw
  skill add hermes
  skill add --target ~/.agent/skills/ssh

Options:
  --target DIR       Install directly to DIR.
  --setup-ssh       Run scripts/install_ssh_config.sh after copying.
  --help            Show this help.
`;

const args = process.argv.slice(2);

if (args.includes("--help") || args.includes("-h")) {
  process.stdout.write(usage);
  process.exit(0);
}

if (args[0] !== "add") {
  process.stderr.write(usage);
  process.exit(2);
}

let agent = null;
let repo = null;
let target = null;
let setupSsh = false;

for (let i = 1; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === "--target") {
    target = args[i + 1];
    i += 1;
  } else if (arg === "--setup-ssh") {
    setupSsh = true;
  } else if (!repo && (arg.includes("/") || arg.startsWith("git+") || arg.startsWith("github:"))) {
    repo = arg;
  } else if (!agent) {
    agent = arg;
  } else {
    process.stderr.write(`Unexpected argument: ${arg}\n\n${usage}`);
    process.exit(2);
  }
}

function expandHome(value) {
  if (!value) return value;
  if (value === "~") return homedir();
  if (value.startsWith("~/")) return join(homedir(), value.slice(2));
  return value;
}

function defaultTargetForAgent(name) {
  switch ((name || "codex").toLowerCase()) {
    case "codex":
      return join(process.env.CODEX_HOME || join(homedir(), ".codex"), "skills", skillName);
    case "claude":
    case "claudecode":
    case "claude-code":
      return join(process.env.CLAUDE_HOME || join(homedir(), ".claude"), "skills", skillName);
    case "openclaw":
      return join(homedir(), ".openclaw", "workspace", "skills", skillName);
    case "hermes":
      return join(homedir(), ".hermes", "skills", "devops", skillName);
    default:
      process.stderr.write(`Unknown agent: ${name}\nUse --target DIR for custom agents.\n\n${usage}`);
      process.exit(2);
  }
}

const destination = resolve(expandHome(target || defaultTargetForAgent(agent)));

const excluded = new Set([
  ".git",
  "node_modules",
  "package-lock.json",
  ".DS_Store"
]);

async function copyTree(src, dest) {
  const srcStat = await stat(src);
  if (srcStat.isDirectory()) {
    await mkdir(dest, { recursive: true });
    for (const entry of await readdir(src)) {
      if (excluded.has(entry)) continue;
      await copyTree(join(src, entry), join(dest, entry));
    }
    return;
  }

  if (srcStat.isFile()) {
    await mkdir(dirname(dest), { recursive: true });
    await copyFile(src, dest);
  }
}

async function main() {
  await rm(destination, { recursive: true, force: true });
  await copyTree(repoRoot, destination);

  process.stdout.write(`Installed /ssh skill to ${destination}\n`);
  process.stdout.write(`Next setup step:\n  bash ${join(destination, "scripts", "install_ssh_config.sh")}\n`);

  if (setupSsh) {
    const { spawn } = await import("node:child_process");
    await new Promise((resolvePromise, rejectPromise) => {
      const child = spawn("bash", [join(destination, "scripts", "install_ssh_config.sh")], {
        stdio: "inherit"
      });
      child.on("exit", (code) => {
        if (code === 0) resolvePromise();
        else rejectPromise(new Error(`install_ssh_config.sh exited with code ${code}`));
      });
      child.on("error", rejectPromise);
    });
  }
}

main().catch((error) => {
  process.stderr.write(`${error.message}\n`);
  process.exit(1);
});
