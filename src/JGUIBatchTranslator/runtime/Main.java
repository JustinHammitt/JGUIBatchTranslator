package JGUIBatchTranslator.runtime;

import javax.swing.*;

import JGUIBatchTranslator.runtime.PyWorker;
import JGUIBatchTranslator.runtime.WorkerInstaller;

import java.awt.*;
import java.util.concurrent.CompletableFuture;

public final class Main {

public static void main(String[] args) {
 SwingUtilities.invokeLater(Main::createAndShow);
}

private static void createAndShow() {
 JFrame f = new JFrame("JGUIBatchTranslator (Java UI + Python worker)");
 f.setDefaultCloseOperation(WindowConstants.EXIT_ON_CLOSE);
 f.setSize(800, 520);

 JTextField src = new JTextField("en", 4);
 JTextField tgt = new JTextField("es", 4);
 JTextArea in = new JTextArea(8, 60);
 JTextArea out = new JTextArea(8, 60);
 out.setEditable(false);

 JButton btnPing = new JButton("Ping Worker");
 JButton btnTranslate = new JButton("Translate");
 JLabel status = new JLabel("Ready");

 JPanel top = new JPanel(new FlowLayout(FlowLayout.LEFT));
 top.add(new JLabel("From:")); top.add(src);
 top.add(new JLabel("To:"));   top.add(tgt);
 top.add(btnPing); top.add(btnTranslate);

 JScrollPane spIn = new JScrollPane(in);
 spIn.setBorder(BorderFactory.createTitledBorder("Input"));
 JScrollPane spOut = new JScrollPane(out);
 spOut.setBorder(BorderFactory.createTitledBorder("Output"));

 JPanel center = new JPanel(new GridLayout(2,1,6,6));
 center.add(spIn);
 center.add(spOut);

 f.getContentPane().setLayout(new BorderLayout(6,6));
 f.add(top, BorderLayout.NORTH);
 f.add(center, BorderLayout.CENTER);
 f.add(status, BorderLayout.SOUTH);

 // Ensure worker installed (runs InstallWorker.cmd once if needed)
 boolean ok = WorkerInstaller.ensureInstalled();
 if (!ok) {
   status.setText("Worker not installed. Place InstallWorker.cmd near app and restart.");
   f.setVisible(true);
   return;
 }

 // Hold one worker for the app lifetime
 final PyWorker[] holder = new PyWorker[1];
 try {
   holder[0] = new PyWorker();
   status.setText("Worker started.");
 } catch (Exception e) {
   status.setText("Failed to start worker: " + e.getMessage());
   f.setVisible(true);
   return;
 }

 btnPing.addActionListener(ev -> {
   status.setText("Pinging…");
   CompletableFuture.runAsync(() -> {
     try {
       boolean pong = holder[0].ping(5000);
       SwingUtilities.invokeLater(() -> status.setText("Ping: " + (pong ? "OK" : "Fail")));
     } catch (Exception ex) {
       SwingUtilities.invokeLater(() -> status.setText("Ping error: " + ex.getMessage()));
     }
   });
 });

 btnTranslate.addActionListener(ev -> {
   String s = src.getText().trim();
   String t = tgt.getText().trim();
   String txt = in.getText();
   status.setText("Translating…");
   out.setText("");
   CompletableFuture.runAsync(() -> {
     try {
       String translated = holder[0].translate(s, t, txt, 120_000);
       SwingUtilities.invokeLater(() -> {
         out.setText(translated);
         status.setText("Done.");
       });
     } catch (Exception ex) {
       SwingUtilities.invokeLater(() -> status.setText("Error: " + ex.getMessage()));
     }
   });
 });

 // Clean shutdown
 f.addWindowListener(new java.awt.event.WindowAdapter() {
   @Override public void windowClosing(java.awt.event.WindowEvent e) {
     try { if (holder[0] != null) holder[0].close(); } catch (Exception ignore) {}
   }
 });

 f.setLocationRelativeTo(null);
 f.setVisible(true);
}
}

