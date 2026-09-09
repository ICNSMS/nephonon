const WORKFLOW_PLOTS = "plots";
const WORKFLOW_FORCE_CONSTANTS = "force_constants";

const sourceMode = document.getElementById("sourceMode");
const exampleWrap = document.getElementById("exampleWrap");
const uploadWrap = document.getElementById("uploadWrap");
const plotControlDrop = document.getElementById("plotControlDrop");
const forceControlDrop = document.getElementById("forceControlDrop");
const plotImportControls = document.getElementById("plotImportControls");
const forceConstantImportControls = document.getElementById("forceConstantImportControls");
const importTitle = document.getElementById("importTitle");
const inputSummary = document.getElementById("inputSummary");
const renderOption = document.getElementById("renderOption");
const cmapSelect = document.getElementById("cmapSelect");
const forceOutputOption = document.getElementById("forceOutputOption");
const runButton = document.getElementById("runButton");
const agentSendButton = document.getElementById("agentSendButton");
const agentConversation = document.getElementById("agentConversation");
const consoleLog = document.getElementById("consoleLog");
const imageGrid = document.getElementById("imageGrid");
const fileList = document.getElementById("fileList");
const statusText = document.getElementById("statusText");
const serverStatus = document.getElementById("serverStatus");
const jobStatus = document.getElementById("jobStatus");
const agentMessage = document.getElementById("agentMessage");
const compoundName = document.getElementById("compoundName");
const intentBox = document.getElementById("intentBox");
const intentHint = document.getElementById("intentHint");

const controlEditor = document.getElementById("controlEditor");
const controlSourceLabel = document.getElementById("controlSourceLabel");
const plotSwitches = document.getElementById("plotSwitches");
const plotParameterGrid = document.getElementById("plotParameterGrid");
const bandsBuilderWrap = document.getElementById("bandsBuilderWrap");
const lphaseWrap = document.getElementById("lphaseWrap");
const cifStatus = document.getElementById("cifStatus");

const styleTarget = document.getElementById("styleTarget");
const styleXlabel = document.getElementById("styleXlabel");
const styleYlabel = document.getElementById("styleYlabel");
const styleTitle = document.getElementById("styleTitle");
const styleFontFamily = document.getElementById("styleFontFamily");
const styleFontSize = document.getElementById("styleFontSize");
const styleFontColor = document.getElementById("styleFontColor");
const styleBold = document.getElementById("styleBold");
const styleItalic = document.getElementById("styleItalic");
const styleXmin = document.getElementById("styleXmin");
const styleXmax = document.getElementById("styleXmax");
const styleYmin = document.getElementById("styleYmin");
const styleYmax = document.getElementById("styleYmax");
const styleQStart = document.getElementById("styleQStart");
const styleQEnd = document.getElementById("styleQEnd");
const styleCmap = document.getElementById("styleCmap");
const styleScale = document.getElementById("styleScale");
const styleCmin = document.getElementById("styleCmin");
const styleCmax = document.getElementById("styleCmax");
const styleGamma = document.getElementById("styleGamma");
const styleLineWidth = document.getElementById("styleLineWidth");
const styleApply = document.getElementById("styleApply");
const styleSave = document.getElementById("styleSave");
const stylePanel = document.getElementById("stylePanel");
const styleModal = document.getElementById("styleModal");
const styleModalBody = document.getElementById("styleModalBody");
const styleModalClose = document.getElementById("styleModalClose");

let activeWorkflow = WORKFLOW_PLOTS;
let lastResult = null;

const cifStructures = {
  [WORKFLOW_PLOTS]: null,
  [WORKFLOW_FORCE_CONSTANTS]: null,
};

const cifLabels = {
  [WORKFLOW_PLOTS]: "No CIF structure loaded",
  [WORKFLOW_FORCE_CONSTANTS]: "No CIF structure loaded",
};

const controlDrafts = {
  [WORKFLOW_PLOTS]: "",
  [WORKFLOW_FORCE_CONSTANTS]: "",
};

const controlLabels = {
  [WORKFLOW_PLOTS]: "No control loaded",
  [WORKFLOW_FORCE_CONSTANTS]: "No control loaded",
};

const plotFileInputs = {
  control: document.getElementById("plotControlFile"),
  cif: document.getElementById("plotCifFile"),
  force_constants: document.getElementById("fcFile"),
  loto: document.getElementById("lotoFile"),
};

const forceConstantFileInputs = {
  control: document.getElementById("forceControlFile"),
  cif: document.getElementById("forceCifFile"),
  nep: document.getElementById("nepFile"),
};

const examples = {
  pbte_band_dos: "PbTe band + DOS",
  zno_band: "ZnO phonon band",
  csi_sqw: "CsI S(Q,E)",
  graphene_surface: "Graphene band + surface",
  nacl_sqw: "NaCl S(Q,E)",
};

const cmapOptions = Array.from(cmapSelect.options).map((option) => ({
  value: option.value,
  label: option.textContent,
}));

const SQW_DEFAULTS = {
  sqw_crystal: {
    xlabel: "Q path",
    ylabel: "Energy (meV)",
    title: "Dynamic structure factor S(Q,E)",
  },
  sqw_powder: {
    xlabel: "Q (1/A)",
    ylabel: "Energy (meV)",
    title: "Powder S(|Q|,E)",
  },
};

const builderDefaults = {
  [WORKFLOW_FORCE_CONSTANTS]: {
    ntypes: "1",
    natoms: "1",
    nsize: "4 4 4",
    nat: "1",
    elements: "Cu",
    displace_delta: "0.01",
    coordinate_mode: "Direct",
    fc_symmetry: true,
    lattice:
      "0.0000000000000000 2.0285682794499998 2.0285682794499998\n" +
      "2.0285682794499998 0.0000000000000000 2.0285682794499998\n" +
      "2.0285682794499998 2.0285682794499998 0.0000000000000000",
    positions: "0.00 0.00 0.00",
  },
  [WORKFLOW_PLOTS]: {
    ntypes: "2",
    natoms: "2",
    nsize: "5 5 5",
    nat: "1 1",
    elements: "Pb Te",
    displace_delta: "0.01",
    coordinate_mode: "Direct",
    dos: true,
    band: true,
    isosurface: false,
    sqw_crystal: false,
    sqw_powder: false,
    nonanalytic: false,
    velocity: false,
    eigenvector: false,
    fc_symmetry: false,
    lphase: true,
    dos_sigma: "0.02",
    dos_qmesh: "40 40 40",
    dw_qmesh: "10 10 10",
    temperature: "30",
    e_min: "0.0",
    e_max: "40.0",
    ne_bins: "501",
    e_smearing: "0.6 0.0 0.001 0.0 0.0",
    isosurface_qmesh: "80 80 1",
    lattice:
      "0.0000000000 3.2708968787 3.2708968787\n" +
      "3.2708968787 0.0000000000 3.2708968787\n" +
      "3.2708968787 3.2708968787 0.0000000000",
    positions: "0.500000000 0.500000000 0.500000000\n0.000000000 0.000000000 0.000000000",
    bands_structure:
      "0.000 0.000 0.000  0.500 0.000 0.500 100 ! G-X\n" +
      "0.500 0.000 0.500  0.625 0.250 0.625 100 ! X-U\n" +
      "0.375 0.375 0.750  0.000 0.000 0.000 100 ! K-G\n" +
      "0.000 0.000 0.000  0.500 0.500 0.500 100 ! G-L\n" +
      "0.500 0.500 0.500  0.500 0.250 0.750 100 ! L-W\n" +
      "0.500 0.250 0.750  0.500 0.000 0.500 100 ! W-X",
  },
};

