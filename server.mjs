import { createServer } from "node:http";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";

const root = process.cwd();
const inputFiles = {
  adam: path.join(root, "adam-specs.yaml"),
  dpp: path.join(root, "output-dpp.yaml"),
};
const outputDir = path.join(root, "output");

function parseScalar(value) {
  const trimmed = value.trim();
  if (trimmed === "") return "";
  if ((trimmed.startsWith('"') && trimmed.endsWith('"')) || (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
    if (trimmed.startsWith('"')) return JSON.parse(trimmed);
    return trimmed.slice(1, -1);
  }
  if (/^-?\d+(\.\d+)?$/.test(trimmed)) return Number(trimmed);
  return trimmed;
}

function indentation(line) {
  return line.match(/^ */)[0].length;
}

function parseBlock(lines, index, indent) {
  return lines[index]?.trim().startsWith("- ")
    ? parseArray(lines, index, indent)
    : parseObject(lines, index, indent);
}

function parseArray(lines, index, indent) {
  const arr = [];
  while (index < lines.length && indentation(lines[index]) === indent && lines[index].trim().startsWith("- ")) {
    const item = lines[index].trim().slice(2);
    if (item.includes(":")) {
      const obj = {};
      const colon = item.indexOf(":");
      const key = item.slice(0, colon).trim();
      const value = item.slice(colon + 1).trim();
      obj[key] = value ? parseScalar(value) : null;
      index += 1;
      while (index < lines.length && indentation(lines[index]) > indent) {
        const text = lines[index].trim();
        const childColon = text.indexOf(":");
        if (childColon < 0) break;
        const childKey = text.slice(0, childColon).trim();
        const childValue = text.slice(childColon + 1).trim();
        if (childValue) {
          obj[childKey] = parseScalar(childValue);
          index += 1;
        } else {
          const parsed = parseBlock(lines, index + 1, indentation(lines[index]) + 2);
          obj[childKey] = parsed.value;
          index = parsed.index;
        }
      }
      arr.push(obj);
    } else {
      arr.push(parseScalar(item));
      index += 1;
    }
  }
  return { value: arr, index };
}

function parseObject(lines, index, indent) {
  const obj = {};
  while (index < lines.length && indentation(lines[index]) === indent) {
    const text = lines[index].trim();
    const colon = text.indexOf(":");
    if (colon < 0) break;
    const key = text.slice(0, colon).trim();
    const value = text.slice(colon + 1).trim();
    if (value) {
      obj[key] = parseScalar(value);
      index += 1;
    } else {
      const parsed = parseBlock(lines, index + 1, indent + 2);
      obj[key] = parsed.value;
      index = parsed.index;
    }
  }
  return { value: obj, index };
}

function parseYamlSubset(source) {
  const lines = source
    .split("\n")
    .map((line) => line.replace(/\t/g, "  "))
    .filter((line) => line.trim() && !line.trim().startsWith("#"));
  return lines.length ? parseBlock(lines, 0, indentation(lines[0])).value : {};
}

function quoteYaml(value) {
  return String(value).includes(":") || String(value).includes("#") || String(value).includes('"')
    ? JSON.stringify(String(value))
    : String(value);
}

function stringifyAdamSpec(data) {
  const lines = [];
  lines.push("study:");
  lines.push(`  id: ${data.study?.id || "DEMO-STUDY"}`);
  lines.push("");
  lines.push("datasets:");
  for (const ds of data.datasets || []) {
    lines.push(`  - id: ${ds.id}`);
    lines.push(`    label: ${quoteYaml(ds.label || ds.id)}`);
    lines.push(`    template: ${ds.template || "mutate"}`);
    lines.push(`    source: ${ds.source || ds.id.toLowerCase()}`);
    if (ds.pre_steps?.length) {
      lines.push("    pre_steps:");
      for (const step of ds.pre_steps) lines.push(`      - ${quoteYaml(step)}`);
    }
    lines.push("    variables:");
    for (const v of ds.variables || []) {
      lines.push(`      - name: ${v.name}`);
      lines.push(`        status: ${v.status}`);
      lines.push(`        status_label: ${quoteYaml(v.status_label || "")}`);
      lines.push(`        spec_similarity: ${v.spec_similarity ?? 0}`);
      lines.push("        sources:");
      for (const source of v.sources || []) lines.push(`          - ${source}`);
      lines.push(`        reference_spec: ${quoteYaml(v.reference_spec || "")}`);
      lines.push(`        current_spec: ${quoteYaml(v.current_spec || "")}`);
      lines.push(`        code: ${quoteYaml(v.code || `${v.name} = ${v.name}`)}`);
    }
    lines.push("");
  }
  return `${lines.join("\n").trimEnd()}\n`;
}

async function loadState() {
  const [adamText, dppText] = await Promise.all([readFile(inputFiles.adam, "utf8"), readFile(inputFiles.dpp, "utf8")]);
  return {
    adamText,
    dppText,
    adam: parseYamlSubset(adamText),
    dpp: parseYamlSubset(dppText),
  };
}

function getAllVariables(adam) {
  return (adam.datasets || []).flatMap((ds) => (ds.variables || []).map((variable) => ({ ...variable, dataset: ds.id })));
}

function variableStatus(adam, fullName) {
  const [dataset, name] = fullName.split(".");
  const ds = (adam.datasets || []).find((candidate) => candidate.id === dataset);
  const variable = ds?.variables?.find((candidate) => candidate.name === name);
  return variable?.status || "red";
}

function outputStatus(adam, output) {
  const statuses = (output.required_variables || []).map((name) => variableStatus(adam, name));
  if (statuses.includes("red")) return "red";
  if (statuses.includes("yellow")) return "yellow";
  return "green";
}

function buildDag(adam, dpp) {
  const outputs = dpp.outputs || [];
  const nodes = [];
  const edges = [];
  const seen = new Set();
  const addNode = (id, type, status = "neutral", label = id) => {
    if (seen.has(id)) return;
    seen.add(id);
    nodes.push({ id, type, status, label });
  };

  for (const ds of adam.datasets || []) {
    addNode(ds.id, "adam_dataset", datasetStatus(ds), ds.label || ds.id);
    for (const v of ds.variables || []) {
      const variableId = `${ds.id}.${v.name}`;
      addNode(variableId, "adam_variable", v.status, v.status_label || v.name);
      edges.push({ from: variableId, to: ds.id });
      for (const source of v.sources || []) {
        addNode(source, source.startsWith("ADSL.") || source.startsWith("ADAE.") ? "adam_variable" : "source_variable");
        edges.push({ from: source, to: variableId });
      }
    }
  }

  for (const output of outputs) {
    addNode(output.id, "output", outputStatus(adam, output), output.title || output.id);
    addNode(output.dataset, "adam_dataset", datasetStatus((adam.datasets || []).find((ds) => ds.id === output.dataset) || { variables: [] }));
    edges.push({ from: output.dataset, to: output.id });
  }
  return { generated_at: new Date().toISOString(), nodes, edges };
}

function datasetStatus(ds) {
  const statuses = (ds.variables || []).map((v) => v.status);
  if (statuses.includes("red")) return "red";
  if (statuses.includes("yellow")) return "yellow";
  return "green";
}

function datasetScript(ds) {
  const snippets = (ds.variables || []).map((v) => `    ${v.code || `${v.name} = ${v.name}`}`).join(",\n");
  if (ds.template === "transmute") {
    return `library(dplyr)\n\n${ds.id.toLowerCase()} <- ${ds.source || ds.id.toLowerCase()} |>\n  transmute(\n${snippets}\n  )\n`;
  }
  const preSteps = (ds.pre_steps || []).map((step) => `  ${step} |>`).join("\n");
  return `library(dplyr)\n\n${ds.id.toLowerCase()} <- ${ds.source || ds.id.toLowerCase()} |>\n${preSteps ? `${preSteps}\n` : ""}  mutate(\n${snippets}\n  ) |>\n  select(${(ds.variables || []).map((v) => v.name).join(", ")})\n`;
}

function outputScript(output) {
  const filters = (output.filters || []).map((filter) => `  filter(${filter}) |>`).join("\n");
  const groupBy = (output.group_by || ["TRT01P"]).join(", ");
  const objectName = String(output.id || "output").toLowerCase().replace(/[^a-z0-9]+/g, "_");
  return `library(dplyr)\n\n${objectName} <- ${String(output.dataset || "adam").toLowerCase()} |>\n  filter(${output.population || "TRUE"}) |>\n${filters ? `${filters}\n` : ""}  group_by(${groupBy}) |>\n  summarise(n = n_distinct(USUBJID), .groups = "drop")\n`;
}

async function generateArtifacts() {
  const state = await loadState();
  await mkdir(path.join(outputDir, "adam"), { recursive: true });
  await mkdir(path.join(outputDir, "output"), { recursive: true });
  const dag = buildDag(state.adam, state.dpp);
  await writeFile(path.join(outputDir, "dag.json"), `${JSON.stringify(dag, null, 2)}\n`);
  for (const ds of state.adam.datasets || []) {
    await writeFile(path.join(outputDir, "adam", `${ds.id.toLowerCase()}.R`), datasetScript(ds));
  }
  for (const output of state.dpp.outputs || []) {
    await writeFile(path.join(outputDir, "output", `${output.id.replaceAll(".", "_")}.R`), outputScript(output));
  }
  return { ...state, dag };
}

async function readJson(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  return JSON.parse(Buffer.concat(chunks).toString("utf8") || "{}");
}

function send(res, status, body, type = "application/json") {
  res.writeHead(status, { "content-type": type });
  res.end(type === "application/json" ? JSON.stringify(body) : body);
}

const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url, "http://localhost");
    if (req.method === "GET" && url.pathname === "/") {
      return send(res, 200, await readFile(path.join(root, "output-lab.html"), "utf8"), "text/html; charset=utf-8");
    }
    if (req.method === "GET" && url.pathname === "/dag-test.html") {
      const html = await readFile(path.join(root, "dag-test.html"), "utf8");
      const payload = JSON.stringify(JSON.stringify(await generateArtifacts()).replaceAll("<", "\\u003c"));
      return send(res, 200, html.replace('"__DAG_TEST_STATE_JSON__"', payload), "text/html; charset=utf-8");
    }
    if (req.method === "GET" && url.pathname === "/focus-dag-test.html") {
      const html = await readFile(path.join(root, "focus-dag-test.html"), "utf8");
      const payload = JSON.stringify(JSON.stringify(await generateArtifacts()).replaceAll("<", "\\u003c"));
      return send(res, 200, html.replace('"__FOCUS_DAG_STATE_JSON__"', payload), "text/html; charset=utf-8");
    }
    if (req.method === "GET" && url.pathname === "/api/state") {
      return send(res, 200, await generateArtifacts());
    }
    if (req.method === "POST" && url.pathname === "/api/save-dpp") {
      const body = await readJson(req);
      await writeFile(inputFiles.dpp, body.dppText);
      return send(res, 200, await generateArtifacts());
    }
    if (req.method === "POST" && url.pathname === "/api/save-variable-code") {
      const body = await readJson(req);
      const state = await loadState();
      const ds = (state.adam.datasets || []).find((candidate) => candidate.id === body.dataset);
      const variable = ds?.variables?.find((candidate) => candidate.name === body.variable);
      if (!variable) return send(res, 404, { error: "Variable not found" });
      variable.code = body.code;
      if (body.approve) {
        variable.status = "green";
        variable.status_label = "Reviewed";
        variable.spec_similarity = 100;
      }
      await writeFile(inputFiles.adam, stringifyAdamSpec(state.adam));
      return send(res, 200, await generateArtifacts());
    }
    if (req.method === "GET" && url.pathname.startsWith("/output/")) {
      const file = path.join(root, url.pathname.slice(1));
      if (!file.startsWith(outputDir) || !existsSync(file)) return send(res, 404, "Not found", "text/plain");
      return send(res, 200, await readFile(file, "utf8"), "text/plain; charset=utf-8");
    }
    return send(res, 404, { error: "Not found" });
  } catch (error) {
    return send(res, 500, { error: error.message });
  }
});

const port = Number(process.env.PORT || 4173);
await generateArtifacts();
server.listen(port, () => {
  console.log(`Clinical AI mockup running at http://localhost:${port}`);
  console.log(`Generated artifacts in ${outputDir}`);
});
