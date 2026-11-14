import { readFile, stat } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { createHash } from "node:crypto";

const root = path.dirname(fileURLToPath(import.meta.url));
const output = path.join(root, "dist");
const html = await readFile(path.join(output, "index.html"), "utf8");
const css = await readFile(path.join(output, "styles.css"), "utf8");
const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map((match) => match[1]);
if (new Set(ids).size !== ids.length) throw new Error("Duplicate HTML IDs.");
if ((html.match(/<h1\b/g) ?? []).length !== 1) throw new Error("One primary heading is required.");
if (!html.includes('<html lang="ko">')) throw new Error("Korean document language missing.");
if (!html.includes('href="https://baram.sionyuel.com/"')) throw new Error("Canonical URL missing.");
if (!html.includes('content="noindex, nofollow"')) throw new Error("Development robots metadata missing.");
if (/<a\b[^>]*\bdownload\b|href="[^"]+\.(?:zip|pkg|dmg)"/i.test(html)) throw new Error("Public binary download present.");
for (const match of html.matchAll(/(?:src|href)="([^"#][^"]*)"/g)) {
  if (/^(?:https?:|mailto:)/.test(match[1])) continue;
  await stat(path.join(output, match[1]));
}
for (const match of html.matchAll(/href="#([^"]+)"/g)) {
  if (!ids.includes(match[1])) throw new Error(`Missing anchor ${match[1]}`);
}
for (const match of css.matchAll(/url\("?([^\)"]+)/g)) {
  if (!/^data:/.test(match[1])) await stat(path.join(output, match[1]));
}
for (const asset of JSON.parse(await readFile(path.join(output, "asset-provenance.json"), "utf8"))) {
  const content = await readFile(path.join(output, asset.file));
  const actual = createHash("sha256").update(content).digest("hex");
  if (actual !== asset.sha256) throw new Error(`Asset checksum differs: ${asset.file}`);
}
if (!css.includes("prefers-reduced-motion") || !css.includes(":focus-visible")) throw new Error("Motion/focus accessibility rules missing.");
console.log("Baram static preview verified: anchors, assets, provenance, no public download, robots, focus and reduced motion.");
