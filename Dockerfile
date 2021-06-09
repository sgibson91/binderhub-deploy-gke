FROM google/cloud-sdk:317.0.0-slim

RUN apt-get update && apt install unzip && \
      # Install kubectl
      curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && \
      chmod +x ./kubectl && \
      mv ./kubectl /usr/local/bin/kubectl && \
      # Install helm
      curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 && \
      chmod 700 get_helm.sh && \
	  ./get_helm.sh && \
      # Install terraform
      curl -fsSL -o terraform_0.13.5_linux_amd64.zip https://releases.hashicorp.com/terraform/0.13.5/terraform_0.13.5_linux_amd64.zip && \
      unzip terraform_0.13.5_linux_amd64.zip && \
      mv ./terraform /usr/local/bin/terraform && \
      rm -rf terraform_0.13.5_linux_amd64.zip

ADD . /app
RUN find /app -type f -name '*.sh' -exec chmod +x {} \;

WORKDIR /app

CMD ["/app/src/deploy.sh"]
