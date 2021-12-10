FROM google/cloud-sdk:366.0.0-slim

# Install kubectl
RUN apt-get update && apt install unzip && \
      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
      chmod +x ./kubectl && \
      mv ./kubectl /usr/local/bin/kubectl

# Install helm
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && \
      chmod 700 get_helm.sh && \
	./get_helm.sh

# Install terraform
RUN apt-get update && apt-get install -y gnupg software-properties-common curl && \
      curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add - && \
      apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" && \
      apt-get update && apt-get install terraform

ADD . /app
RUN find /app -type f -name '*.sh' -exec chmod +x {} \;

WORKDIR /app

CMD ["/app/src/deploy.sh"]
