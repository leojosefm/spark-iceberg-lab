#!/bin/bash

set -e

export SPARK_HOME=/opt/spark
export PATH=$SPARK_HOME/bin:$PATH

export PYTHONPATH=$SPARK_HOME/python/lib/pyspark.zip:$SPARK_HOME/python/lib/py4j-0.10.9.7-src.zip

exec jupyter lab \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --IdentityProvider.token='' \
    --PasswordIdentityProvider.hashed_password='' \
    --ServerApp.allow_origin='*' \
    --ServerApp.allow_remote_access=True