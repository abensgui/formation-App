@feature:formations
Feature: Gestion des formations
  As a user of EST Salé application
  I want to view, add and delete formations
  So that I can keep the catalogue up to date

  Background:
    Given l'application est ouverte dans le navigateur

  @severity:critical
  Scenario: Afficher la page d'accueil avec le bon titre
    When je suis sur la page d'accueil
    Then je vois le titre "Catalogue des Formations"

  @severity:critical
  Scenario: La liste des formations est affichée
    When je suis sur la page d'accueil
    Then je vois au moins une formation dans la liste

  @severity:normal
  Scenario: Le compteur de formations est supérieur à zéro
    When je suis sur la page d'accueil
    Then le compteur de formations affiche un nombre positif

  @severity:normal
  Scenario: Le bouton Ajouter une formation est visible
    When je suis sur la page d'accueil
    Then je vois le bouton d'ajout de formation

  @severity:critical
  Scenario: Naviguer vers le formulaire d'ajout
    When je suis sur la page d'accueil
    And je clique sur le bouton d'ajout de formation
    Then je suis redirigé vers la page d'ajout
    And je vois tous les champs du formulaire

  @severity:critical
  Scenario: Ajouter une nouvelle formation avec succès
    When je suis sur la page d'ajout
    And je saisis "Blockchain & Web3" dans le champ titre
    And je saisis "3 mois" dans le champ durée
    And je sélectionne "Avancé" comme niveau
    And je saisis "Solidity, Ethereum, DeFi" dans le champ description
    And je clique sur le bouton enregistrer
    Then je suis redirigé vers la page d'accueil
    And la formation "Blockchain & Web3" apparaît dans la liste

  @severity:normal
  Scenario: Un message d'erreur s'affiche si le formulaire est vide
    When je suis sur la page d'ajout
    And je soumets le formulaire sans remplir les champs
    Then un message d'erreur est affiché sur la page

  @severity:minor
  Scenario: Le lien retour ramène à la liste des formations
    When je suis sur la page d'ajout
    And je clique sur le lien retour
    Then je suis redirigé vers la page d'accueil

  @severity:critical
  Scenario: Supprimer une formation réduit le compteur
    When je suis sur la page d'accueil
    And je retiens le nombre actuel de formations
    And je supprime la première formation de la liste
    Then le nombre de formations a diminué de un

  @severity:critical
  Scenario: L'endpoint health répond avec le statut 200
    When j'appelle l'endpoint "/health"
    Then le statut de la réponse est 200
    And le champ "status" de la réponse vaut "ok"

  @severity:normal
  Scenario: L'API formations retourne une liste non vide
    When j'appelle l'endpoint "/api/formations"
    Then le statut de la réponse est 200
    And la réponse contient un tableau JSON non vide