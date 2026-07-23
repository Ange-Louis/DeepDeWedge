#!/bin/bash

# Tailles des subtomos à tester
SIZES=(32 64 96)
CONFIG_FILE="config.yaml"

for SIZE in "${SIZES[@]}"; do
    echo "=================================================================="
    echo "DÉMARRAGE DU PIPELINE AVEC SUBTOMO_SIZE = $SIZE"
    echo "=================================================================="

    # Création d'un dossier de projet unique pour chaque taille pour ne pas écraser les données
    PROJECT_DIR="./tutorial_project_${SIZE}"

    # 1. Préparation des données
    echo ">>> 1. prepare-data (size: $SIZE)..."
    ddw prepare-data \
        --config "$CONFIG_FILE" \
        --subtomo-size "$SIZE" \
        --project-dir "$PROJECT_DIR"

    # 2. Entraînement du modèle
    echo ">>> 2. fit-model (size: $SIZE)..."
    ddw fit-model \
        --config "$CONFIG_FILE" \
        --subtomo-size "$SIZE" \
        --project-dir "$PROJECT_DIR"

    # 3. Trouver le meilleur checkpoint généré
    # PyTorch Lightning sauvegarde les modèles dans logdir/checkpoints/val_loss/
    echo ">>> Recherche du meilleur modèle entraîné..."
    # On récupère le fichier .ckpt le plus récent
    BEST_MODEL=$(ls -t "$PROJECT_DIR"/logs/version_*/checkpoints/val_loss/*.ckpt 2>/dev/null | head -n 1)

    if [ -z "$BEST_MODEL" ]; then
        echo "ERREUR : Aucun modèle trouvé pour la taille $SIZE. L'entraînement a peut-être échoué."
        # Si vous sauvegardez uniquement sur la fitting_loss (si pas de données de validation) :
        # BEST_MODEL=$(ls -t "$PROJECT_DIR"/logs/version_*/checkpoints/fitting_loss/*.ckpt 2>/dev/null | head -n 1)
        continue
    fi

    echo ">>> Modèle trouvé : $BEST_MODEL"

    # 4. Raffinement des tomogrammes
    echo ">>> 3. refine-tomogram (size: $SIZE)..."
    ddw refine-tomogram \
        --config "$CONFIG_FILE" \
        --subtomo-size "$SIZE" \
        --project-dir "$PROJECT_DIR" \
        --model-checkpoint-file "$BEST_MODEL"

    echo "Terminé pour subtomo_size = $SIZE"
    echo ""
done

echo "Toutes les tailles ont été traitées avec succès !"