function setStatus(kind, text) {
  serverStatus.className = `status-dot ${kind}`;
  statusText.textContent = text;
  jobStatus.textContent = text;
}

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(2)} MB`;
}

function isBuilderActive() {
  return activeWorkflow === WORKFLOW_FORCE_CONSTANTS || sourceMode.value === "builder";
}

function activeFileInputs() {
  if (activeWorkflow === WORKFLOW_FORCE_CONSTANTS) {
    return isBuilderActive()
      ? { cif: forceConstantFileInputs.cif, nep: forceConstantFileInputs.nep }
      : forceConstantFileInputs;
  }
  if (sourceMode.value === "builder") {
    return {
      cif: plotFileInputs.cif,
      force_constants: plotFileInputs.force_constants,
      loto: plotFileInputs.loto,
    };
  }
  if (sourceMode.value === "example") return {};
  return plotFileInputs;
}

function selectedExampleName() {
  return examples[document.getElementById("exampleSelect").value];
}

function builderFieldElements() {
  return Array.from(document.querySelectorAll("[data-builder-field]"));
}

function getBuilderValue(name, fallback = "") {
  const field = document.querySelector(`[data-builder-field="${name}"]`);
  if (!field) return fallback;
  if (field.type === "checkbox") return field.checked;
  return field.value.trim() || fallback;
}

function setBuilderValue(name, value) {
  const field = document.querySelector(`[data-builder-field="${name}"]`);
  if (!field) return;
  if (field.type === "checkbox") {
    field.checked = Boolean(value);
    return;
  }
  field.value = value ?? "";
}

function setCifStatus(text, state = "idle") {
  cifStatus.textContent = text;
  cifStatus.className = `cif-status ${state}`.trim();
}

function splitBuilderList(name) {
  return getBuilderValue(name, "")
    .split(/[\s,]+/)
    .map((value) => value.trim().replace(/^['"]|['"]$/g, ""))
    .filter(Boolean);
}

function builderStructureSummary() {
  const elements = splitBuilderList("elements");
  const counts = splitBuilderList("nat");
  const atomCount = Number.parseInt(getBuilderValue("natoms", ""), 10);
  const typeCount = Number.parseInt(getBuilderValue("ntypes", ""), 10);
  const totalFromNat = counts.reduce((sum, value) => {
    const count = Number.parseInt(value, 10);
    return sum + (Number.isFinite(count) ? count : 0);
  }, 0);
  const atoms = Number.isFinite(atomCount) && atomCount > 0 ? atomCount : totalFromNat;
  const types = Number.isFinite(typeCount) && typeCount > 0 ? typeCount : elements.length;
  const species = elements
    .map((element, index) => `${element}${counts[index] ? ` x${counts[index]}` : ""}`)
    .join(", ");
  const source = cifStructures[activeWorkflow]?.sourceName || "Current structure";
  if (!elements.length && !atoms) return cifStructures[activeWorkflow] ? cifLabels[activeWorkflow] : "No CIF structure loaded";
  return `${source}: ${atoms || "-"} atoms, ${types || "-"} species${species ? `: ${species}` : ""}`;
}

function currentBuilderStructure() {
  const base = cifStructures[activeWorkflow] || {};
  return {
    ...base,
    sourceName: base.sourceName || "Current structure",
    ntypes: getBuilderValue("ntypes", base.ntypes || ""),
    natoms: getBuilderValue("natoms", base.natoms || ""),
    nsize: getBuilderValue("nsize", base.nsize || ""),
    nat: getBuilderValue("nat", base.nat || ""),
    elements: getBuilderValue("elements", base.elements || ""),
    coordinate_mode: getBuilderValue("coordinate_mode", base.coordinate_mode || "Direct"),
    lattice: getBuilderValue("lattice", base.lattice || ""),
    positions: getBuilderValue("positions", base.positions || ""),
  };
}

function refreshVisibleStructureCard() {
  if (activeWorkflow !== WORKFLOW_FORCE_CONSTANTS || !isBuilderActive()) return;
  const currentCard = imageGrid.querySelector(".structure-card");
  if (!currentCard) return;
  const replacement = appendStructureCard(null, currentBuilderStructure());
  currentCard.replaceWith(replacement);
}

function refreshBuilderStructureStatus() {
  if (!isBuilderActive()) {
    setWorkflowCifStatus();
    return;
  }
  setCifStatus(builderStructureSummary(), cifStructures[activeWorkflow] ? "loaded" : "idle");
}

function setWorkflowCifStatus() {
  if (isBuilderActive()) {
    refreshBuilderStructureStatus();
    return;
  }
  setCifStatus(cifLabels[activeWorkflow], cifStructures[activeWorkflow] ? "loaded" : "idle");
}

function activeCifInput() {
  return activeWorkflow === WORKFLOW_FORCE_CONSTANTS ? forceConstantFileInputs.cif : plotFileInputs.cif;
}

function clearActiveCifStructure() {
  cifStructures[activeWorkflow] = null;
  cifLabels[activeWorkflow] = "No CIF structure loaded";
  const input = activeCifInput();
  if (input) input.value = "";
  setWorkflowCifStatus();
}

function applyCifStructureToBuilder(structure) {
  const mapping = {
    ntypes: structure.ntypes,
    natoms: structure.natoms,
    nat: structure.nat,
    elements: structure.elements,
    coordinate_mode: structure.coordinate_mode,
    lattice: structure.lattice,
    positions: structure.positions,
  };
  for (const [key, value] of Object.entries(mapping)) {
    if (value !== undefined && value !== null) setBuilderValue(key, value);
  }
  builderFieldElements().forEach((field) => {
    if (mapping[field.dataset.builderField] !== undefined) markFieldSample(field);
  });
}

async function parseCifUpload(input, workflow) {
  if (!input.files || !input.files.length) {
    cifStructures[workflow] = null;
    cifLabels[workflow] = "No CIF structure loaded";
    if (activeWorkflow === workflow) {
      setWorkflowCifStatus();
      if (workflow === WORKFLOW_FORCE_CONSTANTS) setResultEmptyState();
    }
    return;
  }

  const file = input.files[0];
  if (activeWorkflow === workflow) setCifStatus(`Parsing ${file.name}...`);
  const data = new FormData();
  data.append("cif", file);
  try {
    const response = await fetch("/api/cif", { method: "POST", body: data });
    const result = await response.json();
    if (!result.ok) throw new Error((result.errors || ["CIF parsing failed"])[0]);
    const structure = { ...result.structure, sourceName: file.name };
    cifStructures[workflow] = structure;
    cifLabels[workflow] = `${file.name}: ${structure.summary}`;
    if (activeWorkflow === workflow) {
      applyCifStructureToBuilder(structure);
      setWorkflowCifStatus();
      updateGeneratedControlPreview();
      if (workflow === WORKFLOW_FORCE_CONSTANTS) setResultEmptyState();
      agentMessage.textContent = `CIF loaded: ${structure.summary}.`;
    }
  } catch (error) {
    cifStructures[workflow] = null;
    cifLabels[workflow] = `CIF error: ${String(error)}`;
    if (activeWorkflow === workflow) {
      setCifStatus(cifLabels[workflow], "failed");
      agentMessage.textContent = String(error);
    }
  }
}

function setDefaultBuilderValues() {
  const defaults = builderDefaults[activeWorkflow];
  for (const [key, value] of Object.entries(defaults)) {
    setBuilderValue(key, value);
  }
  if (activeWorkflow === WORKFLOW_FORCE_CONSTANTS) {
    for (const key of ["dos", "band", "isosurface", "sqw_crystal", "sqw_powder", "nonanalytic", "velocity", "eigenvector", "lphase"]) {
      setBuilderValue(key, Boolean(defaults[key]));
    }
  }
  builderFieldElements().forEach(markFieldSample);
  updateGeneratedControlPreview();
}

function quotedElements(raw) {
  const values = raw
    .split(/[\s,]+/)
    .map((value) => value.trim().replace(/^['"]|['"]$/g, ""))
    .filter(Boolean);
  return values.map((value) => `"${value}"`).join(" ") || '"Cu"';
}

function countLines(raw) {
  return raw.split(/\r?\n/).filter((line) => line.trim()).length;
}

function tf(value) {
  return value ? ".true." : ".false.";
}

function buildControlPreview() {
  const forceMode = activeWorkflow === WORKFLOW_FORCE_CONSTANTS;
  const dos = !forceMode && Boolean(getBuilderValue("dos"));
  const band = !forceMode && Boolean(getBuilderValue("band"));
  const isosurface = !forceMode && Boolean(getBuilderValue("isosurface"));
  const sqwCrystal = !forceMode && Boolean(getBuilderValue("sqw_crystal"));
  const sqwPowder = !forceMode && Boolean(getBuilderValue("sqw_powder"));
  const nonanalytic = !forceMode && Boolean(getBuilderValue("nonanalytic"));
  const velocity = !forceMode && Boolean(getBuilderValue("velocity"));
  const eigenvector = !forceMode && Boolean(getBuilderValue("eigenvector"));
  const fcSymmetry = Boolean(getBuilderValue("fc_symmetry"));
  const bands = getBuilderValue("bands_structure", builderDefaults[WORKFLOW_PLOTS].bands_structure);

  let text = `&basic
     ntypes = ${getBuilderValue("ntypes", forceMode ? "1" : "2")}
     natoms = ${getBuilderValue("natoms", forceMode ? "1" : "2")}
      nsize = ${getBuilderValue("nsize", forceMode ? "4 4 4" : "5 5 5")}
