import * as vscode from "vscode";
import * as cp from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as readline from "readline";

let sidecarProcess: cp.ChildProcess | null = null;
let statusBarItem: vscode.StatusBarItem;
let outputChannel: vscode.OutputChannel;

type KnockPattern = "single" | "double" | "triple";

type KnockEvent = {
  type: string;
  pattern?: KnockPattern;
  count?: number;
  timestamp?: number;
  message?: string;
  mode?: string;
};

export function activate(context: vscode.ExtensionContext) {
  outputChannel = vscode.window.createOutputChannel("Knock Detector");

  statusBarItem = vscode.window.createStatusBarItem(
    vscode.StatusBarAlignment.Right,
    100,
  );
  statusBarItem.command = "knock.start";
  statusBarItem.text = "$(pulse) Knock: Off";
  statusBarItem.show();
  context.subscriptions.push(statusBarItem);

  context.subscriptions.push(
    vscode.commands.registerCommand("knock.start", startListening),
    vscode.commands.registerCommand("knock.stop", stopListening),
    vscode.commands.registerCommand("knock.testSingle", () =>
      triggerPattern("single", true),
    ),
    vscode.commands.registerCommand("knock.testDouble", () =>
      triggerPattern("double", true),
    ),
    vscode.commands.registerCommand("knock.testTriple", () =>
      triggerPattern("triple", true),
    ),
  );

  const config = vscode.workspace.getConfiguration("knock");
  if (config.get<boolean>("autoStart")) {
    startListening();
  }
}

function getSidecarPath(): string {
  const config = vscode.workspace.getConfiguration("knock");
  const custom = config.get<string>("sidecarPath");
  if (custom) {
    return custom;
  }
  const extensionDir = path.resolve(__dirname, "..", "..");
  const repoRoot = path.resolve(extensionDir, "..");
  return path.join(repoRoot, "knock-sidecar", ".build", "release", "KnockSidecar");
}

function startListening() {
  if (sidecarProcess) {
    vscode.window.showWarningMessage("Knock detector is already running.");
    return;
  }

  const binary = getSidecarPath();
  const config = vscode.workspace.getConfiguration("knock");
  const simulate = config.get<boolean>("simulateMode", true);

  const args: string[] = [];
  if (simulate) {
    args.push("--simulate");
  }

  outputChannel.appendLine(`Starting sidecar: ${binary} ${args.join(" ")}`);

  if (!fs.existsSync(binary)) {
    vscode.window.showErrorMessage(
      `Knock sidecar binary not found at ${binary}. Build it first with: cd knock-sidecar && swift build -c release`,
    );
    return;
  }

  try {
    sidecarProcess = cp.spawn(binary, args, {
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch (err) {
    vscode.window.showErrorMessage(
      `Failed to start knock sidecar: ${err}. Build it first with: cd knock-sidecar && swift build -c release`,
    );
    return;
  }

  sidecarProcess.on("error", (err) => {
    outputChannel.appendLine(`Sidecar error: ${err.message}`);
    vscode.window.showErrorMessage(
      `Knock sidecar error: ${err.message}. Make sure the binary is built.`,
    );
    cleanup();
  });

  sidecarProcess.on("exit", (code) => {
    outputChannel.appendLine(`Sidecar exited with code ${code}`);
    cleanup();
  });

  if (sidecarProcess.stderr) {
    const stderrRl = readline.createInterface({
      input: sidecarProcess.stderr,
    });
    stderrRl.on("line", (line) => {
      outputChannel.appendLine(`[sidecar stderr] ${line}`);
    });
  }

  if (sidecarProcess.stdout) {
    const rl = readline.createInterface({ input: sidecarProcess.stdout });
    rl.on("line", (line) => {
      outputChannel.appendLine(`[sidecar] ${line}`);
      try {
        const event = JSON.parse(line) as KnockEvent;
        handleEvent(event);
      } catch {
        outputChannel.appendLine(`[parse error] ${line}`);
      }
    });
  }

  statusBarItem.text = "$(pulse) Knock: Listening";
  statusBarItem.command = "knock.stop";
  vscode.window.showInformationMessage(
    `Knock detector started${simulate ? " (simulate mode)" : ""}.`,
  );
}

function handleEvent(event: KnockEvent) {
  switch (event.type) {
    case "knock_pattern":
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
  pattern: KnockPattern,
  manualTest = false,
  _event?: KnockEvent,
) {
  const config = vscode.workspace.getConfiguration("knock");
  const shouldNotify = config.get<boolean>(`${pattern}Knock.showNotification`, true);
  const command = config.get<string>(`${pattern}Knock.command`, "").trim();
  const commandArgs = config.get<unknown[]>(`${pattern}Knock.args`, []);

  outputChannel.appendLine(
    `>>> ${capitalize(pattern)} knock detected${manualTest ? " (test)" : ""}`,
  );

  if (shouldNotify) {
    const suffix = manualTest ? " (test)" : "";
    void vscode.window.showInformationMessage(
      `${capitalize(pattern)} knock detected!${suffix}`,
    );
  }

  if (!command) {
    return;
  }

  try {
    await vscode.commands.executeCommand(command, ...(commandArgs ?? []));
    outputChannel.appendLine(`Executed command for ${pattern} knock: ${command}`);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    outputChannel.appendLine(
      `Command execution failed for ${pattern} knock (${command}): ${message}`,
    );
    void vscode.window.showErrorMessage(
      `Knock action failed for ${pattern} knock: ${message}`,
    );
  }
}

function capitalize(value: string): string {
  return value.charAt(0).toUpperCase() + value.slice(1);
}

function stopListening() {
  if (!sidecarProcess) {
    vscode.window.showWarningMessage("Knock detector is not running.");
    return;
  }
  sidecarProcess.kill("SIGINT");
  cleanup();
  vscode.window.showInformationMessage("Knock detector stopped.");
}

function cleanup() {
  sidecarProcess = null;
  statusBarItem.text = "$(pulse) Knock: Off";
  statusBarItem.command = "knock.start";
}

export function deactivate() {
  if (sidecarProcess) {
    sidecarProcess.kill("SIGINT");
    sidecarProcess = null;
  }
}
