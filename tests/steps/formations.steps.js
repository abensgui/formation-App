"use strict";

const {
  Given,
  When,
  Then,
  Before,
  After,
  BeforeAll,
  AfterAll,
  setDefaultTimeout,
} = require("@cucumber/cucumber");
const { chromium } = require("playwright");

// ── Config ────────────────────────────────────────────────────
const BASE_URL = process.env.APP_URL || "http://localhost:3000";
setDefaultTimeout(30_000);

// ── State global ──────────────────────────────────────────────
let browser, context, page;
let apiResponse = null;
let initialCount = 0;

// ═════════════════════════════════════════════════════════════
// HOOKS
// ═════════════════════════════════════════════════════════════

BeforeAll(async () => {
  browser = await chromium.launch({
    headless: true,
  });
});

AfterAll(async () => {
  if (browser) await browser.close();
});

Before(async function () {
  context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
  });
  page = await context.newPage();
  apiResponse = null;
  initialCount = 0;
});

After(async function (scenario) {
  if (scenario.result?.status === "FAILED") {
    const screenshot = await page.screenshot({ fullPage: true });
    await this.attach(screenshot, "image/png");
  }
  await context.close();
});

// ═════════════════════════════════════════════════════════════
// GIVEN
// ═════════════════════════════════════════════════════════════

Given("l'application est ouverte dans le navigateur", async function () {
  // Contexte global — le navigateur est déjà lancé (BeforeAll)
  // Rien à faire ici, Playwright est prêt
});

// ═════════════════════════════════════════════════════════════
// WHEN
// ═════════════════════════════════════════════════════════════

When("je suis sur la page d'accueil", async function () {
  await page.goto(BASE_URL);
  await page.waitForLoadState("networkidle");
});

When("je suis sur la page d'ajout", async function () {
  await page.goto(`${BASE_URL}/add`);
  await page.waitForLoadState("networkidle");
});

When("je clique sur le bouton d'ajout de formation", async function () {
  await page.click("#btn-ajouter");
  await page.waitForLoadState("networkidle");
});

When("je saisis {string} dans le champ titre", async function (valeur) {
  await page.fill('[data-testid="input-titre"]', valeur);
});

When("je saisis {string} dans le champ durée", async function (valeur) {
  await page.fill('[data-testid="input-duree"]', valeur);
});

When("je sélectionne {string} comme niveau", async function (valeur) {
  await page.selectOption('[data-testid="input-niveau"]', valeur);
});

When("je saisis {string} dans le champ description", async function (valeur) {
  await page.fill('[data-testid="input-description"]', valeur);
});

When("je clique sur le bouton enregistrer", async function () {
  await page.click('[data-testid="btn-submit"]');
  await page.waitForLoadState("networkidle");
});

When("je soumets le formulaire sans remplir les champs", async function () {
  // Retire les attributs required pour forcer la soumission vide côté serveur
  await page.evaluate(() => {
    document
      .querySelectorAll("[required]")
      .forEach((el) => el.removeAttribute("required"));
  });
  await page.click('[data-testid="btn-submit"]');
  await page.waitForLoadState("networkidle");
});

When("je clique sur le lien retour", async function () {
  await page.click("text=← Retour à la liste");
  await page.waitForLoadState("networkidle");
});

When("je retiens le nombre actuel de formations", async function () {
  const cards = page.locator('[data-testid="formation-card"]');
  initialCount = await cards.count();
  await this.attach(`Nombre initial : ${initialCount}`, "text/plain");
});

When("je supprime la première formation de la liste", async function () {
  page.once("dialog", (dialog) => dialog.accept());
  await page.locator('[data-testid="btn-supprimer"]').first().click();
  await page.waitForLoadState("networkidle");
});

When("j'appelle l'endpoint {string}", async function (endpoint) {
  const resp = await page.request.get(`${BASE_URL}${endpoint}`);
  apiResponse = {
    status: resp.status(),
    body: await resp.text(),
    json: null,
  };
  try {
    apiResponse.json = JSON.parse(apiResponse.body);
  } catch (_) {}
  await this.attach(
    `GET ${endpoint}\nStatus: ${apiResponse.status}\nBody: ${apiResponse.body}`,
    "text/plain",
  );
});

