#!/bin/bash

# ==================================================================
# 1. INITIALISATION DE CONDA POUR LE SCRIPT BASH
# ==================================================================
# On force le chargement du profil conda (nécessaire dans un script)
if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
elif [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/anaconda3/etc/profile.d/conda.sh"
else
    echo "ERREUR : Impossible de trouver l'initialisation de conda. Vérifiez votre dossier d'installation (miniconda3 ou anaconda3)."
    exit 1
fi

# ==================================================================
# 2. CONFIGURATION DES CHEMINS ET VARIABLES
# ==================================================================
# Si votre config.yaml se trouve AUSSI dans le dossier tutorial, modifiez la ligne ci-dessous en : 
# CONFIG_FILE="./tutorial/config.yaml"
# S'il se trouve à la racine (là où vous lancez la commande), laissez-le ainsi :
CONFIG_FILE="./config.yaml"

SIZES=(32 64 96)
CONDA_CMD="conda run --no-capture-output -n ddw_env ddw"

# ==================================================================
# 3. BOUCLE PRINCIPALE
# ==================================================================
for SIZE in "${SIZES[@]}"; do
    echo "=================================================================="
    echo "DÉMARRAGE DU PIPELINE AVEC SUBTOMO_SIZE = $SIZE"
    echo "=================================================================="

    # Création d'un dossier de projet unique pour chaque taille à la racine
    PROJECT_DIR="./tutorial_project_${SIZE}"

    # 1. Préparation des données
    echo ">>> 1. prepare-data (size: $SIZE)..."
    $CONDA_CMD prepare-data \
        --config "$CONFIG_FILE" \
        --subtomo-size "$SIZE" \
        --project-dir "$PROJECT_DIR"

    # 2. Entraînement du modèle
    echo ">>> 2. fit-model (size: $SIZE)..."
    $CONDA_CMD fit-model \
        --config "$CONFIG_FILE" \
        --subtomo-size "$SIZE" \
        --project-dir "$PROJECT_DIR"

    # 3. Trouver le meilleur checkpoint généré
    echo ">>> Recherche du meilleur modèle entraîné..."
    BEST_MODEL=$(ls -t "$PROJECT_DIR"/logs/version_*/checkpoints/val_loss/*.ckpt 2>/dev/null | head -n 1)

    if [ -z "$BEST_MODEL" ]; then
        echo "ERREUR : Aucun modèle trouvé pour la taille $SIZE. L'entraînement a peut-être échoué."
        continue
    fi

    echo ">>> Modèle trouvé : $BEST_MODEL"

    # 4. Raffinement des tomogrammes
    echo ">>> 3. refine-tomogram (size: $SIZE)..."
    $CONDA_CMD refine-tomogram \
        --config "$CONFIG_FILE" \
        --subtomo-size "$SIZE" \
        --project-dir "$PROJECT_DIR" \
        --model-checkpoint-file "$BEST_MODEL"

    echo "Terminé pour subtomo_size = $SIZE"
    echo ""
done

echo "Toutes les tailles ont été traitées avec succès !"