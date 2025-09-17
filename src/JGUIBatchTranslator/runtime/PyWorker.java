package JGUIBatchTranslator.runtime;

//src/com/jgui/worker/PyWorker.java

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.Objects;
import java.util.concurrent.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class PyWorker implements Closeable {

private final Process proc;
private final BufferedWriter toPy;
private final BufferedReader fromPy;
private final Object lock = new Object(); // serialize requests (JSONL, one-at-a-time)
private static final Pattern TEXT_FIELD = Pattern.compile("\\\"text\\\"\\s*:\\s*\\\"((?:\\\\.|[^\\\\\\\"])*)\\\"");

public PyWorker() throws IOException {
 File exe = WorkerPaths.getWorkerExe();
 if (!exe.isFile()) {
   throw new FileNotFoundException("translator_worker.exe not found at: " + exe);
 }
 ProcessBuilder pb = new ProcessBuilder(exe.getAbsolutePath());
 pb.directory(exe.getParentFile());         // so "Models" resolves beside the exe
 pb.redirectErrorStream(true);              // merge stderr into stdout for easier logs
 this.proc = pb.start();
 this.toPy = new BufferedWriter(new OutputStreamWriter(proc.getOutputStream(), StandardCharsets.UTF_8));
 this.fromPy = new BufferedReader(new InputStreamReader(proc.getInputStream(), StandardCharsets.UTF_8));
}

public boolean ping(long timeoutMs) throws Exception {
 String req = "{\"op\":\"ping\"}\n";
 String resp = roundTrip(req, timeoutMs);
 return resp.contains("\"ok\":true");
}

public String translate(String src, String tgt, String text, long timeoutMs) throws Exception {
	  Objects.requireNonNull(src);
	  Objects.requireNonNull(tgt);
	  Objects.requireNonNull(text);
	  String req = "{\"op\":\"translate\",\"src\":\"" + esc(src) + "\",\"tgt\":\"" + esc(tgt) + "\",\"text\":\"" + esc(text) + "\"}\n";
	  String resp = roundTrip(req, timeoutMs);
	  String val = extractText(resp);
	  if (val == null) throw new IOException("Worker error/parse failure: " + resp);
	  return unesc(val);
	}

	private static String extractText(String jsonLine) {
	  Matcher m = TEXT_FIELD.matcher(jsonLine);
	  if (m.find()) return m.group(1);  // still escaped; unesc() will handle it
	  return null;
	}

private String roundTrip(String request, long timeoutMs) throws Exception {
 synchronized (lock) {
   toPy.write(request);
   toPy.flush();
   return readLineWithTimeout(timeoutMs);
 }
}

private String readLineWithTimeout(long timeoutMs) throws Exception {
 ExecutorService es = Executors.newSingleThreadExecutor(r -> {
   Thread t = new Thread(r, "pyworker-read");
   t.setDaemon(true);
   return t;
 });
 try {
   Future<String> f = es.submit(fromPy::readLine);
   String line = f.get(timeoutMs, TimeUnit.MILLISECONDS);
   if (line == null) throw new EOFException("Worker closed");
   return line;
 } catch (TimeoutException te) {
   proc.destroy();
   throw new IOException("Worker timed out", te);
 } finally {
   es.shutdownNow();
 }
}

private static String esc(String s) {
 return s.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r");
}
private static String unesc(String s) {
 return s.replace("\\n","\n").replace("\\r","\r").replace("\\\"","\"").replace("\\\\","\\");
}

@Override public void close() {
 try { toPy.close(); } catch (IOException ignore) {}
 try { fromPy.close(); } catch (IOException ignore) {}
 proc.destroy();
}
}

