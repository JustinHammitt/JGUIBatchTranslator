import sys, json, os, traceback
import argostranslate.package as pkg
import argostranslate.translate as tr

def setup_models():
    base = os.path.dirname(sys.executable if getattr(sys, 'frozen', False) else __file__)
    models = os.path.join(base, "Models")
    os.environ["ARGOS_PACKAGES_DIR"] = models
    # ensure installed packages are visible
    _ = pkg.get_installed_packages()

def translate(src, tgt, text):
    pair = tr.get_translation_from_codes(src, tgt)
    return pair.translate(text)

def main():
    setup_models()
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
            op = req.get("op")
            if op == "translate":
                out = translate(req["src"], req["tgt"], req["text"])
                resp = {"ok": True, "text": out}
            elif op == "ping":
                resp = {"ok": True, "pong": True}
            else:
                resp = {"ok": False, "error": f"unknown op {op}"}
        except Exception as e:
            resp = {"ok": False, "error": str(e), "trace": traceback.format_exc(limit=1)}
        sys.stdout.write(json.dumps(resp, ensure_ascii=False) + "\n")
        sys.stdout.flush()

if __name__ == "__main__":
    main()
