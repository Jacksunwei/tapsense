import * as vscode from "vscode";
import * as cp from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as readline from "readline";

let sidecarProcess: cp.ChildProcess | null = null;
let statusBarItem: vscode.StatusBarItem;
let outputChannel: vscode.OutputChannel;

type TapPattern = "single" | "double" | "triple";
type TapMode = "palmRest" | "desk";
type TapSensitivity = "low" | "medium" | "high";

type TapEvent = {
  type: string;
  pattern?: TapPattern;
  count?: number;
  timestamp?: number;
  message?: string;
  mode?: string;
  profile?: string;
  sensitivity?: string;
};

type SidecarLaunchOptions = {
  simulate: boolean;
  mode: TapMode;
  sensitivity: TapSensitivity;
};

export function activate(context: vscode.ExtensionContext) {
  outputChannel = vscode.window.createOutputChannel("TapSense");

  statusBarItem = vscode.window.createStatusBarItem(
    vscode.StatusBarAlignment.Right,
    100,
  );
  statusBarItem.command = "tapsense.start";
  statusBarItem.text = "$(pulse) TapSense: Off";
  statusBarItem.show();
  context.subscriptions.push(statusBarItem);

  context.subscriptions.push(
    vscode.commands.registerCommand("tapsense.start", startListening),
    vscode.commands.registerCommand("tapsense.stop", stopListening),
    vscode.commands.registerCommand("tapsense.testSingle", () =>
      triggerPattern("single", true),
    ),
    vscode.commands.registerCommand("tapsense.testDouble", () =>
      triggerPattern("double", true),
    ),
    vscode.commands.registerCommand("tapsense.testTriple", () =>
      triggerPattern("triple", true),
    ),
  );

  const config = vscode.workspace.getConfiguration("tapsense");
  if (config.get<boolean>("autoStart")) {
    startListening();
  }
}

function getSidecarPath(): string {
  const config = vscode.workspace.getConfiguration("tapsense");
  const custom = config.get<string>("sidecarPath");
  if (custom) {
    return custom;
  }
  const extensionDir = path.resolve(__dirname, "..", "..");
  const repoRoot = path.resolve(extensionDir, "..");
  return path.join(repoRoot, "tapsense-daemon", ".build", "release", "TapSenseDaemon");
}

function startListening() {
  if (sidecarProcess) {
    vscode.window.showWarningMessage("TapSense detector is already running.");
    return;
  }

  const binary = getSidecarPath();
  const launchOptions = getSidecarLaunchOptions();

  const args: string[] = [
    "--mode",
    launchOptions.mode,
    "--sensitivity",
    launchOptions.sensitivity,
  ];
  if (launchOptions.simulate) {
    args.push("--simulate");
  }

  outputChannel.appendLine(`Starting sidecar: ${binary} ${args.join(" ")}`);

  if (!fs.existsSync(binary)) {
    vscode.window.showErrorMessage(
      `TapSense daemon binary not found at ${binary}. Build it first with: cd tapsense-daemon && swift build -c release`,
    );
    return;
  }

  try {
    const spawned = cp.spawn(binary, args, {
      stdio: ["ignore", "pipe", "pipe"],
    });
    sidecarProcess = spawned;
  } catch (err) {
    vscode.window.showErrorMessage(
      `Failed to start TapSense daemon: ${err}. Build it first with: cd tapsense-daemon && swift build -c release`,
    );
    return;
  }

  const processForHandlers = sidecarProcess;

  processForHandlers.on("error", (err) => {
    outputChannel.appendLine(`Sidecar error: ${err.message}`);
    vscode.window.showErrorMessage(
      `TapSense sidecar error: ${err.message}. Make sure the binary is built.`,
    );
    cleanup(processForHandlers);
  });

  processForHandlers.on("exit", (code, signal) => {
    outputChannel.appendLine(`Sidecar exited with code ${code}`);
    if (signal) {
      outputChannel.appendLine(`Sidecar exit signal: ${signal}`);
    }
    cleanup(processForHandlers);
  });

  if (processForHandlers.stderr) {
    const stderrRl = readline.createInterface({
      input: processForHandlers.stderr,
    });
    stderrRl.on("line", (line) => {
      outputChannel.appendLine(`[sidecar stderr] ${line}`);
    });
  }

  if (processForHandlers.stdout) {
    const rl = readline.createInterface({ input: processForHandlers.stdout });
    rl.on("line", (line) => {
      outputChannel.appendLine(`[sidecar] ${line}`);
      try {
        const event = JSON.parse(line) as TapEvent;
        handleEvent(event);
      } catch {
        outputChannel.appendLine(`[parse error] ${line}`);
      }
    });
  }

  statusBarItem.text = "$(pulse) TapSense: Listening";
  statusBarItem.command = "tapsense.stop";
  vscode.window.showInformationMessage(
    `TapSense detector started${launchOptions.simulate ? " (simulate mode)" : ""}.`,
  );
}

