FROM alpine

RUN mkdir -p /opt/terraform_templates && \
mkdir -p /opt/deployment_scripts && \
mkdir -p /opt/dependencies && \
apk add terraform --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community && \
apk add --no-cache --upgrade bash && \
apk add --no-cache python3 py3-pip && \
pip install boto3 && \
pip install localstack_client && \
pip install awscli && \
pip install python-hcl2 && \
mkdir /opt/deployments && \
apk add curl 

ADD terraform_templates /opt/terraform_templates
ADD deployment_scripts /opt/deployment_scripts
ADD dependencies /opt/dependencies
SHELL ["/bin/bash","-c"]
RUN chmod u+x /opt/deployment_scripts/test.sh && \
chmod u+x /opt/dependencies/awslocal && \
chmod u+x /opt/dependencies/tflocal

ENV PATH="$PATH:/opt/dependencies"
ENTRYPOINT ["/opt/deployment_scripts/test.sh"]