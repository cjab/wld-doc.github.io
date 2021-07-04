import YAML from "yaml";
import { readFileSync, writeFileSync } from "fs";

function doc(yaml) {
  const seq = yaml.seq;
  const rootType = yaml;
  return [
    h(yaml.meta.title, 1),
    "",
    h("Overview", 2),
    ...typeDefinition(rootType, 1),
    ""
  ];
}

function h(content, level = 1) {
  return `${"#".repeat(level)} ${content}`;
}

function typesSection(types, level) {
  return [
    h("Types", level),
    "",
    ...Object.keys(types).flatMap(typeName => {
      const params = (types[typeName].params || []).map(p => p.id).join(", ");
      const paramString = params.length > 0 ? `(${params})` : "";
      const title = `${typeName}${paramString}`;
      return [
        h(title, level + 1),
        ...typeDefinition(types[typeName], level + 1),
        ""
      ];
    })
  ];
}

function typeDefinition(def, level) {
  const doc = def.doc || "";
  const subTypes = def.types ? typesSection(def.types, level + 1) : [""];

  return [doc, "", ...table(def.seq || []), "", ...subTypes];
}

function table(seq) {
  if (seq.length === 0) {
    return [];
  }
  return ["| name | type | doc |", "|------|------|-----|", ...seq.map(row)];
}

function row(seq) {
  const id = seq.id;
  const doc = (seq.doc || "").replace(/\n/g, "<br />");

  return `| ${id} | ${typeCell(seq.type, seq.contents)} | ${doc} |`;
}

function typeCell(type, contents) {
  if (typeof type === "object") {
    return Object.keys(type.cases)
      .map(c => typeLink(type.cases[c]))
      .join("<br /> &#124; ");
  } else {
    const hexContents =
      contents && contents.map(c => `0x${c.toString(16)}`).join(" ");
    return type ? typeLink(type) : hexContents || "";
  }
}

function typeLink(type) {
  if (isPrimitiveType(type)) {
    return type;
  } else {
    const link = type && type.replace(/\(.*\)/g, "");
    return `[${type}](#${link})`;
  }
}

function isPrimitiveType(typeName) {
  return !!typeName.match(/^([usbf]\d+)|str(z)?$/);
}

const file = readFileSync(`static/files/sony_wld.ksy`, "utf8");
const result = doc(YAML.parse(file)).join("\n");

console.log(result);
