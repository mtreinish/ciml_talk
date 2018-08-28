#!/bin/bash

# Run the same experiment on different datasets
# for several combinations of dstat features

# It requires CIML to be installed
# It assumes enough examples are cached already

# Call with --force to force recreating datasets and experiments

NETWORK=${NETWORK:-100/100/100/100/100}
NETWORK_NAME=${NETWORK_NAME:-"dnn-100x5"}
BATCH=128
EPOCHS=500
DATA_PATH=${DATA_PATH:-/git/github.com/mtreinish/ciml/data}
TARGET_DATA_PATH=${TARGET_DATA_PATH:-/git/github.com/mtreinish/ciml/data}
SLICE=${SLICE:-":2000"}
FEATURES="(usr|1m)"
FILENAME_SUFFIX=${FILENAME_SUFFIX:-""}

SAMPLINGS="10s 30s 1min 5min 10min"
CLASS_LABELS="node_provider_all node_provider"


for sampling in ${SAMPLINGS}; do
  for class_label in ${CLASS_LABELS}; do
    DATASET=$(echo $FEATURES | tr "|" "_" | sed -e "s/(//g" -e "s/)//g")-${sampling}-${class_label}
    echo "=== Setting up dataset $DATASET"
    # Build the dataset
    ciml-build-dataset --dataset $DATASET \
      --build-name tempest-full \
      --slicer $SLICE \
      --sample-interval "$sampling" \
      --features-regex "$FEATURES" \
      --class-label $class_label \
      --tdt-split 7 0 3 \
      --data-path $DATA_PATH \
      --target-data-path $TARGET_DATA_PATH $@
    # Setup the experiment
    EXPERIMENT=${NETWORK_NAME}-${EPOCHS}epochs-bs${BATCH}
    echo "=== Setting up experiment $EXPERIMENT"
    ciml-setup-experiment --experiment $EXPERIMENT \
      --dataset $DATASET \
      --estimator tf.estimator.DNNClassifier \
      --hidden-layers $NETWORK \
      --steps $(( 2000 / BATCH * EPOCHS )) \
      --batch-size $BATCH \
      --epochs ${EPOCHS} \
      --data-path $TARGET_DATA_PATH $@
    # Do the training if this is a new experiment
    if [[ "$?" == 0 ]]; then
      echo "=== Training $EXPERIMENT against $DATASET"
      ciml-train-model --dataset $DATASET --experiment $EXPERIMENT \
        --data-path $TARGET_DATA_PATH
    fi
  done
done

DAL_PARAMS=""
# Do the data building and plotting
for sampling in ${SAMPLINGS}; do
  for class_label in ${CLASS_LABELS}; do
    DATASET=$(echo $FEATURES | tr "|" "_" | sed -e "s/(//g" -e "s/)//g")-${sampling}-${class_label}
    LABEL=$sampling
    EXPERIMENT=${NETWORK_NAME}-${EPOCHS}epochs-bs${BATCH}
    if [[ "$class_label" == "node_provider_all" ]]; then
      DAL_PARAMS="$DAL_PARAMS --dataset-experiment-label $DATASET $EXPERIMENT $LABEL"
    else
      DAL_PARAMS="$DAL_PARAMS --dataset-experiment-comp $DATASET $EXPERIMENT"
    fi
  done
done
ciml-plot-data $DAL_PARAMS -k accuracy \
  --output accuracy_by_sampling-compare-classes${FILENAME_SUFFIX}.png \
  --title "1 - Accuracy with different resolution" \
  --experiment-sets-names "All Classes" "Grouped Classes"
ciml-plot-data $DAL_PARAMS -k loss \
  --output loss_by_sampling-compare-classes${FILENAME_SUFFIX}.png \
  --title "Loss with different resolution" \
  --experiment-sets-names "All Classes" "Grouped Classes"
ciml-plot-data $DAL_PARAMS -k average_loss \
  --output avg_loss_by_sampling-compare-classes${FILENAME_SUFFIX}.png \
  --title "Average Loss with different resolution" \
  --experiment-sets-names "All Classes" "Grouped Classes"