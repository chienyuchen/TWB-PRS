# download plink
FROM alpine AS builder
ENV plink2_version "20220503"
ENV plink1_version "20220402"
RUN wget https://s3.amazonaws.com/plink2-assets/plink2_linux_x86_64_$plink2_version.zip && \
    unzip plink2_linux_x86_64_$plink2_version.zip plink2 -d /opt && \
    rm plink2_linux_x86_64_$plink2_version.zip && \
    wget https://s3.amazonaws.com/plink1-assets/plink_linux_x86_64_$plink1_version.zip && \
    unzip plink_linux_x86_64_$plink1_version.zip plink -d /opt && \
    rm plink_linux_x86_64_$plink1_version.zip

# main
FROM python:3.10-slim
RUN pip install --no-cache-dir pandas==1.4.2 numpy==1.22.3
COPY --from=builder /opt/plink* /opt/
RUN ln -s /opt/plink /opt/plink1.9
COPY ./src/utils.py ./src/predictor.sh /opt
ENV PATH /opt:$PATH
ENTRYPOINT ["predictor.sh"]