/

&inputph
   elements = ${quotedElements(getBuilderValue("elements", forceMode ? "Cu" : "Pb Te"))}
        nat = ${getBuilderValue("nat", forceMode ? "1" : "1 1")}
   gen2ndfc = ${tf(forceMode)}
        dos = ${tf(dos)}
       band = ${tf(band)}
   velocity = ${tf(velocity)}
eigenvector = ${tf(eigenvector)}
fc_symmetry = ${tf(fcSymmetry)}
nonanalytic = ${tf(nonanalytic)}
 isosurface = ${tf(isosurface)}
sqw_crystal = ${tf(sqwCrystal)}
 sqw_powder = ${tf(sqwPowder)}
/
`;

  if (sqwCrystal || sqwPowder) {
    text += `
&inputsqw
     lphase = ${tf(Boolean(getBuilderValue("lphase")))}
   dw_qmesh = ${getBuilderValue("dw_qmesh", "10 10 10")}
temperature = ${getBuilderValue("temperature", "30")}
      e_min = ${getBuilderValue("e_min", "0.0")}
      e_max = ${getBuilderValue("e_max", "40.0")}
    ne_bins = ${getBuilderValue("ne_bins", "501")}
 e_smearing = ${getBuilderValue("e_smearing", "0.6 0.0 0.001 0.0 0.0")}
/
`;
  }

  text += `
Displace_DELTA
${getBuilderValue("displace_delta", "0.01")}
`;

  if (dos) {
    text += `
DOS_SIGMA
${getBuilderValue("dos_sigma", "0.02")}

DENSITY_OF_STATES
${getBuilderValue("dos_qmesh", "40 40 40")}
`;
  }

  if (band || sqwCrystal) {
    text += `
BANDS_STRUCTURE
${Math.max(countLines(bands), 1)}
${bands}
`;
  }

  if (isosurface) {
    text += `
ISOSURFACE
${getBuilderValue("isosurface_qmesh", "80 80 1")}
`;
  }

  text += `
LATTICE_PARAMETERS
${getBuilderValue("lattice", forceMode ? builderDefaults[WORKFLOW_FORCE_CONSTANTS].lattice : builderDefaults[WORKFLOW_PLOTS].lattice)}