function getSidecarLaunchOptions(): SidecarLaunchOptions {
  const config = vscode.workspace.getConfiguration("tapsense");
  return {
    simulate: config.get<boolean>("simulateMode", true),
    mode: getEnumConfig<TapMode>("mode", "palmRest", ["palmRest", "desk"]),
    sensitivity: getEnumConfig<TapSensitivity>("sensitivity", "medium", [
      "low",
      "medium",
      "high",
    ]),
  };
}

function getEnumConfig<T extends string>(
  key: string,
  fallback: T,
  allowed: readonly T[],
): T {
  const value = vscode.workspace.getConfiguration("tapsense").get<string>(key);
  if (value && allowed.includes(value as T)) {
    return value as T;
  }
  return fallback;
}

function handleEvent(event: TapEvent) {
  switch (event.type) {
    case "tap_pattern":
      if (event.pattern) {
        void triggerPattern(event.pattern, false, event);
      }
      break;
    case "started":
      outputChannel.appendLine(
        `Sidecar started in ${event.mode ?? "unknown"} mode`,
      );
      break;
    case "error":
      vscode.window.showErrorMessage(`Sidecar: ${event.message}`);
      break;
    case "stopped":
      outputChannel.appendLine("Sidecar stopped gracefully.");
      break;
  }
}

async function triggerPattern(
  pattern: TapPattern,
  manualTest = false,
  _event?: TapEvent,
) {
  const config = vscode.workspace.getConfiguration("tapsense");
  const shouldNotify = config.get<boolean>(`${pattern}Tap.showNotification`, true);
  const command = config.get<string>(`${pattern}Tap.command`, "").trim();
  const commandArgs = config.get<unknown[]>(`${pattern}Tap.args`, []);

  outputChannel.appendLine(
    `>>> ${capitalize(pattern)} tap detected${manualTest ? " (test)" : ""}`,
  );

  if (shouldNotify) {
    const suffix = manualTest ? " (test)" : "";
    void vscode.window.showInformationMessage(
      `${capitalize(pattern)} tap detected!${suffix}`,
    );
  }

  if (!command) {
    return;
  }

  try {
    await vscode.commands.executeCommand(command, ...(commandArgs ?? []));
    outputChannel.appendLine(`Executed command for ${pattern} tap: ${command}`);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    outputChannel.appendLine(
      `Command execution failed for ${pattern} tap (${command}): ${message}`,
    );
    void vscode.window.showErrorMessage(
      `TapSense action failed for ${pattern} tap: ${message}`,
    );
  }
}

function capitalize(value: string): string {
  return value.charAt(0).toUpperCase() + value.slice(1);
}

function stopListening() {
  if (!sidecarProcess) {
    vscode.window.showWarningMessage("TapSense detector is not running.");
    return;
  }
  sidecarProcess.kill("SIGINT");
  cleanup();
  vscode.window.showInformationMessage("TapSense detector stopped.");
}

function cleanup(expectedProcess?: cp.ChildProcess) {
  if (expectedProcess && sidecarProcess !== expectedProcess) {
    return;
  }
  sidecarProcess = null;
  statusBarItem.text = "$(pulse) TapSense: Off";
  statusBarItem.command = "tapsense.start";
}

export function deactivate() {
  if (sidecarProcess) {
    sidecarProcess.kill("SIGINT");
    sidecarProcess = null;
  }
}
