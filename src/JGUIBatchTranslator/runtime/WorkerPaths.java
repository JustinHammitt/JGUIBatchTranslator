package JGUIBatchTranslator.runtime;

//src/com/jgui/worker/WorkerPaths.java

import java.io.File;
import java.nio.file.Path;

public final class WorkerPaths {
private WorkerPaths() {}

// Where InstallWorker.cmd puts the worker on user machines:
// %LOCALAPPDATA%\GUIBatchTranslator\translator_worker\translator_worker.exe
public static File getInstallDir() {
 String lad = System.getenv("LOCALAPPDATA");
 if (lad == null || lad.isBlank()) {
   lad = System.getProperty("user.home");
 }
 return Path.of(lad, "GUIBatchTranslator", "translator_worker").toFile();
}

public static File getWorkerExe() {
 return new File(getInstallDir(), "translator_worker.exe");
}

// Optional: where your Java app ships the installer files relative to the app dir
public static File getBundledInstallerCmd() {
 // Expect these next to your Java app (adjust as needed)
 // e.g., YourApp\worker\InstallWorker.cmd
 File appDir = new File(System.getProperty("user.dir"));
 File candidate = new File(new File(appDir, "worker"), "InstallWorker.cmd");
 return candidate.exists() ? candidate : null;
}
}