ATOMIC_POSITIONS
${getBuilderValue("coordinate_mode", "Direct")}
${getBuilderValue("positions", forceMode ? builderDefaults[WORKFLOW_FORCE_CONSTANTS].positions : builderDefaults[WORKFLOW_PLOTS].positions)}
`;
  return `${text.trim()}\n`;
}

function updateGeneratedControlPreview() {
  if (!isBuilderActive()) return;
  const text = buildControlPreview();
  controlDrafts[activeWorkflow] = text;
  controlLabels[activeWorkflow] = "Generated from parameters";
  controlEditor.value = text;
  controlSourceLabel.textContent = "Generated from parameters";
  refreshBuilderStructureStatus();
  refreshVisibleStructureCard();
}

function setControlDraft(text, label) {
  controlDrafts[activeWorkflow] = text;
  controlLabels[activeWorkflow] = label;
  controlEditor.value = text;
  controlSourceLabel.textContent = label;
}

function storeControlDraft() {
  if (!controlEditor.readOnly) {
    controlDrafts[activeWorkflow] = controlEditor.value;
  }
}

async function loadExampleControl() {
  if (activeWorkflow !== WORKFLOW_PLOTS || sourceMode.value !== "example") return;
  const example = document.getElementById("exampleSelect").value;
  controlSourceLabel.textContent = "Loading example inp.control...";
  try {
    const response = await fetch(`/api/control?workflow=${WORKFLOW_PLOTS}&example=${encodeURIComponent(example)}`);
    const result = await response.json();
    if (!result.ok) throw new Error((result.errors || ["Failed to load inp.control"])[0]);
    setControlDraft(result.text, `${result.name} inp.control`);
  } catch (error) {
    setControlDraft("", String(error));
  }
}

async function readControlFile(input, labelPrefix) {
  if (!input.files || !input.files.length) {
    setControlDraft("", "No control loaded");
    return;
  }
  const file = input.files[0];
  try {
    const text = await file.text();
    setControlDraft(text, `${labelPrefix}: ${file.name}`);
  } catch (error) {
    setControlDraft("", String(error));
  }
}

function loadCurrentControl() {
  if (isBuilderActive()) {
    updateGeneratedControlPreview();
    return;
  }
  if (activeWorkflow === WORKFLOW_PLOTS) {
    if (sourceMode.value === "example") {
      loadExampleControl();
      return;
    }
    if (plotFileInputs.control.files && plotFileInputs.control.files.length) {
      readControlFile(plotFileInputs.control, "Uploaded");
      return;
    }
    setControlDraft("", "Upload an inp.control file");
    return;
  }

  if (forceConstantFileInputs.control.files && forceConstantFileInputs.control.files.length) {
    readControlFile(forceConstantFileInputs.control, "Force constants input");
    return;
  }
  setControlDraft("", "Upload an inp.control file");
}

const elementColors = {
  H: "#f8fafc",
  C: "#222222",
  N: "#3050f8",
  O: "#ff0d0d",
  F: "#90e050",
  Na: "#ab5cf2",
  Mg: "#8aff00",
  Al: "#bfa6a6",
  Si: "#f0c8a0",
  P: "#ff8000",
  S: "#ffff30",
  Cl: "#1ff01f",
  K: "#8f40d4",
  Ca: "#3dff00",
  Ga: "#c38f94",
  As: "#b764d9",
  Zn: "#7d80b0",
  Cu: "#c88033",
  I: "#940094",
  Cs: "#57178f",
  Pb: "#575961",
  Te: "#d47a00",
};

function colorForElement(element) {
  if (elementColors[element]) return elementColors[element];
  let hash = 0;
  for (const char of element) hash = (hash * 31 + char.charCodeAt(0)) % 360;
  return `hsl(${hash}, 64%, 52%)`;
}

function parseTriplets(text) {
  return String(text || "")
    .split(/\r?\n/)
    .map((line) =>
      line
        .trim()
        .split(/\s+/)
        .slice(0, 3)
        .map(Number),
    )
    .filter((row) => row.length === 3 && row.every((value) => Number.isFinite(value)));
}

function vectorAdd(a, b) {
  return [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
}

function vectorSub(a, b) {
  return [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
}

function vectorScale(v, scale) {
  return [v[0] * scale, v[1] * scale, v[2] * scale];
}

function vectorDistance(a, b) {
  const dx = a[0] - b[0];
  const dy = a[1] - b[1];
  const dz = a[2] - b[2];
  return Math.sqrt(dx * dx + dy * dy + dz * dz);
}

function directToCartesian(frac, lattice) {
  return vectorAdd(vectorAdd(vectorScale(lattice[0], frac[0]), vectorScale(lattice[1], frac[1])), vectorScale(lattice[2], frac[2]));
}

function defaultCrystalViewState() {
  return {
    rx: -0.52,
    rz: -0.72,
    zoom: 1,
    showBonds: true,
    showBoundary: true,
  };
}

function rotatePoint(point, state = defaultCrystalViewState()) {
  const rz = state.rz;
  const rx = state.rx;
  const cosZ = Math.cos(rz);
  const sinZ = Math.sin(rz);
  const cosX = Math.cos(rx);
  const sinX = Math.sin(rx);
  const x1 = point[0] * cosZ - point[1] * sinZ;
  const y1 = point[0] * sinZ + point[1] * cosZ;
  const z1 = point[2];
  return [x1, y1 * cosX - z1 * sinX, y1 * sinX + z1 * cosX];
}

function atomsForStructure(structure) {
  if (structure.atoms && structure.atoms.length) return structure.atoms;
  const elements = String(structure.elements || "")
    .split(/\s+/)
    .filter(Boolean);
  const counts = String(structure.nat || "")
    .split(/\s+/)
    .map((value) => Number.parseInt(value, 10))
    .filter((value) => Number.isFinite(value) && value > 0);
  const coords = parseTriplets(structure.positions);
  const atoms = [];
  let cursor = 0;
  for (let i = 0; i < elements.length; i += 1) {
    const count = counts[i] || 0;
    for (let j = 0; j < count && cursor < coords.length; j += 1) {
      atoms.push({ element: elements[i], label: `${elements[i]}${j + 1}`, coords: coords[cursor], coordinateMode: structure.coordinate_mode || "Direct" });
      cursor += 1;
    }
  }
  return atoms;
}

function axisImageOptions(value) {
  const options = [0];
  if (Math.abs(value) < 1e-5) options.push(1);
  if (Math.abs(value - 1) < 1e-5) options.push(-1);
  return options;
}

function expandPeriodicAtoms(atoms, lattice, structure) {
  const expanded = [];
  for (const atom of atoms) {
    const mode = atom.coordinateMode || structure.coordinate_mode || "Direct";
    if (mode.toLowerCase().startsWith("cart")) {
      expanded.push({ ...atom, cart: atom.coords, image: [0, 0, 0] });
      continue;
    }
    const txs = axisImageOptions(atom.coords[0]);
    const tys = axisImageOptions(atom.coords[1]);
    const tzs = axisImageOptions(atom.coords[2]);
    for (const tx of txs) {
      for (const ty of tys) {
        for (const tz of tzs) {
          const coords = [atom.coords[0] + tx, atom.coords[1] + ty, atom.coords[2] + tz];
          expanded.push({ ...atom, coords, cart: directToCartesian(coords, lattice), image: [tx, ty, tz] });
        }
      }
    }
  }
  return expanded;
}

function projectCrystal(structure, width, height, state) {
  const lattice = parseTriplets(structure.lattice);
  const atoms = atomsForStructure(structure);
  if (lattice.length !== 3 || !atoms.length) return null;

  const corners = [];
  for (const i of [0, 1]) {
    for (const j of [0, 1]) {
      for (const k of [0, 1]) {
        corners.push(vectorAdd(vectorAdd(vectorScale(lattice[0], i), vectorScale(lattice[1], j)), vectorScale(lattice[2], k)));
      }
    }
  }

  const cartAtoms = expandPeriodicAtoms(atoms, lattice, structure);
  const sourcePoints = [...corners, ...cartAtoms.map((atom) => atom.cart)];
  const minX = Math.min(...sourcePoints.map((point) => point[0]));
  const maxX = Math.max(...sourcePoints.map((point) => point[0]));
  const minY = Math.min(...sourcePoints.map((point) => point[1]));
  const maxY = Math.max(...sourcePoints.map((point) => point[1]));
  const minZ = Math.min(...sourcePoints.map((point) => point[2]));
  const maxZ = Math.max(...sourcePoints.map((point) => point[2]));
  const center = [(minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2];
  const radius = Math.max(
    0.1,
    ...sourcePoints.map((point) => {
      const shifted = vectorSub(point, center);
      return Math.hypot(shifted[0], shifted[1], shifted[2]);
    }),
  );
  const scale = Math.min((width - 150) / (2 * radius), (height - 104) / (2 * radius)) * state.zoom;
  const offsetX = width / 2;
  const offsetY = height / 2;

  const toScreen = (cart) => {
    const point = rotatePoint(vectorSub(cart, center), state);
    return { x: point[0] * scale + offsetX, y: -point[1] * scale + offsetY, z: point[2] };
  };

  return {
    lattice,
    state,
    corners: corners.map(toScreen),
    atoms: cartAtoms.map((atom) => ({ ...atom, screen: toScreen(atom.cart) })),
    toScreen,
  };
}

function drawArrow(ctx, start, end, color, label) {
  ctx.strokeStyle = color;
  ctx.fillStyle = color;
  ctx.lineWidth = 4;
  ctx.lineCap = "round";
  ctx.beginPath();
  ctx.moveTo(start.x, start.y);
  ctx.lineTo(end.x, end.y);
  ctx.stroke();
  const angle = Math.atan2(end.y - start.y, end.x - start.x);
  ctx.beginPath();
  ctx.moveTo(end.x, end.y);
  ctx.lineTo(end.x - Math.cos(angle - 0.44) * 11, end.y - Math.sin(angle - 0.44) * 11);
  ctx.lineTo(end.x - Math.cos(angle + 0.44) * 11, end.y - Math.sin(angle + 0.44) * 11);
  ctx.closePath();
  ctx.fill();
  ctx.font = "800 24px Segoe UI, Arial";
  ctx.fillText(label, end.x + 7, end.y + 5);
  ctx.lineCap = "butt";
}

function drawOrientationAxes(ctx, width, height, state) {
  const origin = { x: 66, y: height - 66 };
  const axisLength = 54;
  const axes = [
    { label: "a", color: "#ef0000", vector: [1, 0, 0] },
    { label: "b", color: "#00c516", vector: [0, 1, 0] },
    { label: "c", color: "#0000ff", vector: [0, 0, 1] },
  ];
  for (const axis of axes) {
    const point = rotatePoint(axis.vector, state);
    const len = Math.max(Math.hypot(point[0], point[1]), 0.001);
    const end = {
      x: origin.x + (point[0] / len) * axisLength,
      y: origin.y - (point[1] / len) * axisLength,
    };
    drawArrow(ctx, origin, end, axis.color, axis.label);
  }
}

function drawCrystal(canvas, structure) {
  const width = Math.max(canvas.clientWidth || 640, 320);
  const height = Math.max(canvas.clientHeight || 430, 320);
  const ratio = window.devicePixelRatio || 1;
  canvas.width = Math.round(width * ratio);
  canvas.height = Math.round(height * ratio);
  const ctx = canvas.getContext("2d");
  ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
  ctx.clearRect(0, 0, width, height);
  if (!canvas.viewState) canvas.viewState = defaultCrystalViewState();

  const projected = projectCrystal(structure, width, height, canvas.viewState);
  if (!projected) {
    ctx.fillStyle = "#64748b";
    ctx.font = "13px Segoe UI, Arial";
    ctx.fillText("CIF structure cannot be drawn.", 24, 36);
    return;
  }

  ctx.fillStyle = "#fbfdff";
  ctx.fillRect(0, 0, width, height);

  const edgePairs = [
    [0, 4],
    [0, 2],
    [0, 1],
    [4, 6],
    [4, 5],
    [2, 6],
    [2, 3],
    [1, 5],
    [1, 3],
    [6, 7],
    [5, 7],
    [3, 7],
  ];
  if (canvas.viewState.showBoundary) {
    ctx.strokeStyle = "rgba(17, 24, 39, 0.64)";
    ctx.lineWidth = 1.05;
    for (const [from, to] of edgePairs) {
      const a = projected.corners[from];
      const b = projected.corners[to];
      ctx.beginPath();
      ctx.moveTo(a.x, a.y);
      ctx.lineTo(b.x, b.y);
      ctx.stroke();
    }
  }

  if (canvas.viewState.showBonds && projected.atoms.length > 1) {
    const distances = [];
    for (let i = 0; i < projected.atoms.length; i += 1) {
      for (let j = i + 1; j < projected.atoms.length; j += 1) {
        distances.push(vectorDistance(projected.atoms[i].cart, projected.atoms[j].cart));
      }
    }
    const nearest = Math.min(...distances.filter((value) => value > 1e-6));
    const cutoff = Number.isFinite(nearest) ? Math.min(nearest * 1.22, 3.4) : 0;
    const bonds = [];
    for (let i = 0; i < projected.atoms.length; i += 1) {
      for (let j = i + 1; j < projected.atoms.length; j += 1) {
        const distance = vectorDistance(projected.atoms[i].cart, projected.atoms[j].cart);
        if (distance > cutoff || distance < 1e-6) continue;
        const a = projected.atoms[i].screen;
        const b = projected.atoms[j].screen;
        bonds.push({ a: projected.atoms[i], b: projected.atoms[j], depth: (a.z + b.z) / 2 });
      }
    }
    bonds.sort((a, b) => a.depth - b.depth);
    ctx.lineCap = "round";
    for (const bond of bonds) {
      const a = bond.a.screen;
      const b = bond.b.screen;
      const mid = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 };
      ctx.strokeStyle = "rgba(72, 82, 97, 0.42)";
      ctx.lineWidth = 6;
      ctx.beginPath();
      ctx.moveTo(a.x, a.y);
      ctx.lineTo(b.x, b.y);
      ctx.stroke();
      ctx.lineWidth = 3.2;
      ctx.strokeStyle = colorForElement(bond.a.element);
      ctx.beginPath();
      ctx.moveTo(a.x, a.y);
      ctx.lineTo(mid.x, mid.y);
      ctx.stroke();
      ctx.strokeStyle = colorForElement(bond.b.element);
      ctx.beginPath();
      ctx.moveTo(mid.x, mid.y);
      ctx.lineTo(b.x, b.y);
      ctx.stroke();
    }
    ctx.lineCap = "butt";
  }

  const sortedAtoms = [...projected.atoms].sort((a, b) => a.screen.z - b.screen.z);
  const atomCountFactor = sortedAtoms.length > 28 ? 0.78 : sortedAtoms.length > 12 ? 0.9 : 1;
  for (const atom of sortedAtoms) {
    const radius = Math.max(10, Math.min(24, width / 34)) * atomCountFactor;
    const gradient = ctx.createRadialGradient(atom.screen.x - radius * 0.42, atom.screen.y - radius * 0.42, 1, atom.screen.x, atom.screen.y, radius);
    gradient.addColorStop(0, "#ffffff");
    gradient.addColorStop(0.33, colorForElement(atom.element));
    gradient.addColorStop(1, "#384152");
    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.arc(atom.screen.x, atom.screen.y, radius, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "rgba(15, 23, 42, 0.35)";
    ctx.lineWidth = 0.8;
    ctx.stroke();
  }

  drawOrientationAxes(ctx, width, height, canvas.viewState);
}

function structureFormula(structure) {
  const elements = String(structure.elements || "")
    .split(/\s+/)
    .filter(Boolean);
  const counts = String(structure.nat || "")
    .split(/\s+/)
    .map((value) => Number.parseInt(value, 10));
  if (!elements.length) return "Initial Structure";
  return elements.map((element, index) => `${element}${counts[index] > 1 ? counts[index] : ""}`).join("");
}

function structureFactItems(structure) {
  const formula = structureFormula(structure);
  const elements = String(structure.elements || "")
    .split(/\s+/)
    .filter(Boolean);
  const counts = String(structure.nat || "")
    .split(/\s+/)
    .filter(Boolean);
  const species = elements
    .map((element, index) => `${element}${counts[index] ? ` x${counts[index]}` : ""}`)
    .join(", ");
  return [
    ["Formula", formula],
    ["Atoms", structure.natoms || atomsForStructure(structure).length || "-"],
    ["Types", structure.ntypes || elements.length || "-"],
    ["Elements", species || elements.join(", ") || "-"],
    ["Coordinate", structure.coordinate_mode || "-"],
  ];
}

function redrawCanvas(canvas) {
  if (canvas && canvas.structureData) drawCrystal(canvas, canvas.structureData);
}

function attachCrystalInteraction(canvas) {
  if (canvas.hasStructureInteraction) return;
  canvas.hasStructureInteraction = true;
  canvas.viewState = canvas.viewState || defaultCrystalViewState();
  let dragging = false;
  let lastX = 0;
  let lastY = 0;

  canvas.addEventListener("pointerdown", (event) => {
    dragging = true;
    lastX = event.clientX;
    lastY = event.clientY;
    canvas.setPointerCapture(event.pointerId);
  });
  canvas.addEventListener("pointermove", (event) => {
    if (!dragging) return;
    const dx = event.clientX - lastX;
    const dy = event.clientY - lastY;
    lastX = event.clientX;
    lastY = event.clientY;
    canvas.viewState.rz += dx * 0.008;
    canvas.viewState.rx = Math.max(-1.45, Math.min(1.45, canvas.viewState.rx + dy * 0.008));
    redrawCanvas(canvas);
  });
  canvas.addEventListener("pointerup", (event) => {
    dragging = false;
    canvas.releasePointerCapture(event.pointerId);
  });
  canvas.addEventListener("pointercancel", () => {
    dragging = false;
  });
  canvas.addEventListener(
    "wheel",
    (event) => {
      event.preventDefault();
      const factor = event.deltaY < 0 ? 1.12 : 0.9;
      canvas.viewState.zoom = Math.max(0.55, Math.min(2.6, canvas.viewState.zoom * factor));
      redrawCanvas(canvas);
    },
    { passive: false },
  );
}

function makeStructureTool(label, title, action) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "structure-tool";
  button.textContent = label;
  button.title = title;
  button.setAttribute("aria-label", title);
  button.addEventListener("click", action);
  return button;
}

function appendStructureCard(container, structure) {
  const card = document.createElement("div");
  card.className = "structure-card";

  const header = document.createElement("header");
  const source = document.createElement("div");
  source.className = "structure-info source-info";
  const sourceLabel = document.createElement("span");
  sourceLabel.textContent = "Source";
  const sourceValue = document.createElement("strong");
  sourceValue.textContent = structure.sourceName || "Initial Structure";
  source.appendChild(sourceLabel);
  source.appendChild(sourceValue);
  header.appendChild(source);

  for (const [label, value] of structureFactItems(structure)) {
    const item = document.createElement("div");
    item.className = "structure-info";
    const key = document.createElement("span");
    key.textContent = label;
    const val = document.createElement("strong");
    val.textContent = String(value);
    item.appendChild(key);
    item.appendChild(val);
    header.appendChild(item);
  }
  card.appendChild(header);

  const viewer = document.createElement("div");
  viewer.className = "structure-viewer";
  const canvas = document.createElement("canvas");
  canvas.className = "structure-canvas";
  canvas.dataset.structureCanvas = "true";
  canvas.structureData = structure;
  canvas.viewState = defaultCrystalViewState();
  attachCrystalInteraction(canvas);
  viewer.appendChild(canvas);

  const toolbar = document.createElement("div");
  toolbar.className = "structure-toolbar";
  toolbar.appendChild(
    makeStructureTool("F", "Fit view", () => {
      canvas.viewState = defaultCrystalViewState();
      redrawCanvas(canvas);
    }),
  );
  toolbar.appendChild(
    makeStructureTool("+", "Zoom in", () => {
      canvas.viewState.zoom = Math.min(2.6, canvas.viewState.zoom * 1.16);
      redrawCanvas(canvas);
    }),
  );
  toolbar.appendChild(
    makeStructureTool("-", "Zoom out", () => {
      canvas.viewState.zoom = Math.max(0.55, canvas.viewState.zoom / 1.16);
      redrawCanvas(canvas);
    }),
  );
  toolbar.appendChild(
    makeStructureTool("<", "Rotate left", () => {
      canvas.viewState.rz -= 0.2;
      redrawCanvas(canvas);
    }),
  );
  toolbar.appendChild(
    makeStructureTool(">", "Rotate right", () => {
      canvas.viewState.rz += 0.2;
      redrawCanvas(canvas);
    }),
  );
  toolbar.appendChild(
    makeStructureTool("B", "Show bonds", () => {
      canvas.viewState.showBonds = !canvas.viewState.showBonds;
      redrawCanvas(canvas);
    }),
  );
  toolbar.appendChild(
    makeStructureTool("#", "Show boundary", () => {
      canvas.viewState.showBoundary = !canvas.viewState.showBoundary;
      redrawCanvas(canvas);
    }),
  );
  viewer.appendChild(toolbar);

  const legend = document.createElement("div");
  legend.className = "structure-legend";
  for (const element of String(structure.elements || "").split(/\s+/).filter(Boolean)) {
    const item = document.createElement("div");
    item.className = "legend-item";
    const swatch = document.createElement("span");
    swatch.className = "legend-swatch";
    swatch.style.background = colorForElement(element);
    const label = document.createElement("span");
    label.textContent = element;
    item.appendChild(swatch);
    item.appendChild(label);
    legend.appendChild(item);
  }
  viewer.appendChild(legend);
  card.appendChild(viewer);
  if (container) container.appendChild(card);
  requestAnimationFrame(() => drawCrystal(canvas, structure));
  return card;
}

function redrawStructureCanvases() {
  document.querySelectorAll("canvas[data-structure-canvas]").forEach((canvas) => {
    if (canvas.structureData) drawCrystal(canvas, canvas.structureData);
  });
}

function setResultEmptyState() {
  if (activeWorkflow === WORKFLOW_FORCE_CONSTANTS) {
    imageGrid.className = "download-grid";
    imageGrid.innerHTML = "";
    const structure = isBuilderActive() ? currentBuilderStructure() : cifStructures[WORKFLOW_FORCE_CONSTANTS];
    if (structure) appendStructureCard(imageGrid, structure);
    const empty = document.createElement("div");
    empty.className = "empty-state";
    empty.innerHTML = `
      <strong>No FORCE_CONSTANTS yet</strong>
      <span>Upload CIF and nep.txt, then generate.</span>`;
    imageGrid.appendChild(empty);
    return;
  }
  imageGrid.className = "image-grid";
  imageGrid.innerHTML = `
    <div class="empty-state">
      <strong>No result images</strong>
      <span>Fill parameters or run an example.</span>
    </div>`;
}


function updateMode() {
  const forceMode = activeWorkflow === WORKFLOW_FORCE_CONSTANTS;
  const builder = isBuilderActive();

  if (forceMode) {
    inputSummary.textContent = builder ? "CIF + parameters + nep.txt" : "inp.control + nep.txt";
    compoundName.textContent = "Generate FORCE_CONSTANTS";
    agentMessage.textContent = "Standing by for force constant generation.";
    forceControlDrop.classList.toggle("hidden", builder);
  } else {
    const upload = sourceMode.value === "upload";
    const example = sourceMode.value === "example";
    exampleWrap.classList.toggle("hidden", !example);
    uploadWrap.classList.toggle("hidden", example);
    plotControlDrop.classList.toggle("hidden", builder);
    inputSummary.textContent = builder ? "CIF + parameter form" : upload ? "Upload mode" : "Example mode";
    compoundName.textContent = builder ? "Generated inp.control" : upload ? "User calculation" : selectedExampleName();
    agentMessage.textContent = "Standing by.";
  }

  plotSwitches.classList.toggle("hidden", forceMode);
  plotParameterGrid.classList.toggle("hidden", forceMode);
  bandsBuilderWrap.classList.toggle("hidden", forceMode);
  lphaseWrap.classList.toggle("hidden", forceMode);
  controlEditor.readOnly = builder;
  controlEditor.classList.toggle("readonly", builder);
  if (builder) updateGeneratedControlPreview();
}

function setWorkflow(workflow) {
  storeControlDraft();
  activeWorkflow = workflow;
  lastResult = null;

  document.querySelectorAll("[data-workflow-tab]").forEach((button) => {
    button.classList.toggle("active", button.dataset.workflowTab === workflow);
  });

  const forceMode = workflow === WORKFLOW_FORCE_CONSTANTS;
  plotImportControls.classList.toggle("hidden", forceMode);
  forceConstantImportControls.classList.toggle("hidden", !forceMode);
  renderOption.classList.toggle("hidden", forceMode);
  forceOutputOption.classList.toggle("hidden", !forceMode);

  importTitle.textContent = forceMode ? "Import Force Constant Inputs" : "Import Calculation";
  runButton.textContent = forceMode ? "Generate" : "Run";
  document.getElementById("intentBox").placeholder = forceMode
    ? "Force constant generation note..."
    : "Describe your modeling intent...";

  if (!controlDrafts[workflow]) setDefaultBuilderValues();
  controlEditor.value = controlDrafts[workflow];
  controlSourceLabel.textContent = controlLabels[workflow];
  setWorkflowCifStatus();
  updateMode();
  setResultEmptyState();
  loadCurrentControl();
}

function getSelectedFilesText() {
  const names = Object.values(activeFileInputs())
    .filter((input) => input.files && input.files.length)
    .map((input) => input.files[0].name);
  if (isBuilderActive()) names.unshift("generated inp.control");
  return names.length ? names.join(", ") : "No local files selected";
}

function appendCurrentFiles(data) {
  for (const [field, input] of Object.entries(activeFileInputs())) {
    if (input.files && input.files.length) {
      data.append(field, input.files[0]);
    }
  }
}

function appendBuilderFields(data) {
  data.append("control_builder", "1");
  for (const field of builderFieldElements()) {
    const key = field.dataset.builderField;
    data.append(`builder_${key}`, field.type === "checkbox" ? (field.checked ? "true" : "false") : field.value);
  }
}

function buildFormData() {
  storeControlDraft();
  const data = new FormData();
  const builder = isBuilderActive();
  data.append("workflow", activeWorkflow);
  data.append("cmap", cmapSelect.value);
  data.append("source", activeWorkflow === WORKFLOW_FORCE_CONSTANTS ? "upload" : sourceMode.value);

  if (builder) {
    appendBuilderFields(data);
  } else if (controlEditor.value.trim()) {
    data.append("control_text", controlEditor.value);
  }

  if (activeWorkflow === WORKFLOW_PLOTS) {
    data.set("source", sourceMode.value);
    data.append("example", document.getElementById("exampleSelect").value);
  }
  appendCurrentFiles(data);
  return data;
}

function withCacheBust(url) {
  const separator = url.includes("?") ? "&" : "?";
  return `${url}${separator}v=${Date.now()}`;
}

function isSqwImage(image) {
  return image.kind === "sqw_crystal" || image.kind === "sqw_powder";
}

function makeCmapSelect() {
  const label = document.createElement("label");
  label.className = "figure-cmap";
  label.innerHTML = "<span>Colormap</span>";
  const select = document.createElement("select");
  for (const option of cmapOptions) {
    const item = document.createElement("option");
    item.value = option.value;
    item.textContent = option.label;
    select.appendChild(item);
  }
  select.value = cmapSelect.value;
  select.addEventListener("change", () => {
    cmapSelect.value = select.value;
    replotCurrentJob();
  });
  label.appendChild(select);
  return label;
}

function syncStyleCmapOptions() {
  if (!styleCmap || styleCmap.options.length) return;
  for (const option of cmapOptions) {
    const item = document.createElement("option");
    item.value = option.value;
    item.textContent = option.label;
    styleCmap.appendChild(item);
  }
}

function openStyleModal(kind, section = "text") {
  if (!styleModal || !stylePanel || !styleTarget) return;
  syncStyleCmapOptions();
  if (kind) {
    styleTarget.value = kind;
    loadStyleForTarget();
  }
  const image = lastResult?.images?.find((item) => item.kind === styleTarget.value);
  if (image && styleSave) {
    styleSave.href = image.url;
    styleSave.download = image.name;
  }
  styleModalBody.appendChild(stylePanel);
  showStyleSection(section);
  styleModal.classList.remove("hidden");
}

function closeStyleModal() {
  if (!styleModal) return;
  styleModal.classList.add("hidden");
}

function showStyleSection(section) {
  document.querySelectorAll(".style-section").forEach((item) => {
    item.classList.toggle("hidden", item.dataset.section !== section);
  });
  document.querySelectorAll("[data-style-section]").forEach((button) => {
    button.classList.toggle("active", button.dataset.styleSection === section);
  });
}

function downloadImage(image) {
  const link = document.createElement("a");
  link.href = image.url;
  link.download = image.name;
  document.body.appendChild(link);
  link.click();
  link.remove();
}

function renderImages(images) {
  imageGrid.className = "image-grid";
  imageGrid.innerHTML = "";
  if (!images || !images.length) {
    imageGrid.innerHTML = `
      <div class="empty-state">
        <strong>No result images</strong>
        <span>Check console output.</span>
      </div>`;
    fillStyleTargets([]);
    return;
  }
  for (const image of images) {
    const fig = document.createElement("figure");
    fig.className = "result-figure";
    fig.dataset.kind = image.kind;

    if (isSqwImage(image)) {
      const toolbar = document.createElement("div");
      toolbar.className = "figure-toolbar";
      const cleanTools = [
        ["text", "T", "Text"],
        ["axes", "XY", "Axes"],
        ["color", "C", "Color"],
        ["download", "DL", "Download"],
      ];
      const tools = [
        ["text", "T", "Text"],
        ["axes", "↔", "Axes"],
        ["color", "◐", "Color"],
        ["export", "↓", "Export"],
      ];
      for (const [section, icon, label] of cleanTools) {
        const button = document.createElement("button");
        button.className = "figure-tool-button";
        button.type = "button";
        button.textContent = icon;
        button.title = label;
        button.setAttribute("aria-label", label);
        button.addEventListener("click", () => {
          if (section === "download") {
            downloadImage(image);
          } else {
            openStyleModal(image.kind, section);
          }
        });
        toolbar.appendChild(button);
      }
      fig.appendChild(toolbar);
    }

    const img = document.createElement("img");
    img.dataset.kind = image.kind;
    img.src = withCacheBust(image.url);
    img.alt = image.name;
    fig.appendChild(img);

    if (!isSqwImage(image)) {
      const caption = document.createElement("figcaption");
      const kind = document.createElement("span");
      kind.textContent = image.kind;
      caption.appendChild(kind);
      const actions = document.createElement("div");
      actions.className = "figure-actions";
      const download = document.createElement("a");
      download.href = image.url;
      download.download = image.name;
      download.textContent = "Save";
      actions.appendChild(download);
      caption.appendChild(actions);
      fig.appendChild(caption);
    }

    imageGrid.appendChild(fig);
  }
  fillStyleTargets(images);
}

async function replotCurrentJob() {
  if (activeWorkflow !== WORKFLOW_PLOTS || !lastResult || !lastResult.jobId) return;
  setStatus("running", "Rendering");
  try {
    const response = await fetch(`/api/replot?jobId=${encodeURIComponent(lastResult.jobId)}&cmap=${encodeURIComponent(cmapSelect.value)}`);
    const result = await response.json();
    if (!result.ok) throw new Error((result.errors || ["Render failed"])[0]);
    lastResult = { ...lastResult, ...result, workflow: WORKFLOW_PLOTS };
    renderImages(result.images);
    renderFiles(result.files);
    setStatus("idle", "Rendered");
    agentMessage.textContent = `Rendered with ${cmapSelect.options[cmapSelect.selectedIndex].textContent}.`;
  } catch (error) {
    setStatus("failed", "Render failed");
    agentMessage.textContent = String(error);
  }
}

function fillStyleTargets(images) {
  const sqw = (images || []).filter(isSqwImage);
  styleTarget.innerHTML = "";
  if (!sqw.length) {
    const option = document.createElement("option");
    option.value = "";
    option.textContent = "No S(Q,E) plot";
    styleTarget.appendChild(option);
    styleTarget.disabled = true;
    return;
  }
  for (const image of sqw) {
    const option = document.createElement("option");
    option.value = image.kind;
    option.textContent = image.kind === "sqw_crystal" ? "S(Q,E) crystal" : "S(Q,E) powder";
    styleTarget.appendChild(option);
  }
  styleTarget.disabled = false;
  styleTarget.value = sqw[0].kind;
  loadStyleForTarget();
}

function loadStyleForTarget() {
  syncStyleCmapOptions();
  const kind = styleTarget.value;
  const defaults = SQW_DEFAULTS[kind];
  if (!defaults) return;
  styleXlabel.value = defaults.xlabel;
  styleYlabel.value = defaults.ylabel;
  styleTitle.value = defaults.title;
  styleFontFamily.value = "sans-serif";
  styleFontSize.value = "12";
  styleFontColor.value = "#1f2937";
  styleBold.checked = false;
  styleItalic.checked = false;
  styleXmin.value = "";
  styleXmax.value = "";
  styleYmin.value = "";
  styleYmax.value = "";
  styleQStart.value = "";
  styleQEnd.value = "";
  if (styleCmap) styleCmap.value = cmapSelect.value;
  if (styleScale) styleScale.value = "linear";
  styleCmin.value = "";
  styleCmax.value = "";
  styleGamma.value = "";
  if (styleLineWidth) styleLineWidth.value = "";
}

async function applyStyle() {
  if (activeWorkflow !== WORKFLOW_PLOTS || !lastResult || !lastResult.jobId) return;
  const kind = styleTarget.value;
  if (!kind) return;
  const params = new URLSearchParams({
    jobId: lastResult.jobId,
    kind,
    cmap: styleCmap?.value || cmapSelect.value,
    xlabel: styleXlabel.value,
    ylabel: styleYlabel.value,
    title: styleTitle.value,
    font_family: styleFontFamily.value,
    font_size: styleFontSize.value,
    font_color: styleFontColor.value,
    font_bold: styleBold.checked ? "1" : "0",
    font_italic: styleItalic.checked ? "1" : "0",
    xlim_min: styleXmin.value,
    xlim_max: styleXmax.value,
    ylim_min: styleYmin.value,
    ylim_max: styleYmax.value,
    q_start_label: styleQStart.value,
    q_end_label: styleQEnd.value,
    color_scale: styleScale?.value || "linear",
    cmin: styleCmin.value,
    cmax: styleCmax.value,
    gamma: styleGamma.value,
    line_width: styleLineWidth?.value || "",
  });
  if (styleCmap?.value) cmapSelect.value = styleCmap.value;
  setStatus("running", "Rendering");
  try {
    const response = await fetch(`/api/style?${params.toString()}`);
    const result = await response.json();
    if (!result.ok) throw new Error((result.errors || ["Style render failed"])[0]);
    const image = result.image;
    if (lastResult && Array.isArray(lastResult.images)) {
      const target = lastResult.images.find((item) => item.kind === image.kind);
      if (target) target.url = image.url;
    }
    const img = imageGrid.querySelector(`img[data-kind="${CSS.escape(kind)}"]`);
    if (img) img.src = withCacheBust(image.url);
    const fig = imageGrid.querySelector(`figure[data-kind="${CSS.escape(kind)}"]`);
    if (fig) {
      fig.querySelectorAll("a").forEach((link) => {
        link.href = image.url;
      });
    }
    if (styleSave) {
      styleSave.href = image.url;
      styleSave.download = image.name;
    }
    setStatus("idle", "Rendered");
    agentMessage.textContent = `Styled ${kind}.`;
    closeStyleModal();
  } catch (error) {
    setStatus("failed", "Style render failed");
    agentMessage.textContent = String(error);
  }
}

function renderForceConstantResult(files) {
  imageGrid.className = "download-grid";
  imageGrid.innerHTML = "";
  const structure = isBuilderActive() ? currentBuilderStructure() : cifStructures[WORKFLOW_FORCE_CONSTANTS];
  if (structure) appendStructureCard(imageGrid, structure);
  const forceConstants = (files || []).find((file) => file.name === "FORCE_CONSTANTS");
  if (!forceConstants) {
    const empty = document.createElement("div");
    empty.className = "empty-state";
    empty.innerHTML = `
        <strong>No FORCE_CONSTANTS generated</strong>
        <span>Check console output.</span>`;
    imageGrid.appendChild(empty);
    return;
  }

  const card = document.createElement("div");
  card.className = "download-card";
  card.innerHTML = `
    <div>
      <strong>FORCE_CONSTANTS</strong>
      <span>${formatBytes(forceConstants.size)} Phonopy format</span>
    </div>
    <a href="${forceConstants.url}" target="_blank" rel="noreferrer">Download</a>`;
  imageGrid.appendChild(card);
}

function renderPrimaryResults(result) {
  if (result.workflow === WORKFLOW_FORCE_CONSTANTS || activeWorkflow === WORKFLOW_FORCE_CONSTANTS) {
    renderForceConstantResult(result.files);
    return;
  }
  renderImages(result.images);
}

function renderFiles(files) {
  fileList.innerHTML = "";
  if (!files || !files.length) {
    fileList.innerHTML = `<span class="muted">No files yet.</span>`;
    return;
  }
  for (const file of files) {
    const row = document.createElement("div");
    row.className = "file-item";
    row.innerHTML = `
      <a href="${file.url}" target="_blank" rel="noreferrer">${file.name}</a>
      <span class="file-size">${formatBytes(file.size)}</span>`;
    fileList.appendChild(row);
  }
}

function renderConsole(result) {
  const lines = [];
  if (result.jobId) lines.push(`Job: ${result.jobId}`);
  if (result.workflow) lines.push(`Module: ${result.workflow}`);
  if (result.errors && result.errors.length) {
    lines.push("Errors:");
    for (const error of result.errors) lines.push(`  - ${error}`);
  }
  if (result.warnings && result.warnings.length) {
    lines.push("Warnings:");
    for (const warning of result.warnings) lines.push(`  - ${warning}`);
  }
  if (result.run) {
    lines.push(`Return code: ${result.run.returncode}`);
    lines.push(`Duration: ${result.run.duration}s`);
    lines.push("");
    lines.push("STDOUT:");
    lines.push(result.run.stdout || "(empty)");
    if (result.run.stderr) {
      lines.push("");
      lines.push("STDERR:");
      lines.push(result.run.stderr);
    }
  }
  consoleLog.textContent = lines.join("\n");
  consoleLog.scrollTop = consoleLog.scrollHeight;
}

async function runCalculation() {
  setStatus("running", "Running");
  runButton.disabled = true;
  agentMessage.textContent =
    activeWorkflow === WORKFLOW_FORCE_CONSTANTS
      ? getSelectedFilesText()
      : sourceMode.value === "upload"
        ? getSelectedFilesText()
        : sourceMode.value === "builder"
          ? "generated inp.control"
          : selectedExampleName();
  consoleLog.textContent = "Submitting job...";

  try {
    const response = await fetch("/api/run", {
      method: "POST",
      body: buildFormData(),
    });
    const result = await response.json();
    lastResult = result.ok ? result : null;
    renderConsole(result);
    renderPrimaryResults(result);
    renderFiles(result.files);
    if (result.ok) {
      setStatus("idle", "Finished");
      agentMessage.textContent =
        result.workflow === WORKFLOW_FORCE_CONSTANTS
          ? "Finished: FORCE_CONSTANTS is ready."
          : `Finished: ${result.images.length} image(s), ${result.files.length} file(s).`;
    } else {
      setStatus("failed", result.status === "validation_failed" ? "Input check failed" : "Run failed");
      agentMessage.textContent = result.errors && result.errors.length ? result.errors[0] : "Calculation failed.";
    }
  } catch (error) {
    setStatus("failed", "Request failed");
    consoleLog.textContent = String(error);
    imageGrid.innerHTML = `
      <div class="empty-state">
        <strong>Request failed</strong>
        <span>${String(error)}</span>
      </div>`;
  } finally {
    runButton.disabled = false;
  }
}

document.querySelectorAll("[data-collapse]").forEach((button) => {
  button.addEventListener("click", () => {
    const target = document.getElementById(button.dataset.collapse);
    target.classList.toggle("hidden");
    button.textContent = target.classList.contains("hidden") ? "v" : "^";
  });
});

document.querySelectorAll("[data-workflow-tab]").forEach((button) => {
  button.addEventListener("click", () => setWorkflow(button.dataset.workflowTab));
});

function markFieldSample(field) {
  if (field.type === "checkbox" || field.tagName === "SELECT") return;
  field.dataset.sample = "1";
  field.classList.remove("dimmed");
}

function attachFieldDim(field) {
  if (field.type === "checkbox" || field.tagName === "SELECT") return;
  field.addEventListener("focus", () => {
    if (field.dataset.sample === "1" && field.value) {
      field.classList.add("dimmed");
      field.setSelectionRange(0, 0);
    }
  });
  field.addEventListener("click", () => {
    if (field.dataset.sample === "1" && field.value && field.classList.contains("dimmed")) {
      field.setSelectionRange(0, 0);
    }
  });
  field.addEventListener("keydown", (event) => {
    if (field.dataset.sample === "1" && field.classList.contains("dimmed") && event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey) {
      field.classList.remove("dimmed");
      delete field.dataset.sample;
      field.value = "";
    }
  });
  field.addEventListener("input", () => {
    if (field.dataset.sample === "1" && field.classList.contains("dimmed")) {
      field.classList.remove("dimmed");
      delete field.dataset.sample;
    }
  });
}

builderFieldElements().forEach((field) => {
  const eventName = field.type === "checkbox" || field.tagName === "SELECT" ? "change" : "input";
  field.addEventListener(eventName, updateGeneratedControlPreview);
  attachFieldDim(field);
});

controlEditor.addEventListener("input", () => {
  if (controlEditor.readOnly) return;
  controlDrafts[activeWorkflow] = controlEditor.value;
  controlLabels[activeWorkflow] = "Edited inp.control";
  controlSourceLabel.textContent = "Edited inp.control";
});

sourceMode.addEventListener("change", () => {
  updateMode();
  loadCurrentControl();
});
document.getElementById("exampleSelect").addEventListener("change", () => {
  updateMode();
  loadExampleControl();
});
plotFileInputs.control.addEventListener("change", () => readControlFile(plotFileInputs.control, "Uploaded"));
plotFileInputs.cif.addEventListener("change", () => parseCifUpload(plotFileInputs.cif, WORKFLOW_PLOTS));
forceConstantFileInputs.control.addEventListener("change", () => readControlFile(forceConstantFileInputs.control, "Force constants input"));
forceConstantFileInputs.cif.addEventListener("change", () => parseCifUpload(forceConstantFileInputs.cif, WORKFLOW_FORCE_CONSTANTS));
plotFileInputs.force_constants.addEventListener("change", updateMode);
plotFileInputs.loto.addEventListener("change", updateMode);
forceConstantFileInputs.nep.addEventListener("change", updateMode);
cmapSelect.addEventListener("change", replotCurrentJob);
styleTarget.addEventListener("change", loadStyleForTarget);
styleApply.addEventListener("click", applyStyle);
if (styleModalClose) styleModalClose.addEventListener("click", closeStyleModal);
if (styleModal) {
  styleModal.addEventListener("click", (event) => {
    if (event.target === styleModal) closeStyleModal();
  });
}
document.querySelectorAll("[data-style-section]").forEach((button) => {
  button.addEventListener("click", () => {
    showStyleSection(button.dataset.styleSection);
  });
});
if (styleScale) {
  styleScale.addEventListener("change", () => {
    if (!styleGamma) return;
    styleGamma.value = styleScale.value === "power" ? "0.55" : "1";
  });
}

let intentSample = false;
let intentJustCleared = false;

const intentPrompts = [
  "Run the selected input and render all available result plots.",
  "Generate FORCE_CONSTANTS from form parameters and nep.txt.",
  "Calculate phonon band structure and DOS.",
  "Plot single-crystal S(Q,E).",
  "Generate band structure with LO-TO splitting.",
  "Calculate iso-frequency contours.",
  "Plot powder-averaged S(Q,E).",
  "Run phonon dispersion calculation.",
  "Upload CIF + FORCE_CONSTANTS and plot band + DOS.",
];

function setIntentSample(text) {
  intentBox.value = text;
  intentBox.classList.remove("dimmed");
  intentSample = true;
  intentJustCleared = false;
}

function intentMatch() {
  const value = intentBox.value;
  if (!value) return null;
  const lower = value.toLowerCase();
  for (const prompt of intentPrompts) {
    if (prompt.toLowerCase().startsWith(lower) && prompt.length > value.length) {
      return prompt;
    }
  }
  return null;
}

function showIntentHint() {
  if (intentJustCleared) return;
  const match = intentMatch();
  if (match) {
    intentHint.textContent = match;
    intentHint.style.display = "block";
  } else {
    intentHint.textContent = "";
    intentHint.style.display = "none";
  }
}

function appendAgentChatMessage(role, text) {
  if (!agentConversation) return;
  const message = document.createElement("article");
  message.className = `agent-message ${role === "You" ? "user-message" : "assistant-message"}`;

  const roleLabel = document.createElement("span");
  roleLabel.className = "agent-message-role";
  roleLabel.textContent = role;

  const body = document.createElement("p");
  body.textContent = text;
  message.append(roleLabel, body);
  agentConversation.appendChild(message);
  agentConversation.scrollTop = agentConversation.scrollHeight;
}

function sendAgentDraft() {
  const text = intentBox.value.trim();
  if (!text) {
    intentBox.focus();
    return;
  }
  appendAgentChatMessage("You", text);
  intentBox.value = "";
  intentBox.classList.remove("dimmed");
  intentSample = false;
  intentJustCleared = false;
  intentHint.textContent = "";
  intentHint.style.display = "none";
  appendAgentChatMessage("Agent", "Message received. The modeling agent will be connected in a later step.");
  intentBox.focus();
}

intentBox.addEventListener("focus", () => {
  if (intentSample && intentBox.value) {
    intentBox.classList.add("dimmed");
    intentBox.setSelectionRange(0, 0);
  }
  showIntentHint();
});

intentBox.addEventListener("click", () => {
  if (intentSample && intentBox.value && intentBox.classList.contains("dimmed")) {
    intentBox.setSelectionRange(0, 0);
  }
});

intentBox.addEventListener("input", () => {
  if (intentJustCleared) {
    intentJustCleared = false;
    return;
  }
  if (intentSample && intentBox.classList.contains("dimmed")) {
    intentBox.classList.remove("dimmed");
    intentSample = false;
  }
  showIntentHint();
});

intentBox.addEventListener("blur", () => {
  setTimeout(() => { intentHint.style.display = "none"; }, 150);
});

intentBox.addEventListener("keydown", (event) => {
  if (event.key === "Enter" && !event.shiftKey) {
    event.preventDefault();
    sendAgentDraft();
    return;
  }
  if (event.key === "Tab") {
    const match = intentMatch();
    if (match) {
      event.preventDefault();
      intentBox.value = match;
      intentBox.classList.remove("dimmed");
      intentSample = false;
      intentJustCleared = false;
      intentHint.style.display = "none";
    }
    return;
  }
  if (intentSample && intentBox.classList.contains("dimmed") && event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey) {
    intentBox.classList.remove("dimmed");
    intentSample = false;
    intentJustCleared = true;
    intentBox.value = "";
    intentHint.style.display = "none";
  }
});


runButton.addEventListener("click", runCalculation);
agentSendButton.addEventListener("click", sendAgentDraft);
window.addEventListener("resize", redrawStructureCanvases);

const initialWorkflow = location.pathname.includes("/force") ? WORKFLOW_FORCE_CONSTANTS : WORKFLOW_PLOTS;
setWorkflow(initialWorkflow);
