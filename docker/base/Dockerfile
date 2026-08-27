FROM apache/spark:3.5.0

USER root

RUN apt-get update && \
    apt-get install -y \
        git \
        vim \
        tree \
        curl \
        wget \
        unzip \
        jq \
        htop && \
    rm -rf /var/lib/apt/lists/*

COPY docker/base/requirements.txt /tmp/

RUN pip install --no-cache-dir \
    -r /tmp/requirements.txt

#
# Create our own user
#

RUN groupadd -g 1000 jmattam && \
    useradd -m \
        -u 1000 \
        -g jmattam \
        -s /bin/bash \
        jmattam

RUN mkdir -p \
    /home/jmattam/notebooks \
    /data/raw \
    /data/warehouse

RUN chown -R jmattam:jmattam \
    /home/jmattam \
    /data

COPY docker/base/start-notebook.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/start-notebook.sh

ENV SPARK_HOME=/opt/spark
ENV PATH="${SPARK_HOME}/bin:${PATH}"

USER jmattam

WORKDIR /home/jmattam/notebooks

ENTRYPOINT ["start-notebook.sh"]