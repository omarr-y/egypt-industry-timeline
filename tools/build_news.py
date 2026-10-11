"""Builds news.json from the artifact database export.

Usage: python3 -I tools/build_news.py <folder with one JSON file per record> <output news.json>
The folder is what ArtifactData 'list' writes with out_dir (…/news/<doc_id>.json).
Refuses to write if any record is missing a required field."""
import json, glob, os, sys
src, out = sys.argv[1], sys.argv[2]
items = []
for f in glob.glob(os.path.join(src, "*.json")):
    d = json.load(open(f))
    doc = d.get("data", d)                       # tolerate {"id","version","data":{...}} or a flat doc
    did = d.get("id") or os.path.basename(f)[:-5]
    items.append({"id": did, "date": doc.get("date"), "title": doc.get("title"), "summary": doc.get("summary"),
                  "figure": doc.get("figure") or "", "category": doc.get("category"),
                  "sectors": doc.get("sectors") or [], "source": doc.get("source"), "url": doc.get("url"),
                  "addedAt": doc.get("addedAt")})
bad = [i["id"] for i in items if not all(i[k] for k in ("date", "title", "summary", "category", "source", "url"))]
assert not bad, f"incomplete items: {bad}"
items.sort(key=lambda i: (i["date"], i["id"]), reverse=True)
json.dump({"updated": __import__("datetime").date.today().isoformat(), "count": len(items), "items": items}, open(out, "w"), ensure_ascii=False, indent=1)
print(len(items), "items; newest:"); [print(" ", i["date"], i["title"]) for i in items[:4]]
