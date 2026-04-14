import * as vscode from "vscode";
import * as cp from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as readline from "readline";

let sidecarProcess: cp.ChildProcess | null = null;
let statusBarItem: vscode.StatusBarItem;
let outputChannel: vscode.OutputChannel;

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
    vscode.commands.registerCommand("knock.test", () => {
      vscode.window.showInformationMessage("Knock knock detected! (test)");
    }),
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
        const event = JSON.parse(line);
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

function handleEvent(event: { type: string; [key: string]: unknown }) {
  switch (event.type) {
    case "double_knock":
      vscode.window.showInformationMessage("Knock knock detected!");
      outputChannel.appendLine(">>> Double knock detected!");
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