// ═════════════════════════════════════════════════════════════
// THEN
// ═════════════════════════════════════════════════════════════

Then("je vois le titre {string}", async function (titre) {
  const h1 = page.locator("h1");
  await h1.waitFor({ state: "visible" });
  const texte = await h1.innerText();
  if (!texte.includes(titre))
    throw new Error(`Titre attendu "${titre}", trouvé "${texte}"`);
});

Then("je vois au moins une formation dans la liste", async function () {
  const cards = page.locator('[data-testid="formation-card"]');
  await cards.first().waitFor({ state: "visible" });
  const nb = await cards.count();
  if (nb < 1) throw new Error("Aucune formation trouvée");
  await this.attach(`${nb} formation(s) affichée(s)`, "text/plain");
});

Then("le compteur de formations affiche un nombre positif", async function () {
  const counter = page.locator("#formations-count");
  await counter.waitFor({ state: "visible" });
  const val = parseInt(await counter.innerText(), 10);
  if (isNaN(val) || val < 1) throw new Error(`Compteur invalide : "${val}"`);
});

Then("je vois le bouton d'ajout de formation", async function () {
  await page.locator("#btn-ajouter").waitFor({ state: "visible" });
});

Then("je suis redirigé vers la page d'ajout", async function () {
  await page.waitForURL(`${BASE_URL}/add`, { timeout: 8000 });
});

Then("je suis redirigé vers la page d'accueil", async function () {
  await page.waitForURL(`${BASE_URL}/`, { timeout: 8000 });
});

Then("je vois tous les champs du formulaire", async function () {
  for (const id of [
    "input-titre",
    "input-duree",
    "input-niveau",
    "input-description",
  ]) {
    await page.locator(`[data-testid="${id}"]`).waitFor({ state: "visible" });
  }
});

Then("la formation {string} apparaît dans la liste", async function (titre) {
  const card = page
    .locator('[data-testid="formation-titre"]')
    .filter({ hasText: titre });
  await card.waitFor({ state: "visible", timeout: 8000 });
});

Then("un message d'erreur est affiché sur la page", async function () {
  const erreur = page.locator('[data-testid="form-error"]');
  await erreur.waitFor({ state: "visible", timeout: 5000 });
  const msg = await erreur.innerText();
  await this.attach(`Message d'erreur : ${msg}`, "text/plain");
});

Then("le nombre de formations a diminué de un", async function () {
  await page.waitForTimeout(500);
  const nouveau = await page.locator('[data-testid="formation-card"]').count();
  const attendu = initialCount - 1;
  if (nouveau !== attendu)
    throw new Error(`Attendu ${attendu} formations, trouvé ${nouveau}`);
  await this.attach(`Avant: ${initialCount} → Après: ${nouveau}`, "text/plain");
});

Then("le statut de la réponse est {int}", async function (statusAttendu) {
  if (apiResponse.status !== statusAttendu)
    throw new Error(
      `Statut attendu ${statusAttendu}, reçu ${apiResponse.status}`,
    );
});

Then(
  "le champ {string} de la réponse vaut {string}",
  async function (champ, valeur) {
    if (!apiResponse.json)
      throw new Error("La réponse n'est pas du JSON valide");
    if (String(apiResponse.json[champ]) !== valeur)
      throw new Error(
        `json.${champ} = "${apiResponse.json[champ]}", attendu "${valeur}"`,
      );
  },
);

Then("la réponse contient un tableau JSON non vide", async function () {
  if (!Array.isArray(apiResponse.json))
    throw new Error("La réponse n'est pas un tableau JSON");
  if (apiResponse.json.length === 0) throw new Error("Le tableau est vide");
  await this.attach(`${apiResponse.json.length} élément(s)`, "text/plain");
});
