package JGUIBatchTranslator.runtime;

//src/com/jgui/worker/WorkerInstaller.java

import java.io.File;
import java.io.IOException;

public final class WorkerInstaller {
private WorkerInstaller() {}

public static boolean ensureInstalled() {
 File exe = WorkerPaths.getWorkerExe();
 if (exe.isFile()) return true;

 File installer = WorkerPaths.getBundledInstallerCmd();
 if (installer == null) {
   System.err.println("[WorkerInstaller] Missing InstallWorker.cmd near app.");
   return false;
 }

 try {
   System.out.println("[WorkerInstaller] Running installer: " + installer);
   ProcessBuilder pb = new ProcessBuilder("cmd.exe", "/c", installer.getAbsolutePath());
   pb.directory(installer.getParentFile());
   pb.inheritIO(); // show progress in console (or remove if you want it quiet)
   Process p = pb.start();
   int code = p.waitFor();
   if (code != 0) {
     System.err.println("[WorkerInstaller] Installer exited with " + code);
     return false;
   }
   return WorkerPaths.getWorkerExe().isFile();
 } catch (IOException | InterruptedException e) {
   e.printStackTrace();
   return false;
 }
}
}

